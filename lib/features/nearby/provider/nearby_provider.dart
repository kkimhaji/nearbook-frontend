import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/socket/socket_client.dart';
import '../../../shared/socket/socket_events.dart';
import '../../../shared/models/user.dart';
import '../../../shared/ble/ble_peripheral_service.dart';

const String kBleServiceUuid = '12345678-1234-1234-1234-123456789abc';
final _tokenRegex = RegExp(r'^[0-9a-f]{8}$');

class NearbyNotifier extends StateNotifier<NearbyState> {
  NearbyNotifier() : super(const NearbyState());

  Timer? _tokenRefreshTimer;
  StreamSubscription? _scanResultsSub;
  StreamSubscription? _isScanningSSub;

  // 세션 내 감지된 토큰 전체 (중복 전송 방지용)
  final Set<String> _detectedTokens = {};

  // userId → UserModel 누적 맵 (교체 대신 merge에 사용)
  final Map<String, UserModel> _nearbyUserMap = {};

  Future<void> initBleToken() async {
    debugPrint('[BLE][Token] BLE 토큰 초기화 시작');
    await _fetchAndAdvertise();

    _tokenRefreshTimer = Timer.periodic(
      const Duration(minutes: 9),
      (_) {
        debugPrint('[BLE][Token] 토큰 갱신 타이머 실행');
        _fetchAndAdvertise();
      },
    );
  }

  Future<void> _fetchAndAdvertise() async {
    try {
      debugPrint('[BLE][Token] 서버에서 BLE 토큰 요청 중...');
      final response = await DioClient.instance.post('/users/ble-token');
      final token = response.data['token'] as String;
      debugPrint('[BLE][Token] 토큰 발급 성공: $token');
      await BlePeripheralService.startAdvertising(token);
    } catch (e) {
      debugPrint('[BLE][Token] 토큰 발급 실패 ❌: $e');
    }
  }

  Future<void> startScan() async {
    await _scanResultsSub?.cancel();
    await _isScanningSSub?.cancel();

    final isSupported = await FlutterBluePlus.isSupported;
    debugPrint('[BLE][Scan] isSupported: $isSupported');
    if (!isSupported) return;

    BluetoothAdapterState adapterState =
        await FlutterBluePlus.adapterState.first;
    debugPrint('[BLE][Scan] 초기 상태: $adapterState');

    if (adapterState != BluetoothAdapterState.on) {
      debugPrint('[BLE][Scan] on 상태 대기 중...');
      try {
        adapterState = await FlutterBluePlus.adapterState
            .where((s) => s == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        debugPrint('[BLE][Scan] 타임아웃 → 강제 진행');
      }
      debugPrint('[BLE][Scan] 확정 상태: $adapterState');
    }

    if (!mounted) return;

    // 스캔 시작 시 누적 데이터 초기화
    state = state.copyWith(isScanning: true, nearbyUsers: []);
    _detectedTokens.clear();
    _nearbyUserMap.clear();

    await Future.delayed(const Duration(milliseconds: 500));

    final isIOS = Platform.isIOS;
    debugPrint(
        '[BLE][Scan] 스캔 시작 (${isIOS ? "iOS: 필터 없음" : "Android: serviceUUID 필터"})');

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      androidScanMode: AndroidScanMode.lowLatency,
    );

    _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      if (results.isEmpty) return;
      if (!mounted) return;
      _onScanResult(results);
    });

    _isScanningSSub = FlutterBluePlus.isScanning.listen((scanning) {
      debugPrint('[BLE][Scan] 스캔 상태: $scanning');
      if (!mounted) return;
      if (!scanning) {
        state = state.copyWith(isScanning: false);
        debugPrint('[BLE][Scan] 완료. 감지 토큰: $_detectedTokens');
      }
    });
  }

  Future<void> stopScan() async {
    debugPrint('[BLE][Scan] 스캔 중지');
    await FlutterBluePlus.stopScan();
    await _scanResultsSub?.cancel();
    await _isScanningSSub?.cancel();
    await BlePeripheralService.stopAdvertising();
    _tokenRefreshTimer?.cancel();
    _detectedTokens.clear();
    _nearbyUserMap.clear();
    if (mounted) state = state.copyWith(isScanning: false, nearbyUsers: []);
  }

  void _onScanResult(List<ScanResult> results) {
    if (!mounted) return;

    final newTokens = <String>[];

    for (final result in results) {
      String? token;

      // 1순위: serviceUUID에서 token 추출
      for (final uuid in result.advertisementData.serviceUuids) {
        final uuidStr = uuid.toString().toLowerCase();
        final extracted = BlePeripheralService.uuidToToken(uuidStr);
        if (extracted != null) {
          debugPrint(
              '[BLE][Token] ✅ serviceUUID에서 token 추출: $extracted (UUID: $uuidStr)');
          token = extracted;
          break;
        }
      }

      // 2순위: localName regex (Android → Android fallback)
      if (token == null) {
        final localName = result.advertisementData.localName;
        if (localName.isNotEmpty && _tokenRegex.hasMatch(localName)) {
          debugPrint('[BLE][Token] ✅ localName에서 token 추출: $localName');
          token = localName;
        }
      }

      if (token != null && !_detectedTokens.contains(token)) {
        _detectedTokens.add(token);
        newTokens.add(token);
      }
    }

    if (newTokens.isNotEmpty) {
      // 새 토큰이 생길 때마다 세션 내 전체 감지 토큰을 전송
      // → 서버가 현재 가시적인 유저 전체를 응답하므로 누락 없이 merge 가능
      final allTokens = _detectedTokens.toList();
      debugPrint('[BLE][Socket] 서버로 전체 감지 토큰 전송: $allTokens');
      SocketClient.instance?.emit(
        SocketEvents.bleDetected,
        {'deviceTokens': allTokens},
      );
    }
  }

  /// 서버 응답 유저 목록을 기존 목록에 merge (교체하지 않음)
  void updateNearbyUsers(List<UserModel> users) {
    if (!mounted) return;

    for (final user in users) {
      _nearbyUserMap[user.id] = user;
    }

    final merged = _nearbyUserMap.values.toList();
    debugPrint(
        '[NearbyNotifier] 유저 목록 merge: ${merged.map((u) => u.username).toList()}');
    state = state.copyWith(nearbyUsers: merged);
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    _scanResultsSub?.cancel();
    _isScanningSSub?.cancel();
    BlePeripheralService.stopAdvertising();
    super.dispose();
  }
}

class NearbyState {
  final List<UserModel> nearbyUsers;
  final bool isScanning;

  const NearbyState({
    this.nearbyUsers = const [],
    this.isScanning = false,
  });

  NearbyState copyWith({
    List<UserModel>? nearbyUsers,
    bool? isScanning,
  }) {
    return NearbyState(
      nearbyUsers: nearbyUsers ?? this.nearbyUsers,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

final nearbyProvider = StateNotifierProvider<NearbyNotifier, NearbyState>(
  (ref) => NearbyNotifier(),
);

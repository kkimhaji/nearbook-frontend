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
  final Set<String> _detectedTokens = {};

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
    state = state.copyWith(isScanning: true);
    _detectedTokens.clear();

    await Future.delayed(const Duration(milliseconds: 500));

    // 플랫폼별 스캔 전략
    // Android: withServices 필터 사용 (정상 동작)
    // iOS: 필터 없이 전체 스캔 후 regex로 토큰 식별
    final isIOS = Platform.isIOS;
    debugPrint(
        '[BLE][Scan] 스캔 시작 (${isIOS ? "iOS: 필터 없음" : "Android: serviceUUID 필터"})');

    await FlutterBluePlus.startScan(
      // withServices: isIOS ? [] : [Guid(kBleServiceUuid)],
      timeout: const Duration(seconds: 15),
      androidScanMode: AndroidScanMode.lowLatency,
    );

    _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      if (results.isEmpty) return;
      // debugPrint('[BLE][Scan] 결과: ${results.length}개');
      // for (final r in results) {
      //   debugPrint(
      //     '[BLE][Scan] → remoteId: ${r.device.remoteId} | '
      //     'RSSI: ${r.rssi} | '
      //     'localName: "${r.advertisementData.localName}" | '
      //     'serviceUUIDs: ${r.advertisementData.serviceUuids} | '
      //     'serviceDataKeys: ${r.advertisementData.serviceData.keys.toList()} | '
      //     'manufacturerData: ${r.advertisementData.manufacturerData}', // 추가
      //   );
      // }
      if (!mounted) return;
      _onScanResult(results);
    });

    _isScanningSSub = FlutterBluePlus.isScanning.listen((scanning) {
      debugPrint('[BLE][Scan] 스캔 상태: $scanning');
      if (!mounted) return; // StateNotifier mounted 체크
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
    if (mounted) state = state.copyWith(isScanning: false);
  }

  void _onScanResult(List<ScanResult> results) {
    if (!mounted) return;

    final newTokens = <String>[];

    for (final result in results) {
      String? token;

      // 1순위: serviceUUID에서 token 추출
      // Primary Advertisement 패킷에 포함 → iOS/Android 모두 안정적
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
      debugPrint('[BLE][Socket] 서버로 토큰 전송: $newTokens');
      SocketClient.instance?.emit(
        SocketEvents.bleDetected,
        {'deviceTokens': newTokens},
      );
    }
  }

  void updateNearbyUsers(List<UserModel> users) {
    if (!mounted) return;
    debugPrint(
        '[NearbyNotifier] 유저 목록 업데이트: ${users.map((u) => u.username).toList()}');
    state = state.copyWith(nearbyUsers: users);
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

import 'dart:async';
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
    await _fetchAndAdvertise();

    _tokenRefreshTimer = Timer.periodic(
      const Duration(minutes: 9),
      (_) => _fetchAndAdvertise(),
    );
  }

  Future<void> _fetchAndAdvertise() async {
    try {
      final response = await DioClient.instance.post('/users/ble-token');
      final token = response.data['token'] as String;
      await BlePeripheralService.startAdvertising(token);
    } catch (e) {
      return;
    }
  }

  // BLE 스캔 시작
  Future<void> startScan() async {
    // 기존 구독 취소 후 재시작 (중복 리스너 방지)
    await _scanResultsSub?.cancel();
    await _isScanningSSub?.cancel();

    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) return;

    if (!mounted) return;
    state = state.copyWith(isScanning: true);
    _detectedTokens.clear();

    await FlutterBluePlus.startScan(
      withServices: [Guid(kBleServiceUuid)],
      timeout: const Duration(seconds: 10),
    );

    _scanResultsSub = FlutterBluePlus.scanResults.listen(_onScanResult);

    _isScanningSSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && mounted) {
        state = state.copyWith(isScanning: false);
      }
    });
  }

  Future<void> stopScan() async {
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
      // 1. localName에서 token 추출 (iOS/Android 공통)
      final localName = result.advertisementData.localName;
      if (localName != null &&
          localName.isNotEmpty &&
          _tokenRegex.hasMatch(localName) &&
          !_detectedTokens.contains(localName)) {
        _detectedTokens.add(localName);
        newTokens.add(localName);
        continue;
      }

      // 2. serviceData에서 token 추출 (Android 광고 → Android 스캔 fallback)
      final serviceData = result.advertisementData.serviceData;
      final tokenBytes = serviceData[Guid(kBleServiceUuid)];
      if (tokenBytes != null) {
        final token = String.fromCharCodes(tokenBytes);
        if (_tokenRegex.hasMatch(token) && !_detectedTokens.contains(token)) {
          _detectedTokens.add(token);
          newTokens.add(token);
        }
      }
    }

    if (newTokens.isEmpty) return;

    SocketClient.instance?.emit(
      SocketEvents.bleDetected,
      {'deviceTokens': newTokens},
    );
  }

  void listenBleResult() {
    SocketClient.instance?.on(SocketEvents.bleDetectedResult, (data) {
      if (!mounted) return;
      final users = (data['detectedUsers'] as List)
          .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
          .toList();
      state = state.copyWith(nearbyUsers: users);
    });
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

// 상태 클래스 분리
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

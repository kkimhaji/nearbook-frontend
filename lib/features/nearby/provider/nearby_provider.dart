import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/socket/socket_client.dart';
import '../../../shared/socket/socket_events.dart';
import '../../../shared/models/user.dart';
import '../../../shared/ble/ble_peripheral_service.dart';

const String kBleServiceUuid = '12345678-1234-1234-1234-123456789abc';

class NearbyNotifier extends StateNotifier<NearbyState> {
  NearbyNotifier() : super(const NearbyState());

  Timer? _tokenRefreshTimer;
  StreamSubscription? _scanResultsSub;
  StreamSubscription? _isScanningSub;
  final Set<String> _detectedTokens = {};

  Future<void> initBleToken() async {
    await _fetchAndAdvertise();

    // 9분마다 토큰 갱신 및 광고 재시작
    _tokenRefreshTimer = Timer.periodic(
      const Duration(minutes: 9),
      (_) => _fetchAndAdvertise(),
    );
  }

  Future<void> _fetchAndAdvertise() async {
    try {
      final response = await DioClient.instance.post('/users/ble-token');
      final token = response.data['token'] as String;

      // 새 토큰으로 BLE 광고 시작
      await BlePeripheralService.startAdvertising(token);
    } catch (e) {
      return;
    }
  }

  // BLE 스캔 시작
  Future<void> startScan() async {
    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) return;

    await _scanResultsSub?.cancel();
    await _isScanningSub?.cancel();

    state = state.copyWith(isScanning: true);
    _detectedTokens.clear();

    await FlutterBluePlus.startScan(
      withServices: [Guid(kBleServiceUuid)],
      timeout: const Duration(seconds: 10),
    );

    _scanResultsSub = FlutterBluePlus.scanResults.listen(_onScanResult);

    _isScanningSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning) {
        state = state.copyWith(isScanning: false);
      }
    });
  }

  // BLE 스캔 중지
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await BlePeripheralService.stopAdvertising();
    _tokenRefreshTimer?.cancel();
    _detectedTokens.clear();
    state = state.copyWith(isScanning: false);
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    _scanResultsSub?.cancel();
    _isScanningSub?.cancel();
    BlePeripheralService.stopAdvertising();
    super.dispose();
  }

  void _onScanResult(List<ScanResult> results) {
    final newTokens = <String>[];

    for (final result in results) {
      final serviceData = result.advertisementData.serviceData;
      final tokenBytes = serviceData[Guid(kBleServiceUuid)];
      if (tokenBytes == null) continue;

      final token = String.fromCharCodes(tokenBytes);
      if (_detectedTokens.contains(token)) continue;

      _detectedTokens.add(token);
      newTokens.add(token);
    }

    if (newTokens.isEmpty) return;

    SocketClient.instance?.emit(
      SocketEvents.bleDetected,
      {'deviceTokens': newTokens},
    );
  }

  void listenBleResult() {
    SocketClient.instance?.on(SocketEvents.bleDetectedResult, (data) {
      final users = (data['detectedUsers'] as List)
          .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
          .toList();
      state = state.copyWith(nearbyUsers: users);
    });
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

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/socket/socket_client.dart';
import '../../../shared/socket/socket_events.dart';
import '../../../shared/models/user.dart';

class NearbyNotifier extends StateNotifier<List<UserModel>> {
  NearbyNotifier() : super([]);

  Timer? _tokenRefreshTimer;
  String? _currentBleToken;
  final Set<String> _detectedTokens = {};

  // BLE 토큰 발급 및 주기적 갱신
  Future<void> initBleToken() async {
    await _fetchAndStoreBleToken();

    // 9분마다 갱신 (만료 10분 기준)
    _tokenRefreshTimer = Timer.periodic(
      const Duration(minutes: 9),
      (_) => _fetchAndStoreBleToken(),
    );
  }

  Future<void> _fetchAndStoreBleToken() async {
    try {
      final response = await DioClient.instance.post('/users/ble-token');
      _currentBleToken = response.data['token'] as String;
    } catch (e) {
      return;
    }
  }

  Future<void> startScan() async {
    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) return;

    _detectedTokens.clear();

    await FlutterBluePlus.startScan(
      withServices: [Guid(kBleServiceUuid)],
      timeout: const Duration(seconds: 10),
    );

    FlutterBluePlus.scanResults.listen(_onScanResult);
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _tokenRefreshTimer?.cancel();
    _detectedTokens.clear();
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

    SocketClient.instance.emit(
      SocketEvents.bleDetected,
      {'deviceTokens': newTokens},
    );
  }

  void listenBleResult() {
    SocketClient.instance.on(SocketEvents.bleDetectedResult, (data) {
      final users = (data['detectedUsers'] as List)
          .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
          .toList();
      state = users;
    });
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    super.dispose();
  }
}

const String kBleServiceUuid = '12345678-1234-1234-1234-123456789abc';

final nearbyProvider = StateNotifierProvider<NearbyNotifier, List<UserModel>>(
  (ref) => NearbyNotifier(),
);

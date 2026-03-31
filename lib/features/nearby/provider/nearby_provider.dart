import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../shared/socket/socket_client.dart';
import '../../../shared/socket/socket_events.dart';
import '../../../shared/models/user.dart';

// BLE 서비스 UUID (앱 고유값)
const String kBleServiceUuid = '12345678-1234-1234-1234-123456789abc';
const String kBleCharacteristicUuid = '87654321-4321-4321-4321-cba987654321';

class NearbyNotifier extends StateNotifier<List<UserModel>> {
  NearbyNotifier() : super([]);

  final Set<String> _detectedTokens = {};

  // BLE 스캔 시작
  Future<void> startScan() async {
    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) return;

    await FlutterBluePlus.startScan(
      withServices: [Guid(kBleServiceUuid)],
      timeout: const Duration(seconds: 10),
    );

    FlutterBluePlus.scanResults.listen(_onScanResult);
  }

  // BLE 스캔 중지
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _detectedTokens.clear();
  }

  // BLE 광고 시작 (자신을 브로드캐스트)
  Future<void> startAdvertising(String token) async {
    // flutter_blue_plus는 Central 역할(스캔)만 지원
    // Peripheral(광고) 역할은 추후 별도 패키지 검토 필요
    // 현재는 토큰을 서비스 데이터에 포함하는 방식으로 구현 예정
  }

  void _onScanResult(List<ScanResult> results) {
    final newTokens = <String>[];

    for (final result in results) {
      final serviceData = result.advertisementData.serviceData;

      // 서비스 데이터에서 device_token 추출
      final tokenBytes = serviceData[Guid(kBleServiceUuid)];
      if (tokenBytes == null) continue;

      final token = String.fromCharCodes(tokenBytes);
      if (_detectedTokens.contains(token)) continue;

      _detectedTokens.add(token);
      newTokens.add(token);
    }

    if (newTokens.isEmpty) return;

    // 서버로 감지된 토큰 전송 → WebSocket 응답으로 user 정보 수신
    SocketClient.instance.emit(
      SocketEvents.bleDetected,
      {'deviceTokens': newTokens},
    );
  }

  // 서버로부터 BLE 감지 결과 수신
  void listenBleResult() {
    SocketClient.instance.on(SocketEvents.bleDetectedResult, (data) {
      final users = (data['detectedUsers'] as List)
          .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
          .toList();
      state = users;
    });
  }
}

final nearbyProvider = StateNotifierProvider<NearbyNotifier, List<UserModel>>(
  (ref) => NearbyNotifier(),
);

// lib/shared/ble/ble_peripheral_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class BlePeripheralService {
  static final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  // NearBook UUID 접미사 (고정)
  static const String _uuidSuffix = '-1234-1234-1234-123456789abc';

  // token → NearBook UUID 변환
  static String tokenToUuid(String token) => '$token$_uuidSuffix';

  // NearBook UUID → token 추출 (null이면 NearBook UUID 아님)
  static String? uuidToToken(String uuid) {
    if (uuid.endsWith(_uuidSuffix) && uuid.length == 36) {
      final token = uuid.substring(0, 8);
      if (RegExp(r'^[0-9a-f]{8}$').hasMatch(token)) return token;
    }
    return null;
  }

  static Future<bool> isSupported() async {
    final supported = await _peripheral.isSupported;
    debugPrint('[BLE][Peripheral] isSupported: $supported');
    return supported;
  }

  static Future<void> startAdvertising(String token) async {
    final supported = await isSupported();
    if (!supported) {
      debugPrint('[BLE][Peripheral] 광고 불가: Peripheral 미지원');
      return;
    }

    final isAdvertising = await _peripheral.isAdvertising;
    if (isAdvertising) {
      debugPrint('[BLE][Peripheral] 기존 광고 중지 후 재시작');
      await stopAdvertising();
    }

    // token을 serviceUUID에 인코딩
    // Primary Advertisement 패킷에 포함 → iOS에서 항상 읽기 가능
    final dynamicUuid = tokenToUuid(token);
    debugPrint('[BLE][Peripheral] 광고 시작 - token: $token → UUID: $dynamicUuid');

    final advertiseData = AdvertiseData(
      serviceUuid: dynamicUuid,
      localName: token, // Android 스캐너 호환용 fallback
      includeDeviceName: false,
    );

    final advertiseSetParameters = AdvertiseSetParameters(
      legacyMode: true,
      connectable: false,
    );

    try {
      await _peripheral.start(
        advertiseData: advertiseData,
        advertiseSetParameters: advertiseSetParameters,
      );
      debugPrint('[BLE][Peripheral] 광고 시작 성공 ✅');
    } catch (e) {
      debugPrint('[BLE][Peripheral] AdvertiseSetParameters 실패 ❌: $e');

      final advertiseSettings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
        connectable: false,
        timeout: 0,
        advertiseSet: false,
      );
      try {
        await _peripheral.start(
          advertiseData: advertiseData,
          advertiseSettings: advertiseSettings,
        );
        debugPrint('[BLE][Peripheral] Fallback 광고 시작 성공 ✅');
      } catch (e2) {
        debugPrint('[BLE][Peripheral] Fallback도 실패 ❌: $e2');
      }
    }
  }

  static Future<void> stopAdvertising() async {
    final isAdvertising = await _peripheral.isAdvertising;
    if (isAdvertising) {
      await _peripheral.stop();
      debugPrint('[BLE][Peripheral] 광고 중지 완료');
    }
  }

  static Stream<PeripheralState>? get advertisingStateStream =>
      _peripheral.onPeripheralStateChanged;
}

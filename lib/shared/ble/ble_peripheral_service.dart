import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class BlePeripheralService {
  static final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  static const String serviceUuid = '12345678-1234-1234-1234-123456789abc';

  static Future<bool> isSupported() async {
    final supported = await _peripheral.isSupported;
    debugPrint('[BLE][Peripheral] isSupported: $supported');
    return supported;
  }

  static Future<void> startAdvertising(String token) async {
    final supported = await isSupported();
    if (!supported) {
      debugPrint('[BLE][Peripheral] 광고 불가: 기기가 Peripheral을 지원하지 않음');
      return;
    }

    final isAdvertising = await _peripheral.isAdvertising;
    debugPrint('[BLE][Peripheral] 현재 광고 상태: $isAdvertising');

    if (isAdvertising) {
      debugPrint('[BLE][Peripheral] 기존 광고 중지 후 재시작');
      await stopAdvertising();
    }

    debugPrint(
        '[BLE][Peripheral] 광고 시작 시도 - token: $token (${token.length}자, ${token.codeUnits.length}bytes)');

    final advertiseData = AdvertiseData(
      serviceUuid: serviceUuid,
      localName: token,
      includeDeviceName: false,
    );

    final advertiseSettings = AdvertiseSettings(
      advertiseMode: AdvertiseMode.advertiseModeBalanced,
      txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
      connectable: false,
      timeout: 0,
    );

    try {
      await _peripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );
      debugPrint('[BLE][Peripheral] 광고 시작 성공 ✅');
    } catch (e) {
      debugPrint('[BLE][Peripheral] 광고 시작 실패 ❌: $e');
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

import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class BlePeripheralService {
  static final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  static const String _serviceUuid = '12345678-1234-1234-1234-123456789abc';

  static Future<bool> isSupported() async {
    return _peripheral.isSupported;
  }

  static Future<void> startAdvertising(String token) async {
    final isSupported = await BlePeripheralService.isSupported();
    if (!isSupported) return;

    final isAdvertising = await _peripheral.isAdvertising;
    if (isAdvertising) {
      await stopAdvertising();
    }

    final tokenBytes = token.codeUnits;

    final advertiseData = AdvertiseData(
      serviceUuid: _serviceUuid,
      serviceData: tokenBytes,
      includeDeviceName: false,
    );

    final advertiseSettings = AdvertiseSettings(
      advertiseMode: AdvertiseMode.advertiseModeBalanced,
      txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
      connectable: false,
      timeout: 0,
    );

    await _peripheral.start(
      advertiseData: advertiseData,
      advertiseSettings: advertiseSettings,
    );
  }

  static Future<void> stopAdvertising() async {
    final isAdvertising = await _peripheral.isAdvertising;
    if (isAdvertising) {
      await _peripheral.stop();
    }
  }

  static Stream<PeripheralState>? get advertisingStateStream =>
      _peripheral.onPeripheralStateChanged;
}

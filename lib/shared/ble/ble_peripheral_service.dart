import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class BlePeripheralService {
  static final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  static const String serviceUuid = '12345678-1234-1234-1234-123456789abc';

  static Future<bool> isSupported() async {
    return _peripheral.isSupported;
  }

  static Future<void> startAdvertising(String token) async {
    final supported = await isSupported();
    if (!supported) return;

    final isAdvertising = await _peripheral.isAdvertising;
    if (isAdvertising) await stopAdvertising();

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

    await _peripheral.start(
      advertiseData: advertiseData,
      advertiseSettings: advertiseSettings,
    );
  }

  static Future<void> stopAdvertising() async {
    final isAdvertising = await _peripheral.isAdvertising;
    if (isAdvertising) await _peripheral.stop();
  }

  static Stream<PeripheralState>? get advertisingStateStream =>
      _peripheral.onPeripheralStateChanged;
}

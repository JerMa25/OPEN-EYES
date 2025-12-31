import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:http/http.dart' as http;

import '../model/message.dart';



class BLEService {
  static const String SERVICE_UUID = "12345678-1234-1234-1234-1234567890ab";
  static const String CHAR_UUID = "abcd1234-1234-1234-1234-abcdefabcdef";

  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;

  Future<void> connectToESP32() async {
  await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

  FlutterBluePlus.scanResults.listen((results) async {
    for (ScanResult r in results) {
      if (r.device.platformName == "OPEN_EYES_CANE") {
        device = r.device;
        await FlutterBluePlus.stopScan();
        await device!.connect(autoConnect: false);
        await _discoverServices();
        return;
      }
    }
  });
}

  Future<void> _discoverServices() async {
    final services = await device!.discoverServices();
    for (var service in services) {
      if (service.uuid.toString() == SERVICE_UUID) {
        for (var char in service.characteristics) {
          if (char.uuid.toString() == CHAR_UUID) {
            characteristic = char;
            await characteristic!.setNotifyValue(true);
          }
        }
      }
    }
  }

  Stream<String> listenMessages() {
  if (characteristic == null) {
    return const Stream.empty();
  }
  return characteristic!.lastValueStream.map((value) => utf8.decode(value));
}

  Future<void> saveMessageToBackend(Message message) async {
  await http.post(
    Uri.parse("https://ton-backend/api/messages/"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "content": message.content,
      "receiver": message.receiver,
    }),
  );
}
}




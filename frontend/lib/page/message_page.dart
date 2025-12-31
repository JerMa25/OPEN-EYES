import 'dart:convert';
import 'package:flutter/material.dart';
import '../model/message.dart';
import '../services/ble_service.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final BLEService bleService = BLEService();
  final List<Message> messages = [
  Message(
    content: "Obstacle détecté devant vous",
    receiver: "Canne intelligente",
    avatarText: "🦯",
    useEmoji: true,
  ),
];


  @override
  void initState() {
    super.initState();
    _initBLE();
  }

  void _initBLE() async {
  await bleService.connectToESP32();

  bleService.listenMessages().listen((data) async {
    try {
      final jsonData = jsonDecode(data);
      final message = Message.fromJson(jsonData);

      setState(() {
        messages.insert(0, message);
      });

      // 🔹 ENREGISTREMENT BACKEND
      await bleService.saveMessageToBackend(message);

    } catch (e) {
      debugPrint("Message BLE invalide: $data");
    }
  });
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text("Messages reçus")),
      body: ListView.builder(
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final m = messages[index];
          return Semantics(
            label: m.content,
            child: ListTile(
              leading: Text(
                m.avatarText,
                style: const TextStyle(fontSize: 28),
              ),
              title: Text(
                m.content,
                style: const TextStyle(fontSize: 20),
              ),
              subtitle: Text(m.receiver),
            ),
          );
        },
      ),
    );
  }
}

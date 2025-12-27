import 'package:flutter/material.dart';

class OpenEyesApp extends StatelessWidget {
  const OpenEyesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Eyes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: Center(
          child: Text(
            'OPEN EYES\nSystem Initializing...',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26),
          ),
        ),
      ),
    );
  }
}

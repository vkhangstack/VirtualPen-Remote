import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'connect_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const VirtualPenApp());
}

class VirtualPenApp extends StatelessWidget {
  const VirtualPenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VirtualPen Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD24726), brightness: Brightness.dark),
      ),
      home: const ConnectScreen(),
    );
  }
}

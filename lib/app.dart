import 'package:flutter/material.dart';

import 'package:dranyen/features/tuner/tuner_screen.dart';

/// Root app + theme. The tuner is the home screen for now; when more features
/// (player, learn, record) graduate from behind their flags, a home hub can
/// become the initial route here without touching the features themselves.
class DranyenApp extends StatelessWidget {
  const DranyenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dranyen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4A853),
          brightness: Brightness.dark,
        ),
      ),
      home: const TunerScreen(),
    );
  }
}

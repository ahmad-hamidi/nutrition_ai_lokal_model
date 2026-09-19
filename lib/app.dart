import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

class NutriLensApp extends StatelessWidget {
  const NutriLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color seed = Color(0xFF2E7D32);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NutriLens Qwen Offline',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

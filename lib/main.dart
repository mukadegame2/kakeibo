// ========================================
// 家計簿アプリ
// 学習用・個人開発用
// ========================================

// インポート
import 'package:flutter/material.dart';

import 'screens/main_screen.dart';   // メインシーン

// ========================================
// アプリ起動
// ========================================
void main() {
  runApp(const KakeiboApp());
}

// ========================================
// アプリ本体
// ========================================
class KakeiboApp extends StatelessWidget {
  const KakeiboApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '家計簿',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const MainScreen(),
    );
  }
}



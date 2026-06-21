// ========================================
// 家計簿アプリ
// 学習用・個人開発用
// ========================================

// インポート
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/main_screen.dart'; // メインシーン

// ========================================
// アプリ起動
// ========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ja_JP', null);

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

      locale: const Locale('ja', 'JP'),

      supportedLocales: const [Locale('ja', 'JP')],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),

      home: const MainScreen(),
    );
  }
}

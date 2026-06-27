// ========================================
// おうち家計簿
// 収入・支出・カテゴリ・カレンダー・グラフ・貯金額を管理するアプリ
// ========================================

// インポート
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/main_screen.dart'; // メイン画面

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
      title: 'おうち家計簿',

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

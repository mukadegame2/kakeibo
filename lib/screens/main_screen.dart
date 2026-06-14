import 'package:flutter/material.dart'; // Flutter UIライブラリ
import 'package:shared_preferences/shared_preferences.dart'; // データ保存用ライブラリ
import 'dart:convert'; // JSON変換用

import '../models/expense.dart'; // 家計簿データクラス
import '../pages/input_page.dart'; // 入力画面
import '../pages/calendar_page.dart'; // カレンダー画面
import '../pages/graph_page.dart'; // グラフ画面
import '../pages/setting_page.dart'; // 設定画面

// ========================================
// メイン画面
// 下部メニュー管理
// ========================================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// ========================================
// メイン画面の状態管理クラス
// ・下部メニューの切替
// ・家計簿データの保持
// ・保存／読込処理
// を担当する
// ========================================
class _MainScreenState extends State<MainScreen> {
  // 現在選択中の下部メニュー番号
  // 0:入力 1:カレンダー 2:グラフ 3:設定
  int _selectedIndex = 0;

  // 家計簿データ一覧
  final List<Expense> expenses = [];

  // ========================================
  // 画面起動時処理
  // 保存済みデータを読み込む
  // ========================================
  @override
  void initState() {
    super.initState();
    loadExpenses();
  }

  // ========================================
  // 家計簿データを端末へ保存
  // SharedPreferencesを使用
  // ========================================
  Future<void> saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();

    // ExpenseオブジェクトをJSON文字列へ変換
    final jsonList = expenses.map((e) => jsonEncode(e.toJson())).toList();

    await prefs.setStringList('expenses', jsonList);
  }

  // ========================================
  // 保存済みデータを読み込む
  // アプリ起動時に呼ばれる
  // ========================================
  Future<void> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonList = prefs.getStringList('expenses');

    // 保存データが無ければ終了
    if (jsonList == null) {
      return;
    }

    setState(() {
      expenses.clear();

      // JSON文字列をExpenseオブジェクトへ変換
      expenses.addAll(jsonList.map((e) => Expense.fromJson(jsonDecode(e))));
    });
  }

  // ========================================
  // 選択中タブに応じて画面を切り替える
  // ========================================
  Widget _buildPage() {
    switch (_selectedIndex) {
      // 入力画面
      case 0:
        return InputPage(expenses: expenses, onSave: saveExpenses);

      // カレンダー画面
      case 1:
        return CalendarPage(expenses: expenses, onSave: saveExpenses);

      // グラフ画面
      case 2:
        return GraphPage(expenses: expenses);

      // 設定画面
      case 3:
        return SettingPage(expenses: expenses, onSave: saveExpenses);

      // それ以外は空画面
      default:
        return const SizedBox();
    }
  }

  // ========================================
  // メイン画面描画
  // ========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('家計簿アプリ')),

      // 選択中画面表示
      body: _buildPage(),

      // 下部メニュー
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,

        // メニュー選択時の処理
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit), label: '入力'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'カレンダー',
          ),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: 'グラフ'),
          NavigationDestination(icon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}

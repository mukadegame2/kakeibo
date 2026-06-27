import 'package:flutter/material.dart'; // Flutter UIライブラリ
import 'package:shared_preferences/shared_preferences.dart'; // データ保存用ライブラリ
import 'dart:convert'; // JSON変換用

import '../models/expense.dart'; // 家計簿データクラス
import '../pages/input_page.dart'; // 入力画面
import '../pages/calendar_page.dart'; // カレンダー画面
import '../pages/graph_page.dart'; // グラフ画面
import '../pages/setting_page.dart'; // 設定画面

import '../services/initial_setup_service.dart';
import '../services/savings_service.dart';
import '../utils/amount_parser.dart';

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

  bool _initialSetupDialogShown = false;

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

    final jsonList = prefs.getStringList('expenses') ?? [];

    final loadedExpenses = <Expense>[];

    for (final jsonText in jsonList) {
      try {
        loadedExpenses.add(Expense.fromJson(jsonDecode(jsonText)));
      } catch (_) {
        // 壊れたデータは読み飛ばす
      }
    }

    if (!mounted) return;

    setState(() {
      expenses.clear();
      expenses.addAll(loadedExpenses);
    });

    await _checkInitialSetup();
  }

  Future<void> _checkInitialSetup() async {
    final hasCompleted = await InitialSetupService.hasCompletedInitialSetup();

    if (!mounted) {
      return;
    }

    // 既にデータがある場合は、初期設定済みとして扱う
    if (expenses.isNotEmpty) {
      if (!hasCompleted) {
        await InitialSetupService.completeInitialSetup();
      }
      return;
    }

    if (hasCompleted || _initialSetupDialogShown) {
      return;
    }

    _initialSetupDialogShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _showInitialSetupDialog();
    });
  }

  Future<void> _showInitialSetupDialog() async {
    final controller = TextEditingController(text: '0');

    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('初期設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '最初に、現在の貯金額を設定できます。\n'
                'あとから設定画面で変更できます。',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '初期貯金額',
                  prefixText: '¥ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, 0);
              },
              child: const Text('0円で始める'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = AmountParser.parseNonNegativeInt(
                  controller.text,
                );

                if (amount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('初期貯金額は0以上の数字で入力してください')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, amount);
              },
              child: const Text('保存して始める'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) {
      return;
    }

    await SavingsService.saveInitialSavings(result);
    await InitialSetupService.completeInitialSetup();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('初期設定を保存しました')));
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
        return GraphPage(expenses: expenses, onSave: saveExpenses);

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
      appBar: AppBar(title: const Text('おうち家計簿')),

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

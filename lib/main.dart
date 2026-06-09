// ========================================
// 家計簿アプリ
// 学習用・個人開発用
// ========================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ========================================
// アプリ起動
// ========================================
void main()
{
  runApp(const KakeiboApp());
}

// ========================================
// アプリ本体
// ========================================
class KakeiboApp extends StatelessWidget
{
  const KakeiboApp({super.key});

  @override
  Widget build(BuildContext context)
  {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '家計簿',
      theme: ThemeData(
      	colorSchemeSeed: Colors.indigo,
      	useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

// ========================================
// メイン画面
// 下部メニュー管理
// ========================================
class MainScreen extends StatefulWidget
{
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// ========================================
// 家計簿データクラス
// 支出・収入1件分を保持
// ========================================
class Expense
{
  final int amount;
  final String category;
  final String memo;
  final DateTime date;
  final bool isIncome;

  Expense(
    {
    required this.amount,
    required this.category,
    required this.memo,
    required this.date,
    required this.isIncome,
  });

  // JSON保存用
  Map<String, dynamic> toJson()
  {
    return {
      'amount': amount,
      'category': category,
      'memo': memo,
      'date': date.toIso8601String(),
      'isIncome': isIncome,
    };
  }

  // JSON読込用
  factory Expense.fromJson(Map<String, dynamic> json)
  {
    return Expense(
      amount: json['amount'],
      category: json['category'],
      memo: json['memo'],
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      isIncome: json['isIncome'] ?? false,
    );
  }
}

// ========================================
// メイン画面の状態管理クラス
// ・下部メニューの切替
// ・家計簿データの保持
// ・保存／読込処理
// を担当する
// ========================================
class _MainScreenState extends State<MainScreen>
{
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
  Future<void> saveExpenses() async
  {
    final prefs = await SharedPreferences.getInstance();

    // ExpenseオブジェクトをJSON文字列へ変換
    final jsonList = expenses.map((e) => jsonEncode(e.toJson())).toList();

    await prefs.setStringList('expenses', jsonList);
  }

  // ========================================
  // 保存済みデータを読み込む
  // アプリ起動時に呼ばれる
  // ========================================
  Future<void> loadExpenses() async
  {
    final prefs = await SharedPreferences.getInstance();

    final jsonList = prefs.getStringList('expenses');

    // 保存データが無ければ終了
    if (jsonList == null)
    {
      return;
    }

    setState(()
    {
      expenses.clear();

      // JSON文字列をExpenseオブジェクトへ変換
      expenses.addAll(
        jsonList.map(
          (e) => Expense.fromJson(
            jsonDecode(e)
          )
        )
      );
    });
  }

  // ========================================
  // 選択中タブに応じて画面を切り替える
  // ========================================
  Widget _buildPage()
  {
    switch (_selectedIndex)
    {
      // 入力画面
      case 0:
        return InputPage(expenses: expenses, onSave: saveExpenses);

      // カレンダー画面
      case 1:
        return const CalendarPage();

      // グラフ画面
      case 2:
        return GraphPage(expenses: expenses);

      // 設定画面
      case 3:
        return const SettingPage();

      // それ以外は空画面
      default:
        return const SizedBox();
    }
  }

  // ========================================
  // メイン画面描画
  // ========================================
  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      appBar: AppBar(title: const Text('家計簿アプリ')),

      // 選択中画面表示
      body: _buildPage(),

      // 下部メニュー
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,

        // メニュー選択時の処理
        onDestinationSelected: (index)
        {
          setState(()
          {
            _selectedIndex = index;
          });
        },
        destinations: const
        [
          NavigationDestination(
            icon: Icon(Icons.edit),
            label: '入力'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'カレンダー',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart),
            label: 'グラフ'),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: '設定'),
        ],
      ),
    );
  }
}

// ========================================
// 入力画面
// 支出・収入の登録を行う画面
// ========================================
class InputPage extends StatefulWidget
{
  // 家計簿データ一覧
  // MainScreenから受け取る
  final List<Expense> expenses;

  // 保存処理
  // データ追加・削除後に呼び出す
  final Future<void> Function() onSave;

  // コンストラクタ
  // 入力内容や選択日付などが変化するため
  const InputPage(
    {
      super.key,
      required this.expenses,
      required this.onSave
    });

  @override
  State<InputPage> createState() => _InputPageState();
}

// ========================================
// 入力画面の状態管理クラス
// ・入力項目の保持
// ・収支計算
// ・データ登録
// ・データ削除
// を担当
// ========================================
class _InputPageState extends State<InputPage>
{
  // 金額入力欄
  final _amountController = TextEditingController();

  // メモ入力欄
  final _memoController = TextEditingController();

  // 収入／支出フラグ
  // false: 支出
  // true : 収入
  bool _isIncome = false;

  // 選択中の日付
  DateTime _selectedDate = DateTime.now();

  // 選択中のカテゴリ
  String _selectedCategory = '食費';

  // カテゴリ一覧
  final List<String> _categories =
  [
    '食費',
    '日用品',
    '交通費',
    '趣味',
    '交際費',
    'その他'
  ];

  @override
  Widget build(BuildContext context)
  {
    DateTime now = DateTime.now();

    // ========================================
    // 今月の支出合計を計算
    // ========================================
    int totalExpense = widget.expenses
        .where(
          (e) =>
              !e.isIncome &&
              e.date.year == now.year &&
              e.date.month == now.month,
        )
        .fold(0, (sum, e) => sum + e.amount);

    // ========================================
    // 今月の収入合計を計算
    // ========================================
    int totalIncome = widget.expenses
        .where(
          (e) =>
              e.isIncome &&
              e.date.year == now.year &&
              e.date.month == now.month,
        )
        .fold(0, (sum, e) => sum + e.amount);

    // ========================================
    // 収支計算
    // ========================================
    int balance = totalIncome - totalExpense;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:
        [
          const Text(
            '支出入力',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold
            ),
          ),

          const SizedBox(height: 24),

          // ========================================
          // 金額入力
          // ========================================
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '金額',
              border: OutlineInputBorder(),
              prefixText: '¥ ',
            ),
          ),

          const SizedBox(height: 16),

          // ========================================
          // カテゴリ選択
          // ========================================
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'カテゴリ',
              border: OutlineInputBorder(),
            ),
            items: _categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(category)
                  ),
                )
                .toList(),
            onChanged: (value)
            {
              setState(()
              {
                _selectedCategory = value!;
              });
            },
          ),

          const SizedBox(height: 16),

          // ========================================
          // 収入／支出切替
          // ========================================
          SegmentedButton<bool>(
            segments: const
            [
              ButtonSegment(value: false, label: Text('支出')),
              ButtonSegment(value: true, label: Text('収入')),
            ],
            selected:
            {
              _isIncome
            },
            onSelectionChanged: (Set<bool> newSelection)
            {
              setState(()
              {
                _isIncome = newSelection.first;
              });
            },
          ),

          // ========================================
          // 日付選択
          // ========================================
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: Text(
              '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}',
            ),
            trailing: const Icon(Icons.edit),
            onTap: () async
            {
              // 日付選択ダイアログ表示
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );

              if (pickedDate != null)
              {
                setState(()
                {
                  _selectedDate = pickedDate;
                });
              }
            },
          ),

          // ========================================
          // メモ入力
          // ========================================

          TextField(
            controller: _memoController,
            decoration: const InputDecoration(
              labelText: 'メモ',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          // ========================================
          // 支出一覧タイトル
          // ========================================
          const Text(
            '支出一覧',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold
            ),
          ),

          const SizedBox(height: 8),

          // ========================================
          // 保存ボタン
          // ========================================
          ElevatedButton(
            onPressed: () async
            {
              final amountText = _amountController.text;

              // 金額未入力なら登録しない
              if (amountText.isEmpty)
              {
                return;
              }

              // 家計簿データ追加
              widget.expenses.add(
                Expense(
                  amount: int.parse(amountText),
                  category: _selectedCategory,
                  memo: _memoController.text,
                  date: _selectedDate,
                  isIncome: _isIncome,
                ),
              );

              // 永続保存
              await widget.onSave();

              // 日付順でソート
              widget.expenses.sort((a, b) => b.date.compareTo(a.date));

              // 画面更新
              setState(() {});

              // 入力欄クリア
              _amountController.clear();
              _memoController.clear();

              // 日付を今日にリセット
              setState(()
              {
                _selectedDate = DateTime.now();
              });
            },

            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '保存',
                style: TextStyle(fontSize: 18)
              ),
            ),
          ),

          // ========================================
          // 今月の収支サマリー
          // ========================================
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children:
                [
                  Text(
                    '今月収入: ¥$totalIncome',
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    '今月支出: ¥$totalExpense',
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    '収支: ¥$balance',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Divider(),

          const SizedBox(height: 8),

          // ========================================
          // 登録済みデータ一覧
          // ========================================
          ...widget.expenses.map(
            (expense) => Card(
              child: ListTile(

                // 金額表示＋削除ボタン
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children:
                  [
                    Text(
                      expense.isIncome
                          ? '+¥${expense.amount}'
                          : '-¥${expense.amount}',
                    ),

                    // データ削除ボタン
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        setState(() {
                          widget.expenses.remove(expense);
                        });

                        await widget.onSave();
                      },
                    ),
                  ],
                ),
                title: Text(
                  "${expense.amount}円",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ========================================
// カレンダー画面
// 日付ごとの収支確認を行う画面
// （現在は仮実装）
// ========================================
class CalendarPage extends StatelessWidget
{
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 仮実装
    return const Center(child: Text('カレンダー画面', style: TextStyle(fontSize: 24)));
  }
}

// ========================================
// グラフ画面
// カテゴリ別の支出集計を表示する
// ========================================
class GraphPage extends StatelessWidget
{
  // 家計簿データ一覧
  final List<Expense> expenses;

  const GraphPage({super.key, required this.expenses});

  @override
  Widget build(BuildContext context)
  {
    // カテゴリごとの支出合計
    Map<String, int> categoryTotals = {};

    // ========================================
    // 支出データをカテゴリ別に集計
    // 収入は集計対象外
    // ========================================
    for (var expense in expenses)
    {
      // 収入はスキップ
      if (expense.isIncome)
      {
        continue;
      }

      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0)
          + expense.amount;
    }

    // ========================================
    // 集計結果を一覧表示
    // ========================================
    return ListView(
      children: categoryTotals.entries.map((entry)
      {
        return ListTile(
          title: Text(entry.key),             // カテゴリ名
          trailing: Text('¥${entry.value}'),  // カテゴリごとの支出合計
        );
      }).toList(),
    );
  }
}

// ========================================
// 設定画面
// アプリ設定やカテゴリ管理を行う画面
// （現在は仮実装）
// ========================================
class SettingPage extends StatelessWidget
{
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context)
  {
    // 仮実装
    return const Center(child: Text('設定画面', style: TextStyle(fontSize: 24)));
  }
}

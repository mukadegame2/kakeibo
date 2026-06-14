import 'package:flutter/material.dart';

import '../widgets/summary_card.dart';
import '../models/expense.dart';
import '../services/category_service.dart';

// ========================================
// 入力画面
// 支出・収入の登録を行う画面
// ========================================
class InputPage extends StatefulWidget {
  // 家計簿データ一覧
  // MainScreenから受け取る
  final List<Expense> expenses;

  // 保存処理
  // データ追加・削除後に呼び出す
  final Future<void> Function() onSave;

  // コンストラクタ
  // 入力内容や選択日付などが変化するため
  const InputPage({super.key, required this.expenses, required this.onSave});

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
class _InputPageState extends State<InputPage> {
  void _showEditDialog(Expense expense) {
    DateTime editDate = expense.date;
    final amountController = TextEditingController(
      text: expense.amount.toString(),
    );

    final memoController = TextEditingController(text: expense.memo);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("編集"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "金額"),
              ),

              const SizedBox(height: 16),

              StatefulBuilder(
                builder: (context, setDialogState) {
                  return ListTile(
                    leading: const Icon(Icons.calendar_month),
                    title: Text(
                      "${editDate.year}/${editDate.month}/${editDate.day}",
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: editDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );

                      if (pickedDate != null) {
                        setDialogState(() {
                          editDate = pickedDate;
                        });
                      }
                    },
                  );
                },
              ),

              TextField(
                controller: memoController,
                decoration: const InputDecoration(labelText: "メモ"),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("キャンセル"),
            ),

            // 更新ボタン
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                final index = widget.expenses.indexOf(expense);

                widget.expenses[index] = Expense(
                  amount: int.parse(amountController.text),
                  category: expense.category,
                  memo: memoController.text,
                  date: editDate,
                  isIncome: expense.isIncome,
                );

                widget.expenses.sort((a, b) => b.date.compareTo(a.date));

                await widget.onSave();

                if (!mounted) return;

                setState(() {});
              },
              child: const Text("更新"),
            ),
          ],
        );
      },
    );
  }

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
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    _categories = await CategoryService.loadCategories();

    if (_categories.isNotEmpty) {
      _selectedCategory = _categories.first;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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

    if (_categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // ========================================
    // 収支計算
    // ========================================
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '支出入力',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                  (category) =>
                      DropdownMenuItem(value: category, child: Text(category)),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
          ),

          const SizedBox(height: 16),

          // ========================================
          // 収入／支出切替
          // ========================================
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('支出')),
              ButtonSegment(value: true, label: Text('収入')),
            ],
            selected: {_isIncome},
            onSelectionChanged: (Set<bool> newSelection) {
              setState(() {
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
            onTap: () async {
              // 日付選択ダイアログ表示
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );

              if (pickedDate != null) {
                setState(() {
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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          // ========================================
          // 保存ボタン
          // ========================================
          ElevatedButton(
            onPressed: () async {
              final amountText = _amountController.text;

              // 金額未入力なら登録しない
              if (amountText.isEmpty) {
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
              setState(() {
                _selectedDate = DateTime.now();
              });
            },

            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('保存', style: TextStyle(fontSize: 18)),
            ),
          ),

          // ========================================
          // 今月の収支サマリー
          // ========================================
          SummaryCard(income: totalIncome, expense: totalExpense),

          const SizedBox(height: 16),

          const Divider(),

          const SizedBox(height: 8),

          // ========================================
          // 登録済みデータ一覧
          // ========================================
          ...widget.expenses.map(
            (expense) => Card(
              child: ListTile(
                onTap: () {
                  _showEditDialog(expense);
                },

                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      expense.isIncome
                          ? '+¥${expense.amount}'
                          : '-¥${expense.amount}',
                    ),

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
                  expense.category,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                subtitle: Text(
                  "${expense.date.year}/${expense.date.month}/${expense.date.day}"
                  "\n${expense.memo}",
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

import 'package:flutter/material.dart';

import '../widgets/summary_card.dart';
import '../models/expense.dart';
import '../services/category_service.dart';
import '../services/category_helper.dart';
import '../widgets/expense_edit_dialog.dart';
import '../utils/format_helper.dart';

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
  Future<void> _showEditDialog(Expense expense) async {
    final updatedExpense = await showExpenseEditDialog(
      context: context,
      expense: expense,
      categories: expense.isIncome ? _incomeCategories : _expenseCategories,
      expenseCategories: _expenseCategories,
      incomeCategories: _incomeCategories,
      canEditDate: true,
      canEditCategory: true,
    );

    if (updatedExpense == null) {
      return;
    }

    final index = widget.expenses.indexOf(expense);

    if (index == -1) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("編集対象のデータが見つかりませんでした")));
      return;
    }

    widget.expenses[index] = updatedExpense;

    widget.expenses.sort((a, b) => b.date.compareTo(a.date));

    await widget.onSave();

    if (!mounted) return;

    setState(() {});
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

  // 支出カテゴリ一覧
  List<String> _expenseCategories = [];

  // 収入カテゴリ一覧
  List<String> _incomeCategories = [];

  // 現在の収支種別に応じたカテゴリ一覧
  List<String> get _currentCategories {
    return _isIncome ? _incomeCategories : _expenseCategories;
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();

    super.dispose();
  }

  void _syncSelectedCategoryWithType() {
    final currentCategories = _currentCategories;

    if (currentCategories.isEmpty) {
      return;
    }

    if (!currentCategories.contains(_selectedCategory)) {
      _selectedCategory = currentCategories.first;
    }
  }

  Future<void> _loadCategories() async {
    final expenseCategories = await CategoryService.loadExpenseCategories();
    final incomeCategories = await CategoryService.loadIncomeCategories();

    if (!mounted) {
      return;
    }

    setState(() {
      _expenseCategories = expenseCategories;
      _incomeCategories = incomeCategories;
      _syncSelectedCategoryWithType();
    });
  }

  List<String> _buildCategoryDisplayList(List<String> sourceCategories) {
    final parentCategories = sourceCategories
        .where((category) => !CategoryHelper.isChildCategory(category))
        .toList();

    final childCategories = sourceCategories
        .where((category) => CategoryHelper.isChildCategory(category))
        .toList();

    final displayList = <String>[];

    for (final parent in parentCategories) {
      displayList.add(parent);

      final children = childCategories.where((category) {
        return CategoryHelper.parentOf(category) == parent;
      }).toList();

      displayList.addAll(children);
    }

    final orphanChildren = childCategories.where((category) {
      return !displayList.contains(category);
    }).toList();

    displayList.addAll(orphanChildren);

    return displayList;
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

    if (_expenseCategories.isEmpty || _incomeCategories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentCategories = _currentCategories;

    final displayCategories = _buildCategoryDisplayList(currentCategories);

    // ========================================
    // 収支計算
    // ========================================
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isIncome ? '収入入力' : '支出入力',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
            key: ValueKey(_isIncome),
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'カテゴリ',
              border: OutlineInputBorder(),
            ),
            items: displayCategories.map((category) {
              final isChild = CategoryHelper.isChildCategory(category);

              return DropdownMenuItem<String>(
                value: category,
                child: Text(
                  isChild
                      ? "   ↳ ${CategoryHelper.childOf(category)}"
                      : "📁 $category",
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _selectedCategory = value;
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
                _syncSelectedCategoryWithType();
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
                locale: const Locale('ja', 'JP'),
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
              final amount = int.tryParse(_amountController.text);

              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("金額は1以上の数字で入力してください")),
                );
                return;
              }

              // 家計簿データ追加
              widget.expenses.add(
                Expense(
                  amount: amount,
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
          SummaryCard(
            income: totalIncome,
            expense: totalExpense,
            balance: totalIncome - totalExpense,
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
                onTap: () {
                  _showEditDialog(expense);
                },

                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      expense.isIncome
                          ? FormatHelper.signedYen(expense.amount)
                          : FormatHelper.signedYen(-expense.amount),
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
                  CategoryHelper.displayName(expense.category),
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

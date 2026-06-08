import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const KakeiboApp());
}

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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class Expense {
  final int amount;
  final String category;
  final String memo;
  final DateTime date;
  final bool isIncome;

  Expense({
    required this.amount,
    required this.category,
    required this.memo,
    required this.date,
    required this.isIncome,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category,
      'memo': memo,
      'date': date.toIso8601String(),
      'isIncome': isIncome,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
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

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Expense> expenses = [];

  @override
  void initState() {
    super.initState();
    loadExpenses();
  }

  Future<void> saveExpenses() async {
    print("保存開始");
    final prefs = await SharedPreferences.getInstance();

    final jsonList = expenses.map((e) => jsonEncode(e.toJson())).toList();

    await prefs.setStringList('expenses', jsonList);
  }

  Future<void> loadExpenses() async {
    print("読込開始");
    final prefs = await SharedPreferences.getInstance();

    final jsonList = prefs.getStringList('expenses');

    print(jsonList);

    if (jsonList == null) {
      return;
    }

    setState(() {
      expenses.clear();

      expenses.addAll(jsonList.map((e) => Expense.fromJson(jsonDecode(e))));
    });
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return InputPage(expenses: expenses, onSave: saveExpenses);

      case 1:
        return const CalendarPage();

      case 2:
        return GraphPage(expenses: expenses);

      case 3:
        return const SettingPage();

      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('家計簿アプリ')),
      body: _buildPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
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

class InputPage extends StatefulWidget {
  final List<Expense> expenses;
  final Future<void> Function() onSave;

  const InputPage({super.key, required this.expenses, required this.onSave});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  bool _isIncome = false;

  DateTime _selectedDate = DateTime.now();

  String _selectedCategory = '食費';

  final List<String> _categories = ['食費', '日用品', '交通費', '趣味', '交際費', 'その他'];

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    int totalExpense = widget.expenses
        .where(
          (e) =>
              !e.isIncome &&
              e.date.year == now.year &&
              e.date.month == now.month,
        )
        .fold(0, (sum, e) => sum + e.amount);

    int totalIncome = widget.expenses
        .where(
          (e) =>
              e.isIncome &&
              e.date.year == now.year &&
              e.date.month == now.month,
        )
        .fold(0, (sum, e) => sum + e.amount);

    int balance = totalIncome - totalExpense;

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

          DropdownButtonFormField<String>(
            value: _selectedCategory,
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

          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('支出'),
                  value: false,
                  groupValue: _isIncome,
                  onChanged: (value) {
                    setState(() {
                      _isIncome = value!;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('収入'),
                  value: true,
                  groupValue: _isIncome,
                  onChanged: (value) {
                    setState(() {
                      _isIncome = value!;
                    });
                  },
                ),
              ),
            ],
          ),

          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: Text(
              '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}',
            ),
            trailing: const Icon(Icons.edit),
            onTap: () async {
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

          TextField(
            controller: _memoController,
            decoration: const InputDecoration(
              labelText: 'メモ',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            '支出一覧',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          ElevatedButton(
            onPressed: () async {
              final amountText = _amountController.text;

              if (amountText.isEmpty) {
                return;
              }

              widget.expenses.add(
                Expense(
                  amount: int.parse(amountText),
                  category: _selectedCategory,
                  memo: _memoController.text,
                  date: _selectedDate,
                  isIncome: _isIncome,
                ),
              );

              await widget.onSave();

              widget.expenses.sort((a, b) => b.date.compareTo(a.date));

              setState(() {});

              _amountController.clear();
              _memoController.clear();

              setState(() {
                _selectedDate = DateTime.now();
              });
            },
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('保存', style: TextStyle(fontSize: 18)),
            ),
          ),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
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

          ...widget.expenses.map(
            (expense) => Card(
              child: ListTile(
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
                  "${expense.amount}円",
                  style: const TextStyle(fontWeight: FontWeight.bold),
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

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('カレンダー画面', style: TextStyle(fontSize: 24)));
  }
}

class GraphPage extends StatelessWidget {
  final List<Expense> expenses;

  const GraphPage({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    Map<String, int> categoryTotals = {};

    for (var expense in expenses) {
      if (expense.isIncome) {
        continue;
      }

      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    return ListView(
      children: categoryTotals.entries.map((entry) {
        return ListTile(
          title: Text(entry.key),
          trailing: Text('¥${entry.value}'),
        );
      }).toList(),
    );
  }
}

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('設定画面', style: TextStyle(fontSize: 24)));
  }
}

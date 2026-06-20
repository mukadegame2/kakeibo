import '../models/expense.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class CategoryDetailPage extends StatefulWidget {
  final String category;
  final List<Expense> expenses;
  final Future<void> Function() onSave;

  const CategoryDetailPage({
    super.key,
    required this.category,
    required this.expenses,
    required this.onSave,
  });

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  DateTime selectedMonth = DateTime.now();

  Future<void> _deleteExpense(Expense expense) async {
    widget.expenses.remove(expense);
    await widget.onSave();

    if (!mounted) return;

    setState(() {});
  }

  Future<void> _showEditDialog(Expense expense) async {
    final amountController = TextEditingController(
      text: expense.amount.toString(),
    );

    final memoController = TextEditingController(text: expense.memo);

    await showDialog(
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

              TextField(
                controller: memoController,
                decoration: const InputDecoration(labelText: "メモ"),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("キャンセル"),
            ),

            ElevatedButton(
              onPressed: () async {
                final amount = int.tryParse(amountController.text.trim());

                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("金額は1以上の数字で入力してください")),
                  );
                  return;
                }

                final index = widget.expenses.indexOf(expense);

                if (index == -1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("編集対象のデータが見つかりませんでした")),
                  );
                  return;
                }

                widget.expenses[index] = expense.copyWith(
                  amount: amount,
                  memo: memoController.text,
                );

                await widget.onSave();

                if (!mounted) return;

                setState(() {});

                Navigator.pop(dialogContext);
              },
              child: const Text("保存"),
            ),
          ],
        );
      },
    );

    amountController.dispose();
    memoController.dispose();
  }

  @override
  void initState() {
    super.initState();

    final target = widget.expenses
        .where((e) => e.category == widget.category)
        .toList();

    if (target.isNotEmpty) {
      target.sort((a, b) => b.date.compareTo(a.date));
      selectedMonth = target.first.date;
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<int, int> monthlyTotals = {};
    for (int month = 1; month <= 12; month++) {
      monthlyTotals[month] = 0;
    }

    for (var expense in widget.expenses) {
      if (expense.category != widget.category) {
        continue;
      }

      final month = expense.date.month;

      monthlyTotals[month] = (monthlyTotals[month] ?? 0) + expense.amount;
    }

    final monthExpenses = widget.expenses.where((expense) {
      return expense.category == widget.category &&
          expense.date.month == selectedMonth.month;
    }).toList();

    final monthTotal = monthExpenses.fold(
      0,
      (sum, expense) => sum + expense.amount,
    );

    monthExpenses.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: Text(widget.category)),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: BarChart(
                BarChartData(
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchCallback: (event, response) {
                      if (response == null || response.spot == null) return;
                      if (event is! FlTapUpEvent) return;

                      final month = response.spot!.touchedBarGroup.x;

                      setState(() {
                        selectedMonth = DateTime(DateTime.now().year, month);
                      });
                    },
                  ),
                  barGroups: monthlyTotals.entries.map((entry) {
                    final isSelected = entry.key == selectedMonth.month;
                    final hasData = entry.value > 0;

                    return BarChartGroupData(
                      x: entry.key,

                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          width: 20,
                          color: isSelected
                              ? Colors.orange
                              : hasData
                              ? Colors.blueGrey
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              "${selectedMonth.month}月",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text(
              "合計 ¥$monthTotal",
              style: const TextStyle(
                fontSize: 18,
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),

            Expanded(
              child: ListView(
                children: monthExpenses
                    .where((expense) {
                      return expense.category == widget.category &&
                          expense.date.month == selectedMonth.month;
                    })
                    .map(
                      (expense) => ListTile(
                        title: Text(expense.memo),
                        subtitle: Text(
                          "${expense.date.year}/${expense.date.month}/${expense.date.day}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("¥${expense.amount}"),

                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                await _showEditDialog(expense);
                              },
                            ),

                            IconButton(
                              icon: const Icon(Icons.delete),

                              onPressed: () async {
                                final result = await showDialog<bool>(
                                  context: context,

                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text("削除確認"),

                                      content: const Text("この明細を削除しますか？"),

                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context, false);
                                          },
                                          child: const Text("キャンセル"),
                                        ),

                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context, true);
                                          },
                                          child: const Text("削除"),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (result == true) {
                                  await _deleteExpense(expense);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

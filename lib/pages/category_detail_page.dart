import '../models/expense.dart';
import '../services/category_helper.dart';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/category_service.dart';
import '../widgets/expense_edit_dialog.dart';
import '../utils/format_helper.dart';

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

  List<String> _expenseCategories = [];
  List<String> _incomeCategories = [];

  Future<void> _loadCategories() async {
    final expenseCategories = await CategoryService.loadExpenseCategories();
    final incomeCategories = await CategoryService.loadIncomeCategories();

    if (!mounted) return;

    setState(() {
      _expenseCategories = expenseCategories;
      _incomeCategories = incomeCategories;
    });
  }

  bool _isTargetCategory(Expense expense) {
    if (CategoryHelper.isChildCategory(widget.category)) {
      return expense.category == widget.category;
    }

    return expense.category == widget.category ||
        CategoryHelper.parentOf(expense.category) == widget.category;
  }

  List<int> _buildAvailableYears() {
    final years = widget.expenses
        .where((expense) => _isTargetCategory(expense))
        .map((expense) => expense.date.year)
        .toSet()
        .toList();

    final currentYear = DateTime.now().year;

    if (!years.contains(currentYear)) {
      years.add(currentYear);
    }

    if (!years.contains(selectedMonth.year)) {
      years.add(selectedMonth.year);
    }

    years.sort();

    return years;
  }

  Future<void> _deleteExpense(Expense expense) async {
    widget.expenses.remove(expense);
    await widget.onSave();

    if (!mounted) return;

    setState(() {});
  }

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

  Widget _buildChildBreakdown(List<MapEntry<String, int>> childTotalEntries) {
    if (CategoryHelper.isChildCategory(widget.category)) {
      return const SizedBox();
    }

    if (childTotalEntries.length <= 1) {
      return const SizedBox();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "内訳",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            ...childTotalEntries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text(
                      FormatHelper.yen(entry.value),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _loadCategories();

    final target = widget.expenses.where((e) => _isTargetCategory(e)).toList();

    if (target.isNotEmpty) {
      target.sort((a, b) => b.date.compareTo(a.date));
      selectedMonth = target.first.date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableYears = _buildAvailableYears();

    Map<int, int> monthlyTotals = {};
    for (int month = 1; month <= 12; month++) {
      monthlyTotals[month] = 0;
    }

    for (var expense in widget.expenses) {
      if (!_isTargetCategory(expense)) {
        continue;
      }

      if (expense.date.year != selectedMonth.year) {
        continue;
      }

      final month = expense.date.month;

      monthlyTotals[month] = (monthlyTotals[month] ?? 0) + expense.amount;
    }

    final monthExpenses = widget.expenses.where((expense) {
      return _isTargetCategory(expense) &&
          expense.date.year == selectedMonth.year &&
          expense.date.month == selectedMonth.month;
    }).toList();

    final monthTotal = monthExpenses.fold(
      0,
      (sum, expense) => sum + expense.amount,
    );

    final childTotals = <String, int>{};

    for (final expense in monthExpenses) {
      final category = expense.category;

      final displayCategory = CategoryHelper.isChildCategory(category)
          ? CategoryHelper.childOf(category)
          : "親カテゴリ直下";

      childTotals[displayCategory] =
          (childTotals[displayCategory] ?? 0) + expense.amount;
    }

    final childTotalEntries = childTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    monthExpenses.sort((a, b) => b.date.compareTo(a.date));

    final maxMonthlyTotal = monthlyTotals.values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );

    final chartMaxY = maxMonthlyTotal == 0 ? 1000.0 : maxMonthlyTotal * 1.25;

    return Scaffold(
      appBar: AppBar(title: Text(CategoryHelper.displayName(widget.category))),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: BarChart(
                BarChartData(
                  maxY: chartMaxY,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 58,
                        getTitlesWidget: (value, meta) {
                          if (value < 0) {
                            return const SizedBox();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              FormatHelper.yen(value.toInt()),
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.right,
                            ),
                          );
                        },
                      ),
                    ),

                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final month = value.toInt();

                          if (month < 1 || month > 12) {
                            return const SizedBox();
                          }

                          return Text(
                            "$month月",
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),

                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),

                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,

                    touchTooltipData: BarTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      tooltipMargin: 8,

                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          FormatHelper.yen(rod.toY.toInt()),
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),

                    touchCallback: (event, response) {
                      if (response == null || response.spot == null) return;
                      if (event is! FlTapUpEvent) return;

                      final month = response.spot!.touchedBarGroup.x;

                      setState(() {
                        selectedMonth = DateTime(selectedMonth.year, month);
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

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "表示年：",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                DropdownButton<int>(
                  value: selectedMonth.year,
                  items: availableYears.map((year) {
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text("$year年"),
                    );
                  }).toList(),
                  onChanged: (year) {
                    if (year == null) {
                      return;
                    }

                    setState(() {
                      selectedMonth = DateTime(year, selectedMonth.month);
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              "${selectedMonth.year}年${selectedMonth.month}月",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text(
              "合計 ${FormatHelper.yen(monthTotal)}",
              style: const TextStyle(
                fontSize: 18,
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            _buildChildBreakdown(childTotalEntries),

            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                children: monthExpenses
                    .map(
                      (expense) => ListTile(
                        title: Text(expense.memo),
                        subtitle: Text(
                          "${expense.date.year}/${expense.date.month}/${expense.date.day}"
                          "  ${CategoryHelper.displayName(expense.category)}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(FormatHelper.yen(expense.amount)),

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

import '../models/expense.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class CategoryDetailPage extends StatefulWidget {
  final String category;
  final List<Expense> expenses;

  const CategoryDetailPage({
    super.key,
    required this.category,
    required this.expenses,
  });

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  DateTime selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    Map<int, int> monthlyTotals = {};

    for (var expense in widget.expenses) {
      if (expense.category != widget.category) {
        continue;
      }

      final month = expense.date.month;

      monthlyTotals[month] = (monthlyTotals[month] ?? 0) + expense.amount;
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.category)),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: BarChart(
                BarChartData(
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
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [BarChartRodData(toY: entry.value.toDouble())],
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
            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                children: widget.expenses
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
                        trailing: Text("¥${expense.amount}"),
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

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/expense.dart';
import '../utils/format_helper.dart';

class MonthlyBalanceChart extends StatelessWidget {
  final List<Expense> expenses;
  final int year;

  const MonthlyBalanceChart({
    super.key,
    required this.expenses,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final monthlyBalances = <int, int>{};

    for (int month = 1; month <= 12; month++) {
      monthlyBalances[month] = 0;
    }

    for (final expense in expenses) {
      if (expense.date.year != year) {
        continue;
      }

      final month = expense.date.month;
      final amount = expense.isIncome ? expense.amount : -expense.amount;

      monthlyBalances[month] = (monthlyBalances[month] ?? 0) + amount;
    }

    final maxAbsValue = monthlyBalances.values.fold<int>(
      0,
      (max, value) => value.abs() > max ? value.abs() : max,
    );

    final chartMaxY = maxAbsValue == 0 ? 1000.0 : maxAbsValue * 1.25;
    final chartMinY = maxAbsValue == 0 ? -1000.0 : -maxAbsValue * 1.25;

    return SizedBox(
      width: 700,
      height: 220,
      child: BarChart(
        BarChartData(
          minY: chartMinY,
          maxY: chartMaxY,

          gridData: const FlGridData(show: true),

          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey, width: 1),
          ),

          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),

            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),

            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 58,
                getTitlesWidget: (value, meta) {
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

                  return Text('$month月', style: const TextStyle(fontSize: 10));
                },
              ),
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
                  FormatHelper.signedYen(rod.toY.toInt()),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),

          barGroups: monthlyBalances.entries.map((entry) {
            final month = entry.key;
            final balance = entry.value;

            return BarChartGroupData(
              x: month,
              barRods: [
                BarChartRodData(
                  toY: balance.toDouble(),
                  width: 18,
                  color: balance >= 0 ? Colors.blue : Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

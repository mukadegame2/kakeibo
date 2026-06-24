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

  double _calculateYAxisInterval(int maxAbsValue) {
    if (maxAbsValue <= 3000) {
      return 1000;
    }

    if (maxAbsValue <= 10000) {
      return 2000;
    }

    if (maxAbsValue <= 30000) {
      return 5000;
    }

    if (maxAbsValue <= 100000) {
      return 20000;
    }

    if (maxAbsValue <= 300000) {
      return 50000;
    }

    return 100000;
  }

  String _formatAxisYen(double value) {
    final roundedValue = value.round();

    if (roundedValue < 0) {
      return '-${FormatHelper.yen(roundedValue.abs())}';
    }

    return FormatHelper.yen(roundedValue);
  }

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

    final yInterval = _calculateYAxisInterval(maxAbsValue);

    final chartMaxY = maxAbsValue == 0
        ? 1000.0
        : ((maxAbsValue * 1.25) / yInterval).ceil() * yInterval;

    final chartMinY = -chartMaxY;

    return SizedBox(
      width: 700,
      height: 240,
      child: BarChart(
        BarChartData(
          minY: chartMinY,
          maxY: chartMaxY,

          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(y: 0, color: Colors.black54, strokeWidth: 1.2),
            ],
          ),

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
                reservedSize: 76,
                interval: yInterval,
                getTitlesWidget: (value, meta) {
                  final roundedValue = value.round();

                  if (roundedValue < chartMinY || roundedValue > chartMaxY) {
                    return const SizedBox();
                  }

                  final interval = yInterval.round();

                  if (interval > 0 && roundedValue % interval != 0) {
                    return const SizedBox();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      _formatAxisYen(value),
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

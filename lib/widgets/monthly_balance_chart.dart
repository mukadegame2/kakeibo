import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/expense.dart';

class MonthlyBalanceChart extends StatelessWidget {
  final List<Expense> expenses;

  const MonthlyBalanceChart({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    List<FlSpot> spots = [];

    for (int month = 1; month <= 12; month++) {
      final income = expenses
          .where(
            (e) =>
                e.isIncome &&
                e.date.year == currentYear &&
                e.date.month == month,
          )
          .fold(0, (sum, e) => sum + e.amount);

      final expense = expenses
          .where(
            (e) =>
                !e.isIncome &&
                e.date.year == currentYear &&
                e.date.month == month,
          )
          .fold(0, (sum, e) => sum + e.amount);

      final balance = income - expense;

      spots.add(FlSpot(month.toDouble(), balance.toDouble()));
    }

    return Center(
      child: SizedBox(
        width: 700,
        height: 180,
        child: LineChart(
          LineChartData(
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(y: 0, strokeWidth: 2, dashArray: [5, 5]),
              ],
            ),
            minX: 1,
            maxX: 12,

            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),

              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),

              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    if (value < 1 || value > 12) {
                      return const SizedBox();
                    }

                    return Text(
                      "${value.toInt()}月",
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),

              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      "¥${value.toInt()}",
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
            ),

            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                dotData: FlDotData(
                  show: true,

                  getDotPainter: (spot, percent, bar, index) {
                    return FlDotCirclePainter(radius: 4);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

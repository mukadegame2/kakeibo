import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/expense.dart';
import '../utils/format_helper.dart';

class SavingsBalanceChart extends StatelessWidget {
  final List<Expense> expenses;
  final int year;
  final int initialSavings;

  const SavingsBalanceChart({
    super.key,
    required this.expenses,
    required this.year,
    this.initialSavings = 0,
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

  String _formatBalanceYen(int value) {
    if (value < 0) {
      return '-${FormatHelper.yen(value.abs())}';
    }

    return FormatHelper.yen(value);
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

    final yearStart = DateTime(year, 1, 1);

    int baseSavings = initialSavings;

    for (final expense in expenses) {
      if (!expense.date.isBefore(yearStart)) {
        continue;
      }

      baseSavings += expense.isIncome ? expense.amount : -expense.amount;
    }

    final now = DateTime.now();

    final int lastDisplayMonth;

    if (year < now.year) {
      lastDisplayMonth = 12;
    } else if (year == now.year) {
      lastDisplayMonth = now.month;
    } else {
      lastDisplayMonth = 0;
    }

    final savingsByMonth = <int, int>{};
    int runningTotal = baseSavings;

    for (int month = 1; month <= lastDisplayMonth; month++) {
      runningTotal += monthlyBalances[month] ?? 0;
      savingsByMonth[month] = runningTotal;
    }

    final valuesForScale = <int>[baseSavings, ...savingsByMonth.values];

    final maxAbsValue = valuesForScale.fold<int>(
      0,
      (max, value) => value.abs() > max ? value.abs() : max,
    );

    final yInterval = _calculateYAxisInterval(maxAbsValue);

    final chartMaxY = maxAbsValue == 0
        ? 1000.0
        : ((maxAbsValue * 1.25) / yInterval).ceil() * yInterval;

    final chartMinY = -chartMaxY;

    final latestSavings = lastDisplayMonth == 0
        ? 0
        : savingsByMonth[lastDisplayMonth] ?? 0;

    final savingsLabel = lastDisplayMonth == 0
        ? "表示できる月がありません"
        : "$lastDisplayMonth月時点：${_formatBalanceYen(latestSavings)}";

    final displayMonths = List.generate(
      lastDisplayMonth,
      (index) => lastDisplayMonth - index,
    );

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : 700.0;

            final chartWidth = availableWidth > 700 ? 700.0 : availableWidth;

            return Center(
              child: SizedBox(
                width: chartWidth,
                height: 240,
                child: BarChart(
                  BarChartData(
                    minY: chartMinY,
                    maxY: chartMaxY,

                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: 0,
                          color: Colors.black54,
                          strokeWidth: 1.5,
                        ),
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

                            if (roundedValue < chartMinY ||
                                roundedValue > chartMaxY) {
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

                            return Text(
                              '$month月',
                              style: const TextStyle(fontSize: 10),
                            );
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
                          final month = group.x;

                          if (!savingsByMonth.containsKey(month)) {
                            return null;
                          }

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

                    barGroups: List.generate(12, (index) {
                      final month = index + 1;
                      final hasValue = savingsByMonth.containsKey(month);
                      final savings = savingsByMonth[month] ?? 0;

                      return BarChartGroupData(
                        x: month,
                        barRods: [
                          BarChartRodData(
                            toY: hasValue ? savings.toDouble() : 0,
                            width: 18,
                            color: !hasValue
                                ? Colors.transparent
                                : savings >= 0
                                ? Colors.blue
                                : Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 8),

        Text(
          savingsLabel,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),

        if (displayMonths.isNotEmpty) ...[
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : 700.0;

              final listWidth = availableWidth > 700 ? 700.0 : availableWidth;

              return Center(
                child: SizedBox(
                  width: listWidth,
                  child: Card(
                    child: Column(
                      children: displayMonths.map((month) {
                        final savings = savingsByMonth[month] ?? 0;
                        final monthlyBalance = monthlyBalances[month] ?? 0;

                        return Column(
                          children: [
                            ListTile(
                              title: Text(
                                "$month月",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              subtitle: Text(
                                "月間収支：${FormatHelper.signedYen(monthlyBalance)}",
                              ),

                              trailing: Text(
                                _formatBalanceYen(savings),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: savings < 0 ? Colors.red : Colors.blue,
                                ),
                              ),
                            ),

                            if (month != displayMonths.last)
                              const Divider(height: 1),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

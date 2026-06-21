import 'package:flutter/material.dart';

import '../utils/format_helper.dart';

class SummaryCard extends StatelessWidget {
  final int income;
  final int expense;
  final int balance;

  const SummaryCard({
    super.key,
    required this.income,
    required this.expense,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final balanceColor = balance >= 0 ? Colors.blue : Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 4,
          children: [
            Text(
              '収入：${FormatHelper.yen(income)}',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              '支出：${FormatHelper.yen(expense)}',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              '収支：${FormatHelper.signedYen(balance)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: balanceColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final int totalIncome;
  final int totalExpense;
  final int balance;

  const SummaryCard({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
    );
  }
}
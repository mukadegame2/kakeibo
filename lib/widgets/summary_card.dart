import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final int income;
  final int expense;

  const SummaryCard({
    super.key,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final balance = income - expense;

    return Card(
      margin: const EdgeInsets.all(8),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            Text(
              "収入：¥$income",
              style: const TextStyle(fontSize: 16),
            ),

            Text(
              "支出：¥$expense",
              style: const TextStyle(fontSize: 16),
            ),

            Text(
              "収支：¥$balance",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: balance >= 0
                    ? Colors.blue
                    : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
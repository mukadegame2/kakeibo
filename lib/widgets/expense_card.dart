import 'package:flutter/material.dart';

import '../models/expense.dart';

class ExpenseCard extends StatelessWidget {
  final String date;
  final List<Expense> dailyExpenses;

  const ExpenseCard({
    super.key,
    required this.date,
    required this.dailyExpenses,
  });

  @override
  Widget build(BuildContext context) {
    int dailyTotal = dailyExpenses.fold(
      0,
      (sum, expense) =>
          sum +
          (expense.isIncome
              ? expense.amount
              : -expense.amount),
    );

    return Card(
      margin: const EdgeInsets.all(8),

      child: Padding(
        padding: const EdgeInsets.all(8),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              date,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Divider(),

            Text(
              dailyTotal >= 0
                  ? "収支合計: +¥$dailyTotal"
                  : "収支合計: -¥${dailyTotal.abs()}",
            ),

            ...dailyExpenses.map(
              (expense) => ListTile(
                title: Text(expense.category),

                subtitle: Text(expense.memo),

                trailing: Text(
                  expense.isIncome
                      ? "+¥${expense.amount}"
                      : "-¥${expense.amount}",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
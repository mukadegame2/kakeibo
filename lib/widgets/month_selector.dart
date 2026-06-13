import 'package:flutter/material.dart';

class MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const MonthSelector({
    super.key,
    required this.selectedMonth,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.arrow_back), onPressed: onPrevious),

        Text(
          "${selectedMonth.year}年${selectedMonth.month}月",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        IconButton(icon: const Icon(Icons.arrow_forward), onPressed: onNext),
      ],
    );
  }
}

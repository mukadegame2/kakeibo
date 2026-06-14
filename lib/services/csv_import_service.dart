import '../models/expense.dart';

class CsvImportService {
  static List<Expense> importCsv(String csvText) {
    final lines = csvText.split('\n');

    List<Expense> expenses = [];

    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) {
        continue;
      }

      final values = lines[i].split(',');

      final dateParts = values[0].split('/');

      expenses.add(
        Expense(
          date: DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          ),

          isIncome: values[1] == "収入",

          category: values[2],

          amount: int.parse(values[3]),

          memo: values[4],
        ),
      );
    }

    return expenses;
  }
}
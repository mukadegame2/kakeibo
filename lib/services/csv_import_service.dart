import 'package:csv/csv.dart';

import '../models/expense.dart';

class CsvImportService {
  static List<Expense> importCsv(String csvText) {
    final rows = const CsvToListConverter().convert(csvText);

    List<Expense> expenses = [];

    // 0行目はヘッダーなので1から開始
    for (int i = 1; i < rows.length; i++) {
      final values = rows[i];

      if (values.length < 5) {
        continue;
      }

      final dateParts = values[0].toString().split('/');

      expenses.add(
        Expense(
          date: DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          ),
          isIncome: values[1].toString() == "収入",
          category: values[2].toString(),
          amount: int.parse(values[3].toString()),
          memo: values[4].toString(),
        ),
      );
    }

    return expenses;
  }
}

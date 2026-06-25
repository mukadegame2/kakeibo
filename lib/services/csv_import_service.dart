import 'package:csv/csv.dart';

import '../models/expense.dart';

class CsvImportResult {
  final List<Expense> expenses;
  final int skippedRows;

  const CsvImportResult({required this.expenses, required this.skippedRows});
}

class CsvImportService {
  static CsvImportResult importCsv(String csvText) {
    final rows = const CsvToListConverter().convert(csvText);

    final expenses = <Expense>[];
    int skippedRows = 0;

    for (int i = 1; i < rows.length; i++) {
      final values = rows[i];

      if (_isEmptyRow(values)) {
        continue;
      }

      if (values.length < 5) {
        skippedRows++;
        continue;
      }

      final date = _parseDate(values[0].toString());
      final amount = _parseAmount(values[3].toString());

      if (date == null || amount == null || amount <= 0) {
        skippedRows++;
        continue;
      }

      final typeText = values[1].toString().trim();
      final isIncome = typeText == "収入";

      final category = values[2].toString().trim().isEmpty
          ? "その他"
          : values[2].toString().trim();

      final memo = values[4].toString();

      expenses.add(
        Expense(
          date: date,
          isIncome: isIncome,
          category: category,
          amount: amount,
          memo: memo,
        ),
      );
    }

    return CsvImportResult(expenses: expenses, skippedRows: skippedRows);
  }

  static bool _isEmptyRow(List<dynamic> values) {
    return values.every((value) => value.toString().trim().isEmpty);
  }

  static DateTime? _parseDate(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return null;
    }

    final normalizedText = text.replaceAll('-', '/').replaceAll('.', '/');

    final parts = normalizedText.split('/');

    if (parts.length < 3) {
      return null;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null || month == null || day == null) {
      return null;
    }

    if (month < 1 || month > 12) {
      return null;
    }

    if (day < 1 || day > 31) {
      return null;
    }

    final date = DateTime(year, month, day);

    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return date;
  }

  static int? _parseAmount(String value) {
    final text = value
        .trim()
        .replaceAll(',', '')
        .replaceAll('¥', '')
        .replaceAll('+', '')
        .replaceAll('円', '');

    if (text.isEmpty) {
      return null;
    }

    final intValue = int.tryParse(text);

    if (intValue != null) {
      return intValue;
    }

    final doubleValue = double.tryParse(text);

    if (doubleValue == null) {
      return null;
    }

    return doubleValue.round();
  }
}

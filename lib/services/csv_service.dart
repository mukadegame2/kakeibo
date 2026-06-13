import 'package:csv/csv.dart';

import '../models/expense.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CsvService {
  static String createCsv(List<Expense> expenses) {
    List<List<dynamic>> rows = [];

    rows.add(['日付', '収支', 'カテゴリ', '金額', 'メモ']);

    for (final expense in expenses) {
      rows.add([
        "${expense.date.year}/${expense.date.month}/${expense.date.day}",
        expense.isIncome ? '収入' : '支出',
        expense.category,
        expense.amount,
        expense.memo,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  static Future<String> saveCsv(List<Expense> expenses) async {
    final csv = createCsv(expenses);

    final directory = Directory(
      '${Platform.environment['USERPROFILE']}\\Downloads',
    );

    final fileName = "kakeibo_${DateTime.now().millisecondsSinceEpoch}.csv";

    final file = File("${directory.path}/$fileName");

    await file.writeAsString(csv);

    return file.path;
  }
}

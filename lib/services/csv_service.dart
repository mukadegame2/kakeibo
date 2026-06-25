import 'package:csv/csv.dart';

import '../models/expense.dart';

import 'dart:io';

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

  static String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  static Future<String> saveCsv(List<Expense> expenses) async {
    final csv = createCsv(expenses);

    final userProfile = Platform.environment['USERPROFILE'];

    if (userProfile == null || userProfile.isEmpty) {
      throw Exception("ユーザーフォルダを取得できませんでした");
    }

    final directory = Directory('$userProfile\\Downloads');

    if (!await directory.exists()) {
      throw Exception("Downloadsフォルダが見つかりませんでした");
    }

    final now = DateTime.now();

    final timestamp =
        "${now.year}"
        "${_twoDigits(now.month)}"
        "${_twoDigits(now.day)}_"
        "${_twoDigits(now.hour)}"
        "${_twoDigits(now.minute)}"
        "${_twoDigits(now.second)}";

    final file = File('${directory.path}\\kakeibo_$timestamp.csv');

    // Excelで開いたときの文字化け対策としてBOMを付ける
    await file.writeAsString('\ufeff$csv');

    return file.path;
  }
}

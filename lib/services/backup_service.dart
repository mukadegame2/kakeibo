import 'dart:io';

import '../models/expense.dart';
import 'csv_service.dart';

class BackupService {
  static Future<String> saveBackup(List<Expense> expenses) async {
    final csv = CsvService.createCsv(expenses);

    final now = DateTime.now();

    final fileName =
        "kakeibo_backup_"
        "${now.year}"
        "${now.month.toString().padLeft(2, '0')}"
        "${now.day.toString().padLeft(2, '0')}_"
        "${now.hour.toString().padLeft(2, '0')}"
        "${now.minute.toString().padLeft(2, '0')}"
        "${now.second.toString().padLeft(2, '0')}"
        ".csv";

    final userProfile = Platform.environment['USERPROFILE'];

    if (userProfile == null) {
      throw Exception("ユーザーフォルダが取得できませんでした");
    }

    final path = "$userProfile\\Downloads\\$fileName";

    final file = File(path);

    await file.writeAsString(csv);

    return path;
  }
}
import 'package:csv/csv.dart';

import '../models/expense.dart';

class CsvImportResult {
  final List<Expense> expenses;
  final int skippedRows;

  const CsvImportResult({required this.expenses, required this.skippedRows});
}

class CsvImportService {
  static CsvImportResult importCsv(String csvText) {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(csvText);

    if (rows.isEmpty) {
      return const CsvImportResult(expenses: [], skippedRows: 0);
    }

    final expenses = <Expense>[];
    var skippedRows = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      if (_isEmptyRow(row)) {
        continue;
      }

      if (row.length < 5) {
        skippedRows++;
        continue;
      }

      final date = _parseDate(row[0].toString());
      final type = row[1].toString().trim();
      final category = row[2].toString().trim();
      final amount = _parseAmount(row[3].toString());
      final memo = row[4].toString().trim();

      if (date == null || category.isEmpty || amount == null || amount <= 0) {
        skippedRows++;
        continue;
      }

      final isIncome = type.contains('収入');

      expenses.add(
        Expense(
          amount: amount,
          category: category,
          memo: memo,
          date: date,
          isIncome: isIncome,
        ),
      );
    }

    return CsvImportResult(expenses: expenses, skippedRows: skippedRows);
  }

  static CsvImportResult importPayPayCsv(String csvText) {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(csvText);

    if (rows.isEmpty) {
      return const CsvImportResult(expenses: [], skippedRows: 0);
    }

    final header = rows.first.map((cell) {
      return _normalizeHeader(cell.toString());
    }).toList();

    final dateIndex = header.indexOf('取引日');
    final withdrawalIndex = header.indexOf('出金金額（円）');
    final transactionTypeIndex = header.indexOf('取引内容');
    final partnerIndex = header.indexOf('取引先');

    if (dateIndex == -1 || withdrawalIndex == -1) {
      return CsvImportResult(
        expenses: const [],
        skippedRows: rows.length > 1 ? rows.length - 1 : 0,
      );
    }

    final expenses = <Expense>[];
    var skippedRows = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      if (_isEmptyRow(row)) {
        continue;
      }

      final dateText = _valueAt(row, dateIndex);
      final withdrawalText = _valueAt(row, withdrawalIndex);
      final transactionType = transactionTypeIndex == -1
          ? ''
          : _valueAt(row, transactionTypeIndex);
      final partner = partnerIndex == -1 ? '' : _valueAt(row, partnerIndex);

      final date = _parseDate(dateText);
      final amount = _parseAmount(withdrawalText);

      // PayPayチャージなど、出金金額がない行は取り込まない
      if (date == null || amount == null || amount <= 0) {
        skippedRows++;
        continue;
      }

      final memo = _buildPayPayMemo(
        transactionType: transactionType,
        partner: partner,
      );

      expenses.add(
        Expense(
          amount: amount,
          category: 'その他',
          memo: memo,
          date: date,
          isIncome: false,
        ),
      );
    }

    return CsvImportResult(expenses: expenses, skippedRows: skippedRows);
  }

  static String _buildPayPayMemo({
    required String transactionType,
    required String partner,
  }) {
    final cleanPartner = partner.trim();
    final cleanTransactionType = transactionType.trim();

    if (cleanPartner.isNotEmpty && cleanPartner != '-') {
      return cleanPartner;
    }

    if (cleanTransactionType.isNotEmpty && cleanTransactionType != '-') {
      return cleanTransactionType;
    }

    return 'PayPay';
  }

  static String _valueAt(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }

    return row[index].toString().trim();
  }

  static String _normalizeHeader(String value) {
    return value.replaceFirst('\uFEFF', '').trim();
  }

  static bool _isEmptyRow(List<dynamic> row) {
    return row.every((cell) => cell.toString().trim().isEmpty);
  }

  static DateTime? _parseDate(String value) {
    final text = value.trim();

    if (text.isEmpty || text == '-') {
      return null;
    }

    final parts = text.split(RegExp(r'\s+'));
    final dateText = parts.first.replaceAll('-', '/').replaceAll('.', '/');
    final dateParts = dateText.split('/');

    if (dateParts.length != 3) {
      return null;
    }

    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);

    if (year == null || month == null || day == null) {
      return null;
    }

    var hour = 0;
    var minute = 0;
    var second = 0;

    if (parts.length >= 2) {
      final timeParts = parts[1].split(':');

      if (timeParts.length >= 2) {
        hour = int.tryParse(timeParts[0]) ?? 0;
        minute = int.tryParse(timeParts[1]) ?? 0;
      }

      if (timeParts.length >= 3) {
        second = int.tryParse(timeParts[2]) ?? 0;
      }
    }

    final date = DateTime(year, month, day, hour, minute, second);

    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return date;
  }

  static int? _parseAmount(String value) {
    var text = _toHalfWidth(value.trim());

    if (text.isEmpty || text == '-') {
      return null;
    }

    text = text
        .replaceAll(',', '')
        .replaceAll('，', '')
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .replaceAll('円', '')
        .replaceAll(' ', '')
        .replaceAll('　', '');

    if (text.startsWith('+')) {
      text = text.substring(1);
    }

    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) {
      return null;
    }

    final number = double.tryParse(text);

    if (number == null) {
      return null;
    }

    return number.round();
  }

  static String _toHalfWidth(String value) {
    final buffer = StringBuffer();

    for (final codeUnit in value.codeUnits) {
      if (codeUnit >= 0xFF10 && codeUnit <= 0xFF19) {
        buffer.writeCharCode(codeUnit - 0xFF10 + 0x30);
      } else if (codeUnit == 0xFF0B) {
        buffer.write('+');
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }

    return buffer.toString();
  }
}

class AmountParser {
  static int? parsePositiveInt(String value) {
    final amount = parseInt(value);

    if (amount == null || amount <= 0) {
      return null;
    }

    return amount;
  }

  static int? parseNonNegativeInt(String value) {
    final amount = parseInt(value);

    if (amount == null || amount < 0) {
      return null;
    }

    return amount;
  }

  static int? parseInt(String value) {
    var text = _toHalfWidth(value.trim());

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

    if (!RegExp(r'^\d+$').hasMatch(text)) {
      return null;
    }

    return int.tryParse(text);
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

import 'package:intl/intl.dart';

class FormatHelper {
  static final NumberFormat _numberFormatter = NumberFormat('#,###');

  static String yen(int value) {
    return '¥${_numberFormatter.format(value)}';
  }

  static String signedYen(int value) {
    if (value >= 0) {
      return '+¥${_numberFormatter.format(value)}';
    }

    return '-¥${_numberFormatter.format(value.abs())}';
  }
}
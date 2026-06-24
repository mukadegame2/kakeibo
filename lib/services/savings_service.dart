import 'package:shared_preferences/shared_preferences.dart';

class SavingsService {
  static const String initialSavingsKey = 'initial_savings';

  static Future<int> loadInitialSavings() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(initialSavingsKey) ?? 0;
  }

  static Future<void> saveInitialSavings(int amount) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(initialSavingsKey, amount);
  }
}

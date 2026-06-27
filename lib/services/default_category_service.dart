import 'package:shared_preferences/shared_preferences.dart';

class DefaultCategoryService {
  static const String defaultExpenseCategoryKey = "default_expense_category";
  static const String defaultIncomeCategoryKey = "default_income_category";

  static Future<String?> loadExpenseDefaultCategory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(defaultExpenseCategoryKey);
  }

  static Future<void> saveExpenseDefaultCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(defaultExpenseCategoryKey, category);
  }

  static Future<String?> loadIncomeDefaultCategory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(defaultIncomeCategoryKey);
  }

  static Future<void> saveIncomeDefaultCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(defaultIncomeCategoryKey, category);
  }
}

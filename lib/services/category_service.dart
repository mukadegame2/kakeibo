import 'package:shared_preferences/shared_preferences.dart';

class CategoryService {
  // 旧カテゴリキー
  // 既存データとの互換用に残す
  static const String categoryKey = "categories";

  // 新しいカテゴリキー
  static const String expenseCategoryKey = "expense_categories";
  static const String incomeCategoryKey = "income_categories";

  static const List<String> defaultExpenseCategories = [
    '食費',
    '日用品',
    '交通費',
    '趣味',
    '交際費',
    'その他',
  ];

  static const List<String> defaultIncomeCategories = [
    '給与',
    '副収入',
    'おこづかい',
    'その他',
  ];

  static List<String> _ensureOther(List<String> categories) {
    final result = [...categories];

    if (!result.contains('その他')) {
      result.add('その他');
    }

    return result;
  }

  // ========================================
  // 支出カテゴリ
  // ========================================
  static Future<List<String>> loadExpenseCategories() async {
    final prefs = await SharedPreferences.getInstance();

    final categories =
        prefs.getStringList(expenseCategoryKey) ??
        prefs.getStringList(categoryKey) ??
        defaultExpenseCategories;

    return _ensureOther(categories);
  }

  static Future<void> saveExpenseCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(expenseCategoryKey, _ensureOther(categories));
  }

  // ========================================
  // 収入カテゴリ
  // ========================================
  static Future<List<String>> loadIncomeCategories() async {
    final prefs = await SharedPreferences.getInstance();

    final categories =
        prefs.getStringList(incomeCategoryKey) ?? defaultIncomeCategories;

    return _ensureOther(categories);
  }

  static Future<void> saveIncomeCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(incomeCategoryKey, _ensureOther(categories));
  }

  // ========================================
  // 既存コード互換用
  // 今までの loadCategories / saveCategories は支出カテゴリ扱いにする
  // ========================================
  static Future<List<String>> loadCategories() async {
    return loadExpenseCategories();
  }

  static Future<void> saveCategories(List<String> categories) async {
    await saveExpenseCategories(categories);
  }
}

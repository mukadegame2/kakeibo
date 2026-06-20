import 'package:shared_preferences/shared_preferences.dart';

class CategoryService {
  static const String categoryKey = "categories";

  static Future<List<String>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();

    final categories =
        prefs.getStringList(categoryKey) ??
        ['食費', '日用品', '交通費', '趣味', '交際費', 'その他'];

    if (!categories.contains('その他')) {
      categories.add('その他');
      await prefs.setStringList(categoryKey, categories);
    }

    return categories;
  }

  static Future<void> saveCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(categoryKey, categories);
  }
}

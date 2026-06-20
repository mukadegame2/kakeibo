class CategoryHelper {
  static String parentOf(String category) {
    return category.split('/').first;
  }

  static String childOf(String category) {
    final parts = category.split('/');

    if (parts.length < 2) {
      return '';
    }

    return parts.sublist(1).join('/');
  }

  static bool isChildCategory(String category) {
    return category.contains('/');
  }

  static String displayName(String category) {
    return category.replaceAll('/', ' > ');
  }

  static String createChildCategory({
    required String parent,
    required String child,
  }) {
    return '$parent/$child';
  }
}

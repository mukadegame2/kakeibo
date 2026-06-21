import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/category_service.dart';
import '../services/csv_service.dart';
import 'dart:io';
import '../services/csv_import_service.dart';
import 'package:file_picker/file_picker.dart';
import '../services/backup_service.dart';
import '../services/category_helper.dart';

// ========================================
// 設定画面
// アプリ設定やカテゴリ管理を行う画面
// （現在は仮実装）
// ========================================
class SettingPage extends StatefulWidget {
  final List<Expense> expenses;
  final Future<void> Function() onSave;

  // コンストラクタ
  const SettingPage({super.key, required this.expenses, required this.onSave});

  // ========================================
  // 画面描画
  // ========================================
  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _isIncomeCategoryMode = false;

  List<String> _expenseCategories = [];
  List<String> _incomeCategories = [];

  List<String> get categories {
    return _isIncomeCategoryMode ? _incomeCategories : _expenseCategories;
  }

  final TextEditingController categoryController = TextEditingController();

  final TextEditingController childCategoryController = TextEditingController();

  String? selectedParentCategory;

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  @override
  void dispose() {
    categoryController.dispose();
    childCategoryController.dispose();

    super.dispose();
  }

  Future<void> loadCategories() async {
    final expenseCategories = await CategoryService.loadExpenseCategories();
    final incomeCategories = await CategoryService.loadIncomeCategories();

    if (!mounted) return;

    setState(() {
      _expenseCategories = expenseCategories;
      _incomeCategories = incomeCategories;
      _syncSelectedParentCategory();
    });
  }

  void _syncSelectedParentCategory() {
    final parentCategories = categories
        .where((category) => !CategoryHelper.isChildCategory(category))
        .toList();

    if (parentCategories.isEmpty) {
      selectedParentCategory = null;
      return;
    }

    if (selectedParentCategory == null ||
        !parentCategories.contains(selectedParentCategory)) {
      selectedParentCategory = parentCategories.first;
    }
  }

  Future<void> _saveCurrentCategories() async {
    if (_isIncomeCategoryMode) {
      await CategoryService.saveIncomeCategories(_incomeCategories);
    } else {
      await CategoryService.saveExpenseCategories(_expenseCategories);
    }
  }

  Future<void> _syncCategoriesFromExpenses(
    List<Expense> importedExpenses,
  ) async {
    final expenseCategorySet = _expenseCategories.toSet();
    final incomeCategorySet = _incomeCategories.toSet();

    void addCategory({required String category, required bool isIncome}) {
      final targetCategories = isIncome
          ? _incomeCategories
          : _expenseCategories;
      final targetSet = isIncome ? incomeCategorySet : expenseCategorySet;

      if (category.isEmpty) {
        return;
      }

      // 子カテゴリの場合、親カテゴリも自動追加する
      if (CategoryHelper.isChildCategory(category)) {
        final parent = CategoryHelper.parentOf(category);

        if (parent.isNotEmpty && !targetSet.contains(parent)) {
          targetCategories.add(parent);
          targetSet.add(parent);
        }
      }

      // 明細に使われているカテゴリをカテゴリ一覧へ追加する
      if (!targetSet.contains(category)) {
        targetCategories.add(category);
        targetSet.add(category);
      }
    }

    for (final expense in importedExpenses) {
      final category = expense.category.trim();

      addCategory(category: category, isIncome: expense.isIncome);
    }

    if (!expenseCategorySet.contains("その他")) {
      _expenseCategories.add("その他");
    }

    if (!incomeCategorySet.contains("その他")) {
      _incomeCategories.add("その他");
    }

    await CategoryService.saveExpenseCategories(_expenseCategories);
    await CategoryService.saveIncomeCategories(_incomeCategories);

    _syncSelectedParentCategory();
  }

  Future<void> importCsvFile({bool isBackupRestore = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null) {
      return;
    }

    final path = result.files.single.path;

    if (path == null) {
      return;
    }

    final fileName = result.files.single.name;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isBackupRestore ? "バックアップ復元確認" : "CSVインポート確認"),

          content: Text(
            isBackupRestore
                ? "以下のバックアップファイルから復元します。\n\n"
                      "$fileName\n\n"
                      "現在の家計簿データはすべて上書きされます。\n"
                      "この操作は元に戻せません。\n\n"
                      "復元前に、必要であれば現在のデータをバックアップしてください。"
                : "以下のCSVファイルを読み込みます。\n\n"
                      "$fileName\n\n"
                      "現在の家計簿データはすべて上書きされます。\n"
                      "この操作は元に戻せません。",
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text("キャンセル"),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(isBackupRestore ? "復元する" : "インポートする"),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      final csvText = await File(path).readAsString();

      final importedExpenses = CsvImportService.importCsv(csvText);

      importedExpenses.sort((a, b) => b.date.compareTo(a.date));

      await _syncCategoriesFromExpenses(importedExpenses);

      widget.expenses.clear();
      widget.expenses.addAll(importedExpenses);

      await widget.onSave();

      if (!mounted) return;

      setState(() {
        _syncSelectedParentCategory();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBackupRestore
                ? "${importedExpenses.length}件のデータを復元しました"
                : "${importedExpenses.length}件のデータを読み込みました",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBackupRestore
                ? "バックアップ復元に失敗しました\nCSV形式を確認してください"
                : "CSVインポートに失敗しました\nCSV形式を確認してください",
          ),
        ),
      );
    }
  }

  Future<void> _showEditCategoryDialog(String oldCategory) async {
    final controller = TextEditingController(
      text: CategoryHelper.isChildCategory(oldCategory)
          ? CategoryHelper.childOf(oldCategory)
          : oldCategory,
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("カテゴリ名変更"),

          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: CategoryHelper.isChildCategory(oldCategory)
                  ? "子カテゴリ名"
                  : "親カテゴリ名",
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("キャンセル"),
            ),

            ElevatedButton(
              onPressed: () async {
                final inputCategory = controller.text.trim();

                if (inputCategory.isEmpty) {
                  return;
                }

                // 「その他」は名前変更不可
                if (oldCategory == "その他") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("「その他」は名前変更できません")),
                  );
                  return;
                }

                final oldIsChild = CategoryHelper.isChildCategory(oldCategory);

                // 子カテゴリがある親カテゴリは名前変更不可
                final childCategories = categories.where((category) {
                  return CategoryHelper.isChildCategory(category) &&
                      CategoryHelper.parentOf(category) == oldCategory;
                }).toList();

                if (!oldIsChild && childCategories.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("子カテゴリがある親カテゴリ名は変更できません")),
                  );
                  return;
                }

                String newCategory = inputCategory;

                // 子カテゴリの場合、「コンビニ2」だけ入力しても親カテゴリを維持する
                if (oldIsChild && !inputCategory.contains('/')) {
                  newCategory = CategoryHelper.createChildCategory(
                    parent: CategoryHelper.parentOf(oldCategory),
                    child: inputCategory,
                  );
                }

                // 親カテゴリ名に / は使わせない
                if (!oldIsChild && newCategory.contains('/')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("親カテゴリ名に / は使わないでください")),
                  );
                  return;
                }

                // 子カテゴリは 親/子 の2階層だけ許可
                if (oldIsChild && newCategory.split('/').length != 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("子カテゴリは 親カテゴリ/子カテゴリ の形式にしてください"),
                    ),
                  );
                  return;
                }

                // 子カテゴリの親が存在するか確認
                if (oldIsChild) {
                  final parent = CategoryHelper.parentOf(newCategory);

                  if (!categories.contains(parent)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("存在しない親カテゴリは指定できません")),
                    );
                    return;
                  }
                }

                // 同じ名前はOK、別名で既存カテゴリと重複するのはNG
                if (newCategory != oldCategory &&
                    categories.contains(newCategory)) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("既に存在するカテゴリです")));
                  return;
                }

                final index = categories.indexOf(oldCategory);

                if (index == -1) {
                  return;
                }

                categories[index] = newCategory;

                for (int i = 0; i < widget.expenses.length; i++) {
                  final expense = widget.expenses[i];

                  if (expense.category == oldCategory) {
                    widget.expenses[i] = expense.copyWith(
                      category: newCategory,
                    );
                  }
                }

                await _saveCurrentCategories();

                await widget.onSave();

                if (!mounted) return;

                setState(() {
                  _syncSelectedParentCategory();
                });

                Navigator.pop(dialogContext);
              },
              child: const Text("保存"),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parentCategories = categories
        .where((category) => !CategoryHelper.isChildCategory(category))
        .toList();

    final displayCategories = _buildCategoryDisplayList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _buildSectionCard(
          title: "カテゴリ種別",
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text("支出カテゴリ"),
                  icon: Icon(Icons.remove_circle_outline),
                ),
                ButtonSegment(
                  value: true,
                  label: Text("収入カテゴリ"),
                  icon: Icon(Icons.add_circle_outline),
                ),
              ],
              selected: {_isIncomeCategoryMode},
              onSelectionChanged: (selection) {
                setState(() {
                  _isIncomeCategoryMode = selection.first;
                  _syncSelectedParentCategory();
                  categoryController.clear();
                  childCategoryController.clear();
                });
              },
            ),
          ],
        ),

        _buildSectionCard(
          title: _isIncomeCategoryMode ? "収入カテゴリ追加" : "支出カテゴリ追加",
          children: [
            const Text(
              "親カテゴリ追加",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: "親カテゴリ名",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                ElevatedButton(
                  onPressed: () async {
                    final category = categoryController.text.trim();

                    if (category.isEmpty) {
                      return;
                    }

                    if (category.contains('/')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("親カテゴリ名に / は使わないでください")),
                      );
                      return;
                    }

                    if (categories.contains(category)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("既に存在するカテゴリです")),
                      );
                      return;
                    }

                    categories.add(category);

                    await _saveCurrentCategories();

                    if (!mounted) return;

                    categoryController.clear();

                    setState(() {
                      selectedParentCategory = category;
                    });
                  },
                  child: const Text("追加"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              "子カテゴリ追加",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedParentCategory,
                    decoration: const InputDecoration(
                      labelText: "親カテゴリ",
                      border: OutlineInputBorder(),
                    ),
                    items: parentCategories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(CategoryHelper.displayName(category)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedParentCategory = value;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: TextField(
                    controller: childCategoryController,
                    decoration: const InputDecoration(
                      labelText: "子カテゴリ名",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                ElevatedButton(
                  onPressed: () async {
                    final parent = selectedParentCategory;
                    final child = childCategoryController.text.trim();

                    if (parent == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("親カテゴリを選択してください")),
                      );
                      return;
                    }

                    if (child.isEmpty) {
                      return;
                    }

                    if (child.contains('/')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("子カテゴリ名に / は使わないでください")),
                      );
                      return;
                    }

                    final category = CategoryHelper.createChildCategory(
                      parent: parent,
                      child: child,
                    );

                    if (categories.contains(category)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("既に存在するカテゴリです")),
                      );
                      return;
                    }

                    categories.add(category);

                    await _saveCurrentCategories();

                    if (!mounted) return;

                    childCategoryController.clear();

                    setState(() {
                      _syncSelectedParentCategory();
                    });
                  },
                  child: const Text("追加"),
                ),
              ],
            ),
          ],
        ),

        SizedBox(
          height: 260,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ListView(
                primary: false,
                children: displayCategories.map((category) {
                  final isChild = CategoryHelper.isChildCategory(category);

                  return ListTile(
                    leading: Icon(
                      isChild ? Icons.subdirectory_arrow_right : Icons.folder,
                    ),

                    contentPadding: EdgeInsets.only(
                      left: isChild ? 32 : 16,
                      right: 16,
                    ),

                    title: Text(
                      isChild
                          ? CategoryHelper.childOf(category)
                          : CategoryHelper.displayName(category),
                    ),

                    onTap: () {
                      _showEditCategoryDialog(category);
                    },

                    trailing: IconButton(
                      icon: const Icon(Icons.delete),

                      onPressed: () async {
                        if (category == "その他") {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("「その他」は削除できません")),
                          );
                          return;
                        }

                        final childCategories = categories.where((c) {
                          return CategoryHelper.isChildCategory(c) &&
                              CategoryHelper.parentOf(c) == category;
                        }).toList();

                        if (!CategoryHelper.isChildCategory(category) &&
                            childCategories.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("子カテゴリがある親カテゴリは削除できません"),
                            ),
                          );
                          return;
                        }

                        if (categories.length <= 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("最後のカテゴリは削除できません")),
                          );
                          return;
                        }

                        final result = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) {
                            return AlertDialog(
                              title: const Text("カテゴリ削除"),
                              content: Text(
                                "「${CategoryHelper.displayName(category)}」を削除しますか？\n\n"
                                "このカテゴリの既存データは「その他」に変更されます。",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext, false);
                                  },
                                  child: const Text("キャンセル"),
                                ),

                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext, true);
                                  },
                                  child: const Text("削除"),
                                ),
                              ],
                            );
                          },
                        );

                        if (result != true) {
                          return;
                        }

                        for (int i = 0; i < widget.expenses.length; i++) {
                          final expense = widget.expenses[i];

                          if (expense.category == category) {
                            widget.expenses[i] = expense.copyWith(
                              category: "その他",
                            );
                          }
                        }

                        categories.remove(category);

                        await _saveCurrentCategories();

                        await widget.onSave();

                        if (!mounted) return;

                        setState(() {
                          _syncSelectedParentCategory();
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        _buildSectionCard(
          title: "データ管理",
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final path = await BackupService.saveBackup(widget.expenses);

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("バックアップを作成しました\n$path")),
                  );
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("バックアップ作成に失敗しました")),
                  );
                }
              },
              icon: const Icon(Icons.backup),
              label: const Text("バックアップ作成"),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () async {
                await importCsvFile(isBackupRestore: true);
              },
              icon: const Icon(Icons.restore),
              label: const Text("バックアップ復元"),
            ),
          ],
        ),

        _buildSectionCard(
          title: "CSV",
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final path = await CsvService.saveCsv(widget.expenses);

                if (!mounted) return;

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("CSV保存完了\n$path")));
              },
              icon: const Icon(Icons.file_download),
              label: const Text("CSV保存"),
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: () async {
                await importCsvFile();
              },
              icon: const Icon(Icons.file_upload),
              label: const Text("CSVインポート"),
            ),
          ],
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            ...children,
          ],
        ),
      ),
    );
  }

  List<String> _buildCategoryDisplayList() {
    final parentCategories = categories
        .where((category) => !CategoryHelper.isChildCategory(category))
        .toList();

    final displayList = <String>[];

    for (final parent in parentCategories) {
      displayList.add(parent);

      final children = categories.where((category) {
        return CategoryHelper.isChildCategory(category) &&
            CategoryHelper.parentOf(category) == parent;
      }).toList();

      displayList.addAll(children);
    }

    final orphanChildren = categories.where((category) {
      return CategoryHelper.isChildCategory(category) &&
          !parentCategories.contains(CategoryHelper.parentOf(category));
    }).toList();

    displayList.addAll(orphanChildren);

    return displayList;
  }
}

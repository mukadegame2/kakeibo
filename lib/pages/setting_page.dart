import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/category_service.dart';
import '../services/csv_service.dart';
import 'dart:io';
import '../services/csv_import_service.dart';
import 'package:file_picker/file_picker.dart';
import '../services/backup_service.dart';
import '../services/category_helper.dart';
import '../services/savings_service.dart';
import '../utils/format_helper.dart';
import '../utils/amount_parser.dart';
import '../services/default_category_service.dart';
import '../services/initial_setup_service.dart';

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

  final TextEditingController initialSavingsController =
      TextEditingController();

  int initialSavings = 0;
  String? defaultExpenseCategory;
  String? defaultIncomeCategory;

  final TextEditingController childCategoryController = TextEditingController();

  String? selectedParentCategory;

  @override
  void initState() {
    super.initState();
    loadCategories();
    _loadInitialSavings();
  }

  @override
  void dispose() {
    categoryController.dispose();
    childCategoryController.dispose();
    initialSavingsController.dispose();

    super.dispose();
  }

  Future<void> loadCategories() async {
    final expenseCategories = await CategoryService.loadExpenseCategories();
    if (!mounted) return;

    final incomeCategories = await CategoryService.loadIncomeCategories();
    if (!mounted) return;

    final savedDefaultExpenseCategory =
        await DefaultCategoryService.loadExpenseDefaultCategory();
    if (!mounted) return;

    final savedDefaultIncomeCategory =
        await DefaultCategoryService.loadIncomeDefaultCategory();
    if (!mounted) return;

    setState(() {
      _expenseCategories = expenseCategories;
      _incomeCategories = incomeCategories;

      defaultExpenseCategory = _resolveDefaultCategory(
        _expenseCategories,
        savedDefaultExpenseCategory,
      );

      defaultIncomeCategory = _resolveDefaultCategory(
        _incomeCategories,
        savedDefaultIncomeCategory,
      );

      _syncSelectedParentCategory();
    });
  }

  Future<void> _loadInitialSavings() async {
    final value = await SavingsService.loadInitialSavings();
    if (!mounted) return;

    setState(() {
      initialSavings = value;
      initialSavingsController.text = value.toString();
    });
  }

  Future<void> _saveInitialSavings() async {
    final amount = AmountParser.parseNonNegativeInt(
      initialSavingsController.text,
    );

    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("初期貯金額は0以上の数字で入力してください")));
      return;
    }

    await SavingsService.saveInitialSavings(amount);
    if (!mounted) return;

    setState(() {
      initialSavings = amount;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("初期貯金額を保存しました")));
  }

  Future<void> _resetAllData() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("全データ初期化"),
          content: const Text(
            "収支データ、カテゴリ、初期貯金額をすべて初期化します。\n"
            "この操作は元に戻せません。\n\n"
            "実行前にバックアップを作成することをおすすめします。",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text("キャンセル"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text("初期化する"),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) {
      return;
    }

    widget.expenses.clear();

    _expenseCategories = List.from(CategoryService.defaultExpenseCategories);
    _incomeCategories = List.from(CategoryService.defaultIncomeCategories);

    final resetDefaultExpenseCategory = _expenseCategories.first;
    final resetDefaultIncomeCategory = _incomeCategories.first;

    await DefaultCategoryService.saveExpenseDefaultCategory(
      resetDefaultExpenseCategory,
    );
    await DefaultCategoryService.saveIncomeDefaultCategory(
      resetDefaultIncomeCategory,
    );

    await CategoryService.saveExpenseCategories(_expenseCategories);
    await CategoryService.saveIncomeCategories(_incomeCategories);

    await SavingsService.saveInitialSavings(0);

    await InitialSetupService.resetInitialSetup();

    await widget.onSave();

    if (!mounted) {
      return;
    }

    setState(() {
      initialSavings = 0;
      initialSavingsController.text = "0";
      defaultExpenseCategory = resetDefaultExpenseCategory;
      defaultIncomeCategory = resetDefaultIncomeCategory;
      _syncSelectedParentCategory();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("全データを初期化しました")));
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

  String? _resolveDefaultCategory(
    List<String> targetCategories,
    String? savedCategory,
  ) {
    if (targetCategories.isEmpty) {
      return null;
    }

    if (savedCategory != null && targetCategories.contains(savedCategory)) {
      return savedCategory;
    }

    return targetCategories.first;
  }

  String? _currentDefaultCategory() {
    return _isIncomeCategoryMode
        ? defaultIncomeCategory
        : defaultExpenseCategory;
  }

  Future<void> _saveCurrentDefaultCategory(String category) async {
    if (_isIncomeCategoryMode) {
      await DefaultCategoryService.saveIncomeDefaultCategory(category);
      if (!mounted) return;

      setState(() {
        defaultIncomeCategory = category;
      });
    } else {
      await DefaultCategoryService.saveExpenseDefaultCategory(category);
      if (!mounted) return;

      setState(() {
        defaultExpenseCategory = category;
      });
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("初期カテゴリを保存しました")));
  }

  Future<void> _saveCurrentCategories() async {
    if (_isIncomeCategoryMode) {
      await CategoryService.saveIncomeCategories(_incomeCategories);
      if (!mounted) return;
    } else {
      await CategoryService.saveExpenseCategories(_expenseCategories);
      if (!mounted) return;
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
    if (!mounted) return;

    await CategoryService.saveIncomeCategories(_incomeCategories);
    if (!mounted) return;

    _syncSelectedParentCategory();
  }

  String _expenseDuplicateKey(Expense expense) {
    return [
      expense.date.toIso8601String(),
      expense.amount.toString(),
      expense.isIncome ? 'income' : 'expense',
      expense.category,
      expense.memo.trim(),
    ].join('|');
  }

  List<Expense> _removeDuplicateImportedExpenses(
    List<Expense> importedExpenses,
  ) {
    final existingKeys = widget.expenses.map(_expenseDuplicateKey).toSet();

    final newExpenses = <Expense>[];
    final newKeys = <String>{};

    for (final expense in importedExpenses) {
      final key = _expenseDuplicateKey(expense);

      if (existingKeys.contains(key)) {
        continue;
      }

      if (newKeys.contains(key)) {
        continue;
      }

      newExpenses.add(expense);
      newKeys.add(key);
    }

    return newExpenses;
  }

  Future<void> restoreBackupCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (!mounted) return;

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
          title: const Text("バックアップ復元確認"),

          content: Text(
            "以下のバックアップファイルから復元します。\n\n"
            "$fileName\n\n"
            "現在の家計簿データはすべて上書きされます。\n"
            "この操作は元に戻せません。\n\n"
            "復元前に、必要であれば現在のデータをバックアップしてください。",
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
              child: const Text("復元する"),
            ),
          ],
        );
      },
    );
    if (!mounted) return;

    if (confirm != true) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    try {
      final csvText = await File(path).readAsString();

      if (!mounted) {
        return;
      }

      final importResult = CsvImportService.importCsv(csvText);
      final importedExpenses = importResult.expenses;

      if (importedExpenses.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              "復元できるデータがありませんでした\n"
              "スキップ：${importResult.skippedRows}件",
            ),
          ),
        );
        return;
      }

      importedExpenses.sort((a, b) => b.date.compareTo(a.date));

      await _syncCategoriesFromExpenses(importedExpenses);

      if (!mounted) {
        return;
      }

      widget.expenses.clear();
      widget.expenses.addAll(importedExpenses);

      await widget.onSave();

      if (!mounted) {
        return;
      }

      setState(() {
        _syncSelectedParentCategory();
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "バックアップを復元しました\n"
            "取込：${importedExpenses.length}件"
            "${importResult.skippedRows > 0 ? " / スキップ：${importResult.skippedRows}件" : ""}",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text("バックアップ復元に失敗しました\nCSV形式を確認してください")),
      );
    }
  }

  Future<void> importPayPayCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (!mounted) return;

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
          title: const Text("PayPay CSV取込確認"),
          content: Text(
            "以下のPayPay CSVファイルを取り込みます。\n\n"
            "$fileName\n\n"
            "出金金額がある行だけを支出として追加します。\n"
            "チャージなどの入金行は取り込みません。\n\n"
            "既存の家計簿データは上書きされません。",
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
              child: const Text("取り込む"),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (confirm != true) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    try {
      final csvText = await File(path).readAsString();

      if (!mounted) {
        return;
      }

      final importResult = CsvImportService.importPayPayCsv(csvText);
      final importedExpenses = importResult.expenses;

      if (importedExpenses.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              "PayPay CSVから取り込める支出がありませんでした\n"
              "スキップ：${importResult.skippedRows}件",
            ),
          ),
        );
        return;
      }

      final newExpenses = _removeDuplicateImportedExpenses(importedExpenses);

      if (newExpenses.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              "新しく取り込めるPayPay支出はありませんでした\n"
              "取込対象：${importedExpenses.length}件 / 重複：${importedExpenses.length}件",
            ),
          ),
        );
        return;
      }

      newExpenses.sort((a, b) => b.date.compareTo(a.date));

      await _syncCategoriesFromExpenses(newExpenses);

      if (!mounted) {
        return;
      }

      widget.expenses.addAll(newExpenses);
      widget.expenses.sort((a, b) => b.date.compareTo(a.date));

      await widget.onSave();

      if (!mounted) {
        return;
      }

      setState(() {
        _syncSelectedParentCategory();
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "PayPay CSVを取り込みました\n"
            "取込：${newExpenses.length}件"
            "${importedExpenses.length - newExpenses.length > 0 ? " / 重複：${importedExpenses.length - newExpenses.length}件" : ""}"
            "${importResult.skippedRows > 0 ? " / スキップ：${importResult.skippedRows}件" : ""}",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        const SnackBar(content: Text("PayPay CSVの取り込みに失敗しました")),
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

                if (_isIncomeCategoryMode &&
                    defaultIncomeCategory == oldCategory) {
                  defaultIncomeCategory = newCategory;
                  await DefaultCategoryService.saveIncomeDefaultCategory(
                    newCategory,
                  );
                }

                if (!_isIncomeCategoryMode &&
                    defaultExpenseCategory == oldCategory) {
                  defaultExpenseCategory = newCategory;
                  await DefaultCategoryService.saveExpenseDefaultCategory(
                    newCategory,
                  );
                }

                for (int i = 0; i < widget.expenses.length; i++) {
                  final expense = widget.expenses[i];

                  if (expense.isIncome == _isIncomeCategoryMode &&
                      expense.category == oldCategory) {
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

                if (!dialogContext.mounted) return;

                Navigator.pop(dialogContext);
              },
              child: const Text("保存"),
            ),
          ],
        );
      },
    );
    if (!mounted) return;

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
          title: "初期カテゴリ設定",
          children: [
            const Text("入力画面で最初に選ばれるカテゴリを設定します。"),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              key: ValueKey(
                'default-category-$_isIncomeCategoryMode-${_currentDefaultCategory() ?? ""}',
              ),
              initialValue: categories.contains(_currentDefaultCategory())
                  ? _currentDefaultCategory()
                  : categories.isNotEmpty
                  ? categories.first
                  : null,
              decoration: InputDecoration(
                labelText: _isIncomeCategoryMode ? "収入の初期カテゴリ" : "支出の初期カテゴリ",
                border: const OutlineInputBorder(),
              ),
              items: displayCategories.map((category) {
                final isChild = CategoryHelper.isChildCategory(category);

                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(
                    isChild
                        ? "   ↳ ${CategoryHelper.childOf(category)}"
                        : "📁 $category",
                  ),
                );
              }).toList(),
              onChanged: (value) async {
                if (value == null) {
                  return;
                }

                await _saveCurrentDefaultCategory(value);
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
                    key: ValueKey(
                      'parent-$_isIncomeCategoryMode-${selectedParentCategory ?? ""}',
                    ),
                    initialValue: selectedParentCategory,
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
                        if (!mounted) return;

                        if (result != true) {
                          return;
                        }

                        for (int i = 0; i < widget.expenses.length; i++) {
                          final expense = widget.expenses[i];

                          if (expense.isIncome == _isIncomeCategoryMode &&
                              expense.category == category) {
                            widget.expenses[i] = expense.copyWith(
                              category: "その他",
                            );
                          }
                        }

                        categories.remove(category);

                        if (_isIncomeCategoryMode &&
                            defaultIncomeCategory == category) {
                          final fallbackCategory = categories.contains("その他")
                              ? "その他"
                              : categories.first;

                          defaultIncomeCategory = fallbackCategory;
                          await DefaultCategoryService.saveIncomeDefaultCategory(
                            fallbackCategory,
                          );
                        }

                        if (!_isIncomeCategoryMode &&
                            defaultExpenseCategory == category) {
                          final fallbackCategory = categories.contains("その他")
                              ? "その他"
                              : categories.first;

                          defaultExpenseCategory = fallbackCategory;
                          await DefaultCategoryService.saveExpenseDefaultCategory(
                            fallbackCategory,
                          );
                        }

                        await _saveCurrentCategories();
                        if (!mounted) return;

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
                final messenger = ScaffoldMessenger.of(context);

                try {
                  final path = await BackupService.saveBackup(widget.expenses);

                  if (!mounted) return;

                  messenger.showSnackBar(
                    SnackBar(content: Text("バックアップを作成しました\n$path")),
                  );
                } catch (e) {
                  if (!mounted) return;

                  messenger.showSnackBar(
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
                await restoreBackupCsvFile();
                if (!mounted) return;
              },

              icon: const Icon(Icons.restore),
              label: const Text("バックアップ復元"),
            ),
          ],
        ),

        _buildSectionCard(
          title: "CSV",
          children: [
            const Text(
              "PayPayの利用履歴CSVを取り込めます。"
              "出金金額がある行だけを支出として追加し、チャージ行は取り込みません。",
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: () async {
                await importPayPayCsvFile();
                if (!mounted) return;
              },
              icon: const Icon(Icons.file_upload),
              label: const Text("PayPay CSV取込"),
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);

                try {
                  final path = await CsvService.saveCsv(widget.expenses);

                  if (!mounted) return;

                  messenger.showSnackBar(
                    SnackBar(content: Text("家計簿CSVを保存しました\n$path")),
                  );
                } catch (e) {
                  if (!mounted) return;

                  messenger.showSnackBar(
                    SnackBar(content: Text("家計簿CSV保存に失敗しました\n$e")),
                  );
                }
              },
              icon: const Icon(Icons.file_download),
              label: const Text("家計簿CSV保存"),
            ),
          ],
        ),

        _buildSectionCard(
          title: "貯金設定",
          children: [
            TextField(
              controller: initialSavingsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "初期貯金額",
                prefixText: "¥ ",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "現在の設定：${FormatHelper.yen(initialSavings)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _saveInitialSavings,
              icon: const Icon(Icons.savings),
              label: const Text("初期貯金額を保存"),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildSectionCard(
          title: "初期化",
          children: [
            const Text("収支データ、カテゴリ、初期貯金額をすべて初期状態に戻します。"),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: _resetAllData,
              icon: const Icon(Icons.delete_forever),
              label: const Text("全データを初期化"),
            ),
          ],
        ),
      ],
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

import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/category_service.dart';
import '../services/csv_service.dart';
import 'dart:io';
import '../services/csv_import_service.dart';
import 'package:file_picker/file_picker.dart';

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
  List<String> categories = [];

  final TextEditingController categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    categories = await CategoryService.loadCategories();

    setState(() {});
  }

  Future<void> importCsvFile() async {
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

    final csvText = await File(path).readAsString();

    final importedExpenses = CsvImportService.importCsv(csvText);

    widget.expenses.clear();

    widget.expenses.addAll(importedExpenses);

    await widget.onSave();

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${importedExpenses.length}件のデータを読み込みました")),
    );
  }

  void _showEditCategoryDialog(String oldCategory) {
    final controller = TextEditingController(text: oldCategory);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("カテゴリ名変更"),

          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: "カテゴリ名"),
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
                final newCategory = controller.text.trim();

                if (newCategory.isEmpty) {
                  return;
                }

                final index = categories.indexOf(oldCategory);

                categories[index] = newCategory;

                for (int i = 0; i < widget.expenses.length; i++) {
                  if (widget.expenses[i].category == oldCategory) {
                    widget.expenses[i] = Expense(
                      amount: widget.expenses[i].amount,
                      category: newCategory,
                      memo: widget.expenses[i].memo,
                      date: widget.expenses[i].date,
                      isIncome: widget.expenses[i].isIncome,
                    );
                  }
                }

                await CategoryService.saveCategories(categories);

                await widget.onSave();

                if (!mounted) return;

                setState(() {});

                Navigator.pop(dialogContext);
              },
              child: const Text("保存"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),

          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: "カテゴリ名"),
                ),
              ),

              ElevatedButton(
                onPressed: () async {
                  final category = categoryController.text.trim();

                  if (category.isEmpty) {
                    return;
                  }

                  if (categories.contains(category)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("既に存在するカテゴリです")),
                    );
                    return;
                  }

                  categories.add(category);

                  await CategoryService.saveCategories(categories);

                  categoryController.clear();

                  setState(() {});
                },
                child: const Text("追加"),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            children: categories
                .map(
                  (category) => ListTile(
                    title: Text(category),

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
                        if (categories.length <= 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("最後のカテゴリは削除できません")),
                          );
                          return;
                        }
                        final result = await showDialog<bool>(
                          context: context,

                          builder: (context) {
                            return AlertDialog(
                              title: const Text("カテゴリ削除"),

                              content: Text("「$category」を削除しますか？"),

                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context, false);
                                  },
                                  child: const Text("キャンセル"),
                                ),

                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context, true);
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

                        // 削除時にデータ移行
                        for (int i = 0; i < widget.expenses.length; i++) {
                          if (widget.expenses[i].category == category) {
                            widget.expenses[i] = Expense(
                              amount: widget.expenses[i].amount,
                              category: "その他",
                              memo: widget.expenses[i].memo,
                              date: widget.expenses[i].date,
                              isIncome: widget.expenses[i].isIncome,
                            );
                          }
                        }

                        categories.remove(category);

                        await CategoryService.saveCategories(categories);

                        await widget.onSave();

                        setState(() {});
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        ),

        // csv保存（出力）
        ElevatedButton(
          onPressed: () async {
            final path = await CsvService.saveCsv(widget.expenses);

            if (!mounted) return;

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("保存完了\n$path")));
          },
          child: const Text("CSV保存"),
        ),

        // csvインポート
        ElevatedButton(
          onPressed: () async {
            await importCsvFile();
          },
          child: const Text("CSVインポート"),
        ),
      ],
    );
  }
}

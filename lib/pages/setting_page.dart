import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/category_service.dart';
import '../services/csv_service.dart';
import 'dart:io';
import '../services/csv_import_service.dart';
import 'package:file_picker/file_picker.dart';
import '../services/backup_service.dart';

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

  @override
  void dispose() {
    categoryController.dispose();

    super.dispose();
  }

  Future<void> loadCategories() async {
    categories = await CategoryService.loadCategories();

    if (!mounted) return;

    setState(() {});
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

      widget.expenses.clear();
      widget.expenses.addAll(importedExpenses);

      await widget.onSave();

      if (!mounted) return;

      setState(() {});

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
    final controller = TextEditingController(text: oldCategory);

    await showDialog(
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

                // 「その他」は名前変更不可
                if (oldCategory == "その他") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("「その他」は名前変更できません")),
                  );
                  return;
                }

                // 同じ名前はOK
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

    controller.dispose();
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

                  if (!mounted) return;

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
                          final expense = widget.expenses[i];

                          if (expense.category == category) {
                            widget.expenses[i] = expense.copyWith(
                              category: "その他",
                            );
                          }
                        }

                        categories.remove(category);

                        await CategoryService.saveCategories(categories);

                        await widget.onSave();

                        if (!mounted) return;

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

        // バックアップ保存
        ElevatedButton(
          onPressed: () async {
            try {
              final path = await BackupService.saveBackup(widget.expenses);

              if (!mounted) return;

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("バックアップを作成しました\n$path")));
            } catch (e) {
              if (!mounted) return;

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("バックアップ作成に失敗しました\n$e")));
            }
          },
          child: const Text("バックアップ作成"),
        ),

        // csvインポート
        ElevatedButton(
          onPressed: () async {
            await importCsvFile();
          },
          child: const Text("CSVインポート"),
        ),

        // バックアップ復元ボタン
        ElevatedButton(
          onPressed: () async {
            await importCsvFile(isBackupRestore: true);
          },
          child: const Text("バックアップ復元"),
        ),
      ],
    );
  }
}

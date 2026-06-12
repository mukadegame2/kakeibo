import 'package:flutter/material.dart';

import '../services/category_service.dart';

// ========================================
// 設定画面
// アプリ設定やカテゴリ管理を行う画面
// （現在は仮実装）
// ========================================
class SettingPage extends StatefulWidget {
  // コンストラクタ
  const SettingPage({super.key});

  // ========================================
  // 画面描画
  // ========================================
  @override
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

                    trailing: IconButton(
                      icon: const Icon(Icons.delete),

                      onPressed: () async {
                        categories.remove(category);

                        await CategoryService.saveCategories(categories);

                        setState(() {});
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

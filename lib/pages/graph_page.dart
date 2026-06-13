import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/expense.dart';
import '../widgets/month_selector.dart';

// ========================================
// グラフ画面
// カテゴリ別の支出集計を表示する
// ========================================
class GraphPage extends StatefulWidget {
  // 家計簿データのリスト
  final List<Expense> expenses;

  // コンストラクタ
  const GraphPage({super.key, required this.expenses});

  @override // 状態管理クラスの生成
  State<GraphPage> createState() => _GraphPageState();
}

// ========================================
// グラフ画面の状態管理クラス
// ・月切替
// ・カテゴリ別集計
// ・グラフ描画
// を担当する
// ========================================
class _GraphPageState extends State<GraphPage> {
  // 対象カテゴリ抽出
  void _showCategoryDetail(String category) {
    final targetExpenses = widget.expenses.where((expense) {
      return expense.category == category &&
          expense.date.year == selectedMonth.year &&
          expense.date.month == selectedMonth.month &&
          expense.isIncome == showIncome;
    }).toList();

    // ソート
    targetExpenses.sort((a, b) => b.date.compareTo(a.date));

    // 合計金額を計算
    final total = targetExpenses.fold(
      0,
      (sum, expense) => sum + expense.amount,
    );

    int touchedIndex = -1;

    // ダイアログ
    showDialog(
      context: context,

      builder: (_) {
        return AlertDialog(
          title: Text(category),

          content: SizedBox(
            width: 300,

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                Text(
                  "合計 ¥$total",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const Divider(),

                SizedBox(
                  height: 300,

                  child: ListView(
                    children: targetExpenses.map((expense) {
                      return ListTile(
                        title: Text(expense.memo),

                        subtitle: Text(
                          "${expense.date.year}/${expense.date.month}/${expense.date.day}",
                        ),

                        trailing: Text("¥${expense.amount}"),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 表示中の年月
  DateTime selectedMonth = DateTime.now();

  bool showIncome = false;

  // ========================================
  // 画面描画
  // ・選択月のデータをカテゴリ別に集計
  // ・集計結果をグラフと一覧で表示
  // ========================================
  @override
  Widget build(BuildContext context) {
    // カテゴリごとの支出合計
    Map<String, int> categoryTotals = {};

    // ========================================
    // 支出データをカテゴリ別に集計
    // 収入は集計対象外
    // ========================================
    for (var expense in widget.expenses) {
      if (expense.date.year != selectedMonth.year ||
          expense.date.month != selectedMonth.month) {
        continue;
      }

      // 収入はスキップ
      if (expense.isIncome != showIncome) {
        continue;
      }

      // カテゴリ別に金額を加算
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    // データがない場合はメッセージ表示
    if (categoryTotals.isEmpty) {
      return const Center(child: Text("データがありません"));
    }

    // グラフの色設定
    List<Color> colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    // 合計金額（グラフの割合計算用）
    double total = categoryTotals.values.fold(0, (sum, value) => sum + value);
    final categoryList = categoryTotals.entries.toList();

    // ========================================
    // 集計結果を一覧表示
    // ========================================
    List<PieChartSectionData> sections = categoryTotals.entries
        .toList() // MapをListに変換
        .asMap() // インデックスを付与
        .entries // インデックスとデータのペアに変換
        .map((entry) {
          // インデックスとデータを取得
          int index = entry.key; // データを取得
          var data = entry.value; // データを取得

          // グラフの割合計算
          double percent = data.value / total * 100;

          // グラフのセクションデータを作成
          return PieChartSectionData(
            value: data.value.toDouble(), // 金額をグラフの値に設定
            title: "${percent.toStringAsFixed(0)}%", // 割合をタイトルに表示
            radius: 80, // セクションの半径
            color: colors[index % colors.length], // 色を設定（色の数が足りない場合はループ）
          );
        })
        .toList(); // Listに変換

    // ========================================

    // グラフ描画
    return Padding(
      // 画面全体の余白
      padding: const EdgeInsets.all(16),

      // グラフとカテゴリ別集計の一覧を縦に配置
      child: Column(
        // グラフと一覧を縦に配置
        children: [
          // タブ
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text("支出")),
              ButtonSegment(value: true, label: Text("収入")),
            ],

            selected: {showIncome},

            onSelectionChanged: (value) {
              setState(() {
                showIncome = value.first;
              });
            },
          ),

          // 月切替のUI
          MonthSelector(
            selectedMonth: selectedMonth,

            onPrevious: () {
              setState(() {
                selectedMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month - 1,
                );
              });
            },

            onNext: () {
              setState(() {
                selectedMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month + 1,
                );
              });
            },
          ),

          // 月切替とグラフの間の余白
          const SizedBox(height: 20),

          // カテゴリ別集計のタイトル
          const Text(
            "カテゴリ別支出",
            style: TextStyle(
              fontSize: 20, // フォントサイズ
              fontWeight: FontWeight.bold, // フォントの太さ
            ),
          ),

          // タイトルとグラフの間の余白
          const SizedBox(height: 20),

          // グラフ描画
          Expanded(
            child: PieChart(
              PieChartData(
                sections: sections,

                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (response == null || response.touchedSection == null) {
                      return;
                    }

                    final touchedIndex =
                        response.touchedSection!.touchedSectionIndex;

                    final category = categoryList[touchedIndex].key;

                    Future.microtask(() {
                      if (!mounted) return;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _showCategoryDetail(category);
                      });
                    });
                  },
                ),
              ),
            ),
          ),

          // カテゴリー一覧表示
          Expanded(
            child: ListView(
              children: categoryTotals.entries.toList().asMap().entries.map((
                entry,
              ) {
                int index = entry.key;
                var data = entry.value;
                double percent = data.value / total * 100;

                return ListTile(
                  leading: CircleAvatar(
                    radius: 8,
                    backgroundColor: colors[index % colors.length],
                  ),

                  title: Text(data.key),

                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("¥${data.value}"),
                      Text(
                        "${percent.toStringAsFixed(0)}%",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  onTap: () {
                    _showCategoryDetail(data.key);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

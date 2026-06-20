import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/category_service.dart';

import '../models/expense.dart';
import '../widgets/month_selector.dart';
import '../widgets/monthly_balance_chart.dart';
import 'category_detail_page.dart';

// ========================================
// グラフ画面
// カテゴリ別の支出集計を表示する
// ========================================
class GraphPage extends StatefulWidget {
  // 家計簿データのリスト
  final List<Expense> expenses;
  final Future<void> Function() onSave;

  // コンストラクタ
  const GraphPage({super.key, required this.expenses, required this.onSave});

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
  List<String> categories = [];
  Future<void> loadCategories() async {
    categories = await CategoryService.loadCategories();

    if (!mounted) return;

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loadCategories();
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
    Map<String, int> categoryTotals = {
      for (var category in categories) category: 0,
    };

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

    final rankingList = categoryTotals.entries
        .where((entry) => entry.value > 0)
        .toList();

    rankingList.sort((a, b) => b.value.compareTo(a.value));

    final income = widget.expenses
        .where(
          (e) =>
              e.isIncome &&
              e.date.year == selectedMonth.year &&
              e.date.month == selectedMonth.month,
        )
        .fold(0, (sum, e) => sum + e.amount);

    final expense = widget.expenses
        .where(
          (e) =>
              !e.isIncome &&
              e.date.year == selectedMonth.year &&
              e.date.month == selectedMonth.month,
        )
        .fold(0, (sum, e) => sum + e.amount);

    final balance = income - expense;

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
          double percent = total == 0 ? 0 : data.value / total * 100;

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
    return SingleChildScrollView(
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

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text("収入 : ¥$income"),
                  Text("支出 : ¥$expense"),

                  Text(
                    "収支 : ¥$balance",
                    style: TextStyle(
                      color: balance >= 0 ? Colors.blue : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // カテゴリ別集計のタイトル
          const Text(
            "カテゴリ別支出",
            style: TextStyle(
              fontSize: 20, // フォントサイズ
              fontWeight: FontWeight.bold, // フォントの太さ
            ),
          ),

          // タイトルとグラフの間の余白
          const SizedBox(height: 10),

          const Text(
            "カテゴリランキング",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 5),

          // グラフ描画
          SizedBox(
            height: 260,
            child: total == 0
                ? const Center(child: Text("この月のデータはありません"))
                : PieChart(
                    PieChartData(
                      sections: sections,

                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (response == null ||
                              response.touchedSection == null) {
                            return;
                          }

                          final touchedIndex =
                              response.touchedSection!.touchedSectionIndex;

                          if (touchedIndex < 0 ||
                              touchedIndex >= categoryList.length) {
                            return;
                          }

                          if (event is! FlTapUpEvent) {
                            return;
                          }

                          final category = categoryList[touchedIndex].key;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryDetailPage(
                                category: category,
                                expenses: widget.expenses,
                                onSave: widget.onSave,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 8),

          const Text(
            "月別収支推移",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          MonthlyBalanceChart(expenses: widget.expenses),

          const SizedBox(height: 8),

          // カテゴリー一覧表示
          // カテゴリランキング
          SizedBox(
            height: 420,
            child: total == 0
                ? const SizedBox()
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rankingList.length,
                    itemBuilder: (context, index) {
                      final data = rankingList[index];

                      double percent = total == 0
                          ? 0
                          : data.value / total * 100;

                      return ListTile(
                        leading: SizedBox(
                          width: 40,
                          child: Center(
                            child: Text(
                              index == 0
                                  ? "🥇"
                                  : index == 1
                                  ? "🥈"
                                  : index == 2
                                  ? "🥉"
                                  : "${index + 1}",
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),

                        title: Text(data.key),

                        subtitle: Text("${percent.toStringAsFixed(1)}%"),

                        trailing: Text(
                          "¥${data.value}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),

                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryDetailPage(
                                category: data.key,
                                expenses: widget.expenses,
                                onSave: widget.onSave,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

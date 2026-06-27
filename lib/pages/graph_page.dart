import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/category_service.dart';

import '../models/expense.dart';
import '../widgets/month_selector.dart';
import '../widgets/monthly_balance_chart.dart';
import 'category_detail_page.dart';
import '../services/category_helper.dart';
import '../utils/format_helper.dart';
import '../widgets/summary_card.dart';
import '../widgets/savings_balance_chart.dart';
import '../services/savings_service.dart';

enum GraphMode { expense, income, savings }

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

  int initialSavings = 0;

  Future<void> loadInitialSavings() async {
    final value = await SavingsService.loadInitialSavings();

    if (!mounted) return;

    setState(() {
      initialSavings = value;
    });
  }

  @override
  void initState() {
    super.initState();
    loadCategories();
    loadInitialSavings();
  }

  // 表示中の年月
  DateTime selectedMonth = DateTime.now();

  GraphMode graphMode = GraphMode.expense;

  bool get showIncome => graphMode == GraphMode.income;

  bool get isSavingsMode => graphMode == GraphMode.savings;

  List<int> _buildAvailableYears() {
    final years = widget.expenses
        .map((expense) {
          return expense.date.year;
        })
        .toSet()
        .toList();

    final currentYear = DateTime.now().year;

    if (!years.contains(currentYear)) {
      years.add(currentYear);
    }

    if (!years.contains(selectedMonth.year)) {
      years.add(selectedMonth.year);
    }

    years.sort();

    return years;
  }

  // ========================================
  // 画面描画
  // ・選択月のデータをカテゴリ別に集計
  // ・集計結果をグラフと一覧で表示
  // ========================================
  @override
  Widget build(BuildContext context) {
    final availableYears = _buildAvailableYears();

    // カテゴリごとの支出合計
    final parentCategories = categories
        .where((category) => !CategoryHelper.isChildCategory(category))
        .toList();

    Map<String, int> categoryTotals = {
      for (var category in parentCategories) category: 0,
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
      final parentCategory = CategoryHelper.parentOf(expense.category);

      categoryTotals[parentCategory] =
          (categoryTotals[parentCategory] ?? 0) + expense.amount;
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
    final sortedCategoryList =
        categoryTotals.entries.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final double total = sortedCategoryList.fold<double>(
      0,
      (sum, entry) => sum + entry.value,
    );

    final rankingList = sortedCategoryList;

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
    List<PieChartSectionData> sections = sortedCategoryList.asMap().entries.map(
      (entry) {
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
      },
    ).toList(); // Listに変換

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
          SegmentedButton<GraphMode>(
            segments: const [
              ButtonSegment(value: GraphMode.expense, label: Text("支出")),
              ButtonSegment(value: GraphMode.income, label: Text("収入")),
              ButtonSegment(value: GraphMode.savings, label: Text("貯金額")),
            ],

            selected: {graphMode},

            onSelectionChanged: (value) {
              setState(() {
                graphMode = value.first;
              });
            },
          ),

          // 月切替のUI
          if (!isSavingsMode)
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

          if (isSavingsMode) ...[
            const SizedBox(height: 8),
            Text(
              "${selectedMonth.year}年の貯金額",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "今日時点までの累計貯金額を表示しています。未来月は含めません。",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("表示年：", style: TextStyle(fontWeight: FontWeight.bold)),

              DropdownButton<int>(
                value: selectedMonth.year,
                items: availableYears.map((year) {
                  return DropdownMenuItem<int>(
                    value: year,
                    child: Text("$year年"),
                  );
                }).toList(),
                onChanged: (year) {
                  if (year == null) {
                    return;
                  }

                  setState(() {
                    selectedMonth = DateTime(year, selectedMonth.month);
                  });
                },
              ),
            ],
          ),

          // 月切替とグラフの間の余白
          const SizedBox(height: 20),

          if (!isSavingsMode)
            SummaryCard(income: income, expense: expense, balance: balance),

          if (isSavingsMode) ...[
            const SizedBox(height: 16),

            Text(
              "${selectedMonth.year}年 貯金額推移",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            SavingsBalanceChart(
              expenses: widget.expenses,
              year: selectedMonth.year,
              initialSavings: initialSavings,
            ),
          ] else ...[
            const SizedBox(height: 5),

            Text(
              showIncome ? "カテゴリ別収入" : "カテゴリ別支出",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            SizedBox(
              height: 260,
              child: total == 0
                  ? const Center(child: Text("この月のデータはありません"))
                  : PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sections: sections,
                        centerSpaceRadius: 50,

                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (response == null ||
                                response.touchedSection == null) {
                              return;
                            }

                            final touchedIndex =
                                response.touchedSection!.touchedSectionIndex;

                            if (touchedIndex < 0 ||
                                touchedIndex >= sortedCategoryList.length) {
                              return;
                            }

                            if (event is! FlTapUpEvent) {
                              return;
                            }

                            final category =
                                sortedCategoryList[touchedIndex].key;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CategoryDetailPage(
                                  category: category,
                                  isIncomeFilter: showIncome,
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

            Text(
              showIncome
                  ? "${selectedMonth.year}年 月別収入推移"
                  : "${selectedMonth.year}年 月別支出推移",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            MonthlyBalanceChart(
              expenses: widget.expenses,
              year: selectedMonth.year,
              showIncome: showIncome,
            ),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                showIncome ? "カテゴリ収入ランキング" : "カテゴリ支出ランキング",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),

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

                          title: Text(CategoryHelper.displayName(data.key)),

                          subtitle: Text("${percent.toStringAsFixed(1)}%"),

                          trailing: Text(
                            FormatHelper.yen(data.value),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),

                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CategoryDetailPage(
                                  category: data.key,
                                  isIncomeFilter: showIncome,
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
        ],
      ),
    );
  }
}

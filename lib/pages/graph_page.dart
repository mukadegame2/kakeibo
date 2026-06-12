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
  // 表示中の年月
  DateTime selectedMonth = DateTime.now();

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
      if (expense.isIncome) {
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

          // カテゴリ別集計の一覧表示
          Expanded(
            // カテゴリ別集計の一覧表示
            child: ListView(
              children: categoryTotals.entries.toList().asMap().entries.map((
                // インデックスとデータのペアに変換
                entry, // インデックスとデータを取得
              ) {
                int index = entry.key; // インデックスを取得
                var data = entry.value; // データを取得

                // 一覧のアイテムを作成
                return ListTile(
                  // アイコンを設定（色はグラフと同じ）
                  leading: CircleAvatar(
                    radius: 8, // アイコンの半径
                    backgroundColor:
                        colors[index % colors.length], // 色を設定（色の数が足りない場合はループ）
                  ),

                  // カテゴリ名をタイトルに表示
                  title: Text(data.key),

                  // 金額を右側に表示
                  trailing: Text("¥${data.value}"),
                );
              }).toList(), // Listに変換
            ),
          ),

          // グラフ描画
          Expanded(child: PieChart(PieChartData(sections: sections))),
        ],
      ),
    );
  }
}

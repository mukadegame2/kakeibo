import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/expense.dart';

// ========================================
// カレンダー画面
// 日付ごとの収支確認を行う画面
// ========================================
class CalendarPage extends StatefulWidget {
  // 家計簿データのリスト
  final List<Expense> expenses;

  // コンストラクタ
  const CalendarPage({super.key, required this.expenses});

  // 状態管理クラスの生成
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

// ========================================
// カレンダー画面の状態管理クラス
// ・月切替
// ・日付ごとのデータ集計
// ・データ表示
// を担当する
// ========================================
class _CalendarPageState extends State<CalendarPage> {
  // 表示中の年月
  DateTime selectedMonth = DateTime.now();

  // ========================================
  // 画面描画
  // ・選択月のデータを日付ごとに集計
  // ・集計結果を日付順に表示
  // ========================================
  @override
  Widget build(BuildContext context) {
    // 日付ごとにデータをまとめる
    Map<String, List<Expense>> groupedExpenses = {};

    // ========================================
    // 支出データを日付ごとに集計
    // 収入も集計対象とする
    // ========================================
    for (var expense in widget.expenses) {
      // 選択月以外は除外
      if (expense.date.year != selectedMonth.year ||
          expense.date.month != selectedMonth.month) {
        continue;
      }

      // 日付キーを作成（例: "2024/6/15"）
      final dateKey =
          "${expense.date.year}/${expense.date.month}/${expense.date.day}";

      // 日付キーが存在しない場合は空のリストを作成
      groupedExpenses.putIfAbsent(dateKey, () => []);

      // データを日付キーに追加
      groupedExpenses[dateKey]!.add(expense);
    }

    // 日付順ソート
    final entries = groupedExpenses.entries.toList();

    // 日付を降順にソート（新しい日付が上に来るように）
    entries.sort((a, b) => b.key.compareTo(a.key));

    // データがない場合はメッセージ表示
    if (entries.isEmpty) {
      return const Center(child: Text("この月のデータはありません"));
    }

    // 画面描画
    return Column(
      // 全体の余白
      mainAxisAlignment: MainAxisAlignment.start,

      // 子ウィジェットの配置
      children: [
        // 月切替
        Row(
          mainAxisAlignment: MainAxisAlignment.center, // 水平方向の中央揃え
          children: [
            // 前月ボタン、年月表示、次月ボタンを横並びで配置
            IconButton(
              icon: const Icon(Icons.arrow_back), // 前月アイコン
              onPressed: () {
                // 前月に切り替える処理
                setState(() {
                  // 状態更新のためsetStateで囲む
                  selectedMonth = DateTime(
                    // 年はそのまま、月を1減らす
                    selectedMonth.year, // 年はそのまま
                    selectedMonth.month - 1, // 月を1減らす
                  );
                });
              },
            ),

            // 現在の年月表示
            Text(
              "${selectedMonth.year}年${selectedMonth.month}月",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            // 次月ボタン
            IconButton(
              icon: const Icon(Icons.arrow_forward), // 次月アイコン
              onPressed: () {
                // 次月に切り替える処理
                setState(() {
                  // 状態更新のためsetStateで囲む
                  selectedMonth = DateTime(
                    // 年はそのまま、月を1増やす
                    selectedMonth.year, // 年はそのまま
                    selectedMonth.month + 1, // 月を1増やす
                  );
                });
              },
            ),
          ],
        ),

        // 月切替とグラフの間の余白
        const SizedBox(height: 10),

        // 月内データ一覧
        Expanded(
          // データがない場合はメッセージ表示
          child: groupedExpenses.isEmpty
              ? const Center(child: Text("この月のデータはありません"))
              // データがある場合は日付ごとにカード表示
              : ListView(
                  children: entries.map((entry) {
                    // 日付とその日のデータを取得
                    final date = entry.key; // 日付（例: "2024/6/15"）
                    final dailyExpenses = entry.value; // その日の支出データのリスト

                    // その日の収支合計を計算（収入はプラス、支出はマイナス）
                    int dailyTotal = dailyExpenses.fold(
                      0,
                      (sum, expense) =>
                          sum +
                          (expense.isIncome ? expense.amount : -expense.amount),
                    );

                    // 日付ごとにカード表示
                    return Card(
                      // カード全体の余白
                      margin: const EdgeInsets.all(8),
                      // カードの内容を左揃えにする
                      child: Padding(
                        // カード内の余白
                        padding: const EdgeInsets.all(8),
                        // カード内の内容を縦に並べる
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, // 左揃え
                          children: [
                            // 日付、収支合計、その日の支出データを表示
                            Text(
                              date, // 日付を表示
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const Divider(),

                            Text(
                              dailyTotal >= 0
                                  ? "収支合計: +¥$dailyTotal"
                                  : "収支合計: -¥${dailyTotal.abs()}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 8),

                            ...dailyExpenses.map(
                              (expense) => ListTile(
                                title: Text(expense.category),
                                subtitle: Text(expense.memo),
                                trailing: Text(
                                  expense.isIncome
                                      ? "+¥${expense.amount}"
                                      : "-¥${expense.amount}",
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

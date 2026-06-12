import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../widgets/expense_card.dart';
import '../widgets/month_selector.dart';

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

  Map<String, List<Expense>> _groupExpensesByDate() {
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

    return groupedExpenses;
  }

  // ========================================
  // 画面描画
  // ・選択月のデータを日付ごとに集計
  // ・集計結果を日付順に表示
  // ========================================
  @override
  Widget build(BuildContext context) {
    final groupedExpenses = _groupExpensesByDate();

    final entries = groupedExpenses.entries.toList();

    entries.sort((a, b) => b.key.compareTo(a.key));

    if (entries.isEmpty) {
      return const Center(child: Text("この月のデータはありません"));
    }

    return Column(
      children: [
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

        Expanded(
          child: ListView(
            children: entries
                .map(
                  (entry) =>
                      ExpenseCard(date: entry.key, dailyExpenses: entry.value),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

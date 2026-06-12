import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/expense.dart';
import '../widgets/summary_card.dart';
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

  // 選択日の保持
  DateTime? selectedDay;

  int _getDailyTotal(DateTime day) {
    int total = 0;

    for (var expense in _getExpensesForDay(day)) {
      total += expense.isIncome ? expense.amount : -expense.amount;
    }

    return total;
  }

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

  List<Expense> _getExpensesForDay(DateTime day) {
    return widget.expenses.where((expense) {
      return expense.date.year == day.year &&
          expense.date.month == day.month &&
          expense.date.day == day.day;
    }).toList();
  }

  // ========================================
  // 画面描画
  // ・選択月のデータを日付ごとに集計
  // ・集計結果を日付順に表示
  // ========================================
  @override
  Widget build(BuildContext context) {
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

    final groupedExpenses = _groupExpensesByDate();

    final entries = groupedExpenses.entries.toList();
    entries.sort((a, b) => b.key.compareTo(a.key));
    if (entries.isEmpty) {
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

          SummaryCard(income: income, expense: expense),

          Expanded(
            flex: 2,
            child: TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2100),
              focusedDay: selectedMonth,

              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final total = _getDailyTotal(day);

                  return Container(
                    margin: const EdgeInsets.all(2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${day.day}",
                          style: const TextStyle(fontSize: 14),
                        ),

                        if (_getExpensesForDay(day).isNotEmpty)
                          Text(
                            total >= 0 ? "+¥$total" : "-¥${total.abs()}",
                            style: TextStyle(
                              fontSize: 10,
                              color: total >= 0 ? Colors.blue : Colors.red,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

              eventLoader: (day) {
                return _getExpensesForDay(day);
              },

              selectedDayPredicate: (day) {
                return isSameDay(selectedDay, day);
              },

              onDaySelected: (selected, focused) {
                setState(() {
                  selectedDay = selected;
                  selectedMonth = focused;
                });
              },
            ),
          ),

          Expanded(
            flex: 1,
            child: entries.isEmpty
                ? const Center(child: Text("この月のデータはありません"))
                : ListView(
                    children: _getExpensesForDay(selectedDay!)
                        .map(
                          (expense) => ListTile(
                            title: Text(expense.category),
                            subtitle: Text(expense.memo),
                            trailing: Text(
                              expense.isIncome
                                  ? "+¥${expense.amount}"
                                  : "-¥${expense.amount}",
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      );
    }

    return Column(
      children: [
        

        SummaryCard(income: income, expense: expense),

        Expanded(
          flex: 2,
          child: TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2100),
            focusedDay: selectedMonth,

            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final total = _getDailyTotal(day);

                return Container(
                  margin: const EdgeInsets.all(2),

                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Text("${day.day}", style: const TextStyle(fontSize: 14)),

                      if (_getExpensesForDay(day).isNotEmpty)
                        Text(
                          total >= 0 ? "+¥$total" : "-¥${total.abs()}",
                          style: TextStyle(
                            fontSize: 10,
                            color: total >= 0 ? Colors.blue : Colors.red,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            eventLoader: (day) {
              return _getExpensesForDay(day);
            },

            selectedDayPredicate: (day) {
              return isSameDay(selectedDay, day);
            },

            onDaySelected: (selected, focused) {
              setState(() {
                selectedDay = selected;
                selectedMonth = focused;
              });
            },
          ),
        ),

        if (selectedDay != null)
          Expanded(
            flex: 1,
            child: ListView(
              children: _getExpensesForDay(selectedDay!)
                  .map(
                    (expense) => ListTile(
                      title: Text(expense.category),
                      subtitle: Text(expense.memo),
                      trailing: Text(
                        expense.isIncome
                            ? "+¥${expense.amount}"
                            : "-¥${expense.amount}",
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

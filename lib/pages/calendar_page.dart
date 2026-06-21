import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/expense.dart';
import '../widgets/summary_card.dart';
import '../widgets/month_selector.dart';
import '../services/category_helper.dart';
import '../services/category_service.dart';
import '../widgets/expense_edit_dialog.dart';
import '../utils/format_helper.dart';

// ========================================
// カレンダー画面
// 日付ごとの収支確認を行う画面
// ========================================
class CalendarPage extends StatefulWidget {
  final List<Expense> expenses;
  final Future<void> Function() onSave;

  // コンストラクタ
  const CalendarPage({super.key, required this.expenses, required this.onSave});

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

  String searchText = "";

  // 選択日の保持
  DateTime? selectedDay;

  List<String> _expenseCategories = [];
  List<String> _incomeCategories = [];

  Future<void> _loadCategories() async {
    final expenseCategories = await CategoryService.loadExpenseCategories();
    final incomeCategories = await CategoryService.loadIncomeCategories();

    if (!mounted) return;

    setState(() {
      _expenseCategories = expenseCategories;
      _incomeCategories = incomeCategories;
    });
  }

  int _getDailyTotal(DateTime day) {
    int total = 0;

    for (var expense in _getExpensesForDay(day)) {
      total += expense.isIncome ? expense.amount : -expense.amount;
    }

    return total;
  }

  List<Expense> _getExpensesForMonth() {
    return widget.expenses.where((expense) {
      return expense.date.year == selectedMonth.year &&
          expense.date.month == selectedMonth.month;
    }).toList();
  }

  Future<void> _showEditDialog(Expense expense) async {
    final updatedExpense = await showExpenseEditDialog(
      context: context,
      expense: expense,
      categories: expense.isIncome ? _incomeCategories : _expenseCategories,
      expenseCategories: _expenseCategories,
      incomeCategories: _incomeCategories,
      canEditDate: true,
      canEditCategory: true,
    );

    if (updatedExpense == null) {
      return;
    }

    final index = widget.expenses.indexOf(expense);

    if (index == -1) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("編集対象のデータが見つかりませんでした")));
      return;
    }

    widget.expenses[index] = updatedExpense;

    widget.expenses.sort((a, b) => b.date.compareTo(a.date));

    await widget.onSave();

    if (!mounted) return;

    setState(() {});
  }

  List<Expense> _getExpensesForDay(DateTime day) {
    return widget.expenses.where((expense) {
      return expense.date.year == day.year &&
          expense.date.month == day.month &&
          expense.date.day == day.day;
    }).toList();
  }

  Widget _buildDayCell(
    DateTime day, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    final total = _getDailyTotal(day);
    final hasExpenses = _getExpensesForDay(day).isNotEmpty;

    final isOutsideMonth = isOutside || day.month != selectedMonth.month;

    Color backgroundColor = Colors.transparent;
    Color dayTextColor = isOutsideMonth ? Colors.grey.shade300 : Colors.black;
    Color amountTextColor;

    if (isOutsideMonth) {
      amountTextColor = total >= 0 ? Colors.blue.shade300 : Colors.red.shade300;
    } else {
      amountTextColor = total >= 0 ? Colors.blue : Colors.red;
    }

    if (isToday) {
      backgroundColor = Colors.indigo.shade50;
    }

    if (isSelected) {
      backgroundColor = Colors.indigo;
      dayTextColor = Colors.white;
      amountTextColor = Colors.white;
    }

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${day.day}",
              style: TextStyle(
                fontSize: 14,
                color: dayTextColor,
                fontWeight: isToday || isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),

            if (hasExpenses)
              Text(
                FormatHelper.signedYen(total),
                style: TextStyle(
                  fontSize: 10,
                  color: amountTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar({required int flex}) {
    return Expanded(
      flex: flex,
      child: TableCalendar(
        locale: 'ja_JP',

        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: '月'},
        firstDay: DateTime(2020),
        lastDay: DateTime(2100),
        focusedDay: selectedMonth,

        headerVisible: false,
        daysOfWeekHeight: 28,
        rowHeight: 38,

        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            return _buildDayCell(day);
          },

          todayBuilder: (context, day, focusedDay) {
            return _buildDayCell(day, isToday: true);
          },

          selectedBuilder: (context, day, focusedDay) {
            return _buildDayCell(day, isSelected: true);
          },

          outsideBuilder: (context, day, focusedDay) {
            return _buildDayCell(day, isOutside: true);
          },
        ),

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
    );
  }

  Widget _buildExpenseList(List<Expense> displayExpenses) {
    return SizedBox(
      height: 200,
      child: displayExpenses.isEmpty
          ? const Center(child: Text("表示するデータがありません"))
          : ListView(
              children: displayExpenses
                  .map(
                    (expense) => ListTile(
                      title: Text(CategoryHelper.displayName(expense.category)),
                      subtitle: Text(
                        "${expense.date.month}/${expense.date.day}  ${expense.memo}",
                      ),
                      trailing: Text(
                        expense.isIncome
                            ? FormatHelper.signedYen(expense.amount)
                            : FormatHelper.signedYen(-expense.amount),
                      ),
                      onTap: () {
                        _showEditDialog(expense);
                      },
                    ),
                  )
                  .toList(),
            ),
    );
  }

  @override
  void initState() {
    super.initState();

    selectedDay = DateTime.now();
    _loadCategories();
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

    final displayExpenses = searchText.isEmpty
        ? (selectedDay == null ? <Expense>[] : _getExpensesForDay(selectedDay!))
        : _getExpensesForMonth().where((expense) {
            return expense.memo.contains(searchText) ||
                expense.category.contains(searchText) ||
                expense.amount.toString().contains(searchText);
          }).toList();

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

              selectedDay = DateTime(
                selectedMonth.year,
                selectedMonth.month,
                1,
              );
            });
          },
          onNext: () {
            setState(() {
              selectedMonth = DateTime(
                selectedMonth.year,
                selectedMonth.month + 1,
              );

              selectedDay = DateTime(
                selectedMonth.year,
                selectedMonth.month,
                1,
              );
            });
          },
        ),

        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: const InputDecoration(
              labelText: "検索",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                searchText = value;
              });
            },
          ),
        ),

        SummaryCard(
          income: income,
          expense: expense,
          balance: income - expense,
        ),

        _buildCalendar(flex: 2),

        _buildExpenseList(displayExpenses),
      ],
    );
  }
}

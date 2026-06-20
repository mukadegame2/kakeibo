import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/expense.dart';
import '../widgets/summary_card.dart';
import '../widgets/month_selector.dart';
import '../services/category_helper.dart';

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
    DateTime editDate = expense.date;

    final amountController = TextEditingController(
      text: expense.amount.toString(),
    );

    final memoController = TextEditingController(text: expense.memo);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("編集"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "金額"),
              ),

              const SizedBox(height: 16),

              StatefulBuilder(
                builder: (context, setDialogState) {
                  return ListTile(
                    leading: const Icon(Icons.calendar_month),
                    title: Text(
                      "${editDate.year}/${editDate.month}/${editDate.day}",
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: dialogContext,
                        initialDate: editDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );

                      if (pickedDate != null) {
                        setDialogState(() {
                          editDate = pickedDate;
                        });
                      }
                    },
                  );
                },
              ),

              TextField(
                controller: memoController,
                decoration: const InputDecoration(labelText: "メモ"),
              ),
            ],
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
                final amount = int.tryParse(amountController.text.trim());

                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("金額は1以上の数字で入力してください")),
                  );
                  return;
                }

                final index = widget.expenses.indexOf(expense);

                if (index == -1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("編集対象のデータが見つかりませんでした")),
                  );
                  return;
                }

                widget.expenses[index] = expense.copyWith(
                  amount: amount,
                  memo: memoController.text,
                  date: editDate,
                );

                widget.expenses.sort((a, b) => b.date.compareTo(a.date));

                await widget.onSave();

                if (!mounted) return;

                setState(() {});

                Navigator.pop(dialogContext);
              },
              child: const Text("更新"),
            ),
          ],
        );
      },
    );

    amountController.dispose();
    memoController.dispose();
  }

  List<Expense> _getExpensesForDay(DateTime day) {
    return widget.expenses.where((expense) {
      return expense.date.year == day.year &&
          expense.date.month == day.month &&
          expense.date.day == day.day;
    }).toList();
  }

  Widget _buildCalendar({required int flex}) {
    return Expanded(
      flex: flex,
      child: TableCalendar(
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: '月'},
        firstDay: DateTime(2020),
        lastDay: DateTime(2100),
        focusedDay: selectedMonth,

        headerVisible: false,

        rowHeight: 38,

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
                            ? "+¥${expense.amount}"
                            : "-¥${expense.amount}",
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

        SummaryCard(income: income, expense: expense),

        _buildCalendar(flex: 2),

        _buildExpenseList(displayExpenses),
      ],
    );
  }
}

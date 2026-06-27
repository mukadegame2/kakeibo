import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../services/category_helper.dart';
import '../utils/amount_parser.dart';

Future<Expense?> showExpenseEditDialog({
  required BuildContext context,
  required Expense expense,
  required List<String> categories,
  List<String>? expenseCategories,
  List<String>? incomeCategories,
  bool canEditDate = true,
  bool canEditCategory = true,
}) {
  return showDialog<Expense>(
    context: context,
    builder: (context) {
      return _ExpenseEditDialog(
        expense: expense,
        categories: categories,
        expenseCategories: expenseCategories ?? categories,
        incomeCategories: incomeCategories ?? categories,
        canEditDate: canEditDate,
        canEditCategory: canEditCategory,
      );
    },
  );
}

class _ExpenseEditDialog extends StatefulWidget {
  final Expense expense;
  final List<String> categories;
  final List<String> expenseCategories;
  final List<String> incomeCategories;
  final bool canEditDate;
  final bool canEditCategory;

  const _ExpenseEditDialog({
    required this.expense,
    required this.categories,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.canEditDate,
    required this.canEditCategory,
  });

  @override
  State<_ExpenseEditDialog> createState() => _ExpenseEditDialogState();
}

class _ExpenseEditDialogState extends State<_ExpenseEditDialog> {
  late final TextEditingController amountController;
  late final TextEditingController memoController;

  late DateTime editDate;
  late String selectedCategory;
  late bool editIsIncome;

  List<String> get _currentCategories {
    return editIsIncome ? widget.incomeCategories : widget.expenseCategories;
  }

  void _syncSelectedCategoryWithType() {
    final currentCategories = _currentCategories;

    if (currentCategories.isEmpty) {
      return;
    }

    if (!currentCategories.contains(selectedCategory)) {
      selectedCategory = currentCategories.first;
    }
  }

  @override
  void initState() {
    super.initState();

    amountController = TextEditingController(
      text: widget.expense.amount.toString(),
    );

    memoController = TextEditingController(text: widget.expense.memo);

    editDate = widget.expense.date;
    selectedCategory = widget.expense.category;
    editIsIncome = widget.expense.isIncome;

    _syncSelectedCategoryWithType();
  }

  @override
  void dispose() {
    amountController.dispose();
    memoController.dispose();

    super.dispose();
  }

  List<String> _buildCategoryDisplayList() {
    final sourceCategories = [...widget.categories];

    if (!sourceCategories.contains(selectedCategory)) {
      sourceCategories.add(selectedCategory);
    }

    final parentCategories = sourceCategories
        .where((category) => !CategoryHelper.isChildCategory(category))
        .toList();

    final displayList = <String>[];

    for (final parent in parentCategories) {
      displayList.add(parent);

      final children = sourceCategories.where((category) {
        return CategoryHelper.isChildCategory(category) &&
            CategoryHelper.parentOf(category) == parent;
      }).toList();

      displayList.addAll(children);
    }

    final orphanChildren = sourceCategories.where((category) {
      return CategoryHelper.isChildCategory(category) &&
          !parentCategories.contains(CategoryHelper.parentOf(category));
    }).toList();

    displayList.addAll(orphanChildren);

    return displayList;
  }

  @override
  Widget build(BuildContext context) {
    final displayCategories = _buildCategoryDisplayList();
    final currentCategories = _currentCategories;

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

          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text("支出")),
              ButtonSegment(value: true, label: Text("収入")),
            ],
            selected: {editIsIncome},
            onSelectionChanged: (Set<bool> newSelection) {
              setState(() {
                editIsIncome = newSelection.first;
                _syncSelectedCategoryWithType();
              });
            },
          ),

          if (widget.canEditCategory && displayCategories.isNotEmpty) ...[
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              key: ValueKey(editIsIncome),
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'カテゴリ',
                border: OutlineInputBorder(),
              ),
              items: currentCategories.map((category) {
                final isChild = CategoryHelper.isChildCategory(category);

                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(
                    isChild
                        ? "   ↳ ${CategoryHelper.childOf(category)}"
                        : "📁 $category",
                  ),
                );
              }).toList(),
              onChanged: widget.canEditCategory
                  ? (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        selectedCategory = value;
                      });
                    }
                  : null,
            ),
          ],

          if (widget.canEditDate) ...[
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text("${editDate.year}/${editDate.month}/${editDate.day}"),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  locale: const Locale('ja', 'JP'),
                  initialDate: editDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );

                if (pickedDate == null) {
                  return;
                }

                if (!mounted) {
                  return;
                }

                setState(() {
                  editDate = pickedDate;
                });
              },
            ),
          ],

          TextField(
            controller: memoController,
            decoration: const InputDecoration(labelText: "メモ"),
          ),
        ],
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("キャンセル"),
        ),

        ElevatedButton(
          onPressed: () {
            final amount = AmountParser.parsePositiveInt(amountController.text);

            if (amount == null || amount <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("金額は1以上の数字で入力してください")),
              );
              return;
            }

            final updatedExpense = widget.expense.copyWith(
              amount: amount,
              category: selectedCategory,
              memo: memoController.text,
              date: editDate,
              isIncome: editIsIncome,
            );

            Navigator.pop(context, updatedExpense);
          },
          child: const Text("保存"),
        ),
      ],
    );
  }
}

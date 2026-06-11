import 'package:fl_chart/fl_chart.dart';    // グラフ描画用ライブラリ
import 'dart:convert';                    // JSON変換用
import 'package:flutter/material.dart';     // Flutter UIライブラリ
import 'package:shared_preferences/shared_preferences.dart';  // データ保存用ライブラリ

// ========================================
// 家計簿データクラス
// ========================================
class Expense {
  final int amount;
  final String category;
  final String memo;
  final DateTime date;
  final bool isIncome;

  Expense({
    required this.amount,
    required this.category,
    required this.memo,
    required this.date,
    required this.isIncome,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category,
      'memo': memo,
      'date': date.toIso8601String(),
      'isIncome': isIncome,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      amount: json['amount'],
      category: json['category'],
      memo: json['memo'],
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      isIncome: json['isIncome'] ?? false,
    );
  }
}
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/meal_analysis.dart';

class HistoryService {
  static const String _key = 'meal_history_v1';

  Future<void> save(MealAnalysis analysis) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> rows = prefs.getStringList(_key) ?? <String>[];
    final Map<String, dynamic> row = <String, dynamic>{
      'createdAt': analysis.createdAt.toIso8601String(),
      'calories': analysis.calories,
      'protein': analysis.protein,
      'carbs': analysis.carbs,
      'fat': analysis.fat,
      'fiber': analysis.fiber,
      'sugar': analysis.sugar,
      'sodiumMg': analysis.sodiumMg,
      'unmatchedFoods': analysis.unmatchedFoods,
      'foods': analysis.items.map((item) => item.food.name).toList(),
    };
    rows.insert(0, jsonEncode(row));
    if (rows.length > 30) rows.removeRange(30, rows.length);
    await prefs.setStringList(_key, rows);
  }

  Future<List<Map<String, dynamic>>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> rows = prefs.getStringList(_key) ?? <String>[];
    return rows
        .map((String row) => jsonDecode(row) as Map<String, dynamic>)
        .toList();
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

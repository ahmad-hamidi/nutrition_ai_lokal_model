import 'dart:convert';

import '../data/food_database.dart';
import 'food.dart';
import 'meal_analysis.dart';

class FoodVisionResult {
  const FoodVisionResult({
    required this.items,
    required this.rawResponse,
    this.unmatchedFoods = const <String>[],
    this.mealName,
    this.recipe,
  });

  final List<DetectedFood> items;
  final String rawResponse;
  final List<String> unmatchedFoods;
  final String? mealName;
  final RecipeSuggestion? recipe;
}

class FoodVisionResultParser {
  const FoodVisionResultParser._();

  static FoodVisionResult parse(String raw) {
    final String jsonText = _extractJson(raw);
    final dynamic decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Respons model bukan JSON object.');
    }

    final List<DetectedFood> items = <DetectedFood>[];
    final Set<String> unmatchedFoods = <String>{};
    final Set<String> usedIds = <String>{};
    final dynamic foodsValue = decoded['foods'];
    if (foodsValue is List<dynamic>) {
      for (final dynamic row in foodsValue.take(4)) {
        if (row is! Map<String, dynamic>) continue;
        final String observedName = (row['observed_name'] ?? '').toString().trim();
        if (observedName.isEmpty) continue;
        // Never trust a generated food_id over what the model says it observed.
        final FoodItem? food = FoodDatabase.matchLabel(observedName);
        if (food == null) {
          unmatchedFoods.add(observedName);
          continue;
        }
        if (usedIds.contains(food.id)) continue;

        final num? gramValue = _finiteNumber(row['estimated_grams']);
        final double grams = (gramValue?.toDouble() ?? food.defaultGrams)
            .clamp(10.0, 1000.0)
            .toDouble();
        final num? confidenceValue = _finiteNumber(row['confidence']);
        final double confidence = (confidenceValue?.toDouble() ?? 0.5)
            .clamp(0.0, 1.0)
            .toDouble();

        items.add(
          DetectedFood(
            food: food,
            grams: grams,
            confidence: confidence,
            sourceLabel: observedName.isEmpty ? food.name : observedName,
          ),
        );
        usedIds.add(food.id);
      }
    }

    RecipeSuggestion? recipe;
    final dynamic recipeValue = decoded['recipe'];
    if (recipeValue is Map<String, dynamic>) {
      final String title = (recipeValue['title'] ?? '').toString().trim();
      final List<String> ingredients = _stringList(recipeValue['ingredients']);
      final List<String> steps = _stringList(recipeValue['steps']);
      if (title.isNotEmpty || ingredients.isNotEmpty || steps.isNotEmpty) {
        recipe = RecipeSuggestion(
          title: title.isEmpty ? 'Resep perkiraan' : title,
          ingredients: ingredients,
          steps: steps,
        );
      }
    }

    final String mealName = (decoded['meal_name'] ?? '').toString().trim();
    return FoodVisionResult(
      items: items,
      unmatchedFoods: unmatchedFoods.toList(),
      rawResponse: raw,
      mealName: mealName.isEmpty ? null : mealName,
      recipe: recipe,
    );
  }

  static num? _finiteNumber(dynamic value) {
    final num? number = value is num ? value : num.tryParse('$value');
    return number != null && number.isFinite ? number : null;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List<dynamic>) return <String>[];
    return value
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .take(16)
        .toList();
  }

  static String _extractJson(String raw) {
    final int start = raw.indexOf('{');
    final int end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw FormatException('Model tidak mengembalikan JSON valid. Respons: $raw');
    }
    return raw.substring(start, end + 1);
  }
}

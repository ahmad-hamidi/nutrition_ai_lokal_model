import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens_offline/data/food_database.dart';
import 'package:nutrilens_offline/services/qwen_food_vision_service.dart';
import 'package:nutrilens_offline/widgets/unmatched_foods_card.dart';

void main() {
  final service = QwenFoodVisionService();

  test('unknown dish never inherits a generated but unrelated food ID', () {
    final result = service.parseResponse(jsonEncode({
      'meal_name': 'Dadar gulung',
      'foods': [
        {'food_id': 'tempe_fried', 'observed_name': 'Dadar gulung',
          'estimated_grams': 120, 'confidence': 0.82},
      ],
    }));
    expect(result.items, isEmpty);
    expect(result.unmatchedFoods, ['Dadar gulung']);
    expect(result.mealName, 'Dadar gulung');
  });

  test('specific matching avoids substring, category and preparation mistakes', () {
    for (final name in ['fruit', 'fried food', 'tempe', 'ayam',
      'kue pandan', 'nasi kuning', 'tahu isi', 'vitamin', 'soy']) {
      expect(FoodDatabase.matchLabel(name), isNull, reason: name);
    }
    expect(FoodDatabase.matchLabel(' NASI GORENG ')?.id, 'fried_rice');
    expect(FoodDatabase.matchLabel('fried chicken')?.id, 'chicken_fried');
    expect(FoodDatabase.matchLabel('tempe goreng')?.id, 'tempe_fried');
    expect(FoodDatabase.matchLabel('gado gado')?.id, 'gado_gado');
  });

  test('mixed result preserves unknown foods without adding their nutrition', () {
    final result = service.parseResponse(jsonEncode({
      'foods': [
        {'observed_name': 'Nasi putih', 'estimated_grams': '100', 'confidence': '0.9'},
        {'observed_name': 'Kue hijau berisi kelapa', 'estimated_grams': 120},
      ],
    }));
    expect(result.items.single.food.id, 'rice_white');
    expect(result.items.single.calories, 130);
    expect(result.unmatchedFoods, ['Kue hijau berisi kelapa']);
  });

  test('empty recognition does not invent a fallback food', () {
    final result = service.parseResponse('{"foods": []}');
    expect(result.items, isEmpty);
    expect(result.unmatchedFoods, isEmpty);
  });

  testWidgets('unmatched dish is visible with nutrition unavailable', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: UnmatchedFoodsCard(names: ['Dadar gulung']),
    )));
    expect(find.text('• Dadar gulung'), findsOneWidget);
    expect(find.text('Belum ada kecocokan di database'), findsOneWidget);
    expect(find.textContaining('Nutrisi belum dihitung'), findsOneWidget);
    expect(find.textContaining('kcal'), findsNothing);
  });
}

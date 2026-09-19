import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens_offline/services/weekly_menu_prompt.dart';

void main() {
  test('valid day parses with clamped grams and known foods only', () {
    final result = parseDailyMenu(
      jsonEncode({
        'day': 'Hari 1',
        'meals': [
          {
            'name': 'Sarapan',
            'foods': [
              {'food_id': 'rice_white', 'estimated_grams': 220},
              {'food_id': 'mie_instan_xyz', 'estimated_grams': 100},
              {'food_id': 'egg_boiled', 'estimated_grams': '110'},
              {'food_id': 'banana', 'estimated_grams': 5000},
            ],
            'ingredients': ['Nasi 220 g'],
            'steps': ['Masak.'],
          },
        ],
      }),
      'Hari 1',
    );
    expect(result.day, 'Hari 1');
    expect(result.meals, hasLength(1));
    final ids = result.meals.single.foods.map((f) => f.foodId).toList();
    expect(ids, ['rice_white', 'egg_boiled', 'banana']);
    expect(result.meals.single.foods.last.grams, 600);
  });

  test('day without valid meals throws for static fallback', () {
    expect(() => parseDailyMenu('{"meals": []}', 'Hari 2'),
        throwsA(isA<FormatException>()));
    expect(() => parseDailyMenu('bukan json', 'Hari 2'),
        throwsA(isA<FormatException>()));
  });

  test('prompt constrains output to catalog ids', () {
    final prompt = buildDailyMenuPrompt(
      dayLabel: 'Hari 3',
      avoidIds: const {'rice_white'},
    );
    expect(prompt, contains('Hari 3'));
    expect(prompt, contains('rice_white'));
    expect(prompt, contains('HANYA JSON'));
  });
}

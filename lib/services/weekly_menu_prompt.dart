import 'dart:convert';

import '../data/food_database.dart';
import '../models/food.dart';
import '../models/weekly_plan.dart';

/// Prompt + parser bersama untuk generate menu harian oleh model lokal
/// (Qwen3-VL maupun Gemma 3n). Output dibatasi ke food_id katalog lokal
/// supaya semua angka nutrisi tetap bisa dihitung deterministik.
String buildDailyMenuPrompt({
  required String dayLabel,
  required Set<String> avoidIds,
}) {
  final String catalog = FoodDatabase.foods
      .map((FoodItem food) => '${food.id} = ${food.name}')
      .join('\n');
  final String avoid = avoidIds.isEmpty
      ? ''
      : '\nHindari food_id berikut yang sudah dipakai hari sebelumnya agar menunya bervariasi: ${avoidIds.join(', ')}.\n';

  return '''
Buatkan menu 1 hari ($dayLabel) makanan Indonesia sehari-hari: tepat 3 waktu makan
(sarapan, makan siang, makan malam). Setiap meal berisi 2-4 makanan dari katalog.
$avoid
Katalog food_id yang BOLEH dipakai (jangan mengarang id lain):
$catalog

Aturan:
- Setiap food: food_id dari katalog + estimated_grams (20-600).
- Ingredient dalam Bahasa Indonesia, ringkas beserta takaran (maks 8 per meal).
- Steps maksimal 5 langkah singkat per meal.
- Variasikan antar waktu makan; porsi wajar untuk 1 orang dewasa.

Balas HANYA JSON valid tanpa markdown dengan schema tepat ini:
{
  "day": "$dayLabel",
  "meals": [
    {
      "name": "Nasi ayam bakar & lalapan",
      "foods": [
        {"food_id": "rice_white", "estimated_grams": 220},
        {"food_id": "chicken_grilled", "estimated_grams": 150}
      ],
      "ingredients": ["Nasi matang 220 g", "Ayam 150 g"],
      "steps": ["Bumbui ayam lalu ungkep.", "Bakar sambil dioles kecap."]
    }
  ]
}
''';
}

/// Mengurai 1 hari menu dari output model. Melempar [FormatException] bila
/// tidak ada meal valid sehingga pemanggil bisa fallback ke menu statis.
DailyMealPlan parseDailyMenu(String raw, String dayLabel) {
  final int start = raw.indexOf('{');
  final int end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw FormatException('Model tidak mengembalikan JSON valid. Respons: $raw');
  }
  final dynamic decoded = jsonDecode(raw.substring(start, end + 1));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Respons menu bukan JSON object.');
  }

  final List<PlannedMeal> meals = <PlannedMeal>[];
  final dynamic mealsValue = decoded['meals'];
  if (mealsValue is List<dynamic>) {
    for (final dynamic row in mealsValue.take(3)) {
      if (row is! Map<String, dynamic>) continue;
      final String name = (row['name'] ?? '').toString().trim();

      final List<PlannedFood> foods = <PlannedFood>[];
      final Set<String> usedIds = <String>{};
      final dynamic foodsValue = row['foods'];
      if (foodsValue is List<dynamic>) {
        for (final dynamic item in foodsValue.take(4)) {
          if (item is! Map<String, dynamic>) continue;
          final String foodId = (item['food_id'] ?? '').toString().trim();
          final FoodItem? food = FoodDatabase.byId(foodId);
          if (food == null || usedIds.contains(food.id)) continue;
          final num? gramValue = item['estimated_grams'] is num
              ? item['estimated_grams'] as num?
              : num.tryParse('${item['estimated_grams']}');
          final double grams = (gramValue?.toDouble() ?? food.defaultGrams)
              .clamp(20.0, 600.0)
              .toDouble();
          foods.add(PlannedFood(foodId: food.id, grams: grams));
          usedIds.add(food.id);
        }
      }
      if (foods.isEmpty) continue;

      meals.add(
        PlannedMeal(
          name: name.isEmpty ? 'Menu $dayLabel' : name,
          foods: foods,
          ingredients: _stringList(row['ingredients'], 8),
          steps: _stringList(row['steps'], 5),
        ),
      );
    }
  }

  if (meals.isEmpty) {
    throw const FormatException('Model tidak menghasilkan meal yang valid.');
  }
  return DailyMealPlan(day: dayLabel, meals: meals);
}

List<String> _stringList(dynamic value, int limit) {
  if (value is! List<dynamic>) return <String>[];
  return value
      .map((dynamic item) => item.toString().trim())
      .where((String item) => item.isNotEmpty)
      .take(limit)
      .toList();
}

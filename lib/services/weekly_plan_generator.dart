import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/weekly_meal_plan.dart';
import '../models/weekly_plan.dart';
import 'gemma_food_vision_service.dart';
import 'local_model_manager.dart';
import 'qwen_food_vision_service.dart';
import 'weekly_menu_prompt.dart';

/// Hasil generate menu mingguan: 7 hari + info hari mana yang fallback
/// ke contoh statis (mis. 1 hari gagal dibuat model).
class WeeklyPlanResult {
  const WeeklyPlanResult({
    required this.days,
    required this.fallbackDayIndexes,
    required this.modelLabel,
  });

  final List<DailyMealPlan> days;
  final Set<int> fallbackDayIndexes;
  final String modelLabel;

  bool get fullyAi => fallbackDayIndexes.isEmpty;
}

/// Generate menu 7 hari memakai model AI lokal yang sedang aktif.
/// Berjalan per-hari agar output muat di konteks model kecil dan 1 hari
/// yang gagal tidak menggugurkan sisanya (fallback ke contoh statis).
class WeeklyPlanGenerator {
  WeeklyPlanGenerator({required this._qwen, required this._gemma});

  static const String _cacheDaysKey = 'ai_weekly_plan_days_v1';
  static const String _cacheModelKey = 'ai_weekly_plan_model_v1';

  final QwenFoodVisionService _qwen;
  final GemmaFoodVisionService _gemma;

  Future<WeeklyPlanResult> generate({
    required LocalModelStatus status,
    void Function(int done, int total)? onProgress,
  }) async {
    final bool useGemma = status.selectedModel == LocalAiModel.gemma3nE2b;
    if (useGemma && status.gemmaPath == null) {
      throw StateError('Impor model Gemma 3n E2B terlebih dahulu.');
    }
    if (!useGemma && !status.qwenReady) {
      throw StateError('Siapkan model Qwen Q4 + vision projector terlebih dahulu.');
    }

    final List<DailyMealPlan> days = <DailyMealPlan>[];
    final Set<int> fallback = <int>{};
    final Set<String> avoidIds = <String>{};
    for (int i = 0; i < 7; i++) {
      final String dayLabel = 'Hari ${i + 1}';
      try {
        final DailyMealPlan day = useGemma
            ? await _gemma.generateDailyMenu(
                modelPath: status.gemmaPath!,
                dayLabel: dayLabel,
                avoidIds: avoidIds,
              )
            : await _qwen.generateDailyMenu(
                modelPath: status.modelPath!,
                mmprojPath: status.mmprojPath!,
                dayLabel: dayLabel,
                avoidIds: avoidIds,
              );
        days.add(day);
        for (final PlannedMeal meal in day.meals) {
          for (final PlannedFood food in meal.foods) {
            avoidIds.add(food.foodId);
          }
        }
      } catch (_) {
        days.add(WeeklyMealPlanData.days[i]);
        fallback.add(i);
      }
      onProgress?.call(days.length, 7);
    }

    final WeeklyPlanResult result = WeeklyPlanResult(
      days: days,
      fallbackDayIndexes: fallback,
      modelLabel: status.selectedModel.label,
    );
    await saveCache(result);
    return result;
  }

  Future<void> saveCache(WeeklyPlanResult result) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _cacheDaysKey,
      result.days.map(_encodeDay).toList(),
    );
    await prefs.setString(_cacheModelKey, result.modelLabel);
  }

  /// Memuat hasil AI tersimpan. Mengembalikan null bila belum ada / rusak.
  Future<WeeklyPlanResult?> loadCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? raw = prefs.getStringList(_cacheDaysKey);
    if (raw == null || raw.length != 7) return null;
    try {
      final List<DailyMealPlan> days = <DailyMealPlan>[];
      for (int i = 0; i < 7; i++) {
        days.add(parseDailyMenu(raw[i], 'Hari ${i + 1}'));
      }
      return WeeklyPlanResult(
        days: days,
        fallbackDayIndexes: <int>{},
        modelLabel: prefs.getString(_cacheModelKey) ?? 'AI',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheDaysKey);
    await prefs.remove(_cacheModelKey);
  }

  static String _encodeDay(DailyMealPlan day) {
    return jsonEncode(<String, dynamic>{
      'day': day.day,
      'meals': day.meals
          .map((PlannedMeal meal) => <String, dynamic>{
                'name': meal.name,
                'foods': meal.foods
                    .map((PlannedFood food) => <String, dynamic>{
                          'food_id': food.foodId,
                          'estimated_grams': food.grams,
                        })
                    .toList(),
                'ingredients': meal.ingredients,
                'steps': meal.steps,
              })
          .toList(),
    });
  }
}

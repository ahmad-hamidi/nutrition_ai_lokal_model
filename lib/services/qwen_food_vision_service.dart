import 'dart:convert';

import 'package:lib_llama_cpp/lib_llama_cpp.dart';

import '../data/food_database.dart';
import '../models/food.dart';
import '../models/meal_analysis.dart';

class QwenVisionResult {
  const QwenVisionResult({
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

class QwenFoodVisionService {
  LlamaOpenAIClient? _client;
  String? _loadedSignature;

  Future<QwenVisionResult> analyze({
    required String imagePath,
    required String modelPath,
    required String mmprojPath,
  }) async {
    final String signature = '$modelPath::$mmprojPath';
    if (_client == null || _loadedSignature != signature) {
      _client = LlamaOpenAIClient(
        models: <String, LlamaModelConfig>{
          'qwen3-vl': LlamaModelConfig(
            modelPath: modelPath,
            mmprojPath: mmprojPath,
            // A null context becomes n_ctx=0 (the model's training context).
            // Bound the KV cache instead of allocating it for that full context.
            contextSize: 4096,
            imageMaxTokens: 1024,
          ),
        },
      );
      _loadedSignature = signature;
    }

    final LlamaResponseObject response = await _client!.responses.create(
      model: 'qwen3-vl',
      maxOutputTokens: 1024,
      temperature: 0.1,
      input: <LlamaResponseInputItem>[
        LlamaResponseInputItem(
          role: 'user',
          content: [
            LlamaTextPart(_buildPrompt()),
            LlamaImageFilePart(path: imagePath),
          ],
        ),
      ],
    );

    final String raw = response.outputText.trim();
    return parseResponse(raw);
  }

  String _buildPrompt() {
    return '''
Identify the food actually visible in this photo. Write food names in English.
Use a regional dish name only if you know it; never invent or translate a name
into an unrelated dish. A precise descriptive name is better than a wrong name.
Describe the visible evidence BEFORE deciding the dish name: color, shape,
texture, wrapper and visible filling. Distinguish soft rolled crepes and cakes
from dry baked cookies, and filled wrappers from solid fried protein. Do not invent ingredients
that are not visible. Identify the prepared dish, not separate ingredients inside it.
Do not classify by color alone. Ignore decorative leaves, plates and backgrounds.
If the exact dish is uncertain, use a short visual description as observed_name
and meal_name instead of guessing. The name must agree with the visual evidence.
Do not choose a substitute food. No nutrition values, recipes or food IDs.

Return ONLY valid JSON without markdown, with up to four distinct foods:
{
  "foods": [
    {
      "visual_evidence": "one sentence of visible features supporting this identification",
      "observed_name": "specific dish name or visual description",
      "estimated_grams": 120,
      "confidence": 0.5
    }
  ],
  "meal_name": "specific dish name or visual description"
}
Use your own estimates, not the example values. If there is no food, return foods: [].
''';
  }

  /// Resolves independently identified names against the local nutrition catalog.
  QwenVisionResult parseResponse(String raw) {
    final String jsonText = _extractJson(raw);
    final dynamic decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Respons Qwen bukan JSON object.');
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
    return QwenVisionResult(
      items: items,
      unmatchedFoods: unmatchedFoods.toList(),
      rawResponse: raw,
      mealName: mealName.isEmpty ? null : mealName,
      recipe: recipe,
    );
  }

  num? _finiteNumber(dynamic value) {
    final num? number = value is num ? value : num.tryParse('$value');
    return number != null && number.isFinite ? number : null;
  }

  List<String> _stringList(dynamic value) {
    if (value is! List<dynamic>) return <String>[];
    return value
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .take(12)
        .toList();
  }

  String _extractJson(String raw) {
    final int start = raw.indexOf('{');
    final int end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw FormatException('Qwen tidak mengembalikan JSON valid. Respons: $raw');
    }
    return raw.substring(start, end + 1);
  }
}

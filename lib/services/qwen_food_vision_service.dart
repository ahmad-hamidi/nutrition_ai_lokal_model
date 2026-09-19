import 'dart:convert';

import 'package:lib_llama_cpp/lib_llama_cpp.dart';

import '../data/food_database.dart';
import '../models/food.dart';
import '../models/meal_analysis.dart';

class QwenVisionResult {
  const QwenVisionResult({
    required this.items,
    required this.rawResponse,
    this.mealName,
    this.recipe,
  });

  final List<DetectedFood> items;
  final String rawResponse;
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
          ),
        },
      );
      _loadedSignature = signature;
    }

    final LlamaResponseObject response = await _client!.responses.create(
      model: 'qwen3-vl',
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
    return _parseResponse(raw);
  }

  String _buildPrompt() {
    final String catalog = FoodDatabase.foods
        .map((FoodItem food) => '${food.id} = ${food.name}')
        .join('\n');

    return '''
Anda adalah vision model lokal untuk aplikasi nutrisi Indonesia.
Analisis HANYA makanan/minuman yang benar-benar terlihat pada foto. Jangan mengarang objek yang tidak terlihat.

Pilih food_id PALING DEKAT dari katalog lokal berikut:
$catalog

Tugas:
1. Identifikasi maksimal 6 komponen makanan yang terlihat.
2. Estimasikan gram secara konservatif dari foto 2D. Jika tidak yakin, gunakan porsi umum dan turunkan confidence.
3. Buat nama hidangan singkat.
4. Buat resep PERKIRAAN singkat berdasarkan makanan yang terlihat. Jangan mengklaim resep pasti.

Balas HANYA JSON valid tanpa markdown dengan schema tepat ini:
{
  "meal_name": "string",
  "foods": [
    {
      "food_id": "id_dari_katalog",
      "observed_name": "nama yang terlihat",
      "estimated_grams": 120,
      "confidence": 0.82
    }
  ],
  "recipe": {
    "title": "string",
    "ingredients": ["string"],
    "steps": ["string"]
  }
}

Aturan confidence: 0.0 sampai 1.0. Jangan memberi nilai nutrisi; aplikasi menghitung nutrisi dari database lokal.
''';
  }

  QwenVisionResult _parseResponse(String raw) {
    final String jsonText = _extractJson(raw);
    final dynamic decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Respons Qwen bukan JSON object.');
    }

    final List<DetectedFood> items = <DetectedFood>[];
    final Set<String> usedIds = <String>{};
    final dynamic foodsValue = decoded['foods'];
    if (foodsValue is List<dynamic>) {
      for (final dynamic row in foodsValue.take(6)) {
        if (row is! Map<String, dynamic>) continue;
        final String foodId = (row['food_id'] ?? '').toString().trim();
        final String observedName = (row['observed_name'] ?? '').toString().trim();
        FoodItem? food = FoodDatabase.byId(foodId);
        food ??= FoodDatabase.matchLabel(observedName);
        if (food == null || usedIds.contains(food.id)) continue;

        final num? gramValue = row['estimated_grams'] as num?;
        final double grams = (gramValue?.toDouble() ?? food.defaultGrams)
            .clamp(10.0, 1000.0)
            .toDouble();
        final num? confidenceValue = row['confidence'] as num?;
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
      rawResponse: raw,
      mealName: mealName.isEmpty ? null : mealName,
      recipe: recipe,
    );
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

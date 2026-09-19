import 'package:lib_llama_cpp/lib_llama_cpp.dart';

import '../models/food_vision_result.dart';
import '../models/weekly_plan.dart';
import 'weekly_menu_prompt.dart';

class QwenFoodVisionService {
  LlamaOpenAIClient? _client;
  String? _loadedSignature;

  Future<FoodVisionResult> analyze({
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

  /// Membuat 1 hari menu (teks saja, tanpa foto) memakai runtime Qwen
  /// yang sudah dimuat. Temperature lebih tinggi agar menu bervariasi.
  Future<DailyMealPlan> generateDailyMenu({
    required String modelPath,
    required String mmprojPath,
    required String dayLabel,
    Set<String> avoidIds = const <String>{},
  }) async {
    final String signature = '$modelPath::$mmprojPath';
    if (_client == null || _loadedSignature != signature) {
      _client = LlamaOpenAIClient(
        models: <String, LlamaModelConfig>{
          'qwen3-vl': LlamaModelConfig(
            modelPath: modelPath,
            mmprojPath: mmprojPath,
            contextSize: 4096,
            imageMaxTokens: 1024,
          ),
        },
      );
      _loadedSignature = signature;
    }

    final LlamaResponseObject response = await _client!.responses.create(
      model: 'qwen3-vl',
      maxOutputTokens: 2048,
      temperature: 0.7,
      input: <LlamaResponseInputItem>[
        LlamaResponseInputItem(
          role: 'user',
          content: [
            LlamaTextPart(
              buildDailyMenuPrompt(dayLabel: dayLabel, avoidIds: avoidIds),
            ),
          ],
        ),
      ],
    );
    return parseDailyMenu(response.outputText.trim(), dayLabel);
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
  /// Shared with the Gemma 3n path via [FoodVisionResultParser].
  FoodVisionResult parseResponse(String raw) => FoodVisionResultParser.parse(raw);
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';

import '../data/food_database.dart';
import '../models/food.dart';
import '../models/food_vision_result.dart';

class GemmaFoodVisionService {
  dynamic _model;

  Future<FoodVisionResult> analyze({
    required String imagePath,
    required String modelPath,
  }) async {
    try {
      _model ??= await _loadModel(modelPath);
    } catch (error) {
      _model = null;
      throw StateError(_friendlyLoadError(error));
    }
    final Uint8List bytes = await File(imagePath).readAsBytes();
    final dynamic chat = await _model.createChat(
      maxOutputTokens: 320,
      systemInstruction:
          'Anda adalah vision model lokal untuk aplikasi nutrisi Indonesia. '
          'Jawab ringkas dan patuhi schema JSON yang diminta.',
    );

    await chat.addQueryChunk(
      Message.withImages(
        text: _buildPrompt(),
        imageBytes: <Uint8List>[bytes],
        isUser: true,
      ),
    );

    final StringBuffer buffer = StringBuffer();
    await for (final ModelResponse response in chat.generateChatResponseAsync()) {
      if (response is TextResponse) buffer.write(response.token);
    }

    try {
      await chat.session.close();
    } catch (_) {
      // Session cleanup is best-effort; keep model warm for the next photo.
    }

    return FoodVisionResultParser.parse(buffer.toString().trim());
  }

  Future<dynamic> _loadModel(String modelPath) async {
    // fromFile registers an external file; it does not copy model bytes.
    // Re-register after URI access has been restored for the current process.
    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.litertlm,
    ).fromFile(modelPath).install();
    try {
      return await FlutterGemma.getActiveModel(
        maxTokens: 1536,
        preferredBackend: PreferredBackend.gpu,
        preferredVisionBackend: PreferredBackend.gpu,
        supportImage: true,
        maxConcurrentSessions: 1,
      );
    } catch (_) {
      return FlutterGemma.getActiveModel(
        maxTokens: 1536,
        preferredBackend: PreferredBackend.cpu,
        preferredVisionBackend: PreferredBackend.cpu,
        supportImage: true,
        maxConcurrentSessions: 1,
      );
    }
  }

  /// Menerjemahkan error init backend LiteRT-LM menjadi pesan aksi.
  ///
  /// File `gemma-3n-E2B-it-int4.litertlm` mengemas vision encoder khusus GPU
  /// ("Vision backend constraint mismatch. Model requires one of [gpu]").
  /// Emulator tidak punya GPU delegate fisik sehingga semua backend gagal;
  /// di HP fisik dengan GPU (mis. Pixel 8+) model yang sama berjalan normal.
  String _friendlyLoadError(Object error) {
    final String text = error.toString();
    if (text.contains('Vision backend constraint mismatch') ||
        text.contains('requires one of [gpu]')) {
      return 'Gemma 3n E2B butuh GPU fisik untuk vision encoder dan tidak dapat '
          'berjalan di emulator. Uji di HP Android fisik dengan GPU (atau pakai '
          'model Qwen3-VL yang berjalan di CPU). File .litertlm Anda valid; '
          'yang gagal adalah inisialisasi backend GPU di perangkat ini.';
    }
    return 'Gagal memuat Gemma 3n E2B: $text';
  }

  String _buildPrompt() {
    final String catalog = FoodDatabase.foods
        .map((FoodItem food) => '${food.id} = ${food.name}')
        .join('\n');

    return '''
Analisis HANYA makanan/minuman yang benar-benar terlihat. Jangan mengarang.
Pilih food_id terdekat dari katalog:
$catalog

Tugas:
- maksimal 4 komponen utama;
- estimasi gram konservatif;
- confidence 0.0-1.0;
- nama hidangan singkat.

Balas HANYA JSON valid tanpa markdown:
{
  "meal_name": "string",
  "foods": [
    {
      "food_id": "id_dari_katalog",
      "observed_name": "nama yang terlihat",
      "estimated_grams": 120,
      "confidence": 0.82
    }
  ]
}
Jangan memberi nilai nutrisi; aplikasi menghitungnya dari database lokal.
''';
  }

  Future<void> dispose() async {
    final dynamic model = _model;
    _model = null;
    if (model != null) {
      try {
        await model.close();
      } catch (_) {}
    }
  }
}

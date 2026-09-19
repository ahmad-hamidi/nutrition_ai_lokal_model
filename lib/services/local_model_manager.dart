import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model_documents.dart';

enum LocalAiModel { qwen3Vl, gemma3nE2b }

extension LocalAiModelLabel on LocalAiModel {
  String get label => switch (this) {
        LocalAiModel.qwen3Vl => 'Qwen3-VL-2B Q4',
        LocalAiModel.gemma3nE2b => 'Gemma 3n E2B',
      };
}

class LocalModelStatus {
  const LocalModelStatus({
    this.modelPath,
    this.mmprojPath,
    this.gemmaPath,
    this.selectedModel = LocalAiModel.qwen3Vl,
    this.error,
  });

  final String? modelPath;
  final String? mmprojPath;
  final String? gemmaPath;
  final LocalAiModel selectedModel;
  final String? error;

  bool get modelReady => modelPath != null;
  bool get projectorReady => mmprojPath != null;
  bool get qwenReady => modelReady && projectorReady;
  bool get gemmaReady => gemmaPath != null;
  bool get ready => switch (selectedModel) {
        LocalAiModel.qwen3Vl => qwenReady,
        LocalAiModel.gemma3nE2b => gemmaReady,
      };
}

typedef ModelTransferProgress = void Function(double progress);

class LocalModelManager {
  LocalModelManager({ModelDocuments? documents, bool? useDocuments})
      : _documents = documents ?? ModelDocuments(),
        _useDocuments = useDocuments ?? Platform.isAndroid;

  final ModelDocuments _documents;
  final bool _useDocuments;
  static const String _modelKey = 'qwen3_vl_model_path_v1';
  static const String _mmprojKey = 'qwen3_vl_mmproj_path_v1';
  static const String _gemmaKey = 'gemma3n_e2b_model_path_v1';
  static const String _selectedModelKey = 'active_local_ai_model_v1';

  static const String languageModelFileName = 'Qwen3VL-2B-Instruct-Q4_K_M.gguf';
  static const String visionProjectorFileName = 'mmproj-Qwen3VL-2B-Instruct-Q8_0.gguf';
  static const String gemmaModelFileName = 'gemma-3n-E2B-it-int4.litertlm';

  static const String languageModelSha256 =
      '089d75c52f4b7ffc56ba998ffc50aae89fcafc755f9e7208aacca281dca6c2ae';
  static const String visionProjectorSha256 =
      'f9a68fabba69c3b81e153367b2c7521030b0fa8bb0de400c9599c8e6725f9c82';

  static final Uri languageModelUri = Uri.parse(
    'https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/'
    '$languageModelFileName?download=true',
  );

  static final Uri visionProjectorUri = Uri.parse(
    'https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/'
    '$visionProjectorFileName?download=true',
  );

  Future<LocalModelStatus> getStatus() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? modelPath = prefs.getString(_modelKey);
      final String? mmprojPath = prefs.getString(_mmprojKey);
      final String? gemmaPath = prefs.getString(_gemmaKey);
      final String selectedRaw = prefs.getString(_selectedModelKey) ?? LocalAiModel.qwen3Vl.name;
      final LocalAiModel selected = LocalAiModel.values.firstWhere(
        (LocalAiModel value) => value.name == selectedRaw,
        orElse: () => LocalAiModel.qwen3Vl,
      );
      final errors = <String>[];
      Future<String?> resolve(String? reference) async {
        try {
          return await _existingPath(reference);
        } catch (_) {
          errors.add('File model asli tidak dapat diakses. Pilih ulang file; jangan pindahkan atau hapus file sumber.');
          return null;
        }
      }
      final model = await resolve(modelPath);
      final projector = await resolve(mmprojPath);
      final gemma = await resolve(gemmaPath);
      return LocalModelStatus(
        modelPath: model,
        mmprojPath: projector,
        gemmaPath: gemma,
        error: errors.isEmpty ? null : errors.first,
        selectedModel: selected,
      );
    } catch (error) {
      return LocalModelStatus(error: error.toString());
    }
  }

  Future<LocalModelStatus> selectModel(LocalAiModel model) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedModelKey, model.name);
    return getStatus();
  }

  Future<LocalModelStatus> importLanguageModel({ModelTransferProgress? onProgress}) =>
      _importReference(_modelKey, ['gguf'], languageModelSha256, onProgress);

  Future<LocalModelStatus> importVisionProjector({ModelTransferProgress? onProgress}) =>
      _importReference(_mmprojKey, ['gguf'], visionProjectorSha256, onProgress);

  Future<LocalModelStatus> importGemmaModel({ModelTransferProgress? onProgress}) =>
      _importReference(_gemmaKey, ['litertlm'], null, onProgress);

  Future<LocalModelStatus> _importReference(String key, List<String> extensions,
      String? checksum, ModelTransferProgress? onProgress) async {
    final String? reference = await _pickModel(extensions);
    if (reference == null) return getStatus();
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString(key);
    try {
      final path = await _existingPath(reference);
      if (path == null) throw StateError('File asli tidak tersedia. Pilih ulang model.');
      if (checksum != null) await _verifySha256(File(path), checksum);
      // Store the durable URI, not the process-specific /proc descriptor path.
      await _saveModelPath(key, reference);
    } catch (_) {
      if (reference != old && reference.startsWith('content://')) {
        await _releaseUnused(reference);
      }
      rethrow;
    }
    if (old != null && old != reference && old.startsWith('content://')) {
      await _releaseUnused(old);
    }
    if (key == _gemmaKey) await selectModel(LocalAiModel.gemma3nE2b);
    onProgress?.call(1);
    return getStatus();
  }

  Future<LocalModelStatus> downloadLanguageModel({ModelTransferProgress? onProgress}) async {
    final String target = await _downloadIntoPrivateStorage(
      languageModelUri,
      targetName: languageModelFileName,
      expectedSha256: languageModelSha256,
      onProgress: onProgress,
    );
    await _saveModelPath(_modelKey, target);
    return getStatus();
  }

  Future<LocalModelStatus> downloadVisionProjector({ModelTransferProgress? onProgress}) async {
    final String target = await _downloadIntoPrivateStorage(
      visionProjectorUri,
      targetName: visionProjectorFileName,
      expectedSha256: visionProjectorSha256,
      onProgress: onProgress,
    );
    await _saveModelPath(_mmprojKey, target);
    return getStatus();
  }

  Future<void> clearQwen() async {
    await _removeReference(_modelKey);
    await _removeReference(_mmprojKey);
    final dir = await _modelsDirectory();
    for (final name in [languageModelFileName, visionProjectorFileName]) {
      final part = File('${dir.path}/$name.part');
      if (await part.exists()) await part.delete();
    }
  }

  Future<void> clearGemma() async {
    await FlutterGemma.clearActiveInferenceIdentity();
    await _removeReference(_gemmaKey);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_selectedModelKey) == LocalAiModel.gemma3nE2b.name) {
      await prefs.setString(_selectedModelKey, LocalAiModel.qwen3Vl.name);
    }
  }

  Future<void> _removeReference(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final reference = prefs.getString(key);
    await prefs.remove(key);
    if (reference != null) {
      if (reference.startsWith('content://')) {
        await _releaseUnused(reference);
      } else {
        // Only delete app-owned downloaded/legacy copies, never an external file.
        final dir = await _modelsDirectory();
        if (File(reference).parent.path == dir.path) {
          final file = File(reference);
          if (await file.exists()) await file.delete();
        }
      }
    }
    await prefs.remove(key);
  }

  Future<void> _releaseUnused(String reference) async {
    final prefs = await SharedPreferences.getInstance();
    if ([_modelKey, _mmprojKey, _gemmaKey]
        .any((key) => prefs.getString(key) == reference)) {
      return;
    }
    await _documents.release(reference);
  }

  Future<void> clear() async {
    await clearQwen();
    await clearGemma();
  }

  Future<String?> _pickModel(List<String> extensions) async {
    if (_useDocuments) return _documents.pick(extensions);
    // Android MimeTypeMap tidak mengenal '.gguf'/'.litertlm', sehingga
    // FileType.custom memicu warning "unsupported and will not be filtered".
    // Pakai FileType.any di Android untuk menghilangkan warning;
    // validasi ekstensi dilakukan manual.
    final bool isAndroid = Platform.isAndroid;
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: isAndroid ? FileType.any : FileType.custom,
        allowedExtensions: isAndroid ? null : extensions,
        allowMultiple: false,
        withData: false,
      );
    } on PlatformException catch (error) {
      throw StateError(_friendlyPickError(error, extensions));
    }
    if (result == null || result.files.isEmpty) return null;
    final String? path = result.files.single.path;
    if (path == null) {
      throw StateError(
        'File picker tidak memberikan path lokal. Buka aplikasi Files → Downloads, '
        'pilih file ${extensions.join('/')} dari penyimpanan perangkat (bukan dari Recent/Drive), lalu coba lagi.',
      );
    }
    final String lower = path.toLowerCase();
    if (!extensions.any((String ext) => lower.endsWith('.$ext'))) {
      throw StateError(
        'File yang dipilih bukan ${extensions.join('/')} '
        'Pilih file model dengan ekstensi yang sesuai.',
      );
    }
    return path;
  }

  /// Menerjemahkan error native file_picker menjadi pesan aksi.
  ///
  /// `unknown_path / Failed to retrieve path` dari plugin berarti plugin
  /// gagal menyalin content:// ke cache (lokasi tidak didukung seperti
  /// Recent/Drive, izin dicabut, atau penyimpanan penuh — file model
  /// berukuran GB sehingga butuh ruang ganda saat impor).
  String _friendlyPickError(PlatformException error, List<String> extensions) {
    if (error.code == 'unknown_path') {
      return 'Tidak bisa membaca file dari lokasi itu. Pilih file ${extensions.join('/')} lewat '
          'aplikasi Files → Downloads dari penyimpanan perangkat (jangan dari '
          'Recent/Google Drive), pastikan ruang penyimpanan cukup (model berukuran GB), '
          'lalu coba lagi. Alternatif: gunakan tombol Download otomatis.';
    }
    return 'Gagal membuka file picker: ${error.message ?? error.code}';
  }

  Future<String> _downloadIntoPrivateStorage(
    Uri uri, {
    required String targetName,
    required String expectedSha256,
    ModelTransferProgress? onProgress,
  }) async {
    final Directory modelsDir = await _modelsDirectory();
    final File target = File('${modelsDir.path}/$targetName');
    final File part = File('${modelsDir.path}/$targetName.part');

    if (await target.exists()) {
      try {
        await _verifySha256(target, expectedSha256);
        onProgress?.call(1);
        return target.path;
      } catch (_) {
        await target.delete();
      }
    }

    int resumeAt = await part.exists() ? await part.length() : 0;
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 30);

    try {
      HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'NutriLens-OfflineAI/1.3');
      request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
      if (resumeAt > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$resumeAt-');
      }

      HttpClientResponse response = await request.close();

      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable && resumeAt > 0) {
        await part.delete();
        resumeAt = 0;
        request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.userAgentHeader, 'NutriLens-OfflineAI/1.3');
        request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
        response = await request.close();
      }

      if (response.statusCode != HttpStatus.ok && response.statusCode != HttpStatus.partialContent) {
        throw HttpException(
          'Server mengembalikan HTTP ${response.statusCode}. Coba lagi atau gunakan Import Model.',
          uri: uri,
        );
      }

      final bool resumed = response.statusCode == HttpStatus.partialContent && resumeAt > 0;
      if (!resumed && resumeAt > 0) {
        await part.delete();
        resumeAt = 0;
      }

      final int remaining = response.contentLength;
      final int total = remaining > 0 ? resumeAt + remaining : -1;
      int downloaded = resumeAt;
      int lastPercent = -1;

      if (total > 0) {
        onProgress?.call(downloaded / total);
      }

      final IOSink sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
      try {
        await for (final List<int> chunk in response) {
          sink.add(chunk);
          downloaded += chunk.length;
          if (total > 0) {
            final int percent = ((downloaded / total) * 100).floor();
            if (percent != lastPercent) {
              lastPercent = percent;
              onProgress?.call((downloaded / total).clamp(0, 1));
            }
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (total > 0 && await part.length() != total) {
        throw StateError(
          'Download terhenti sebelum selesai. File parsial disimpan dan akan dilanjutkan saat mencoba lagi.',
        );
      }

      await _verifySha256(part, expectedSha256);
      if (await target.exists()) await target.delete();
      await part.rename(target.path);
      onProgress?.call(1);
      return target.path;
    } on SocketException catch (error) {
      throw StateError(
        'Koneksi internet terputus (${error.message}). Progres parsial disimpan; tekan Download lagi untuk melanjutkan.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _verifySha256(File file, String expected) async {
    final Digest digest = await sha256.bind(file.openRead()).first;
    final String actual = digest.toString().toLowerCase();
    if (actual != expected.toLowerCase()) {
      throw StateError(
        'Checksum SHA-256 tidak cocok untuk ${file.path.split(Platform.pathSeparator).last}. '
        'File mungkin rusak atau bukan model resmi yang diharapkan.',
      );
    }
  }

  Future<Directory> _modelsDirectory() async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory modelsDir = Directory('${support.path}/models');
    await modelsDir.create(recursive: true);
    return modelsDir;
  }

  Future<void> _saveModelPath(String key, String path) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, path);
  }

  Future<String?> _existingPath(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('content://')) return _documents.open(path);
    return await File(path).exists() ? path : null;
  }
}

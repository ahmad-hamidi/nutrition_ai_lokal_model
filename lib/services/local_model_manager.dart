import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalModelStatus {
  const LocalModelStatus({
    this.modelPath,
    this.mmprojPath,
    this.error,
  });

  final String? modelPath;
  final String? mmprojPath;
  final String? error;

  bool get modelReady => modelPath != null;
  bool get projectorReady => mmprojPath != null;
  bool get ready => modelReady && projectorReady;
}

typedef ModelTransferProgress = void Function(double progress);

class LocalModelManager {
  static const String _modelKey = 'qwen3_vl_model_path_v1';
  static const String _mmprojKey = 'qwen3_vl_mmproj_path_v1';

  static const String languageModelFileName = 'Qwen3VL-2B-Instruct-Q4_K_M.gguf';
  static const String visionProjectorFileName = 'mmproj-Qwen3VL-2B-Instruct-Q8_0.gguf';

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
      return LocalModelStatus(
        modelPath: await _existingPath(modelPath),
        mmprojPath: await _existingPath(mmprojPath),
      );
    } catch (error) {
      return LocalModelStatus(error: error.toString());
    }
  }

  Future<LocalModelStatus> importLanguageModel({ModelTransferProgress? onProgress}) async {
    final String? sourcePath = await _pickGguf();
    if (sourcePath == null) return getStatus();
    final String target = await _copyIntoPrivateStorage(
      sourcePath,
      targetName: languageModelFileName,
      expectedSha256: languageModelSha256,
      onProgress: onProgress,
    );
    await _saveModelPath(_modelKey, target);
    return getStatus();
  }

  Future<LocalModelStatus> importVisionProjector({ModelTransferProgress? onProgress}) async {
    final String? sourcePath = await _pickGguf();
    if (sourcePath == null) return getStatus();
    final String target = await _copyIntoPrivateStorage(
      sourcePath,
      targetName: visionProjectorFileName,
      expectedSha256: visionProjectorSha256,
      onProgress: onProgress,
    );
    await _saveModelPath(_mmprojKey, target);
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

  Future<void> clear() async {
    final LocalModelStatus status = await getStatus();
    final Directory modelsDir = await _modelsDirectory();

    for (final String? path in <String?>[status.modelPath, status.mmprojPath]) {
      if (path == null) continue;
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    for (final String name in <String>[languageModelFileName, visionProjectorFileName]) {
      final File part = File('${modelsDir.path}/$name.part');
      if (await part.exists()) {
        await part.delete();
      }
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_modelKey);
    await prefs.remove(_mmprojKey);
  }

  Future<String?> _pickGguf() async {
    // Android MimeTypeMap tidak mengenal '.gguf', sehingga FileType.custom
    // memicu warning "Custom file type 'gguf' is unsupported and will not
    // be filtered" dan filter diabaikan. Pakai FileType.any di Android
    // untuk menghilangkan warning; validasi ekstensi dilakukan manual.
    final bool isAndroid = Platform.isAndroid;
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: isAndroid ? FileType.any : FileType.custom,
        allowedExtensions: isAndroid ? null : <String>['gguf'],
        allowMultiple: false,
        withData: false,
      );
    } on PlatformException catch (error) {
      throw StateError(_friendlyPickError(error));
    }
    if (result == null || result.files.isEmpty) return null;
    final String? path = result.files.single.path;
    if (path == null) {
      throw StateError(
        'File picker tidak memberikan path lokal. Buka aplikasi Files → Downloads, '
        'pilih file .gguf dari penyimpanan perangkat (bukan dari Recent/Drive), lalu coba lagi.',
      );
    }
    if (!path.toLowerCase().endsWith('.gguf')) {
      throw StateError(
        'File yang dipilih bukan .gguf. Pilih file model dengan ekstensi .gguf.',
      );
    }
    return path;
  }

  /// Menerjemahkan error native file_picker menjadi pesan aksi.
  ///
  /// `unknown_path / Failed to retrieve path` dari plugin berarti plugin
  /// gagal menyalin content:// ke cache (lokasi tidak didukung seperti
  /// Recent/Drive, izin dicabut, atau penyimpanan penuh — file GGUF
  /// berukuran GB sehingga butuh ruang ganda saat impor).
  String _friendlyPickError(PlatformException error) {
    if (error.code == 'unknown_path') {
      return 'Tidak bisa membaca file dari lokasi itu. Pilih file .gguf lewat '
          'aplikasi Files → Downloads dari penyimpanan perangkat (jangan dari '
          'Recent/Google Drive), pastikan ruang penyimpanan cukup (model berukuran GB), '
          'lalu coba lagi. Alternatif: gunakan tombol Download otomatis.';
    }
    return 'Gagal membuka file picker: ${error.message ?? error.code}';
  }

  Future<String> _copyIntoPrivateStorage(
    String sourcePath, {
    required String targetName,
    required String expectedSha256,
    ModelTransferProgress? onProgress,
  }) async {
    final File source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('File model tidak ditemukan: $sourcePath');
    }

    final Directory modelsDir = await _modelsDirectory();
    final File target = File('${modelsDir.path}/$targetName');
    final File temp = File('${modelsDir.path}/$targetName.importing');

    if (await temp.exists()) await temp.delete();

    final int total = await source.length();
    int copied = 0;
    int lastPercent = -1;
    final IOSink sink = temp.openWrite();
    try {
      await for (final List<int> chunk in source.openRead()) {
        sink.add(chunk);
        copied += chunk.length;
        if (total > 0) {
          final int percent = ((copied / total) * 100).floor();
          if (percent != lastPercent) {
            lastPercent = percent;
            onProgress?.call(copied / total);
          }
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (await temp.length() != total) {
      await temp.delete();
      throw StateError('Copy model tidak lengkap. Coba impor ulang.');
    }

    await _verifySha256(temp, expectedSha256);
    if (await target.exists()) await target.delete();
    await temp.rename(target.path);
    onProgress?.call(1);
    return target.path;
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
      request.headers.set(HttpHeaders.userAgentHeader, 'NutriLens-Qwen3VL/1.2');
      request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
      if (resumeAt > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$resumeAt-');
      }

      HttpClientResponse response = await request.close();

      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable && resumeAt > 0) {
        await part.delete();
        resumeAt = 0;
        request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.userAgentHeader, 'NutriLens-Qwen3VL/1.2');
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
    return await File(path).exists() ? path : null;
  }
}

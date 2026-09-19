import 'package:flutter/services.dart';

/// Persists document URIs, never process-local descriptor numbers or file copies.
class ModelDocuments {
  static const channel = MethodChannel('nutrilens/model_documents');

  Future<String?> pick(List<String> extensions) async {
    final result = await channel.invokeMapMethod<String, dynamic>(
      'pick', <String, dynamic>{'extensions': extensions},
    );
    return result?['uri'] as String?;
  }

  Future<String> open(String uri) async {
    final result = await channel.invokeMapMethod<String, dynamic>(
      'open', <String, dynamic>{'uri': uri},
    );
    final path = result?['path'] as String?;
    if (path == null) throw StateError('File asli tidak tersedia. Pilih ulang model.');
    return path;
  }

  Future<void> release(String uri) => channel.invokeMethod<void>(
    'release', <String, dynamic>{'uri': uri},
  );
}

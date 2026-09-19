import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens_offline/services/local_model_manager.dart';
import 'package:nutrilens_offline/services/model_documents.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDocuments extends ModelDocuments {
  String? selection;
  final paths = <String, String>{};
  final released = <String>[];

  @override
  Future<String?> pick(List<String> extensions) async => selection;

  @override
  Future<String> open(String uri) async {
    if (!paths.containsKey(uri)) throw StateError('Permission revoked');
    return paths[uri]!;
  }

  @override
  Future<void> release(String uri) async { released.add(uri); }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late FakeDocuments documents;
  late LocalModelManager manager;
  const gemmaKey = 'gemma3n_e2b_model_path_v1';
  const qwenKey = 'qwen3_vl_model_path_v1';
  const uri = 'content://documents/model';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('model-documents-test');
    SharedPreferences.setMockInitialValues({});
    documents = FakeDocuments();
    manager = LocalModelManager(documents: documents, useDocuments: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => directory.path);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('import saves URI, leaves source untouched and creates no model copy', () async {
    final source = await File('${directory.path}/original.litertlm').writeAsString('model');
    documents.selection = uri;
    documents.paths[uri] = source.path;
    final result = await manager.importGemmaModel();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(gemmaKey), uri);
    expect(result.gemmaPath, source.path);
    expect(await source.readAsString(), 'model');
    expect(await directory.list().length, 1);
    // A new process may resolve the same durable URI to a different descriptor.
    documents.paths[uri] = '/new/process/model.litertlm';
    final restored = await LocalModelManager(documents: documents, useDocuments: true).getStatus();
    expect(restored.gemmaPath, '/new/process/model.litertlm');
  });

  test('cancel preserves previous selection', () async {
    SharedPreferences.setMockInitialValues({gemmaKey: uri});
    documents.paths[uri] = '/original';
    expect((await manager.importGemmaModel()).gemmaPath, '/original');
    expect(documents.released, isEmpty);
  });

  test('revoked document is unavailable without hiding other models', () async {
    SharedPreferences.setMockInitialValues({gemmaKey: uri, qwenKey: 'content://documents/qwen'});
    documents.paths['content://documents/qwen'] = '/qwen';
    final status = await manager.getStatus();
    expect(status.gemmaReady, isFalse);
    expect(status.modelReady, isTrue);
    expect(status.error, contains('Pilih ulang'));
  });

  test('failed checksum retains old model and releases rejected document', () async {
    final invalid = await File('${directory.path}/invalid.gguf').writeAsString('invalid');
    SharedPreferences.setMockInitialValues({qwenKey: 'content://documents/old'});
    documents.selection = uri;
    documents.paths[uri] = invalid.path;
    await expectLater(manager.importLanguageModel(), throwsStateError);
    expect((await SharedPreferences.getInstance()).getString(qwenKey), 'content://documents/old');
    expect(documents.released, [uri]);
    expect(await invalid.exists(), isTrue);
  });

  test('clear only releases imported document and does not delete source', () async {
    final original = await File('${directory.path}/original.gguf').writeAsString('original');
    SharedPreferences.setMockInitialValues({qwenKey: uri});
    documents.paths[uri] = original.path;
    await manager.clearQwen();
    expect(documents.released, [uri]);
    expect(await original.readAsString(), 'original');
    expect((await SharedPreferences.getInstance()).containsKey(qwenKey), isFalse);
  });
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens_offline/services/local_model_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late LocalModelManager manager;

  const gemmaKey = 'gemma3n_e2b_model_path_v1';
  const qwenKey = 'qwen3_vl_model_path_v1';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('model-import-test');
    SharedPreferences.setMockInitialValues({});
    manager = LocalModelManager();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => directory.path);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('getStatus resolves private copies that exist on disk', () async {
    final copy =
        await File('${directory.path}/gemma-3n-E2B-it-int4.litertlm')
            .writeAsString('model');
    SharedPreferences.setMockInitialValues({gemmaKey: copy.path});
    final status = await LocalModelManager().getStatus();
    expect(status.gemmaReady, isTrue);
    expect(status.error, isNull);
  });

  test('missing private copy reports reimport guidance', () async {
    SharedPreferences.setMockInitialValues(
        {gemmaKey: '${directory.path}/gone.litertlm'});
    final status = await LocalModelManager().getStatus();
    expect(status.gemmaReady, isFalse);
    expect(status.error, contains('Impor ulang'));
  });

  test('clear deletes private copies, prefs, and reselects qwen', () async {
    final copy =
        await File('${directory.path}/gemma-3n-E2B-it-int4.litertlm')
            .writeAsString('model');
    SharedPreferences.setMockInitialValues({
      gemmaKey: copy.path,
      'active_local_ai_model_v1': 'gemma3nE2b',
    });
    await manager.clearGemma();
    expect(await copy.exists(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(gemmaKey), isFalse);
    expect(prefs.getString('active_local_ai_model_v1'), 'qwen3Vl');
  });

  test('clearQwen removes stored keys', () async {
    SharedPreferences.setMockInitialValues({qwenKey: '${directory.path}/gone.gguf'});
    await manager.clearQwen();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(qwenKey), isFalse);
  });
}

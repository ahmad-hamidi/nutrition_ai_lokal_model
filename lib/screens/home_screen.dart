import '../widgets/unmatched_foods_card.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/food_database.dart';
import '../models/food.dart';
import '../models/meal_analysis.dart';
import '../services/history_service.dart';
import '../services/image_preprocess.dart';
import '../services/local_model_manager.dart';
import '../services/qwen_food_vision_service.dart';
import '../widgets/nutrition_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final LocalModelManager _models = LocalModelManager();
  final QwenFoodVisionService _vision = QwenFoodVisionService();
  final HistoryService _history = HistoryService();

  LocalModelStatus _modelStatus = const LocalModelStatus();
  MealAnalysis? _analysis;
  bool _checkingModel = true;
  bool _loading = false;
  bool _importing = false;
  double _importProgress = 0;
  String? _error;
  String? _stage;

  @override
  void initState() {
    super.initState();
    _refreshModelStatus();
  }

  Future<void> _refreshModelStatus() async {
    final LocalModelStatus status = await _models.getStatus();
    if (!mounted) return;
    setState(() {
      _modelStatus = status;
      _checkingModel = false;
    });
  }

  Future<void> _importModel({required bool projector}) async {
    setState(() {
      _error = null;
      _importing = true;
      _importProgress = 0;
      _stage = projector ? 'Menyalin vision projector...' : 'Menyalin Qwen3-VL Q4...';
    });
    try {
      final LocalModelStatus status = projector
          ? await _models.importVisionProjector(
              onProgress: (double value) {
                if (mounted) setState(() => _importProgress = value);
              },
            )
          : await _models.importLanguageModel(
              onProgress: (double value) {
                if (mounted) setState(() => _importProgress = value);
              },
            );
      if (!mounted) return;
      setState(() => _modelStatus = status);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Impor model gagal: $error');
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _stage = null;
        });
      }
    }
  }

  Future<void> _downloadModel({required bool projector}) async {
    setState(() {
      _error = null;
      _importing = true;
      _importProgress = 0;
      _stage = projector
          ? 'Mengunduh vision projector Q8 dari Qwen/Hugging Face...'
          : 'Mengunduh Qwen3-VL-2B Q4 dari Qwen/Hugging Face...';
    });

    try {
      final LocalModelStatus status = projector
          ? await _models.downloadVisionProjector(
              onProgress: (double value) {
                if (mounted) setState(() => _importProgress = value);
              },
            )
          : await _models.downloadLanguageModel(
              onProgress: (double value) {
                if (mounted) setState(() => _importProgress = value);
              },
            );
      if (!mounted) return;
      setState(() => _modelStatus = status);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Download model gagal: $error');
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _stage = null;
        });
      }
    }
  }

  Future<void> _downloadAllModels() async {
    setState(() {
      _error = null;
      _importing = true;
      _importProgress = 0;
      _stage = '1/2 Mengunduh Qwen3-VL-2B Q4 (~1,11 GB)...';
    });

    try {
      LocalModelStatus status = await _models.getStatus();
      if (!status.modelReady) {
        status = await _models.downloadLanguageModel(
          onProgress: (double value) {
            if (mounted) setState(() => _importProgress = value);
          },
        );
      }

      if (!mounted) return;
      setState(() {
        _modelStatus = status;
        _importProgress = 0;
        _stage = '2/2 Mengunduh vision projector Q8 (~445 MB)...';
      });

      if (!status.projectorReady) {
        status = await _models.downloadVisionProjector(
          onProgress: (double value) {
            if (mounted) setState(() => _importProgress = value);
          },
        );
      }

      if (!mounted) return;
      setState(() => _modelStatus = status);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Download model gagal: $error');
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _stage = null;
        });
      }
    }
  }

  Future<void> _clearModels() async {
    setState(() {
      _loading = true;
      _error = null;
      _stage = 'Menghapus model lokal...';
    });
    try {
      await _models.clear();
      final LocalModelStatus status = await _models.getStatus();
      if (!mounted) return;
      setState(() {
        _modelStatus = status;
        _analysis = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Gagal menghapus model: $error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _stage = null;
        });
      }
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (!_modelStatus.ready) {
      setState(() => _error = 'Download atau impor model Q4 dan vision projector terlebih dahulu.');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
      _stage = 'Memilih foto...';
    });

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file == null) return;

      if (mounted) setState(() => _stage = 'Menyiapkan foto...');
      final String photoPath = await normalizeFoodPhoto(
        file,
        maxWidth: 1024,
        quality: 85,
      );

      if (mounted) setState(() => _stage = 'Qwen3-VL sedang mengenali makanan di perangkat...');
      final QwenVisionResult result = await _vision.analyze(
        imagePath: photoPath,
        modelPath: _modelStatus.modelPath!,
        mmprojPath: _modelStatus.mmprojPath!,
      );

      final MealAnalysis analysis = MealAnalysis(
        imagePath: photoPath,
        items: result.items,
        unmatchedFoods: result.unmatchedFoods,
        rawModelOutput: result.rawResponse,
        mealName: result.mealName,
        recipe: result.recipe,
      );
      if (!mounted) return;
      setState(() => _analysis = analysis);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Analisis Qwen3-VL gagal: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _stage = null;
        });
      }
    }
  }

  void _addFood() {
    final MealAnalysis? analysis = _analysis;
    if (analysis == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView.builder(
            itemCount: FoodDatabase.foods.length,
            itemBuilder: (BuildContext context, int index) {
              final FoodItem food = FoodDatabase.foods[index];
              return ListTile(
                title: Text(food.name),
                subtitle: Text('${food.proteinPer100g.toStringAsFixed(1)} g protein / 100 g'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    analysis.items.add(
                      DetectedFood(
                        food: food,
                        grams: food.defaultGrams,
                        confidence: 1,
                        sourceLabel: 'manual',
                      ),
                    );
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  void _replaceFood(int itemIndex) {
    final MealAnalysis? analysis = _analysis;
    if (analysis == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView.builder(
            itemCount: FoodDatabase.foods.length,
            itemBuilder: (BuildContext context, int index) {
              final FoodItem food = FoodDatabase.foods[index];
              return ListTile(
                title: Text(food.name),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    analysis.items[itemIndex].food = food;
                    analysis.items[itemIndex].grams = food.defaultGrams;
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final MealAnalysis? analysis = _analysis;
    if (analysis == null || analysis.items.isEmpty) return;
    await _history.save(analysis);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Makanan disimpan ke riwayat lokal.')),
    );
  }

  Future<void> _showHistory() async {
    final List<Map<String, dynamic>> rows = await _history.load();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (BuildContext context, ScrollController controller) {
            if (rows.isEmpty) return const Center(child: Text('Belum ada riwayat.'));
            return ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> row = rows[index];
                final List<dynamic> foods = row['foods'] as List<dynamic>? ?? <dynamic>[];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(foods.join(', ')),
                  subtitle: Text(
                    '${(row['unmatchedFoods'] as List<dynamic>? ?? []).isNotEmpty ? 'Parsial • ' : ''}'
                    '${(row['protein'] as num).toStringAsFixed(1)} g protein • '
                    '${(row['calories'] as num).round()} kcal',
                  ),
                  trailing: Text(_formatDate(row['createdAt'] as String)),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatDate(String raw) {
    final DateTime date = DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
    return '${date.day}/${date.month}\n'
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final MealAnalysis? analysis = _analysis;
    return Scaffold(
      appBar: AppBar(
        title: const Text('NutriLens Qwen Offline'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Riwayat',
            onPressed: _showHistory,
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const _OfflineBanner(),
            const SizedBox(height: 12),
            _ModelSetupCard(
              status: _modelStatus,
              checking: _checkingModel,
              importing: _importing,
              progress: _importProgress,
              onDownloadAll: _downloadAllModels,
              onDownloadModel: () => _downloadModel(projector: false),
              onDownloadProjector: () => _downloadModel(projector: true),
              onImportModel: () => _importModel(projector: false),
              onImportProjector: () => _importModel(projector: true),
              onClear: _clearModels,
            ),
            if (_stage != null) ...<Widget>[
              const SizedBox(height: 12),
              _StageCard(text: _stage!, showSpinner: _loading || _importing),
            ],
            const SizedBox(height: 16),
            _PhotoPanel(
              imagePath: analysis?.imagePath,
              loading: _loading,
              enabled: _modelStatus.ready && !_importing,
              onCamera: () => _pick(ImageSource.camera),
              onGallery: () => _pick(ImageSource.gallery),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (analysis != null && !_loading) ...<Widget>[
              const SizedBox(height: 16),
              if (analysis.mealName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    analysis.mealName!,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              if (analysis.unmatchedFoods.isNotEmpty)
                UnmatchedFoodsCard(names: analysis.unmatchedFoods),
              if (analysis.items.isEmpty && analysis.unmatchedFoods.isEmpty)
                _NoFoodCard(onAdd: _addFood),
              if (analysis.items.isNotEmpty) ...<Widget>[
                if (analysis.unmatchedFoods.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Nutrisi parsial: hanya makanan yang cocok dengan database.'),
                  ),
                NutritionCard(
                  calories: analysis.calories,
                  protein: analysis.protein,
                  carbs: analysis.carbs,
                  fat: analysis.fat,
                ),
                const SizedBox(height: 12),
                _DetectedFoodsCard(
                  analysis: analysis,
                  onChanged: () => setState(() {}),
                  onReplace: _replaceFood,
                  onAdd: _addFood,
                ),
                const SizedBox(height: 12),
                _RecipeCard(analysis: analysis),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Simpan hasil'),
                ),
              ],
              const SizedBox(height: 12),
              _RawOutputCard(raw: analysis.rawModelOutput),
            ],
            const SizedBox(height: 24),
            Text(
              'Catatan: Qwen3-VL memperkirakan jenis dan porsi dari foto 2D. Angka kalori/protein dihitung ulang dari database lokal, bukan dari tebakan LLM. Koreksi jenis makanan dan gram sebelum menggunakan hasil.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.memory_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Qwen3-VL-2B Q4 + vision projector berjalan lokal melalui llama.cpp. Foto tidak dikirim ke server.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelSetupCard extends StatelessWidget {
  const _ModelSetupCard({
    required this.status,
    required this.checking,
    required this.importing,
    required this.progress,
    required this.onDownloadAll,
    required this.onDownloadModel,
    required this.onDownloadProjector,
    required this.onImportModel,
    required this.onImportProjector,
    required this.onClear,
  });

  final LocalModelStatus status;
  final bool checking;
  final bool importing;
  final double progress;
  final VoidCallback onDownloadAll;
  final VoidCallback onDownloadModel;
  final VoidCallback onDownloadProjector;
  final VoidCallback onImportModel;
  final VoidCallback onImportProjector;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.smart_toy_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Model lokal Qwen3-VL', style: Theme.of(context).textTheme.titleMedium),
                ),
                if (status.ready)
                  const Chip(
                    avatar: Icon(Icons.check_circle, size: 18),
                    label: Text('Siap'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Download langsung dari repo resmi Qwen atau impor file GGUF yang sudah Anda miliki.',
            ),
            const SizedBox(height: 6),
            Text(
              'Internet hanya diperlukan untuk download model. Setelah kedua model siap, analisis foto berjalan lokal/offline.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (!status.ready)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: importing || checking ? null : onDownloadAll,
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: const Text('Download Semua (~1,55 GB)'),
                ),
              ),
            if (!status.ready) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Disarankan Wi-Fi dan ruang kosong minimal 2 GB. Download parsial akan disimpan untuk dicoba lanjutkan jika koneksi terputus.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
            ],
            _ModelFileRow(
              title: LocalModelManager.languageModelFileName,
              subtitle: 'Language model Q4_K_M • sekitar 1,11 GB',
              ready: status.modelReady,
              checking: checking,
              busy: importing,
              onDownload: onDownloadModel,
              onImport: onImportModel,
            ),
            const Divider(),
            _ModelFileRow(
              title: LocalModelManager.visionProjectorFileName,
              subtitle: 'Vision projector Q8_0 • sekitar 445 MB',
              ready: status.projectorReady,
              checking: checking,
              busy: importing,
              onDownload: onDownloadProjector,
              onImport: onImportProjector,
            ),
            if (importing) ...<Widget>[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress > 0 ? progress : null),
              const SizedBox(height: 6),
              Text(
                progress > 0
                    ? '${(progress * 100).clamp(0, 100).round()}%'
                    : 'Menghubungkan ke server model...',
              ),
            ],
            if (status.ready) ...<Widget>[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: importing ? null : onClear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus model lokal'),
              ),
            ],
            if (status.error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(status.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModelFileRow extends StatelessWidget {
  const _ModelFileRow({
    required this.title,
    required this.subtitle,
    required this.ready,
    required this.checking,
    required this.busy,
    required this.onDownload,
    required this.onImport,
  });

  final String title;
  final String subtitle;
  final bool ready;
  final bool checking;
  final bool busy;
  final VoidCallback onDownload;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(ready ? Icons.check_circle : Icons.description_outlined),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (checking)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
          if (!checking) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: busy ? null : onImport,
                    icon: const Icon(Icons.folder_open_outlined, size: 18),
                    label: Text(ready ? 'Impor pengganti' : 'Impor'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onDownload,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(ready ? 'Download ulang' : 'Download'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.text, required this.showSpinner});

  final String text;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          if (showSpinner) ...<Widget>[
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PhotoPanel extends StatelessWidget {
  const _PhotoPanel({
    required this.imagePath,
    required this.loading,
    required this.enabled,
    required this.onCamera,
    required this.onGallery,
  });

  final String? imagePath;
  final bool loading;
  final bool enabled;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 4 / 3,
            child: imagePath == null
                ? Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.restaurant_menu, size: 64),
                          const SizedBox(height: 10),
                          Text(enabled ? 'Foto makanan untuk Qwen3-VL' : 'Download atau impor model terlebih dahulu'),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.file(File(imagePath!), fit: BoxFit.cover),
                      if (loading)
                        Container(
                          color: Colors.black45,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: enabled && !loading ? onCamera : null,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled && !loading ? onGallery : null,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeri'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectedFoodsCard extends StatelessWidget {
  const _DetectedFoodsCard({
    required this.analysis,
    required this.onChanged,
    required this.onReplace,
    required this.onAdd,
  });

  final MealAnalysis analysis;
  final VoidCallback onChanged;
  final void Function(int index) onReplace;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text('Makanan terdeteksi', style: Theme.of(context).textTheme.titleMedium)),
                TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Tambah')),
              ],
            ),
            const SizedBox(height: 6),
            for (int i = 0; i < analysis.items.length; i++) ...<Widget>[
              _FoodEditor(
                item: analysis.items[i],
                onRemove: () {
                  analysis.items.removeAt(i);
                  onChanged();
                },
                onReplace: () => onReplace(i),
                onChanged: onChanged,
              ),
              if (i != analysis.items.length - 1) const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _FoodEditor extends StatelessWidget {
  const _FoodEditor({
    required this.item,
    required this.onChanged,
    required this.onReplace,
    required this.onRemove,
  });

  final DetectedFood item;
  final VoidCallback onChanged;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: InkWell(
                onTap: onReplace,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(item.food.name, style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        item.sourceLabel == 'manual'
                            ? 'Ditambahkan manual'
                            : 'Perkiraan Qwen: ${item.sourceLabel} • perlu diperiksa',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(onPressed: onRemove, icon: const Icon(Icons.close), tooltip: 'Hapus'),
          ],
        ),
        Row(
          children: <Widget>[
            IconButton(
              onPressed: () {
                item.grams = (item.grams - 10).clamp(10, 2000).toDouble();
                onChanged();
              },
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Expanded(
              child: Slider(
                value: item.grams.clamp(10, 500).toDouble(),
                min: 10,
                max: 500,
                divisions: 49,
                label: '${item.grams.round()} g',
                onChanged: (double value) {
                  item.grams = value;
                  onChanged();
                },
              ),
            ),
            IconButton(
              onPressed: () {
                item.grams = (item.grams + 10).clamp(10, 2000).toDouble();
                onChanged();
              },
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        Text(
          '${item.grams.round()} g • ${item.protein.toStringAsFixed(1)} g protein • ${item.calories.round()} kcal',
        ),
      ],
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.analysis});

  final MealAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final RecipeSuggestion? aiRecipe = analysis.recipe;
    final FoodItem? fallback = analysis.items.isEmpty ? null : analysis.items.first.food;
    final String title = aiRecipe?.title ?? fallback?.recipeTitle ?? 'Resep perkiraan';
    final List<String> ingredients = aiRecipe?.ingredients ?? fallback?.ingredients ?? <String>[];
    final List<String> steps = aiRecipe?.steps ?? fallback?.steps ?? <String>[];

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: const Text('Resep cepat lokal'),
        subtitle: Text(title),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          Align(alignment: Alignment.centerLeft, child: Text('Bahan', style: Theme.of(context).textTheme.titleSmall)),
          const SizedBox(height: 6),
          for (final String ingredient in ingredients)
            Align(alignment: Alignment.centerLeft, child: Text('• $ingredient')),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: Text('Cara', style: Theme.of(context).textTheme.titleSmall)),
          const SizedBox(height: 6),
          for (int i = 0; i < steps.length; i++)
            Align(alignment: Alignment.centerLeft, child: Text('${i + 1}. ${steps[i]}')),
        ],
      ),
    );
  }
}

class _RawOutputCard extends StatelessWidget {
  const _RawOutputCard({required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.data_object),
        title: const Text('Output mentah Qwen3-VL'),
        subtitle: const Text('Untuk debugging / benchmark'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          SelectableText(raw, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _NoFoodCard extends StatelessWidget {
  const _NoFoodCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            const Text('Qwen tidak menemukan item yang cocok dengan database nutrisi lokal.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Tambah manual')),
          ],
        ),
      ),
    );
  }
}

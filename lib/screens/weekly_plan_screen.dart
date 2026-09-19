import 'package:flutter/material.dart';

import '../data/weekly_meal_plan.dart';
import '../models/weekly_plan.dart';
import '../services/gemma_food_vision_service.dart';
import '../services/local_model_manager.dart';
import '../services/qwen_food_vision_service.dart';
import '../services/weekly_plan_generator.dart';

class WeeklyPlanScreen extends StatefulWidget {
  const WeeklyPlanScreen({super.key});

  @override
  State<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends State<WeeklyPlanScreen> {
  final LocalModelManager _models = LocalModelManager();
  late final WeeklyPlanGenerator _generator = WeeklyPlanGenerator(
    qwen: QwenFoodVisionService(),
    gemma: GemmaFoodVisionService(),
  );

  LocalModelStatus? _status;
  WeeklyPlanResult? _aiPlan;
  bool _showAi = false;
  bool _generating = false;
  int _progressDone = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final LocalModelStatus status = await _models.getStatus();
    final WeeklyPlanResult? cached = await _generator.loadCache();
    if (!mounted) return;
    setState(() {
      _status = status;
      _aiPlan = cached;
      _showAi = cached != null;
    });
  }

  Future<void> _generate() async {
    final LocalModelStatus? status = _status;
    if (status == null || !status.ready || _generating) return;
    setState(() {
      _generating = true;
      _progressDone = 0;
      _error = null;
    });
    try {
      final WeeklyPlanResult result = await _generator.generate(
        status: status,
        onProgress: (int done, int total) {
          if (mounted) setState(() => _progressDone = done);
        },
      );
      if (!mounted) return;
      setState(() {
        _aiPlan = result;
        _showAi = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Generate menu gagal: $error');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showingAi = _showAi && _aiPlan != null;
    final List<DailyMealPlan> days =
        showingAi ? _aiPlan!.days : WeeklyMealPlanData.days;
    final LocalModelStatus? status = _status;

    return Scaffold(
      appBar: AppBar(title: const Text('Resep & Menu 7 Hari')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            showingAi ? 'Menu 7 hari buatan AI' : 'Contoh menu 7 hari',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            showingAi
                ? 'Dibuat ${_aiPlan!.modelLabel} dari katalog lokal.${_aiPlan!.fullyAi ? '' : ' Beberapa hari fallback ke contoh.'} Semua angka adalah estimasi.'
                : 'Semua angka adalah estimasi dari database lokal. Sesuaikan porsi, kebutuhan energi, alergi, kondisi kesehatan, dan preferensi Anda.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (status == null)
            const LinearProgressIndicator()
          else if (!status.ready)
            Text(
              'Untuk generate dengan AI, siapkan dulu model di halaman utama.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else if (_generating)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                LinearProgressIndicator(
                  value: _progressDone > 0 ? _progressDone / 7 : null,
                ),
                const SizedBox(height: 6),
                Text(
                  _progressDone > 0
                      ? 'Membuat Hari $_progressDone/7 dengan ${status.selectedModel.label}... (bisa beberapa menit di CPU)'
                      : 'Memuat model...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(showingAi ? 'Generate ulang' : 'Generate dengan AI'),
                ),
                if (showingAi)
                  OutlinedButton(
                    onPressed: () => setState(() => _showAi = false),
                    child: const Text('Lihat contoh'),
                  ),
              ],
            ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          for (int i = 0; i < days.length; i++) ...<Widget>[
            if (showingAi && _aiPlan!.fallbackDayIndexes.contains(i))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${days[i].day} memakai contoh (generate gagal).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            _DayCard(day: days[i]),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final DailyMealPlan day;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: day.day == 'Hari 1',
        title: Text(day.day),
        subtitle: Text(
          '${day.calories.round()} kcal • ${day.protein.toStringAsFixed(0)} g protein • '
          '${day.fiber.toStringAsFixed(1)} g serat',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          _DayNutrition(day: day),
          const SizedBox(height: 12),
          for (int i = 0; i < day.meals.length; i++) ...<Widget>[
            _MealCard(meal: day.meals[i]),
            if (i != day.meals.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DayNutrition extends StatelessWidget {
  const _DayNutrition({required this.day});

  final DailyMealPlan day;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _Chip('Kalori', '${day.calories.round()} kcal'),
        _Chip('Protein', '${day.protein.toStringAsFixed(1)} g'),
        _Chip('Karbo', '${day.carbs.toStringAsFixed(1)} g'),
        _Chip('Lemak', '${day.fat.toStringAsFixed(1)} g'),
        _Chip('Serat', '${day.fiber.toStringAsFixed(1)} g'),
        _Chip('Gula', '${day.sugar.toStringAsFixed(1)} g'),
        _Chip('Natrium', '${day.sodiumMg.round()} mg'),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});

  final PlannedMeal meal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(meal.name, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '${meal.calories.round()} kcal • ${meal.protein.toStringAsFixed(1)} g protein • '
            '${meal.carbs.toStringAsFixed(1)} g karbo • ${meal.fat.toStringAsFixed(1)} g lemak',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Text('Ingredient', style: Theme.of(context).textTheme.labelLarge),
          for (final String item in meal.ingredients) Text('• $item'),
          const SizedBox(height: 8),
          Text('Cara membuat', style: Theme.of(context).textTheme.labelLarge),
          for (int i = 0; i < meal.steps.length; i++) Text('${i + 1}. ${meal.steps[i]}'),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Chip(label: Text('$label: $value'));
}

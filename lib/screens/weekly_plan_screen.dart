import 'package:flutter/material.dart';

import '../data/weekly_meal_plan.dart';
import '../models/weekly_plan.dart';

class WeeklyPlanScreen extends StatelessWidget {
  const WeeklyPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resep & Menu 7 Hari')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Contoh menu 7 hari',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Semua angka adalah estimasi dari database lokal. Sesuaikan porsi, kebutuhan energi, alergi, kondisi kesehatan, dan preferensi Anda.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          for (final DailyMealPlan day in WeeklyMealPlanData.days) ...<Widget>[
            _DayCard(day: day),
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

import 'package:flutter/material.dart';

class NutritionCard extends StatelessWidget {
  const NutritionCard({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Estimasi nutrisi', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(child: _Metric(label: 'Kalori', value: '${calories.round()} kcal')),
                Expanded(child: _Metric(label: 'Protein', value: '${protein.toStringAsFixed(1)} g')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(child: _Metric(label: 'Karbo', value: '${carbs.toStringAsFixed(1)} g')),
                Expanded(child: _Metric(label: 'Lemak', value: '${fat.toStringAsFixed(1)} g')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

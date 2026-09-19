import 'package:flutter/material.dart';

class NutritionCard extends StatelessWidget {
  const NutritionCard({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.saturatedFat,
    required this.sodiumMg,
    required this.cholesterolMg,
    required this.potassiumMg,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double saturatedFat;
  final double sodiumMg;
  final double cholesterolMg;
  final double potassiumMg;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Estimasi nutrisi lengkap', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 14,
              children: <Widget>[
                _Metric(label: 'Kalori', value: '${calories.round()} kcal'),
                _Metric(label: 'Protein', value: '${protein.toStringAsFixed(1)} g'),
                _Metric(label: 'Karbo', value: '${carbs.toStringAsFixed(1)} g'),
                _Metric(label: 'Lemak', value: '${fat.toStringAsFixed(1)} g'),
                _Metric(label: 'Lemak jenuh', value: '${saturatedFat.toStringAsFixed(1)} g'),
                _Metric(label: 'Serat', value: '${fiber.toStringAsFixed(1)} g'),
                _Metric(label: 'Gula', value: '${sugar.toStringAsFixed(1)} g'),
                _Metric(label: 'Natrium', value: '${sodiumMg.round()} mg'),
                _Metric(label: 'Kolesterol', value: '${cholesterolMg.round()} mg'),
                _Metric(label: 'Kalium', value: '${potassiumMg.round()} mg'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Nilai adalah estimasi berdasarkan jenis makanan dan gram yang dipilih; bukan hasil laboratorium.',
              style: Theme.of(context).textTheme.bodySmall,
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
    return SizedBox(
      width: 145,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

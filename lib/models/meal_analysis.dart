import 'food.dart';

class RecipeSuggestion {
  const RecipeSuggestion({
    required this.title,
    required this.ingredients,
    required this.steps,
  });

  final String title;
  final List<String> ingredients;
  final List<String> steps;
}

class MealAnalysis {
  MealAnalysis({
    required this.imagePath,
    required this.items,
    required this.rawModelOutput,
    this.unmatchedFoods = const <String>[],
    this.mealName,
    this.recipe,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String imagePath;
  final List<DetectedFood> items;
  final String rawModelOutput;
  final List<String> unmatchedFoods;
  final String? mealName;
  final RecipeSuggestion? recipe;
  final DateTime createdAt;

  double _sum(double Function(DetectedFood item) selector) =>
      items.fold(0, (double sum, DetectedFood item) => sum + selector(item));

  double get calories => _sum((DetectedFood item) => item.calories);
  double get protein => _sum((DetectedFood item) => item.protein);
  double get carbs => _sum((DetectedFood item) => item.carbs);
  double get fat => _sum((DetectedFood item) => item.fat);
  double get fiber => _sum((DetectedFood item) => item.fiber);
  double get sugar => _sum((DetectedFood item) => item.sugar);
  double get saturatedFat => _sum((DetectedFood item) => item.saturatedFat);
  double get sodiumMg => _sum((DetectedFood item) => item.sodiumMg);
  double get cholesterolMg => _sum((DetectedFood item) => item.cholesterolMg);
  double get potassiumMg => _sum((DetectedFood item) => item.potassiumMg);
}

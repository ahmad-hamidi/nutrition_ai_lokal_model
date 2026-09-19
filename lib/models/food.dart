class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.aliases,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fiberPer100g = 0,
    this.sugarPer100g = 0,
    this.saturatedFatPer100g = 0,
    this.sodiumMgPer100g = 0,
    this.cholesterolMgPer100g = 0,
    this.potassiumMgPer100g = 0,
    required this.defaultGrams,
    required this.recipeTitle,
    required this.ingredients,
    required this.steps,
  });

  final String id;
  final String name;
  final List<String> aliases;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final double sugarPer100g;
  final double saturatedFatPer100g;
  final double sodiumMgPer100g;
  final double cholesterolMgPer100g;
  final double potassiumMgPer100g;
  final double defaultGrams;
  final String recipeTitle;
  final List<String> ingredients;
  final List<String> steps;
}

class DetectedFood {
  DetectedFood({
    required this.food,
    required this.grams,
    required this.confidence,
    required this.sourceLabel,
  });

  FoodItem food;
  double grams;
  final double confidence;
  final String sourceLabel;

  double _scaled(double value) => value * grams / 100;

  double get calories => _scaled(food.caloriesPer100g);
  double get protein => _scaled(food.proteinPer100g);
  double get carbs => _scaled(food.carbsPer100g);
  double get fat => _scaled(food.fatPer100g);
  double get fiber => _scaled(food.fiberPer100g);
  double get sugar => _scaled(food.sugarPer100g);
  double get saturatedFat => _scaled(food.saturatedFatPer100g);
  double get sodiumMg => _scaled(food.sodiumMgPer100g);
  double get cholesterolMg => _scaled(food.cholesterolMgPer100g);
  double get potassiumMg => _scaled(food.potassiumMgPer100g);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'foodId': food.id,
        'grams': grams,
        'confidence': confidence,
        'sourceLabel': sourceLabel,
      };
}

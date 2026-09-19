import '../data/food_database.dart';
import 'food.dart';

class PlannedFood {
  const PlannedFood({required this.foodId, required this.grams});

  final String foodId;
  final double grams;

  FoodItem? get food => FoodDatabase.byId(foodId);
  double _scaled(double value) => value * grams / 100;

  double get calories => _scaled(food?.caloriesPer100g ?? 0);
  double get protein => _scaled(food?.proteinPer100g ?? 0);
  double get carbs => _scaled(food?.carbsPer100g ?? 0);
  double get fat => _scaled(food?.fatPer100g ?? 0);
  double get fiber => _scaled(food?.fiberPer100g ?? 0);
  double get sugar => _scaled(food?.sugarPer100g ?? 0);
  double get saturatedFat => _scaled(food?.saturatedFatPer100g ?? 0);
  double get sodiumMg => _scaled(food?.sodiumMgPer100g ?? 0);
  double get cholesterolMg => _scaled(food?.cholesterolMgPer100g ?? 0);
  double get potassiumMg => _scaled(food?.potassiumMgPer100g ?? 0);
}

class PlannedMeal {
  const PlannedMeal({
    required this.name,
    required this.foods,
    required this.ingredients,
    required this.steps,
  });

  final String name;
  final List<PlannedFood> foods;
  final List<String> ingredients;
  final List<String> steps;

  double _sum(double Function(PlannedFood food) pick) =>
      foods.fold(0, (double total, PlannedFood food) => total + pick(food));

  double get calories => _sum((PlannedFood food) => food.calories);
  double get protein => _sum((PlannedFood food) => food.protein);
  double get carbs => _sum((PlannedFood food) => food.carbs);
  double get fat => _sum((PlannedFood food) => food.fat);
  double get fiber => _sum((PlannedFood food) => food.fiber);
  double get sugar => _sum((PlannedFood food) => food.sugar);
  double get sodiumMg => _sum((PlannedFood food) => food.sodiumMg);
}

class DailyMealPlan {
  const DailyMealPlan({
    required this.day,
    required this.meals,
  });

  final String day;
  final List<PlannedMeal> meals;

  double _sum(double Function(PlannedMeal meal) pick) =>
      meals.fold(0, (double total, PlannedMeal meal) => total + pick(meal));

  double get calories => _sum((PlannedMeal meal) => meal.calories);
  double get protein => _sum((PlannedMeal meal) => meal.protein);
  double get carbs => _sum((PlannedMeal meal) => meal.carbs);
  double get fat => _sum((PlannedMeal meal) => meal.fat);
  double get fiber => _sum((PlannedMeal meal) => meal.fiber);
  double get sugar => _sum((PlannedMeal meal) => meal.sugar);
  double get sodiumMg => _sum((PlannedMeal meal) => meal.sodiumMg);
}

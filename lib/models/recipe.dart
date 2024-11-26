import 'package:hive/hive.dart';

part 'recipe.g.dart';

@HiveType(typeId: 0)
class Recipe extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<String> ingredients;

  @HiveField(2)
  List<String> steps;

  @HiveField(3)
  DateTime date; // New field for storing the meal date

  Recipe({
    required this.name,
    required this.ingredients,
    required this.steps,
    required this.date, // Pass the date when creating a Recipe
  });
}

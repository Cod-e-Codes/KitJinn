import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/recipe.dart';
import 'settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/recipe_list_screen.dart';
import 'screens/meal_planner_screen.dart';
import 'screens/pantry_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Register the Recipe adapter
  Hive.registerAdapter(RecipeAdapter());

  // Open the boxes you will need before the app starts
  await Future.wait([
    Hive.openBox<String>('ingredients'),
    Hive.openBox<Recipe>('recipes'),
    Hive.openBox<Recipe>('meals'),
    Hive.openBox('settings'),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        Provider<Box<String>>(create: (_) => Hive.box<String>('ingredients')),
        Provider<Box<Recipe>>(create: (_) => Hive.box<Recipe>('recipes')),
        Provider<Box<Recipe>>(create: (_) => Hive.box<Recipe>('meals')),
      ],
      child: const CookingAssistantApp(),
    ),
  );
}

class CookingAssistantApp extends StatelessWidget {
  const CookingAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cooking Assistant App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/recipe-list': (context) => const RecipeListScreen(),
        '/meal-planner': (context) => const MealPlannerScreen(),
        '/pantry': (context) => const PantryScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

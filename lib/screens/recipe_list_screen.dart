import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:alphabet_list_view/alphabet_list_view.dart';
import 'package:provider/provider.dart'; // Import provider for settings
import '../models/recipe.dart';
import 'recipe_detail_screen.dart';
import '../widgets/custom_bottom_app_bar.dart';
import '../settings_provider.dart'; // Import the SettingsProvider
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:flutter_tts/flutter_tts.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  RecipeListScreenState createState() => RecipeListScreenState();
}

class RecipeListScreenState extends State<RecipeListScreen> {
  late Box<Recipe> recipeBox;
  late Box<Recipe> mealBox;
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  String _command = '';
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initializeHiveBoxes();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initializeSpeech();
  }

  void _initializeHiveBoxes() async {
    if (!Hive.isBoxOpen('recipes')) {
      await Hive.openBox<Recipe>('recipes');
    }
    if (!Hive.isBoxOpen('meals')) {
      await Hive.openBox<Recipe>('meals');
    }
    recipeBox = Hive.box<Recipe>('recipes');
    mealBox = Hive.box<Recipe>('meals');
  }

  void _initializeSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech Status: $status'),
      onError: (errorNotification) =>
          debugPrint('Speech Error: $errorNotification'),
    );

    setState(() {
      _speechAvailable = _speech.isAvailable;
    });
  }

  Future<void> _speak(String message) async {
    var settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.voiceFeedbackEnabled) {
      await _flutterTts.speak(message);
    }
  }

  void _startListening() async {
    if (!_speechAvailable || _isListening) return;

    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
      });

      _speech.listen(
        onResult: (val) {
          if (val.finalResult) {
            setState(() {
              _command = val.recognizedWords;
              debugPrint('Finalized Command: $_command');
            });
            _onVoiceCommand(_command);
            _stopListening();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
      });
      debugPrint('Stopped listening.');
    }
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  Future<bool> _handleNavigationCommand(String command) async {
    final navCommands = [
      'go to pantry',
      'go to recipe list',
      'go to meal planner'
    ];

    var bestMatch = command.bestMatch(navCommands).bestMatch.target;

    if (bestMatch == 'go to pantry') {
      await _speak('Navigating to Pantry');
      if (mounted) {
        Navigator.pushNamed(context, '/pantry');
        return true;
      }
    } else if (bestMatch == 'go to recipe list') {
      await _speak('You are already in the Recipe List');
    } else if (bestMatch == 'go to meal planner') {
      await _speak('Navigating to Meal Planner');
      if (mounted) {
        Navigator.pushNamed(context, '/meal-planner');
        return true;
      }
    }

    return false;
  }

  void _onVoiceCommand(String command) async {
    if (command.startsWith('add ')) {
      String recipeName = command.replaceFirst('add ', '').trim();
      if (recipeName.isNotEmpty) {
        _addRecipe(recipeName, [], []);
        await _speak('Recipe "$recipeName" added');
      } else {
        await _speak('No recipe name detected.');
      }
      return;
    }

    if (await _handleNavigationCommand(command)) return;

    command = command.toLowerCase().trim();

    final commands = [
      'view recipe',
      'delete recipe',
      'edit recipe',
      'cook recipe on'
    ];

    var bestMatch = command.bestMatch(commands).bestMatch.target;

    if (bestMatch == 'view recipe' && RegExp(r'view (.+)').hasMatch(command)) {
      final match = RegExp(r'view (.+)').firstMatch(command);
      String recipeName = match?.group(1) ?? '';
      if (recipeName.isNotEmpty) {
        _viewRecipeDetails(recipeName);
        await _speak('Opening recipe "$recipeName"');
      }
    } else if (bestMatch == 'delete recipe' &&
        RegExp(r'delete (.+)').hasMatch(command)) {
      final match = RegExp(r'delete (.+)').firstMatch(command);
      String recipeName = match?.group(1) ?? '';
      if (recipeName.isNotEmpty) {
        _deleteRecipe(recipeName, isVoiceCommand: true);
      }
      await _speak('Recipe "$recipeName" deleted');
    } else if (bestMatch == 'edit recipe' &&
        RegExp(r'edit (.+) to (.+)').hasMatch(command)) {
      final match = RegExp(r'edit (.+) to (.+)').firstMatch(command);
      String oldRecipeName = match?.group(1) ?? '';
      String newRecipeName = match?.group(2) ?? '';
      if (oldRecipeName.isNotEmpty && newRecipeName.isNotEmpty) {
        _editRecipe(oldRecipeName, newRecipeName);
        await _speak('Recipe "$oldRecipeName" renamed to "$newRecipeName"');
      }
    } else if (bestMatch == 'cook recipe on' &&
        RegExp(r'cook (.+) on (.+)').hasMatch(command)) {
      final match = RegExp(r'cook (.+) on (.+)').firstMatch(command);
      String recipeName = match?.group(1) ?? '';
      String dayOfWeek = match?.group(2) ?? '';
      _scheduleRecipeForDay(recipeName, dayOfWeek);
      await _speak('Recipe "$recipeName" scheduled on $dayOfWeek');
    } else {
      await _speak('Command not recognized, please try again.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Command not recognized, please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _scheduleRecipeForDay(String recipeName, String dayOfWeek) {
    final recipe = recipeBox.values.firstWhere(
          (r) => r.name.toLowerCase() == recipeName.toLowerCase(),
      orElse: () =>
          Recipe(name: '', ingredients: [], steps: [], date: DateTime.now()),
    );

    if (recipe.name.isNotEmpty) {
      DateTime scheduledDate = _getDayOfWeek(dayOfWeek);
      final newMeal = Recipe(
        name: recipe.name,
        ingredients: List<String>.from(recipe.ingredients),
        steps: List<String>.from(recipe.steps),
        date: scheduledDate,
      );
      mealBox.add(newMeal);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Recipe "${recipe.name}" scheduled on ${DateFormat.EEEE().format(scheduledDate)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Recipe "$recipeName" not found'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  DateTime _getDayOfWeek(String dayOfWeek) {
    final now = DateTime.now();
    final daysOfWeek = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };
    int weekday = daysOfWeek[dayOfWeek.toLowerCase()] ?? now.weekday;
    return now.add(Duration(days: (weekday - now.weekday) % 7));
  }

  void _addRecipe(String name, List<String> ingredients, List<String> steps) {
    final newRecipe = Recipe(
        name: name,
        ingredients: ingredients,
        steps: steps,
        date: DateTime.now());
    recipeBox.add(newRecipe);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Recipe "$name" added'),
          behavior: SnackBarBehavior.floating),
    );
  }

  void _viewRecipeDetails(String recipeName) {
    final recipe = recipeBox.values.firstWhere(
          (r) => r.name.toLowerCase() == recipeName.toLowerCase(),
      orElse: () =>
          Recipe(name: '', ingredients: [], steps: [], date: DateTime.now()),
    );

    if (recipe.name.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailScreen(recipe: recipe),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Recipe "$recipeName" not found'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _deleteRecipe(String recipeName, {bool isVoiceCommand = false}) {
    final recipe = recipeBox.values.firstWhere(
          (r) => r.name.toLowerCase() == recipeName.toLowerCase(),
      orElse: () =>
          Recipe(name: '', ingredients: [], steps: [], date: DateTime.now()),
    );

    if (recipe.name.isNotEmpty) {
      if (isVoiceCommand) {
        int recipeKey = recipe.key as int;
        recipeBox.delete(recipeKey);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Recipe "$recipeName" deleted'),
              behavior: SnackBarBehavior.floating),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 8.0,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete Recipe',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Are you sure you want to delete the recipe "$recipeName"?',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.purple.shade900,
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            int recipeKey = recipe.key as int;
                            recipeBox.delete(recipeKey);
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Recipe "$recipeName" deleted'),
                                  behavior: SnackBarBehavior.floating),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Recipe "$recipeName" not found'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _editRecipe(String oldRecipeName, String newRecipeName) {
    final recipe = recipeBox.values.firstWhere(
          (r) => r.name.toLowerCase() == oldRecipeName.toLowerCase(),
      orElse: () =>
          Recipe(name: '', ingredients: [], steps: [], date: DateTime.now()),
    );

    if (recipe.name.isNotEmpty) {
      recipe.name = newRecipeName;
      recipe.save();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Recipe updated to "$newRecipeName"'),
            behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Recipe "$oldRecipeName" not found'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  List<AlphabetListViewItemGroup> _buildRecipeAlphabetGroups() {
    Map<String, List<Widget>> groupedRecipes = {};

    for (var recipe in recipeBox.values) {
      String firstLetter = recipe.name[0].toUpperCase();
      if (!groupedRecipes.containsKey(firstLetter)) {
        groupedRecipes[firstLetter] = [];
      }
      groupedRecipes[firstLetter]!.add(
        ListTile(
          title: Text(
            recipe.name,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.white70),
            onPressed: () {
              _deleteRecipe(recipe.name, isVoiceCommand: false);
            },
          ),
          onTap: () {
            _viewRecipeDetails(recipe.name);
          },
        ),
      );
    }

    return groupedRecipes.entries
        .map((entry) =>
        AlphabetListViewItemGroup(tag: entry.key, children: entry.value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    var settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade900, Colors.greenAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          const Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Recipe List',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 4.0,
                      color: Colors.black45,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.home, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.pushNamed(context, '/');
              },
            ),
          ),
          Positioned.fill(
            top: 120,
            child: ValueListenableBuilder(
              valueListenable: recipeBox.listenable(),
              builder: (context, Box<Recipe> box, _) {
                if (box.values.isEmpty) {
                  return const Center(child: Text('No recipes added yet.'));
                }

                return AlphabetListView(
                  items: _buildRecipeAlphabetGroups(),
                  options: AlphabetListViewOptions(
                    listOptions: ListOptions(
                      listHeaderBuilder: (context, symbol) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.black12, Colors.transparent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              symbol,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    scrollbarOptions: ScrollbarOptions(
                      width: 36,
                      padding: const EdgeInsets.symmetric(vertical: 16.0), // Add vertical padding
                      symbolBuilder: (context, symbol, state) => Text(
                        symbol,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.transparent, Colors.black12],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),

                    overlayOptions: OverlayOptions(
                      showOverlay: true,
                      alignment: Alignment.center,
                      overlayBuilder: (context, symbol) {
                        return Container(
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            symbol,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isListening && settings.commandOverlayEnabled)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5), // Translucent overlay
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Listening...',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Available Commands:',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '1. "Add [recipe name]"\n'
                          '2. "View [recipe name]"\n'
                          '3. "Delete [recipe name]"\n'
                          '4. "Edit [old recipe name] to [new recipe name]"\n'
                          '5. "Cook [recipe name] on [day of the week]"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: CustomBottomAppBar(
        onMicPressed: _toggleListening,
        isListening: _isListening,
        helpText:
        'Available Commands:\n\n1. "Add [recipe name]": Add a new recipe\n2. "View [recipe name]": View details of a recipe\n3. "Delete [recipe name]": Delete a recipe\n4. "Edit [old recipe name] to [new recipe name]": Rename a recipe\n5. "Cook [recipe name] on [day of the week]": Schedule a recipe',
      ),
      floatingActionButton: SizedBox(
        height: 80,
        width: 80,
        child: FloatingActionButton(
          onPressed: _toggleListening,
          backgroundColor: _isListening ? Colors.greenAccent : Colors.white,
          shape: CircleBorder(
            side: BorderSide(
              color: _isListening ? Colors.purple.shade900 : Colors.greenAccent,
              width: 3.0,
            ),
          ),
          elevation: 6.0,
          child: Icon(
            _isListening ? Icons.mic : Icons.mic_none,
            color:
            _isListening ? Colors.purple.shade900 : Colors.purple.shade900,
            size: 48,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart'; // Import flutter_tts
import '../models/recipe.dart';
import '../widgets/custom_bottom_app_bar.dart';
import 'package:hive/hive.dart';
import 'package:string_similarity/string_similarity.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  RecipeDetailScreenState createState() => RecipeDetailScreenState();
}

class RecipeDetailScreenState extends State<RecipeDetailScreen> {
  FlutterLocalNotificationsPlugin? notificationsPlugin;
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts; // Initialize FlutterTts instance
  bool _isListening = false;
  bool _speechAvailable = false;
  int currentStep = 0;
  String _command = '';
  late Box<Recipe> mealBox;

  @override
  void initState() {
    super.initState();
    var androidInitSettings = const AndroidInitializationSettings('app_icon');
    var initSettings = InitializationSettings(android: androidInitSettings);
    notificationsPlugin = FlutterLocalNotificationsPlugin();
    notificationsPlugin?.initialize(initSettings);

    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts(); // Initialize TTS in initState
    _initializeSpeech();
    _initializeMealBox(); // Initialize Hive box for meals
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

  Future<void> _initializeMealBox() async {
    mealBox = await Hive.openBox<Recipe>('meals');
  }

  // Function to handle text-to-speech for a given message
  Future<void> _speak(String message) async {
    await _flutterTts.speak(message);
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
            _onVoiceCommand(_command); // Process only finalized commands
            _stopListening(); // Stop listening after the command is processed
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3), // Natural breaks detection
      );
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  // Improved command parsing using fuzzy matching
  void _onVoiceCommand(String command) async {
    command = command.toLowerCase().trim();

    // Set of possible voice commands
    final commands = [
      'cook on',
      'add ingredient',
      'add step',
      'delete ingredient',
      'delete step',
      'next step'
    ];

    var bestMatch = command.bestMatch(commands).bestMatch.target;

    if (bestMatch == 'cook on' && command.startsWith('cook on ')) {
      String dayOfWeek = command.replaceFirst('cook on ', '').trim();
      await _speak('Cooking on $dayOfWeek');
      _addRecipeToMealPlan(dayOfWeek);
    } else if (bestMatch == 'add ingredient' &&
        command.startsWith('add ingredient ')) {
      String ingredient = command.replaceFirst('add ingredient ', '').trim();
      if (ingredient.isNotEmpty) {
        await _speak('Adding ingredient $ingredient');
        _addIngredientVoice(ingredient);
      }
    } else if (bestMatch == 'add step' && command.startsWith('add step ')) {
      String step = command.replaceFirst('add step ', '').trim();
      if (step.isNotEmpty) {
        await _speak('Adding step $step');
        _addStepVoice(step);
      }
    } else if (bestMatch == 'delete ingredient' &&
        command.startsWith('delete ingredient ')) {
      String ingredient = command.replaceFirst('delete ingredient ', '').trim();
      if (ingredient.isNotEmpty) {
        await _speak('Deleting ingredient $ingredient');
        _deleteIngredientVoice(ingredient);
      }
    } else if (bestMatch == 'delete step' &&
        command.startsWith('delete step ')) {
      String stepWord = command.replaceFirst('delete step ', '').trim();
      int? stepIndex = int.tryParse(stepWord) ?? _convertWordToNumber(stepWord);
      if (stepIndex != null &&
          stepIndex > 0 &&
          stepIndex <= widget.recipe.steps.length) {
        await _speak('Deleting step $stepIndex');
        _deleteStepVoice(stepIndex - 1);
      }
    } else if (bestMatch == 'next step' && command.contains('next step')) {
      await _speak('Moving to the next step');
      _nextStep(); // Call the method to go to the next step
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

  // Method to move to the next step in the recipe
  void _nextStep() {
    if (currentStep < widget.recipe.steps.length - 1) {
      setState(() {
        currentStep++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Proceed to step ${currentStep + 1}'),
            behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You are already at the last step'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  // Method to add the recipe to the meal plan for a specific day
  void _addRecipeToMealPlan(String dayOfWeek) {
    DateTime selectedDate = _getNextDayOfWeek(dayOfWeek);
    Recipe newMeal = Recipe(
      name: widget.recipe.name,
      ingredients: widget.recipe.ingredients,
      steps: widget.recipe.steps,
      date: selectedDate,
    );
    mealBox.add(newMeal); // Add the recipe to the Hive box for the selected day

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
          Text('Added "${widget.recipe.name}" to $dayOfWeek\'s meal plan!'),
          behavior: SnackBarBehavior.floating),
    );
  }

  DateTime _getNextDayOfWeek(String dayOfWeek) {
    final daysOfWeek = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    int? day = daysOfWeek[dayOfWeek.toLowerCase()];
    if (day == null) return DateTime.now(); // Default to today if invalid day

    DateTime now = DateTime.now();
    int currentDay = now.weekday;
    int daysToAdd = (day - currentDay) % 7;
    if (daysToAdd <= 0) daysToAdd += 7;

    return now.add(Duration(days: daysToAdd));
  }

  int? _convertWordToNumber(String word) {
    switch (word) {
      case 'one':
        return 1;
      case 'two':
        return 2;
      case 'three':
        return 3;
      case 'four':
        return 4;
      case 'five':
        return 5;
      case 'six':
        return 6;
      case 'seven':
        return 7;
      case 'eight':
        return 8;
      case 'nine':
        return 9;
      case 'ten':
        return 10;
      default:
        return null;
    }
  }

  void _addIngredientVoice(String ingredient) {
    setState(() {
      widget.recipe.ingredients.add(ingredient);
      widget.recipe.save();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Ingredient "$ingredient" added'),
          behavior: SnackBarBehavior.floating),
    );
  }

  void _addStepVoice(String step) {
    setState(() {
      widget.recipe.steps.add(step);
      widget.recipe.save();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Step "$step" added'),
          behavior: SnackBarBehavior.floating),
    );
  }

  void _deleteIngredientVoice(String ingredient) {
    setState(() {
      widget.recipe.ingredients
          .removeWhere((i) => i.toLowerCase() == ingredient.toLowerCase());
      widget.recipe.save();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Ingredient "$ingredient" deleted'),
          behavior: SnackBarBehavior.floating),
    );
  }

  void _deleteStepVoice(int stepIndex) {
    setState(() {
      widget.recipe.steps.removeAt(stepIndex);
      widget.recipe.save();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Step ${stepIndex + 1} deleted'),
          behavior: SnackBarBehavior.floating),
    );
  }

  void _confirmDeleteIngredient(int index) {
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
              const Text(
                'Delete Ingredient',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Are you sure you want to delete this ingredient?'),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _deleteIngredient(index);
                        Navigator.of(context).pop(); // Close dialog
                      },
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

  void _confirmDeleteStep(int index) {
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
              const Text(
                'Delete Step',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Are you sure you want to delete this step?'),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _deleteStep(index);
                        Navigator.of(context).pop(); // Close dialog
                      },
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

  void _deleteIngredient(int index) {
    setState(() {
      widget.recipe.ingredients.removeAt(index);
      widget.recipe.save();
    });
  }

  void _deleteStep(int index) {
    setState(() {
      widget.recipe.steps.removeAt(index);
      widget.recipe.save();
    });
  }

  @override
  Widget build(BuildContext context) {
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 30),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.recipe.name,
                          style: const TextStyle(
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
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            top: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Ingredients:',
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.recipe.ingredients.length,
                    itemBuilder: (context, index) {
                      return Card(
                        color: Colors.white.withOpacity(0.2),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 4.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0)),
                        child: ListTile(
                          title: Text(
                            widget.recipe.ingredients[index],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                              color: Colors.white70,
                            ),
                          ),
                          trailing: IconButton(
                            icon:
                            const Icon(Icons.delete, color: Colors.white70),
                            onPressed: () {
                              _confirmDeleteIngredient(index);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Steps:',
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.recipe.steps.length,
                    itemBuilder: (context, index) {
                      return Card(
                        color: Colors.white.withOpacity(0.2),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 4.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0)),
                        child: ListTile(
                          title: Text(
                            'Step ${index + 1}: ${widget.recipe.steps[index]}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                              color: Colors.white70,
                            ),
                          ),
                          trailing: IconButton(
                            icon:
                            const Icon(Icons.delete, color: Colors.white70),
                            onPressed: () {
                              _confirmDeleteStep(index);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_isListening)
            Positioned.fill(
              child: Container(
                color: Colors.black54, // Translucent overlay
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Listening...',
                        style: TextStyle(
                          fontSize: 30,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Available Commands:\n\n'
                            '1. "Next step"\n'
                            '2. "Add ingredient [ingredient name]"\n'
                            '3. "Add step [step description]"\n'
                            '4. "Delete ingredient [ingredient name]"\n'
                            '5. "Delete step [step number]"\n'
                            '6. "Cook on [day of the week]"',
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
            ),
        ],
      ),
      bottomNavigationBar: CustomBottomAppBar(
        onMicPressed: _toggleListening,
        isListening: _isListening,
        helpText: 'Available Commands:\n\n'
            '1. "Next step"\n'
            '2. "Previous step"\n'
            '3. "Add ingredient [ingredient name]"\n'
            '4. "Add step [step description]"\n'
            '5. "Delete ingredient [ingredient name]"\n'
            '6. "Delete step [step number]"\n'
            '7. "Cook on [day of the week]"',
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

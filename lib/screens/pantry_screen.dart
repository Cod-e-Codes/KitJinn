import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_bottom_app_bar.dart';
import '../settings_provider.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  PantryScreenState createState() => PantryScreenState();
}

class PantryScreenState extends State<PantryScreen> {
  late Box<String> ingredientBox;
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  String _command = '';
  bool _speechAvailable = false;
  bool _boxInitialized = false; // Track if the box is initialized

  @override
  void initState() {
    super.initState();
    _initializePantry();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initializeSpeech();
  }

  Future<void> _initializePantry() async {
    // Open the box asynchronously
    ingredientBox = await Hive.openBox<String>('ingredients');
    setState(() {
      _boxInitialized = true; // Set the flag when the box is ready
    });
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
      await _speak('You are already in the Pantry');
      return true;
    } else if (bestMatch == 'go to recipe list') {
      await _speak('Navigating to Recipe List');
      if (mounted) {
        Navigator.pushNamed(context, '/recipe-list');
        return true;
      }
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
    if (await _handleNavigationCommand(command)) return;

    command = command.toLowerCase().trim();

    final commands = [
      'add ingredient to category',
      'view category',
      'delete ingredient'
    ];

    var bestMatch = command.bestMatch(commands).bestMatch.target;

    if (bestMatch == 'add ingredient to category' &&
        RegExp(r'add (.+) to (.+)').hasMatch(command)) {
      final match = RegExp(r'add (.+) to (.+)').firstMatch(command);
      String ingredient = match?.group(1) ?? '';
      String category = match?.group(2) ?? '';
      if (ingredient.isNotEmpty && category.isNotEmpty) {
        await _speak('Adding $ingredient to $category');
        _addIngredientToCategory(ingredient, category);
      }
    } else if (bestMatch == 'view category' &&
        RegExp(r'view (.+)').hasMatch(command)) {
      final match = RegExp(r'view (.+)').firstMatch(command);
      String category = match?.group(1) ?? '';
      if (category.isNotEmpty) {
        await _speak('Viewing $category');
        _showCategoryIngredients(category);
      }
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

  void _addIngredientToCategory(String ingredient, String category) {
    category = category.toLowerCase();
    debugPrint('Adding "$ingredient" to category: "$category"');

    if ([
      'fruits and vegetables',
      'grains',
      'dairy',
      'proteins',
      'fats',
      'sugars'
    ].contains(category)) {
      ingredientBox.add('$ingredient|$category');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Added "$ingredient" to $category'),
            behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Unknown category: $category'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  List<String> _filterIngredientsByCategory(Box<String> box, String category) {
    category = category.toLowerCase();

    return box.values
        .where((entry) => entry.split('|').last.toLowerCase() == category)
        .map((entry) => entry.split('|').first)
        .toList();
  }

  void _showCategoryIngredients(String category) {
    List<String> ingredients =
    _filterIngredientsByCategory(ingredientBox, category);
    showModalBottomSheet(
      backgroundColor: const Color(0xFF6B6C91),
      context: context,
      builder: (context) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Ingredients in $category',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: ingredients.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      ingredients[index],
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white70),
                      onPressed: () {
                        _deleteIngredientFromCategory(
                            ingredients[index], category);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteIngredientFromCategory(String ingredient, String category) {
    int indexToDelete = ingredientBox.values
        .toList()
        .indexWhere((entry) => entry == '$ingredient|$category');

    if (indexToDelete != -1) {
      ingredientBox.deleteAt(indexToDelete);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Deleted "$ingredient" from $category'),
            behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ingredient not found'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var settings = Provider.of<SettingsProvider>(context);

    if (!_boxInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

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
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.home, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.pushNamed(context, '/');
              },
            ),
          ),
          const Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Pantry',
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
          Positioned.fill(
            top: 120,
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(8),
              children: [
                _buildCategorySection(
                    "Fruits and Vegetables", "Fruits and Vegetables"),
                _buildCategorySection("Grains", "Grains"),
                _buildCategorySection("Dairy", "Dairy"),
                _buildCategorySection("Proteins", "Proteins"),
                _buildCategorySection("Fats", "Fats"),
                _buildCategorySection("Sugars", "Sugars"),
              ],
            ),
          ),
          if (_isListening && settings.commandOverlayEnabled)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
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
                      '1. "Add [ingredient] to [category]"\n'
                          '2. "View [category]"',
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
        'Available Commands:\n\n1. "Add [ingredient] to [category]"\n2. "View [category]"',
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

  Widget _buildCategorySection(String categoryName, String category) {
    return GestureDetector(
      onTap: () {
        _showCategoryIngredients(category);
      },
      child: Card(
        color: Colors.white24,
        margin: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                categoryName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${_filterIngredientsByCategory(ingredientBox, category).length} items',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

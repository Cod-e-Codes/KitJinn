import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:string_similarity/string_similarity.dart'; // For fuzzy matching
import '../models/recipe.dart';
import '../widgets/custom_bottom_app_bar.dart';
import 'meal_detail_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart'; // Import flutter_tts for TTS
import 'package:provider/provider.dart'; // Import provider for settings
import '../settings_provider.dart'; // Import the settings provider

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  MealPlannerScreenState createState() => MealPlannerScreenState();
}

class MealPlannerScreenState extends State<MealPlannerScreen> {
  late Box<Recipe> mealBox;
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  String _command = '';
  bool _speechAvailable = false;
  DateTime _selectedDate = DateTime.now();
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeBox();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initializeSpeech();
  }

  Future<void> _initializeBox() async {
    mealBox = await Hive.openBox<Recipe>('meals');
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
      await _speak('Navigating to Pantry');
      if (mounted) {
        Navigator.pushNamed(context, '/pantry');
        return true;
      }
    } else if (bestMatch == 'go to recipe list') {
      await _speak('Navigating to Recipe List');
      if (mounted) {
        Navigator.pushNamed(context, '/recipe-list');
        return true;
      }
    } else if (bestMatch == 'go to meal planner') {
      await _speak('You are already in the Meal Planner');
      return true;
    }

    return false;
  }

  void _onVoiceCommand(String command) async {
    if (command.startsWith('add meal ')) {
      String mealName = command.replaceFirst('add meal ', '').trim();
      if (mealName.isNotEmpty) {
        _addMeal(mealName);
        await _speak('Meal "$mealName" added for ${_selectedDate.toLocal()}');
      } else {
        await _speak('No meal name detected.');
      }
      return;
    }

    if (await _handleNavigationCommand(command)) return;

    command = command.toLowerCase().trim();

    final commands = ['delete meal'];

    var bestMatch = command.bestMatch(commands).bestMatch.target;

    if (bestMatch == 'delete meal' && command.contains('delete meal')) {
      await _speak('Meal deleted.');
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

  void _addMeal(String name) async {
    final newMeal = Recipe(
      name: name,
      ingredients: [],
      steps: [],
      date: _selectedDate,
    );
    mealBox.add(newMeal);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Meal "$name" added for ${_selectedDate.toLocal()}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _deleteMeal(int index) {
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
                'Delete Meal',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Are you sure you want to delete this meal?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.purple.shade900,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        mealBox.deleteAt(index);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Meal deleted'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

  // Method to update the date of a meal when dropped
  void _rescheduleMeal(Recipe meal, DateTime newDate) {
    meal.date = newDate;
    meal.save();
  }

  @override
  Widget build(BuildContext context) {
    var settings = Provider.of<SettingsProvider>(context);

    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
              child: Text('Error initializing data: ${snapshot.error}'));
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
                    'Meal Planner',
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
                child: Column(
                  children: [
                    EasyDateTimeLine(
                      initialDate: DateTime.now(),
                      onDateChange: (selectedDate) {
                        setState(() {
                          _selectedDate = selectedDate;
                        });
                      },
                      activeColor: Colors.greenAccent,
                      dayProps: EasyDayProps(
                        todayStyle: DayStyle(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white, Colors.white],
                            ),
                          ),
                          monthStrStyle: const TextStyle(color: Colors.black),
                          dayNumStyle: TextStyle(
                              color: Colors.purple.shade900,
                              fontWeight: FontWeight.bold),
                          dayStrStyle: const TextStyle(color: Colors.black87),
                        ),
                        activeDayStyle: const DayStyle(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.greenAccent, Colors.greenAccent],
                            ),
                          ),
                        ),
                        inactiveDayStyle: DayStyle(
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          monthStrStyle: const TextStyle(color: Colors.white),
                          dayNumStyle: const TextStyle(color: Colors.white70),
                          dayStrStyle: const TextStyle(color: Colors.white70),
                        ),
                        height: 56.0,
                        width: 64.0,
                      ),
                      headerProps: const EasyHeaderProps(
                        monthPickerType: MonthPickerType.switcher,
                        selectedDateStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        monthStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      itemBuilder: (context, date, isSelected, onTap) {
                        return DragTarget<Recipe>(
                          onAcceptWithDetails: (DragTargetDetails<Recipe> details) {
                            setState(() {
                              _rescheduleMeal(details.data, date);
                            });
                          },
                          builder: (context, candidateData, rejectedData) {
                            return InkWell(
                              onTap: onTap,
                              borderRadius: BorderRadius.circular(16.0),
                              child: Container(
                                width: 64.0,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.greenAccent.withOpacity(0.7)
                                      : null,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: candidateData.isNotEmpty
                                        ? Colors.greenAccent
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        date.day.toString(),
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      Text(
                                        EasyDateFormatter.shortDayName(
                                            date, "en_US"),
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: mealBox.listenable(),
                        builder: (context, Box<Recipe> box, _) {
                          var mealsForSelectedDay = box.values
                              .where((meal) =>
                          meal.date.day == _selectedDate.day &&
                              meal.date.month == _selectedDate.month &&
                              meal.date.year == _selectedDate.year)
                              .toList();

                          if (mealsForSelectedDay.isEmpty) {
                            return const Center(
                                child: Text('No meals for this day.'));
                          }
                          return ListView.builder(
                            itemCount: mealsForSelectedDay.length,
                            itemBuilder: (context, index) {
                              Recipe meal = mealsForSelectedDay[index];

                              return Draggable<Recipe>(
                                data: meal,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    color: Colors.white24,
                                    elevation: 8.0,
                                    child: Container(
                                      height: 64,
                                      width: 64,
                                      alignment: Alignment.center,
                                      child: Text(
                                        meal.name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                childWhenDragging: Container(),
                                dragAnchorStrategy: pointerDragAnchorStrategy,
                                child: Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  elevation: 2,
                                  color: Colors.white24,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      meal.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Scheduled meal prep',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white60,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                              Icons.arrow_forward,
                                              color: Colors.white70),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    MealDetailScreen(
                                                        meal: meal),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.white70),
                                          onPressed: () {
                                            _deleteMeal(index);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
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
                          '1. "Add meal [meal name]"\n'
                              '2. "Delete meal"',
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
            helpText: 'Available Commands:\n\n1. "Add meal [meal name]"',
          ),
          floatingActionButton: SizedBox(
            height: 80,
            width: 80,
            child: FloatingActionButton(
              onPressed: _toggleListening,
              backgroundColor: _isListening ? Colors.greenAccent : Colors.white,
              shape: CircleBorder(
                side: BorderSide(
                  color: _isListening
                      ? Colors.purple.shade900
                      : Colors.greenAccent,
                  width: 3.0,
                ),
              ),
              elevation: 6.0,
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening
                    ? Colors.purple.shade900
                    : Colors.purple.shade900,
                size: 48,
              ),
            ),
          ),
          floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
        );
      },
    );
  }
}

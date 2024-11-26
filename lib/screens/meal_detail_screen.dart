import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart'; // Import flutter_tts
import 'package:string_similarity/string_similarity.dart'; // Fuzzy matching
import 'package:provider/provider.dart'; // Import provider for settings
import '../models/recipe.dart';
import '../widgets/custom_bottom_app_bar.dart';
import '../settings_provider.dart';

class MealDetailScreen extends StatefulWidget {
  final Recipe meal;

  const MealDetailScreen({super.key, required this.meal});

  @override
  MealDetailScreenState createState() => MealDetailScreenState();
}

class MealDetailScreenState extends State<MealDetailScreen> {
  FlutterLocalNotificationsPlugin? notificationsPlugin;
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts; // Initialize FlutterTts instance
  bool _isListening = false;
  bool _speechAvailable = false;
  String _command = '';
  int currentStep = 0;

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
            _onVoiceCommand(_command); // Process only finalized commands
            _stopListening(); // Stop listening after the command is processed
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
      'next step',
      'previous step',
      'start timer for step',
      'set timer for',
      'pause timer',
      'restart timer',
      'stop timer'
    ];

    var bestMatch = command.bestMatch(commands).bestMatch.target;

    if (bestMatch == 'next step' && command.contains('next step')) {
      await _speak('Proceeding to the next step');
      _nextStep();
    } else if (bestMatch == 'previous step' &&
        command.contains('previous step')) {
      await _speak('Going back to the previous step');
      _previousStep();
    } else if (bestMatch == 'start timer for step' &&
        command.contains('start timer for step')) {
      int stepNumber = int.tryParse(command.split(' ').last) ?? 1;
      await _speak('Starting timer for step $stepNumber');
      if (mounted) {
        _startTimer(context, 'Step $stepNumber timer', 10);
      }
    } else if (bestMatch == 'set timer for' &&
        command.contains('set timer for')) {
      int time = int.tryParse(command.split(' ').last) ?? 10;
      await _speak('Setting timer for $time seconds');
      if (mounted) {
        _startTimer(context, 'Custom Timer', time);
      }
    } else if (bestMatch == 'pause timer' && command.contains('pause timer')) {
      await _speak('Pausing the timer');
      _pauseTimer();
    } else if (bestMatch == 'restart timer' &&
        command.contains('restart timer')) {
      await _speak('Restarting the timer');
      _restartTimer();
    } else if (bestMatch == 'stop timer' && command.contains('stop timer')) {
      await _speak('Stopping the timer');
      _stopTimer();
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

  void _nextStep() {
    if (currentStep < widget.meal.steps.length - 1) {
      setState(() {
        currentStep++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Proceed to step ${currentStep + 1}'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Back to step ${currentStep + 1}'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _startTimer(BuildContext context, String title, int seconds) {
    notificationsPlugin?.show(
      0,
      title,
      'Time to move to the next step!',
      const NotificationDetails(
          android: AndroidNotificationDetails('0', 'cooking')),
    );
  }

  void _pauseTimer() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Timer paused'), behavior: SnackBarBehavior.floating),
    );
  }

  void _restartTimer() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Timer restarted'),
          behavior: SnackBarBehavior.floating),
    );
  }

  void _stopTimer() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Timer stopped'), behavior: SnackBarBehavior.floating),
    );
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
                          widget.meal.name,
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
                    itemCount: widget.meal.ingredients.length,
                    itemBuilder: (context, index) {
                      return Card(
                        color: Colors.white.withOpacity(0.2),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 4.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: ListTile(
                          title: Text(
                            widget.meal.ingredients[index],
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          trailing: IconButton(
                            icon:
                            const Icon(Icons.delete, color: Colors.white70),
                            onPressed: () {
                              setState(() {
                                widget.meal.ingredients.removeAt(index);
                                widget.meal.save();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Ingredient removed'),
                                    behavior: SnackBarBehavior.floating),
                              );
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
                    itemCount: widget.meal.steps.length,
                    itemBuilder: (context, index) {
                      return Card(
                        color: Colors.white.withOpacity(0.2),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 4.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: ListTile(
                          title: Text(
                            'Step ${index + 1}: ${widget.meal.steps[index]}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.timer,
                                    color: Colors.white70),
                                onPressed: () {
                                  _startTimer(
                                      context, 'Step ${index + 1} timer', 10);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.white70),
                                onPressed: () {
                                  setState(() {
                                    widget.meal.steps.removeAt(index);
                                    widget.meal.save();
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Step removed'),
                                        behavior: SnackBarBehavior.floating),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
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
                      '1. "Next step"\n'
                          '2. "Previous step"\n'
                          '3. "Start timer for step [number]"\n'
                          '4. "Set timer for [time in seconds]"\n'
                          '5. "Pause timer"\n'
                          '6. "Restart timer"\n'
                          '7. "Stop timer"',
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
        helpText: 'Available Commands:\n\n'
            '1. "Next step"\n'
            '2. "Previous step"\n'
            '3. "Start timer for step [number]"\n'
            '4. "Set timer for [time in seconds]"\n'
            '5. "Pause timer"\n'
            '6. "Restart timer"\n'
            '7. "Stop timer"',
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

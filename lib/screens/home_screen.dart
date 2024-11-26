import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lottie/lottie.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:provider/provider.dart'; // Import provider for settings
import '../widgets/custom_bottom_app_bar.dart';
import '../settings_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  String _command = '';
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
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

    // Add other HomeScreen-specific commands here, if any
  }

  @override
  Widget build(BuildContext context) {
    var settings = Provider.of<SettingsProvider>(context);
    String genieAnimation =
    _isListening ? 'assets/images/genie2.json' : 'assets/images/genie.json';

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
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Welcome to KitJinn',
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
                const SizedBox(height: 20),
                const Text(
                  'Your hands-free kitchen companion',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                Lottie.asset(
                  genieAnimation,
                  width: 300,
                  height: 250,
                  fit: BoxFit.fill,
                ),
                const SizedBox(height: 40),
                Text(
                  _isListening
                      ? 'Hearing your kitchen magic now...'
                      : 'Speak your culinary wish after pressing the mic.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
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
                        fontSize: 30,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Available Commands:\n\n'
                          '1. "Go to recipe list"\n'
                          '2. "Go to meal planner"\n'
                          '3. "Go to pantry"',
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
        'Available Commands:\n\n1. "Go to recipe list"\n2. "Go to meal planner"\n3. "Go to pantry"',
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

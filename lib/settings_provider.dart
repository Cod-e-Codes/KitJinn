import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsProvider with ChangeNotifier {
  bool _voiceFeedbackEnabled = true;
  bool _commandOverlayEnabled = true;

  bool get voiceFeedbackEnabled => _voiceFeedbackEnabled;
  bool get commandOverlayEnabled => _commandOverlayEnabled;

  SettingsProvider() {
    _loadSettings();
  }

  // Load settings from Hive on startup
  Future<void> _loadSettings() async {
    final settingsBox = await Hive.openBox('settings');
    _voiceFeedbackEnabled = settingsBox.get('voiceFeedbackEnabled', defaultValue: true);
    _commandOverlayEnabled = settingsBox.get('commandOverlayEnabled', defaultValue: true);
    notifyListeners();
  }

  // Save settings to Hive
  Future<void> _saveSetting(String key, dynamic value) async {
    final settingsBox = await Hive.openBox('settings');
    await settingsBox.put(key, value);
  }

  // Toggle and save voice feedback setting
  void toggleVoiceFeedback() {
    _voiceFeedbackEnabled = !_voiceFeedbackEnabled;
    _saveSetting('voiceFeedbackEnabled', _voiceFeedbackEnabled);
    notifyListeners();
  }

  // Toggle and save command overlay setting
  void toggleCommandOverlay() {
    _commandOverlayEnabled = !_commandOverlayEnabled;
    _saveSetting('commandOverlayEnabled', _commandOverlayEnabled);
    notifyListeners();
  }
}

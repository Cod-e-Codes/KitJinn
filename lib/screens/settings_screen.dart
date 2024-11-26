import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40), // Add spacing at the top
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Settings',
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
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                SwitchListTile(
                  activeColor: Colors.greenAccent,
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.white30,
                  title: const Text(
                    'Enable Voice Feedback',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2.0,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                  value: settings.voiceFeedbackEnabled,
                  onChanged: (value) {
                    settings.toggleVoiceFeedback();
                  },
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  activeColor: Colors.greenAccent,
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.white30,
                  title: const Text(
                    'Enable Command Overlay',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2.0,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                  value: settings.commandOverlayEnabled,
                  onChanged: (value) {
                    settings.toggleCommandOverlay();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

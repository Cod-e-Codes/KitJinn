import 'package:flutter/material.dart';

class CustomBottomAppBar extends StatelessWidget {
  final void Function()? onMicPressed;
  final bool isListening;
  final String helpText; // Added helpText parameter

  const CustomBottomAppBar({
    super.key,
    this.onMicPressed,
    required this.isListening,
    required this.helpText, // Required parameter for help text
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      elevation: 10.0, // Adds shadow effect
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.menu_book),
            iconSize: 30,
            color: Colors.purple.shade900,
            onPressed: () {
              Navigator.pushNamed(context, '/recipe-list');
            },
            splashRadius: 24.0,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            iconSize: 30,
            color: Colors.purple.shade900,
            onPressed: () {
              Navigator.pushNamed(context, '/meal-planner');
            },
            splashRadius: 24.0,
          ),
          const SizedBox(width: 48), // Space for the FloatingActionButton
          IconButton(
            icon: const Icon(Icons.food_bank),
            iconSize: 30,
            color: Colors.purple.shade900,
            onPressed: () {
              Navigator.pushNamed(context, '/pantry');
            },
            splashRadius: 24.0,
          ),
          IconButton(
            icon: const Icon(Icons.help_center),
            iconSize: 30,
            color: Colors.purple.shade900,
            onPressed: () {
              _showHelpDialog(context, helpText);
            },
            splashRadius: 24.0,
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context, String helpText) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0), // Rounded corners
          ),
          elevation: 8.0, // Adds elevation for a modern look
          backgroundColor: Colors.white, // Set background to white for contrast
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help & Commands',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade900, // Match the app theme color
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  helpText,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade800, // Use a more subtle text color
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Colors.purple.shade900, // Match app theme color
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

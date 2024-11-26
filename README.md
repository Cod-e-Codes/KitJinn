
# KitJinn - Your Hands-Free Kitchen Assistant 🍳✨

KitJinn is a smart, hands-free kitchen assistant app developed by **CodēCodes**. It helps you plan meals, manage your pantry, and discover recipes efficiently. With voice recognition commands and engaging Lottie animations, KitJinn ensures your culinary journey is seamless and enjoyable.

## Features

- **Hands-Free Operation**: Use voice commands to navigate and interact with the app while keeping your hands free for cooking.
- **Lottie Animations**: Smooth, engaging animations enhance the user experience and make the app visually appealing.
- **Home Screen**: A dashboard to access key features like meal planning, pantry organization, and recipes.
- **Meal Planner**: Plan your meals for the week with easy-to-use scheduling tools.
- **Pantry Management**: Track ingredients and inventory in your pantry to reduce food waste.
- **Recipe Discovery**: Browse, search, and save recipes with detailed instructions and images.
- **Recipe Detail View**: View in-depth recipe information, including ingredients, steps, and cooking tips.
- **Settings**: Customize the app experience, including theme preferences and notifications.

## Screenshots 📸

1. **Home Screen**
   <img src="./assets/images/home_screen.png" alt="Home Screen" width="300"/>

2. **Meal Planner**
   <img src="./assets/images/meal_planner.png" alt="Meal Planner" width="300"/>

3. **Pantry Screen**
   <img src="./assets/images/pantry_screen.png" alt="Pantry Screen" width="300"/>

4. **Recipe List**
   <img src="./assets/images/recipe_list.png" alt="Recipe List" width="300"/>

5. **Recipe Detail**
   <img src="./assets/images/recipe_detail.png" alt="Recipe Detail" width="300"/>

## Folder Structure

```plaintext
KitJinn/
├── lib/
│   ├── main.dart                     # Entry point of the app
│   ├── settings_provider.dart        # App settings and state management
│   ├── models/
│   │   ├── recipe.dart               # Recipe data model
│   │   └── recipe.g.dart             # Generated code for recipe model
│   ├── screens/
│   │   ├── home_screen.dart          # Home screen
│   │   ├── meal_detail_screen.dart   # Meal detail screen
│   │   ├── meal_planner_screen.dart  # Meal planner screen
│   │   ├── pantry_screen.dart        # Pantry management screen
│   │   ├── recipe_detail_screen.dart # Recipe detail view
│   │   ├── recipe_list_screen.dart   # List of recipes
│   │   └── settings_screen.dart      # App settings
│   ├── widgets/
│   │   └── custom_bottom_app_bar.dart # Custom navigation bar
├── assets/
│   ├── images/                       # App assets and images
│   │   ├── genie.png
│   │   ├── genie.json
│   │   ├── genie2.json
│   │   └── genie3.json
├── pubspec.yaml                      # App dependencies and metadata
```

## Getting Started

### Prerequisites

Ensure you have Flutter installed. If not, follow the [Flutter installation guide](https://flutter.dev/docs/get-started/install).

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/Cod-e-Codes/KitJinn.git
   ```

2. Navigate to the project directory:
   ```bash
   cd KitJinn
   ```

3. Fetch dependencies:
   ```bash
   flutter pub get
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Contribution

Feel free to fork this repository and submit pull requests. Contributions are always welcome!

## Author

Developed by [CodēCodes](https://github.com/Cod-e-Codes). For inquiries or collaboration, reach out via the GitHub profile.

---

KitJinn - Your hands-free kitchen companion with voice commands and delightful animations. 🍽️✨

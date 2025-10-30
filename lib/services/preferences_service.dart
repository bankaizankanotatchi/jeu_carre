// services/preferences_service.dart
// import 'package:shared_preferences/shared_preferences.dart';

// class PreferencesService {
//   static const String _firstLaunchKey = 'first_launch';

//   static Future<bool> isFirstLaunch() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getBool(_firstLaunchKey) ?? true;
//   }

//   static Future<void> setFirstLaunchCompleted() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool(_firstLaunchKey, false);
//   }
// }

// services/preferences_service.dart
class PreferencesService {
  static bool _firstLaunch = true;

  static Future<bool> isFirstLaunch() async {
    // Pour l'instant, on utilise une variable simple
    // Plus tard, vous pourrez intégrer shared_preferences
    return _firstLaunch;
  }

  static Future<void> setFirstLaunchCompleted() async {
    _firstLaunch = false;
    
    // Optionnel: log pour le débogage
    print('First launch marked as completed');
  }

  // Méthode pour réinitialiser (utile pour les tests)
  static void resetForTesting() {
    _firstLaunch = true;
  }
}
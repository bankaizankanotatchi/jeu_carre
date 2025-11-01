// // services/preferences_service.dart
// class PreferencesService {
//   static bool _firstLaunch = true;

//   static Future<bool> isFirstLaunch() async {
//     // Pour l'instant, on utilise une variable simple
//     // Plus tard, vous pourrez intégrer shared_preferences
//     return _firstLaunch;
//   }

//   static Future<void> setFirstLaunchCompleted() async {
//     _firstLaunch = false;
    
//     // Optionnel: log pour le débogage
//     print('First launch marked as completed');
//   }

//   // Méthode pour réinitialiser (utile pour les tests)
//   static void resetForTesting() {
//     _firstLaunch = true;
//   }
// }

// services/preferences_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyFirstLaunch = 'first_launch';

  /// Vérifie si c'est le premier lancement de l'application
  static Future<bool> isFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Si la clé n'existe pas, c'est le premier lancement
      final bool? hasLaunchedBefore = prefs.getBool(_keyFirstLaunch);
      return hasLaunchedBefore == null || !hasLaunchedBefore;
    } catch (e) {
      print('Erreur lors de la vérification du premier lancement: $e');
      return true; // Par défaut, on considère que c'est le premier lancement
    }
  }

  /// Marque le premier lancement comme terminé
  static Future<void> setFirstLaunchCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyFirstLaunch, true);
      print('✅ Premier lancement marqué comme terminé');
    } catch (e) {
      print('❌ Erreur lors de l\'enregistrement du premier lancement: $e');
    }
  }

  /// Réinitialise le statut du premier lancement (utile pour les tests)
  static Future<void> resetForTesting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFirstLaunch);
      print('🔄 Statut du premier lancement réinitialisé');
    } catch (e) {
      print('❌ Erreur lors de la réinitialisation: $e');
    }
  }

  /// Efface toutes les préférences (utile pour débogage)
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('🗑️ Toutes les préférences ont été effacées');
    } catch (e) {
      print('❌ Erreur lors de l\'effacement des préférences: $e');
    }
  }
}
// main.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:jeu_carre/firebase_options.dart';
import 'package:jeu_carre/screens/login_screen.dart';
import 'package:jeu_carre/screens/navigation_screen.dart';
import 'package:jeu_carre/screens/first_launch_rules_screen.dart';
import 'package:jeu_carre/screens/signup_screen.dart';
import 'package:jeu_carre/services/feedback_notification_service.dart';
import 'package:jeu_carre/services/match_request_notification.dart';
import 'package:jeu_carre/services/preferences_service.dart';
import 'package:jeu_carre/services/presence_service.dart';
import 'package:jeu_carre/services/game_start_service.dart'; // 🔥 AJOUTER

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shikaku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainWrapper(), // 🔥 REMPLACER AppInitializer par MainWrapper
      routes: {
        '/home': (context) => const NavigationScreen(),
        '/signup': (context) => const SignupScreen(),
        '/login': (context) => LoginScreen(),
        '/rules': (context) => const FirstLaunchRulesScreen(),
      },
      // Clé de navigation globale pour accéder au contexte partout
      navigatorKey: GlobalKey<NavigatorState>(),
    );
  }
}

// 🔥 AJOUTER CE CODE - MainWrapper qui remplace AppInitializer
class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> with WidgetsBindingObserver {
  final PresenceService _presenceService = PresenceService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MatchNotificationService _matchNotificationService = MatchNotificationService();
  final FeedbackNotificationService _feedbackNotificationService = FeedbackNotificationService(); 
  final GameStartService _gameStartService = GameStartService(); 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Mettre en ligne immédiatement si connecté
    _updatePresenceStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updatePresenceStatus(false);
    _matchNotificationService.dispose();
    _gameStartService.dispose();
    _feedbackNotificationService.dispose(); 
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _updatePresenceStatus(true);
        _matchNotificationService.restart();
        _gameStartService.restart();
        _feedbackNotificationService.restart(); 
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _updatePresenceStatus(false);
        _matchNotificationService.stop();
        _gameStartService.stop();
        _feedbackNotificationService.stop();
        break;
    }
  }

  Future<void> _updatePresenceStatus(bool isOnline) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      if (isOnline) {
        await _presenceService.setUserOnline();
      } else {
        await _presenceService.setUserOffline();
      }
    }
  }

  /// Détermine quel écran afficher en fonction du statut
  Future<Widget> _determineHomeScreen() async {
    // 1. Vérifier si c'est le premier lancement
    final bool isFirstLaunch = await PreferencesService.isFirstLaunch();
    
    if (isFirstLaunch) {
      // Premier lancement : afficher les règles
      return const FirstLaunchRulesScreen();
    }
    
    // 2. Vérifier si l'utilisateur est connecté
    final User? currentUser = _auth.currentUser;
    
    if (currentUser == null) {
      // Pas connecté : rediriger vers l'inscription
      return const SignupScreen();
    }
    
    // 3. Utilisateur connecté : initialiser TOUS les services
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _matchNotificationService.initialize(context);
       _gameStartService.initialize(context);
       _feedbackNotificationService.initialize(context); 
      }
    });
    
    return const NavigationScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _determineHomeScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Écran à afficher (avec tous les services initialisés)
        return snapshot.data ?? const SignupScreen();
      },
    );
  }
}
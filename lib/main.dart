// main.dart (version mise à jour)
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:jeu_carre/firebase_options.dart';
import 'package:jeu_carre/screens/navigation_screen.dart';
import 'package:jeu_carre/screens/first_launch_rules_screen.dart';
import 'package:jeu_carre/screens/signup_screen.dart';
import 'package:jeu_carre/services/preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shikaku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AppInitializer(),
      routes: {
        '/home': (context) => const NavigationScreen(),
        '/signup': (context) => const SignupScreen(),
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late Future<bool> _isFirstLaunch;

  @override
  void initState() {
    super.initState();
    _isFirstLaunch = PreferencesService.isFirstLaunch();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isFirstLaunch,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        final isFirstLaunch = snapshot.data ?? true;
        
        if (isFirstLaunch) {
          return const FirstLaunchRulesScreen();
        } else {
          return const NavigationScreen();
        }
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0015),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF00d4ff),
                    Color(0xFF0099cc),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00d4ff).withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.games,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'SHIKAKU',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00d4ff)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
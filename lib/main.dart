import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:jeu_carre/firebase_options.dart';
import 'package:jeu_carre/screens/navigation_screen.dart';

void main() async{
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
     home: const NavigationScreen(),
    );
  }
}
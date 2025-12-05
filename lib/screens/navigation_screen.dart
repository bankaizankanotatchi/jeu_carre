import 'package:flutter/material.dart';
import 'package:jeu_carre/screens/home_screen/home_screen.dart';
import 'package:jeu_carre/screens/match_screen/match_screen.dart';
import 'package:jeu_carre/screens/feedback_screen/feedback_screen.dart';
import 'package:jeu_carre/screens/profile_screen/profile_screen.dart';
//import 'package:jeu_carre/screens/stats_migration_screen.dart'; // Nouvelle page

class NavigationScreen extends StatefulWidget {
  final int initialIndex;

  const NavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  final List<Widget> _pages = [
    HomeScreen(),
    const MatchScreen(),
    const FeedbackScreen(),
    const ProfileScreen(),
    //const StatsMigrationScreen(), // Nouvelle page à l'index 4
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a0033),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF2d0052),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_esports),
            label: 'Matchs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feedback),
            label: 'Feedback',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
          // BottomNavigationBarItem( // Nouvel item
          //   icon: Icon(Icons.settings_backup_restore),
          //   label: 'Admin',
          // ),
        ],
      ),
    );
  }
}
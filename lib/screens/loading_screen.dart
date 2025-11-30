// screens/loading_screen.dart
import 'package:flutter/material.dart';

class GameLoadingScreen extends StatelessWidget {
  final String opponentName;
  final int gridSize;

  const GameLoadingScreen({
    super.key,
    required this.opponentName,
    required this.gridSize,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0a0015),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a0033), Color(0xFF2d0052), Color(0xFF0a0015)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animation de chargement
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF00d4ff).withOpacity(0.8),
                      Color(0xFF0099cc).withOpacity(0.3),
                    ],
                  ),
                  border: Border.all(color: Color(0xFF00d4ff), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF00d4ff).withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animation rotative
                    TweenAnimationBuilder(
                      duration: Duration(seconds: 2),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      builder: (context, double value, child) {
                        return Transform.rotate(
                          angle: value * 2 * 3.14159,
                          child: child,
                        );
                      },
                      child: Icon(
                        Icons.grid_on,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                    
                  ],
                ),
              ),
              
              SizedBox(height: 40),
              
              // Texte de chargement
              Column(
                children: [
                  Text(
                    'CRÉATION DE LA PARTIE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  Text(
                    'Grille ${gridSize}×$gridSize',
                    style: TextStyle(
                      color: Color(0xFF00d4ff),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  
                  SizedBox(height: 8),
                  
                  Text(
                    'vs $opponentName',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Barre de progression animée
                  Container(
                    width: 200,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Color(0xFF2d0052),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Stack(
                      children: [
                        // Animation de progression
                        TweenAnimationBuilder(
                          duration: Duration(seconds: 3),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, double value, child) {
                            return Container(
                              width: 200 * value,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF00d4ff),
                                    Color(0xFFe040fb),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Message d'attente
                  Text(
                    'Préparation du terrain de jeu...',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
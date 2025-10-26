// models/ai_player.dart
import 'dart:math';

import 'package:jeu_carre/models/game_model.dart';
import 'package:jeu_carre/utils/game_logic.dart';

class AIPlayer {
  static Future<GridPoint?> getBestMove(
    List<GridPoint> points,
    int gridSize,
    String aiPlayerId,
  ) async {
    // Simulation d'un temps de réflexion
    await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(1000)));
    
    // Trouver tous les points disponibles
    final availablePoints = _getAvailablePoints(points, gridSize);
    
    if (availablePoints.isEmpty) return null;
    
    // Stratégie simple : prioriser les points qui peuvent former des carrés
    for (final point in availablePoints) {
      // Vérifier si ce point peut former un carré
      final potentialSquares = _checkPotentialSquares(
        points, 
        gridSize, 
        aiPlayerId, 
        point.x, 
        point.y
      );
      
      if (potentialSquares.isNotEmpty) {
        return GridPoint(x: point.x, y: point.y, playerId: aiPlayerId);
      }
    }
    
    // Sinon, choisir un point au hasard
    final randomPoint = availablePoints[Random().nextInt(availablePoints.length)];
    return GridPoint(
      x: randomPoint.x, 
      y: randomPoint.y, 
      playerId: aiPlayerId
    );
  }
  
  static List<GridPoint> _getAvailablePoints(List<GridPoint> points, int gridSize) {
    final List<GridPoint> available = [];
    
    for (int x = 0; x <= gridSize; x++) {
      for (int y = 0; y <= gridSize; y++) {
        if (!points.any((p) => p.x == x && p.y == y)) {
          available.add(GridPoint(x: x, y: y));
        }
      }
    }
    
    return available;
  }
  
  static List<Square> _checkPotentialSquares(
    List<GridPoint> points,
    int gridSize,
    String playerId,
    int testX,
    int testY,
  ) {
    // Logique simplifiée pour vérifier les carrés potentiels
    // Vous pouvez implémenter une logique plus sophistiquée ici
    final testPoints = List<GridPoint>.from(points)
      ..add(GridPoint(x: testX, y: testY, playerId: playerId));
    
    return GameLogic.checkSquares(
      testPoints,
      gridSize,
      playerId,
      testX,
      testY,
    );
  }
}
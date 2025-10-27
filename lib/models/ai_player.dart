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
    // Temps de réflexion aléatoire entre 1 et 10 secondes
    // pour simuler une IA qui peut parfois être lente
    final thinkingTime = 1000 + Random().nextInt(9000);
    await Future.delayed(Duration(milliseconds: thinkingTime));
    
    final availablePoints = _getAvailablePoints(points, gridSize);
    if (availablePoints.isEmpty) return null;
    
    // Stratégie prioritaire : chercher les carrés
    for (final point in availablePoints) {
      final potentialSquares = _checkPotentialSquares(
        points, gridSize, aiPlayerId, point.x, point.y
      );
      if (potentialSquares.isNotEmpty) {
        return GridPoint(x: point.x, y: point.y, playerId: aiPlayerId);
      }
    }
    
    // Stratégie secondaire : bloquer l'adversaire
    final humanPlayerId = aiPlayerId == 'bleu' ? 'rouge' : 'bleu';
    for (final point in availablePoints) {
      final potentialSquares = _checkPotentialSquares(
        points, gridSize, humanPlayerId, point.x, point.y
      );
      if (potentialSquares.isNotEmpty) {
        return GridPoint(x: point.x, y: point.y, playerId: aiPlayerId);
      }
    }
    
    // Sinon : point stratégique au centre ou aléatoire
    return _getStrategicMove(availablePoints, gridSize, aiPlayerId);
  }
  
  static GridPoint _getStrategicMove(
    List<GridPoint> availablePoints, 
    int gridSize, 
    String aiPlayerId
  ) {
    // Prioriser le centre de la grille
    final center = gridSize / 2;
    availablePoints.sort((a, b) {
      final distA = (a.x - center).abs() + (a.y - center).abs();
      final distB = (b.x - center).abs() + (b.y - center).abs();
      return distA.compareTo(distB);
    });
    
    // Prendre un des 3 meilleurs points stratégiques
    final bestPoints = availablePoints.take(3).toList();
    return GridPoint(
      x: bestPoints[Random().nextInt(bestPoints.length)].x,
      y: bestPoints[Random().nextInt(bestPoints.length)].y,
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
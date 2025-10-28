// models/ai_player.dart
import 'dart:math';
import 'package:jeu_carre/models/game_model.dart';
import 'package:jeu_carre/utils/game_logic.dart';

/// Niveaux de difficulté de l'IA
enum AIDifficulty {
  beginner,      // Débutant : joue souvent aléatoirement
  intermediate,  // Intermédiaire : stratégies basiques
  expert,        // Expert : toutes les stratégies avancées
}

class AIPlayer {
  /// Point d'entrée principal - choisit la stratégie selon la difficulté
  static Future<GridPoint?> getBestMove(
    List<GridPoint> points,
    int gridSize,
    String aiPlayerId,
    {AIDifficulty difficulty = AIDifficulty.intermediate}
  ) async {
    // Temps de réflexion variable selon la difficulté
    int thinkingTime;
    switch (difficulty) {
      case AIDifficulty.beginner:
        thinkingTime = 1500 + Random().nextInt(2500); // 1.5-4 secondes (hésite)
        break;
      case AIDifficulty.intermediate:
        thinkingTime = 800 + Random().nextInt(1700); // 0.8-2.5 secondes
        break;
      case AIDifficulty.expert:
        thinkingTime = 300 + Random().nextInt(700); // 0.3-1 seconde (rapide)
        break;
    }
    
    await Future.delayed(Duration(milliseconds: thinkingTime));

    final availablePoints = _getAvailablePoints(points, gridSize);
    if (availablePoints.isEmpty) return null;

    // ========== DÉBUTANT : Joue souvent au hasard ==========
    if (difficulty == AIDifficulty.beginner) {
      return _getBeginnerMove(points, gridSize, aiPlayerId, availablePoints);
    }

    // ========== INTERMÉDIAIRE : Stratégies basiques ==========
    if (difficulty == AIDifficulty.intermediate) {
      return _getIntermediateMove(points, gridSize, aiPlayerId, availablePoints);
    }

    // ========== EXPERT : Stratégies avancées ==========
    return _getExpertMove(points, gridSize, aiPlayerId, availablePoints);
  }

  // ============================================================
  // NIVEAU DÉBUTANT - Facile à battre
  // ============================================================
  static GridPoint _getBeginnerMove(
    List<GridPoint> points,
    int gridSize,
    String aiPlayerId,
    List<GridPoint> availablePoints,
  ) {
    // 70% de chance de jouer complètement au hasard
    if (Random().nextDouble() < 0.7) {
      final randomPoint = availablePoints[Random().nextInt(availablePoints.length)];
      return GridPoint(x: randomPoint.x, y: randomPoint.y, playerId: aiPlayerId);
    }

    // 30% de chance de faire un coup "intelligent"
    // Vérifie seulement s'il peut compléter un carré
    for (final point in availablePoints) {
      final potentialSquares = _checkPotentialSquares(
        points, gridSize, aiPlayerId, point.x, point.y
      );
      
      if (potentialSquares.isNotEmpty) {
        return GridPoint(x: point.x, y: point.y, playerId: aiPlayerId);
      }
    }

    // Sinon joue au hasard
    final randomPoint = availablePoints[Random().nextInt(availablePoints.length)];
    return GridPoint(x: randomPoint.x, y: randomPoint.y, playerId: aiPlayerId);
  }

  // ============================================================
  // NIVEAU INTERMÉDIAIRE - Défi équilibré
  // ============================================================
  static GridPoint _getIntermediateMove(
    List<GridPoint> points,
    int gridSize,
    String aiPlayerId,
    List<GridPoint> availablePoints,
  ) {
    final humanPlayerId = aiPlayerId == 'bleu' ? 'rouge' : 'bleu';

    // STRATÉGIE 1 : Compléter un carré si possible
    for (final point in availablePoints) {
      final potentialSquares = _checkPotentialSquares(
        points, gridSize, aiPlayerId, point.x, point.y
      );
      
      if (potentialSquares.isNotEmpty) {
        return GridPoint(x: point.x, y: point.y, playerId: aiPlayerId);
      }
    }

    // STRATÉGIE 2 : Bloquer l'adversaire
    for (final point in availablePoints) {
      final potentialSquares = _checkPotentialSquares(
        points, gridSize, humanPlayerId, point.x, point.y
      );
      
      if (potentialSquares.isNotEmpty) {
        return GridPoint(x: point.x, y: point.y, playerId: aiPlayerId);
      }
    }

    // STRATÉGIE 3 : Jouer près du centre
    availablePoints.sort((a, b) {
      final center = gridSize / 2;
      final distA = (a.x - center).abs() + (a.y - center).abs();
      final distB = (b.x - center).abs() + (b.y - center).abs();
      return distA.compareTo(distB);
    });

    // Prendre un des 5 meilleurs points centraux
    final topPoints = availablePoints.take(5).toList();
    final selectedPoint = topPoints[Random().nextInt(topPoints.length)];
    
    return GridPoint(x: selectedPoint.x, y: selectedPoint.y, playerId: aiPlayerId);
  }

  // ============================================================
  // NIVEAU EXPERT - Très difficile à battre
  // ============================================================
  static GridPoint _getExpertMove(
    List<GridPoint> points,
    int gridSize,
    String aiPlayerId,
    List<GridPoint> availablePoints,
  ) {
    final humanPlayerId = aiPlayerId == 'bleu' ? 'rouge' : 'bleu';

    // STRATÉGIE 1 : Compléter un carré (priorité absolue)
    for (final point in availablePoints) {
      final potentialSquares = _checkPotentialSquares(
        points, gridSize, aiPlayerId, point.x, point.y
      );
      
      if (potentialSquares.isNotEmpty) {
        return GridPoint(x: point.x, y: point.y, playerId: aiPlayerId);
      }
    }

    // STRATÉGIE 2 : Bloquer l'adversaire
    for (final point in availablePoints) {
      final potentialSquares = _checkPotentialSquares(
        points, gridSize, humanPlayerId, point.x, point.y
      );
      
      if (potentialSquares.isNotEmpty) {
        return GridPoint(x: point.x, y: point.y, playerId: aiPlayerId);
      }
    }

    // STRATÉGIE 3 : Analyse avancée avec scoring
    final scoredMoves = <GridPoint, int>{};
    
    for (final point in availablePoints) {
      int score = 0;
      
      // Points pour la proximité avec d'autres points de l'IA
      score += _countAdjacentAIPoints(points, point.x, point.y, aiPlayerId) * 15;
      
      // Points pour être au centre (contrôle du jeu)
      score += _getCentralityScore(point.x, point.y, gridSize);
      
      // Points pour créer des opportunités futures
      score += _countPotentialFutureSquares(points, gridSize, aiPlayerId, point.x, point.y) * 8;
      
      // Pénalité si le coup donne une opportunité à l'adversaire
      score -= _givesOpportunityToOpponent(points, gridSize, humanPlayerId, point.x, point.y) * 12;
      
      // Bonus pour les coins (positions stratégiques)
      if (_isCornerOrEdge(point.x, point.y, gridSize)) {
        score += 5;
      }
      
      scoredMoves[point] = score;
    }

    // Trier par score décroissant
    final sortedMoves = scoredMoves.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Prendre un des 3 meilleurs coups (variété)
    final topMoves = sortedMoves.take(3).toList();
    final selectedMove = topMoves[Random().nextInt(topMoves.length)].key;

    return GridPoint(
      x: selectedMove.x,
      y: selectedMove.y,
      playerId: aiPlayerId
    );
  }

  // ============================================================
  // FONCTIONS D'ÉVALUATION (pour Expert)
  // ============================================================

  static int _countAdjacentAIPoints(List<GridPoint> points, int x, int y, String aiPlayerId) {
    int count = 0;
    final directions = [
      [0, 1], [1, 0], [0, -1], [-1, 0],
      [1, 1], [1, -1], [-1, 1], [-1, -1]
    ];

    for (final dir in directions) {
      final nx = x + dir[0];
      final ny = y + dir[1];
      
      if (points.any((p) => p.x == nx && p.y == ny && p.playerId == aiPlayerId)) {
        count++;
      }
    }

    return count;
  }

  static int _getCentralityScore(int x, int y, int gridSize) {
    final center = gridSize / 2;
    final distance = (x - center).abs() + (y - center).abs();
    return ((gridSize - distance) * 3).toInt();
  }

  static int _countPotentialFutureSquares(
    List<GridPoint> points,
    int gridSize,
    String aiPlayerId,
    int x,
    int y,
  ) {
    int futureOpportunities = 0;
    
    final testPoints = List<GridPoint>.from(points)
      ..add(GridPoint(x: x, y: y, playerId: aiPlayerId));

    final directions = [[0, 1], [1, 0], [0, -1], [-1, 0]];
    
    for (final dir in directions) {
      final nx = x + dir[0];
      final ny = y + dir[1];
      
      if (nx >= 0 && nx <= gridSize && ny >= 0 && ny <= gridSize) {
        if (!testPoints.any((p) => p.x == nx && p.y == ny)) {
          final futureSquares = _checkPotentialSquares(
            testPoints, gridSize, aiPlayerId, nx, ny
          );
          futureOpportunities += futureSquares.length;
        }
      }
    }

    return futureOpportunities;
  }

  static int _givesOpportunityToOpponent(
    List<GridPoint> points,
    int gridSize,
    String opponentId,
    int x,
    int y,
  ) {
    final testPoints = List<GridPoint>.from(points)
      ..add(GridPoint(x: x, y: y, playerId: opponentId));

    int opponentOpportunities = 0;
    final availableAfter = _getAvailablePoints(testPoints, gridSize);
    
    for (final point in availableAfter.take(10)) { // Limite pour performance
      final potentialSquares = _checkPotentialSquares(
        testPoints, gridSize, opponentId, point.x, point.y
      );
      opponentOpportunities += potentialSquares.length;
    }

    return opponentOpportunities;
  }

  static bool _isCornerOrEdge(int x, int y, int gridSize) {
    return x == 0 || x == gridSize || y == 0 || y == gridSize;
  }

  // ============================================================
  // FONCTIONS UTILITAIRES
  // ============================================================

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
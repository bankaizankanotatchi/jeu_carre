// models/ai_player.dart
import 'dart:math';
import 'package:jeu_carre/models/game_model.dart';
import 'package:jeu_carre/utils/game_logic.dart';

/// Niveaux de difficulté de l'IA
enum AIDifficulty {
  beginner,      // Débutant : stratégies réfléchies mais basiques
  intermediate,  // Intermédiaire : tactiques avancées
  expert,        // Expert : maître du jeu
}

class AIPlayer {
  /// Point d'entrée principal - choisit la stratégie selon la difficulté
  static Future<GridPoint?> getBestMove(
    List<GridPoint> points,
    int gridSize,
    String aiPlayerId,
    {AIDifficulty difficulty = AIDifficulty.intermediate}
  ) async {
    // VALIDATION DES PARAMÈTRES
    if (points.isEmpty || gridSize <= 0) {
      return _getRandomMove(points, gridSize, aiPlayerId);
    }

    // Temps de réflexion réaliste
    int thinkingTime;
    switch (difficulty) {
      case AIDifficulty.beginner:
        thinkingTime = 1000 + Random().nextInt(2000); // 1-3 secondes
        break;
      case AIDifficulty.intermediate:
        thinkingTime = 500 + Random().nextInt(1500); // 0.5-2 secondes
        break;
      case AIDifficulty.expert:
        thinkingTime = 200 + Random().nextInt(800); // 0.2-1 seconde
        break;
    }
    
    await Future.delayed(Duration(milliseconds: thinkingTime));

    final availablePoints = _getAvailablePoints(points, gridSize);
    if (availablePoints.isEmpty) return null;

    try {
      switch (difficulty) {
        case AIDifficulty.beginner:
          return _getBeginnerMove(points, gridSize, aiPlayerId, availablePoints);
        case AIDifficulty.intermediate:
          return _getIntermediateMove(points, gridSize, aiPlayerId, availablePoints);
        case AIDifficulty.expert:
          return _getIntermediateMove(points, gridSize, aiPlayerId, availablePoints);
      }
    } catch (e) {
      // Fallback en cas d'erreur
      return _getRandomMove(points, gridSize, aiPlayerId);
    }
  }

  // ============================================================
  // NIVEAU DÉBUTANT RENFORCÉ - Tous les coups sont réfléchis
  // ============================================================
  static GridPoint _getBeginnerMove(
    List<GridPoint> points,
    int gridSize,
    String aiPlayerId,
    List<GridPoint> availablePoints,
  ) {
    final humanPlayerId = aiPlayerId == 'bleu' ? 'rouge' : 'bleu';

    // STRATÉGIE 1 : Compléter ses propres carrés (priorité)
    for (final point in availablePoints) {
      final potentialSquares = _checkPotentialSquares(
        points, gridSize, aiPlayerId, point.x, point.y
      );
      if (potentialSquares.isNotEmpty) {
        return GridPoint(x: point.x, y: point.y, playerId: aiPlayerId);
      }
    }

    // STRATÉGIE 2 : Bloquer les carrés adverses immédiats
    for (final point in availablePoints) {
      final potentialSquares = _checkPotentialSquares(
        points, gridSize, humanPlayerId, point.x, point.y
      );
      if (potentialSquares.isNotEmpty) {
        return GridPoint(x: point.x, y: point.y, playerId: aiPlayerId);
      }
    }

    // STRATÉGIE 3 : Créer des opportunités futures pour soi-même
    final opportunityMoves = <GridPoint, int>{};
    for (final point in availablePoints) {
      int opportunities = _countFutureOpportunities(points, gridSize, aiPlayerId, point.x, point.y);
      opportunityMoves[point] = opportunities;
    }

    if (opportunityMoves.isNotEmpty) {
      final bestOpportunity = _getBestScoredMove(opportunityMoves);
      if (bestOpportunity != null && (opportunityMoves[bestOpportunity] ?? 0) >= 2) {
        return GridPoint(x: bestOpportunity.x, y: bestOpportunity.y, playerId: aiPlayerId);
      }
    }

    // STRATÉGIE 4 : Éviter de donner des opportunités à l'adversaire
    final safeMoves = availablePoints.where((point) {
      return !_givesImmediateOpportunity(points, gridSize, humanPlayerId, point.x, point.y);
    }).toList();

    if (safeMoves.isNotEmpty) {
      // Préférer les positions centrales pour le contrôle
      safeMoves.sort((a, b) {
        final center = gridSize / 2;
        final distA = (a.x - center).abs() + (a.y - center).abs();
        final distB = (b.x - center).abs() + (b.y - center).abs();
        return distA.compareTo(distB);
      });
      return GridPoint(x: safeMoves.first.x, y: safeMoves.first.y, playerId: aiPlayerId);
    }

    // STRATÉGIE 5 : Fallback intelligent - regrouper ses points
    return _getGroupingMove(points, gridSize, aiPlayerId, availablePoints);
  }

  // ============================================================
  // NIVEAU INTERMÉDIAIRE RENFORCÉ - Tactiques avancées
  // ============================================================
  static GridPoint _getIntermediateMove(
    List<GridPoint> points,
    int gridSize,
    String aiPlayerId,
    List<GridPoint> availablePoints,
  ) {
    final humanPlayerId = aiPlayerId == 'bleu' ? 'rouge' : 'bleu';

    // STRATÉGIE 1 : Compléter ses carrés (priorité absolue)
    for (final point in availablePoints) {
      final potentialSquares = _checkPotentialSquares(
        points, gridSize, aiPlayerId, point.x, point.y
      );
      if (potentialSquares.isNotEmpty) {
        return GridPoint(x: point.x, y: point.y, playerId: aiPlayerId);
      }
    }

    // STRATÉGIE 2 : Bloquer l'adversaire de manière proactive
    final blockingMoves = <GridPoint, int>{};
    for (final point in availablePoints) {
      final threatLevel = _evaluateThreatLevel(points, gridSize, humanPlayerId, point.x, point.y);
      blockingMoves[point] = threatLevel;
    }

    final bestBlock = _getBestScoredMove(blockingMoves);
    if (bestBlock != null && (blockingMoves[bestBlock] ?? 0) >= 2) {
      return GridPoint(x: bestBlock.x, y: bestBlock.y, playerId: aiPlayerId);
    }

    // STRATÉGIE 3 : Développement territorial stratégique
    final territoryMoves = <GridPoint, int>{};
    for (final point in availablePoints) {
      int score = 0;
      
      // Bonus pour le contrôle du centre
      score += _getCentralityScore(point.x, point.y, gridSize);
      
      // Bonus pour le regroupement stratégique
      score += _countStrategicGrouping(points, point.x, point.y, aiPlayerId) * 10;
      
      // Bonus pour les chaînes de points
      score += _evaluateChainPotential(points, gridSize, aiPlayerId, point.x, point.y) * 8;
      
      // Pénalité pour les coups isolés
      score -= _isIsolatedMove(points, point.x, point.y) ? 15 : 0;
      
      territoryMoves[point] = score;
    }

    final bestTerritory = _getBestScoredMove(territoryMoves);
    if (bestTerritory != null && (territoryMoves[bestTerritory] ?? 0) > 20) {
      return GridPoint(x: bestTerritory.x, y: bestTerritory.y, playerId: aiPlayerId);
    }

    // STRATÉGIE 4 : Créer des pièges et combos
    final trapMoves = availablePoints.where((point) {
      return _createsTrap(points, gridSize, aiPlayerId, point.x, point.y);
    }).toList();

    if (trapMoves.isNotEmpty) {
      return GridPoint(
        x: trapMoves[Random().nextInt(trapMoves.length)].x,
        y: trapMoves[Random().nextInt(trapMoves.length)].y,
        playerId: aiPlayerId
      );
    }

    // STRATÉGIE 5 : Fallback optimisé
    return _getOptimizedPositioning(points, gridSize, aiPlayerId, availablePoints);
  }


  // ============================================================
  // FONCTIONS D'ANALYSE AVANCÉES CORRIGÉES
  // ============================================================

  static int _countOneMoveAwaySquares(List<GridPoint> points, int gridSize, String playerId, int x, int y) {
    try {
      final testPoints = List<GridPoint>.from(points)
        ..add(GridPoint(x: x, y: y, playerId: playerId));
      
      int almostComplete = 0;
      
      // Vérifier tous les carrés adjacents à cette position
      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          final squareX = x + dx;
          final squareY = y + dy;
          
          if (_isValidSquare(squareX, squareY, gridSize)) {
            final corners = [
              [squareX, squareY],
              [squareX + 1, squareY],
              [squareX, squareY + 1],
              [squareX + 1, squareY + 1],
            ];
            
            int playerCorners = 0;
            int emptyCorners = 0;
            
            for (final corner in corners) {
              if (_hasPlayerPoint(testPoints, corner[0], corner[1], playerId)) {
                playerCorners++;
              } else if (!_hasAnyPoint(testPoints, corner[0], corner[1])) {
                emptyCorners++;
              }
            }
            
            if (playerCorners == 3 && emptyCorners == 1) {
              almostComplete++;
            }
          }
        }
      }
      
      return almostComplete;
    } catch (e) {
      return 0;
    }
  }

  // ============================================================
  // FONCTIONS UTILITAIRES RENFORCÉES
  // ============================================================

  static int _countFutureOpportunities(List<GridPoint> points, int gridSize, String playerId, int x, int y) {
    try {
      final testPoints = List<GridPoint>.from(points)
        ..add(GridPoint(x: x, y: y, playerId: playerId));
      
      int opportunities = 0;
      
      // Vérifier un rayon plus large pour les opportunités futures
      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          final checkX = x + dx;
          final checkY = y + dy;
          
          if (checkX >= 0 && checkX <= gridSize && checkY >= 0 && checkY <= gridSize) {
            if (!_hasAnyPoint(testPoints, checkX, checkY)) {
              final potential = _checkPotentialSquares(testPoints, gridSize, playerId, checkX, checkY);
              opportunities += potential.length;
            }
          }
        }
      }
      
      return opportunities;
    } catch (e) {
      return 0;
    }
  }

  static bool _givesImmediateOpportunity(List<GridPoint> points, int gridSize, String opponentId, int x, int y) {
    try {
      final testPoints = List<GridPoint>.from(points)
        ..add(GridPoint(x: x, y: y, playerId: opponentId));
      
      // Vérifie si ce coup donne des carrés immédiats à l'adversaire
      return _checkPotentialSquares(testPoints, gridSize, opponentId, x, y).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static int _evaluateThreatLevel(List<GridPoint> points, int gridSize, String opponentId, int x, int y) {
    try {
      final testPoints = List<GridPoint>.from(points)
        ..add(GridPoint(x: x, y: y, playerId: opponentId));
      
      int threatLevel = 0;
      
      // Menaces immédiates
      threatLevel += _checkPotentialSquares(testPoints, gridSize, opponentId, x, y).length * 10;
      
      // Menaces à 1 coup
      threatLevel += _countOneMoveAwaySquares(testPoints, gridSize, opponentId, x, y) * 5;
      
      return threatLevel;
    } catch (e) {
      return 0;
    }
  }

  static int _countStrategicGrouping(List<GridPoint> points, int x, int y, String playerId) {
    try {
      int groupScore = 0;
      
      final directions = [[0,1], [1,0], [0,-1], [-1,0], [1,1], [1,-1], [-1,1], [-1,-1]];
      
      for (final dir in directions) {
        if (_hasPlayerPoint(points, x + dir[0], y + dir[1], playerId)) {
          groupScore += 2;
        }
      }
      
      return groupScore;
    } catch (e) {
      return 0;
    }
  }

  static bool _createsTrap(List<GridPoint> points, int gridSize, String playerId, int x, int y) {
    try {
      final testPoints = List<GridPoint>.from(points)
        ..add(GridPoint(x: x, y: y, playerId: playerId));
      
      int multiThreats = 0;
      
      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          final checkX = x + dx;
          final checkY = y + dy;
          
          if (checkX >= 0 && checkX <= gridSize && checkY >= 0 && checkY <= gridSize) {
            if (!_hasAnyPoint(testPoints, checkX, checkY)) {
              final threats = _checkPotentialSquares(testPoints, gridSize, playerId, checkX, checkY);
              if (threats.length >= 2) {
                multiThreats++;
              }
            }
          }
        }
      }
      
      return multiThreats >= 1;
    } catch (e) {
      return false;
    }
  }

  static bool _isIsolatedMove(List<GridPoint> points, int x, int y) {
    try {
      final directions = [[0,1], [1,0], [0,-1], [-1,0]];
      
      for (final dir in directions) {
        if (_hasAnyPoint(points, x + dir[0], y + dir[1])) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  static GridPoint _getGroupingMove(List<GridPoint> points, int gridSize, String playerId, List<GridPoint> availablePoints) {
    try {
      // Trouve le meilleur coup pour se regrouper
      final groupedMoves = <GridPoint, int>{};
      
      for (final point in availablePoints) {
        int groupScore = _countStrategicGrouping(points, point.x, point.y, playerId);
        groupedMoves[point] = groupScore;
      }
      
      final bestGroup = _getBestScoredMove(groupedMoves);
      if (bestGroup != null) {
        return GridPoint(x: bestGroup.x, y: bestGroup.y, playerId: playerId);
      }
    } catch (e) {
      // Fallback en cas d'erreur
    }
    
    return _getRandomMoveFromList(availablePoints, playerId);
  }

  static GridPoint _getOptimizedPositioning(List<GridPoint> points, int gridSize, String playerId, List<GridPoint> availablePoints) {
    try {
      // Positionnement optimisé pour l'intermédiaire
      final positionedMoves = <GridPoint, int>{};
      
      for (final point in availablePoints) {
        int score = _getCentralityScore(point.x, point.y, gridSize);
        score += _countStrategicGrouping(points, point.x, point.y, playerId) * 8;
        score -= _isIsolatedMove(points, point.x, point.y) ? 20 : 0;
        
        positionedMoves[point] = score;
      }
      
      final bestPosition = _getBestScoredMove(positionedMoves);
      if (bestPosition != null) {
        return GridPoint(x: bestPosition.x, y: bestPosition.y, playerId: playerId);
      }
    } catch (e) {
      // Fallback en cas d'erreur
    }
    
    return _getRandomMoveFromList(availablePoints, playerId);
  }


  static GridPoint? _getBestScoredMove(Map<GridPoint, int> scoredMoves) {
    try {
      if (scoredMoves.isEmpty) return null;
      
      return scoredMoves.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // FONCTIONS UTILITAIRES DE BASE SÉCURISÉES
  // ============================================================

  static List<GridPoint> _getAvailablePoints(List<GridPoint> points, int gridSize) {
    try {
      final List<GridPoint> available = [];
      
      for (int x = 0; x <= gridSize; x++) {
        for (int y = 0; y <= gridSize; y++) {
          if (!points.any((p) => p.x == x && p.y == y)) {
            available.add(GridPoint(x: x, y: y));
          }
        }
      }
      
      return available;
    } catch (e) {
      return [];
    }
  }

  static List<Square> _checkPotentialSquares(
    List<GridPoint> points,
    int gridSize,
    String playerId,
    int testX,
    int testY,
  ) {
    try {
      final testPoints = List<GridPoint>.from(points)
        ..add(GridPoint(x: testX, y: testY, playerId: playerId));
        
      return GameLogic.checkSquares(
        testPoints,
        gridSize,
        playerId,
        testX,
        testY,
      );
    } catch (e) {
      return [];
    }
  }

  static bool _hasPlayerPoint(List<GridPoint> points, int x, int y, String playerId) {
    try {
      return points.any((p) => p.x == x && p.y == y && p.playerId == playerId);
    } catch (e) {
      return false;
    }
  }

  static bool _hasAnyPoint(List<GridPoint> points, int x, int y) {
    try {
      return points.any((p) => p.x == x && p.y == y);
    } catch (e) {
      return false;
    }
  }

  static bool _isValidSquare(int x, int y, int gridSize) {
    try {
      return x >= 0 && y >= 0 && (x + 1) <= gridSize && (y + 1) <= gridSize;
    } catch (e) {
      return false;
    }
  }

  static int _getCentralityScore(int x, int y, int gridSize) {
    try {
      final center = gridSize / 2;
      final distance = (x - center).abs() + (y - center).abs();
      return ((gridSize - distance) * 2).toInt();
    } catch (e) {
      return 0;
    }
  }

  // ============================================================
  // FONCTIONS DE CHAÎNES CORRIGÉES
  // ============================================================

  static int _evaluateChainPotential(
    List<GridPoint> points,
    int gridSize,
    String playerId,
    int x,
    int y,
  ) {
    try {
      int chainPotential = 0;
      
      // Vérifier les 4 directions principales pour former des chaînes
      final directions = [
        [[0,1], [0,2], [0,-1]], // Vertical
        [[1,0], [2,0], [-1,0]], // Horizontal
        [[1,1], [2,2], [-1,-1]], // Diagonale \
        [[1,-1], [2,-2], [-1,1]], // Diagonale /
      ];

      for (final direction in directions) {
        int chainLength = 1; // Le point actuel
        
        // Vérifier chaque direction pour les points connectés
        for (final dir in direction) {
          final checkX = x + dir[0];
          final checkY = y + dir[1];
          
          if (checkX >= 0 && checkX <= gridSize && checkY >= 0 && checkY <= gridSize) {
            if (_hasPlayerPoint(points, checkX, checkY, playerId)) {
              chainLength++;
            } else if (!_hasAnyPoint(points, checkX, checkY)) {
              // Point vide - potentiel de prolongement
              chainLength += 1; // Simplifié pour éviter les conversions
            }
          }
        }
        
        // Bonus pour les chaînes longues
        if (chainLength >= 3) {
          chainPotential += chainLength * 3;
        } else if (chainLength >= 2) {
          chainPotential += chainLength * 2;
        }
      }

      // Bonus spécial pour les formations en L (début de carré)
      if (_formsLShape(points, x, y, playerId, gridSize)) {
        chainPotential += 8;
      }

      // Bonus pour les intersections de chaînes
      chainPotential += _countChainIntersections(points, x, y, playerId, gridSize) * 4;

      return chainPotential;
    } catch (e) {
      return 0;
    }
  }

  static bool _formsLShape(
    List<GridPoint> points,
    int x,
    int y,
    String playerId,
    int gridSize,
  ) {
    try {
      // Vérifie si ce point forme un L avec d'autres points (début de carré)
      final lPatterns = [
        // Pattern: point actuel + 2 autres points formant un L
        [[0,1], [1,0]], // L en bas-droite
        [[0,1], [-1,0]], // L en bas-gauche
        [[0,-1], [1,0]], // L en haut-droite
        [[0,-1], [-1,0]], // L en haut-gauche
      ];

      for (final pattern in lPatterns) {
        bool hasPattern = true;
        
        for (final offset in pattern) {
          final checkX = x + offset[0];
          final checkY = y + offset[1];
          
          if (!_hasPlayerPoint(points, checkX, checkY, playerId)) {
            hasPattern = false;
            break;
          }
        }
        
        if (hasPattern) {
          // Vérifier que le 4ème coin est vide (potentiel de carré)
          final fourthX = x + pattern[0][0] + pattern[1][0];
          final fourthY = y + pattern[0][1] + pattern[1][1];
          
          if (fourthX >= 0 && fourthX <= gridSize && fourthY >= 0 && fourthY <= gridSize) {
            if (!_hasAnyPoint(points, fourthX, fourthY)) {
              return true;
            }
          }
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static int _countChainIntersections(
    List<GridPoint> points,
    int x,
    int y,
    String playerId,
    int gridSize,
  ) {
    try {
      // Compte combien de chaînes différentes se croisent en ce point
      int intersections = 0;
      
      final horizontalFriends = _countDirectionalFriends(points, x, y, playerId, gridSize, 1, 0) +
                              _countDirectionalFriends(points, x, y, playerId, gridSize, -1, 0);
      
      final verticalFriends = _countDirectionalFriends(points, x, y, playerId, gridSize, 0, 1) +
                             _countDirectionalFriends(points, x, y, playerId, gridSize, 0, -1);
      
      final diag1Friends = _countDirectionalFriends(points, x, y, playerId, gridSize, 1, 1) +
                          _countDirectionalFriends(points, x, y, playerId, gridSize, -1, -1);
      
      final diag2Friends = _countDirectionalFriends(points, x, y, playerId, gridSize, 1, -1) +
                          _countDirectionalFriends(points, x, y, playerId, gridSize, -1, 1);

      // Une intersection signifie au moins 2 directions avec des amis
      int activeDirections = 0;
      if (horizontalFriends > 0) activeDirections++;
      if (verticalFriends > 0) activeDirections++;
      if (diag1Friends > 0) activeDirections++;
      if (diag2Friends > 0) activeDirections++;

      if (activeDirections >= 2) {
        intersections = activeDirections;
      }

      return intersections;
    } catch (e) {
      return 0;
    }
  }

  static int _countDirectionalFriends(
    List<GridPoint> points,
    int x,
    int y,
    String playerId,
    int gridSize,
    int dx,
    int dy,
  ) {
    try {
      int count = 0;
      int currentX = x + dx;
      int currentY = y + dy;
      
      while (currentX >= 0 && currentX <= gridSize && currentY >= 0 && currentY <= gridSize) {
        if (_hasPlayerPoint(points, currentX, currentY, playerId)) {
          count++;
        } else {
          break; // Arrête à la première interruption
        }
        currentX += dx;
        currentY += dy;
      }
      
      return count;
    } catch (e) {
      return 0;
    }
  }

  // ============================================================
  // FONCTIONS DE FALLBACK SÉCURISÉES
  // ============================================================

  static GridPoint _getRandomMoveFromList(List<GridPoint> availablePoints, String playerId) {
    if (availablePoints.isEmpty) {
      throw StateError('Aucun coup disponible pour l\'IA');
    }
    final randomPoint = availablePoints[Random().nextInt(availablePoints.length)];
    return GridPoint(x: randomPoint.x, y: randomPoint.y, playerId: playerId);
  }

  static GridPoint _getRandomMove(List<GridPoint> points, int gridSize, String playerId) {
    final availablePoints = _getAvailablePoints(points, gridSize);
    if (availablePoints.isEmpty) {
      throw StateError('Aucun coup disponible pour l\'IA');
    }
    return _getRandomMoveFromList(availablePoints, playerId);
  }
}
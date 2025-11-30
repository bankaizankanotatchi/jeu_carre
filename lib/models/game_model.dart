class Game {
  final String id;
  final List<String> players;
  final String currentPlayer;
  final Map<String, int> scores;
  final int gridSize;
  final List<GridPoint> points;
  final List<Square> squares;
  final GameStatus status;
  // NOUVELLES PROPRIÉTÉS POUR LE JEU EN TEMPS RÉEL
  final String? player1Id;      // ID du joueur 1
  final String? player2Id;      // ID du joueur 2
  final bool isAgainstAI;       // Contre l'IA
  final String? aiDifficulty;   // Difficulté IA
  final int gameDuration;       // Durée totale en secondes
  final int reflexionTime;      // Temps de réflexion par tour
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final List<String> spectators; // IDs des spectateurs
  final Map<String, dynamic> gameSettings; // Paramètres de partie
  final int timeRemaining;      // Temps restant global
  final Map<String, int> reflexionTimeRemaining; // Temps par joueur
  final List<Map<String, dynamic>> moveHistory; // Historique des coups
  final String? winnerId;       // ID du gagnant
  final String? endReason; // CHANGEMENT: Utiliser String au lieu de GameEndReason
  final Map<String, int> consecutiveMissedTurns; // Tours manqués consécutifs

  Game({
    required this.id,
    required this.players,
    required this.currentPlayer,
    required this.scores,
    required this.gridSize,
    required this.points,
    required this.squares,
    required this.status,
    // Nouvelles propriétés
    this.player1Id,
    this.player2Id,
    this.isAgainstAI = false,
    this.aiDifficulty,
    this.gameDuration = 180,
    this.reflexionTime = 15,
    required this.createdAt,
    required this.updatedAt,
    this.startedAt,
    this.finishedAt,
    List<String>? spectators,
    Map<String, dynamic>? gameSettings,
    this.timeRemaining = 180,
    Map<String, int>? reflexionTimeRemaining,
    List<Map<String, dynamic>>? moveHistory,
    this.winnerId,
    this.endReason, // CHANGEMENT: String au lieu de GameEndReason
    Map<String, int>? consecutiveMissedTurns,
  }) : spectators = spectators ?? [],
       gameSettings = gameSettings ?? {
         'allowSpectators': true,
         'isRanked': false,
         'maxSpectators': 50,
       },
       reflexionTimeRemaining = reflexionTimeRemaining ?? {},
       moveHistory = moveHistory ?? [],
       consecutiveMissedTurns = consecutiveMissedTurns ?? {};

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'players': players,
      'currentPlayer': currentPlayer,
      'scores': scores,
      'gridSize': gridSize,
      'points': points.map((p) => p.toMap()).toList(),
      'squares': squares.map((s) => s.toMap()).toList(),
      'status': status.toString(),
      // Nouvelles propriétés
      'player1Id': player1Id,
      'player2Id': player2Id,
      'isAgainstAI': isAgainstAI,
      'aiDifficulty': aiDifficulty,
      'gameDuration': gameDuration,
      'reflexionTime': reflexionTime,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'startedAt': startedAt?.millisecondsSinceEpoch,
      'finishedAt': finishedAt?.millisecondsSinceEpoch,
      'spectators': spectators,
      'gameSettings': gameSettings,
      'timeRemaining': timeRemaining,
      'reflexionTimeRemaining': reflexionTimeRemaining,
      'moveHistory': moveHistory,
      'winnerId': winnerId,
      'endReason': endReason, // CHANGEMENT: Stocker directement le String
      'consecutiveMissedTurns': consecutiveMissedTurns,
    };
  }

  static Game fromMap(Map<String, dynamic> map) {
    return Game(
      id: map['id'],
      players: List<String>.from(map['players']),
      currentPlayer: map['currentPlayer'],
      scores: Map<String, int>.from(map['scores']),
      gridSize: map['gridSize'],
      points: List<GridPoint>.from((map['points'] as List).map((p) => GridPoint.fromMap(p))),
      squares: List<Square>.from((map['squares'] as List).map((s) => Square.fromMap(s))),
      status: _parseGameStatus(map['status']),
      // Nouvelles propriétés
      player1Id: map['player1Id'],
      player2Id: map['player2Id'],
      isAgainstAI: map['isAgainstAI'] ?? false,
      aiDifficulty: map['aiDifficulty'],
      gameDuration: map['gameDuration'] ?? 180,
      reflexionTime: map['reflexionTime'] ?? 15,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      startedAt: map['startedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['startedAt'])
          : null,
      finishedAt: map['finishedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['finishedAt'])
          : null,
      spectators: List<String>.from(map['spectators'] ?? []),
      gameSettings: Map<String, dynamic>.from(map['gameSettings'] ?? {}),
      timeRemaining: map['timeRemaining'] ?? 180,
      reflexionTimeRemaining: Map<String, int>.from(map['reflexionTimeRemaining'] ?? {}),
      moveHistory: List<Map<String, dynamic>>.from(map['moveHistory'] ?? []),
      winnerId: map['winnerId'],
      endReason: map['endReason'], // CHANGEMENT: Lire directement le String
      consecutiveMissedTurns: Map<String, int>.from(map['consecutiveMissedTurns'] ?? {}),
    );
  }

  // Méthode helper pour parser GameStatus de manière sécurisée
  static GameStatus _parseGameStatus(dynamic value) {
    if (value == null) return GameStatus.waiting;
    
    try {
      final stringValue = value.toString();
      return GameStatus.values.firstWhere(
        (e) => e.toString() == stringValue,
        orElse: () => GameStatus.waiting,
      );
    } catch (e) {
      return GameStatus.waiting;
    }
  }

  // Méthodes utilitaires existantes...
  Game copyWithConsecutiveMissedTurns(String playerId, int value) {
    final newConsecutiveMissedTurns = Map<String, int>.from(consecutiveMissedTurns);
    newConsecutiveMissedTurns[playerId] = value;
    
    return Game(
      id: id,
      players: players,
      currentPlayer: currentPlayer,
      scores: scores,
      gridSize: gridSize,
      points: points,
      squares: squares,
      status: status,
      player1Id: player1Id,
      player2Id: player2Id,
      isAgainstAI: isAgainstAI,
      aiDifficulty: aiDifficulty,
      gameDuration: gameDuration,
      reflexionTime: reflexionTime,
      createdAt: createdAt,
      updatedAt: updatedAt,
      startedAt: startedAt,
      finishedAt: finishedAt,
      spectators: spectators,
      gameSettings: gameSettings,
      timeRemaining: timeRemaining,
      reflexionTimeRemaining: reflexionTimeRemaining,
      moveHistory: moveHistory,
      winnerId: winnerId,
      endReason: endReason,
      consecutiveMissedTurns: newConsecutiveMissedTurns,
    );
  }

  Game copyWithResetMissedTurns(String playerId) {
    return copyWithConsecutiveMissedTurns(playerId, 0);
  }

  bool hasPlayerMissedThreeTurns(String playerId) {
    return (consecutiveMissedTurns[playerId] ?? 0) >= 3;
  }
}

class GridPoint {
  final int x;
  final int y;
  final String? playerId;
  final int timestamp;


  GridPoint({required this.x, required this.y, this.playerId,int? timestamp, }): timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;
  

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'playerId': playerId,
       'timestamp': timestamp,
    };
  }

  static GridPoint fromMap(Map<String, dynamic> map) {
    return GridPoint(
      x: map['x'],
      y: map['y'],
      playerId: map['playerId'],
       timestamp: map['timestamp'],
    );
  }
}

class Square {
  final int x;
  final int y;
  final String playerId;
  final DateTime completedAt;

  Square({
    required this.x,
    required this.y,
    required this.playerId,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'playerId': playerId,
      'completedAt': completedAt.millisecondsSinceEpoch,
    };
  }

  static Square fromMap(Map<String, dynamic> map) {
    return Square(
      x: map['x'],
      y: map['y'],
      playerId: map['playerId'],
      completedAt: DateTime.fromMillisecondsSinceEpoch(map['completedAt']),
    );
  }
}

enum GameStatus { waiting, playing, finished }
enum GameEndReason {
  timeUp,           // Temps écoulé
  gridFull,         // Grille complète
  playerSurrendered, // Abandon
  consecutiveMissedTurns, // 3 tours manqués
  disconnect,       // Déconnexion
  timeUpWinBlue,    // Temps écoulé - victoire bleu
  timeUpWinRed,     // Temps écoulé - victoire rouge
  timeUpDraw,       // Temps écoulé - match nul
  gridFullWinBlue,  // Grille pleine - victoire bleu
  gridFullWinRed,   // Grille pleine - victoire rouge
  gridFullDraw,     // Grille pleine - match nul
  timeout,
}
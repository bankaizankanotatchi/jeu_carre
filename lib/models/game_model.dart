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
  final GameEndReason? endReason; // Raison de fin de partie

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
    this.endReason,
  }) : spectators = spectators ?? [],
       gameSettings = gameSettings ?? {
         'allowSpectators': true,
         'isRanked': false,
         'maxSpectators': 50,
       },
       reflexionTimeRemaining = reflexionTimeRemaining ?? {},
       moveHistory = moveHistory ?? [];

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
      'endReason': endReason?.toString(),
    };
  }

  static Game fromMap(Map<String, dynamic> map) {
    return Game(
      id: map['id'],
      players: List<String>.from(map['players']),
      currentPlayer: map['currentPlayer'],
      scores: Map<String, int>.from(map['scores']),
      gridSize: map['gridSize'],
      points: List<GridPoint>.from(map['points'].map((p) => GridPoint.fromMap(p))),
      squares: List<Square>.from(map['squares'].map((s) => Square.fromMap(s))),
      status: GameStatus.values.firstWhere((e) => e.toString() == map['status']),
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
      endReason: map['endReason'] != null
          ? GameEndReason.values.firstWhere((e) => e.toString() == map['endReason'])
          : null,
    );
  }
}

class GridPoint {
  final int x;
  final int y;
  final String? playerId;

  GridPoint({required this.x, required this.y, this.playerId});

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'playerId': playerId,
    };
  }

  static GridPoint fromMap(Map<String, dynamic> map) {
    return GridPoint(
      x: map['x'],
      y: map['y'],
      playerId: map['playerId'],
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
  threeMissedTurns, // 3 tours manqués
  disconnect,       // Déconnexion
}
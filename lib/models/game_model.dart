class Game {
  final String id;
  final List<String> players;
  final String currentPlayer;
  final Map<String, int> scores;
  final int gridSize;
  final List<GridPoint> points;
  final List<Square> squares;
  final GameStatus status;

  Game({
    required this.id,
    required this.players,
    required this.currentPlayer,
    required this.scores,
    required this.gridSize,
    required this.points,
    required this.squares,
    required this.status,
  });

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
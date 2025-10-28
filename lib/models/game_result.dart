// ============================================
// RÉSULTAT DE PARTIE (pour mise à jour automatique)
// ============================================
class GameResult {
  final String userId;
  final int pointsScored;  // Nombre de carrés réalisés dans cette partie
  final GameOutcome outcome;
  final DateTime playedAt;

  GameResult({
    required this.userId,
    required this.pointsScored,
    required this.outcome,
    required this.playedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'pointsScored': pointsScored,
      'outcome': outcome.toString(),
      'playedAt': playedAt.millisecondsSinceEpoch,
    };
  }

  static GameResult fromMap(Map<String, dynamic> map) {
    return GameResult(
      userId: map['userId'],
      pointsScored: map['pointsScored'],
      outcome: GameOutcome.values.firstWhere((e) => e.toString() == map['outcome']),
      playedAt: DateTime.fromMillisecondsSinceEpoch(map['playedAt']),
    );
  }
}

enum GameOutcome {
  win,   // Victoire
  loss,  // Défaite
  draw,  // Match nul
}
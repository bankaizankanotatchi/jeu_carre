// ============================================
// RÉSULTAT DE PARTIE (version corrigée)
// ============================================
class GameResult {
  final String userId;
  final String gameId;        // NOUVEAU CHAMP
  final int pointsScored;
  final GameOutcome outcome;
  final DateTime playedAt;
  final String? opponentId;   // NOUVEAU CHAMP (optionnel)
  final int gridSize;         // NOUVEAU CHAMP

  GameResult({
    required this.userId,
    required this.gameId,     // AJOUTÉ
    required this.pointsScored,
    required this.outcome,
    required this.playedAt,
    this.opponentId,          // AJOUTÉ (optionnel)
    required this.gridSize,   // AJOUTÉ
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'gameId': gameId,       // AJOUTÉ
      'pointsScored': pointsScored,
      'outcome': outcome.toString(),
      'playedAt': playedAt.millisecondsSinceEpoch,
      'opponentId': opponentId, // AJOUTÉ
      'gridSize': gridSize,   // AJOUTÉ
    };
  }

  static GameResult fromMap(Map<String, dynamic> map) {
    return GameResult(
      userId: map['userId'],
      gameId: map['gameId'],   // AJOUTÉ
      pointsScored: map['pointsScored'],
      outcome: GameOutcome.values.firstWhere((e) => e.toString() == map['outcome']),
      playedAt: DateTime.fromMillisecondsSinceEpoch(map['playedAt']),
      opponentId: map['opponentId'], // AJOUTÉ
      gridSize: map['gridSize'] ?? 15, //valeur par défaut
    );
  }
}

enum GameOutcome {
  win,   // Victoire
  loss,  // Défaite
  draw,  // Match nul
}
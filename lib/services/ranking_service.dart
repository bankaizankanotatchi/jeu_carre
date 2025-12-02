import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeu_carre/models/player.dart';

class RankingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static final CollectionReference _playersCollection = 
      _firestore.collection('users');
  static final CollectionReference _gamesCollection = 
      _firestore.collection('games');

  // Cache pour le top 10
  static List<Player> _top10Cache = [];
  static DateTime? _lastTop10Update;

  // ============================================
  // CLASSEMENT GLOBAL
  // ============================================

  // Récupérer le classement global (top 10)
  static Stream<List<Player>> getGlobalRanking({int limit = 10}) {
    return _playersCollection
        .where('totalPoints', isGreaterThan: 0)
        .orderBy('totalPoints', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final players = snapshot.docs.map((doc) {
            return Player.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();
          
          // Mettre à jour le cache pour le top 10
          if (limit == 10) {
            _top10Cache = players;
            _lastTop10Update = DateTime.now();
          }
          
          return players;
        });
  }

  // ============================================
  // MISE À JOUR APRÈS UNE PARTIE
  // ============================================

  /// Mettre à jour les rangs après une partie
  static Future<void> updateRanksAfterGame(List<String> playerIds) async {
    try {
      print('🔄 Mise à jour des rangs après partie pour ${playerIds.length} joueurs...');
      
      // Rafraîchir le cache du top 10
      await refreshTop10Cache();
      
      print('✅ Top 10 mis à jour après la partie');
    } catch (e) {
      print('❌ Erreur mise à jour rangs après partie: $e');
    }
  }

  // ============================================
  // FONCTIONS UTILITAIRES
  // ============================================

  // Fonction pour compter le nombre de joueurs actifs (avec points)
  static Future<int> getActivePlayersCount() async {
    try {
      final countSnapshot = await _playersCollection
          .where('totalPoints', isGreaterThan: 0)
          .count()
          .get();
      return countSnapshot.count ?? 0;
    } catch (e) {
      print('❌ Erreur comptage joueurs actifs: $e');
      return 0;
    }
  }


// Récupérer le rang d'un joueur spécifique (uniquement s'il est dans le top 10)
static int getPlayerRank(String playerId) {
  // Vérifier si le joueur est dans le top 10 (cache)
  final index = _top10Cache.indexWhere((player) => player.id == playerId);
  return index >= 0 ? index + 1 : 0; // 0 = non classé
}
  // Vérifier si un joueur est dans le top 10 (via cache)
  static bool isPlayerInTop10(String playerId) {
    return _top10Cache.any((player) => player.id == playerId);
  }

  // Récupérer le rang d'un joueur dans le top 10
  static int? getPlayerRankInTop10(String playerId) {
    if (_top10Cache.isEmpty) return null;
    
    final index = _top10Cache.indexWhere((player) => player.id == playerId);
    return index >= 0 ? index + 1 : null;
  }

  // ============================================
  // STATISTIQUES GLOBALES
  // ============================================

  // Récupérer les statistiques globales de la plateforme
  static Future<Map<String, dynamic>> getPlatformStats() async {
    try {
      final playersSnapshot = await _playersCollection.get();
      final gamesSnapshot = await _gamesCollection.get();
      
      int totalPlayers = playersSnapshot.size;
      int totalGames = gamesSnapshot.size;
      int activeToday = 0;
      int totalPoints = 0;
      
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      for (final doc in playersSnapshot.docs) {
        final playerData = doc.data() as Map<String, dynamic>;
        final pts = (playerData['totalPoints'] as num?)?.toInt() ?? 0;
        totalPoints += pts;
        
        final lastLogin = playerData['lastLoginAt'];
        if (lastLogin != null) {
          final lastLoginTime = DateTime.fromMillisecondsSinceEpoch(
            (lastLogin as num).toInt()
          );
          if (lastLoginTime.isAfter(startOfDay)) {
            activeToday++;
          }
        }
      }

      return {
        'totalPlayers': totalPlayers,
        'totalGames': totalGames,
        'activeToday': activeToday,
        'totalPoints': totalPoints,
        'averagePointsPerPlayer': totalPlayers > 0 ? totalPoints / totalPlayers : 0,
      };
    } catch (e) {
      print('Erreur statistiques plateforme: $e');
      rethrow;
    }
  }

  // ============================================
  // STATISTIQUES PERSONNELLES
  // ============================================

  // Récupérer les statistiques détaillées d'un joueur
  static Future<Map<String, dynamic>> getPlayerStats(String playerId) async {
    try {
      final playerDoc = await _playersCollection.doc(playerId).get();
      if (!playerDoc.exists) {
        throw Exception('Joueur non trouvé');
      }

      final playerData = playerDoc.data() as Map<String, dynamic>;
      final player = Player.fromMap(playerData);

      // Récupérer les jeux récents du joueur
      final recentGames = await _gamesCollection
          .where('players', arrayContains: playerId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      // Calculer les statistiques avancées
      int winsAgainstAI = 0;
      int totalGamesAgainstAI = 0;
      double averageGameDuration = 0;
      List<int> recentScores = [];

      for (final gameDoc in recentGames.docs) {
        final gameData = gameDoc.data() as Map<String, dynamic>;
        
        // Durée moyenne des parties
        final createdAt = gameData['createdAt'] as int?;
        final finishedAt = gameData['finishedAt'] as int?;
        if (createdAt != null && finishedAt != null) {
          final duration = (finishedAt - createdAt) / 1000; // en secondes
          averageGameDuration += duration;
        }

        // Victoires contre IA
        if (gameData['isAgainstAI'] == true) {
          totalGamesAgainstAI++;
          final winner = gameData['winner'];
          if (winner == playerId) {
            winsAgainstAI++;
          }
        }

        // Scores récents
        final scores = gameData['scores'] as Map<String, dynamic>?;
        if (scores != null && scores[playerId] != null) {
          final score = scores[playerId];
          if (score is num) {
            recentScores.add(score.toInt());
          }
        }
      }

      if (recentGames.docs.isNotEmpty) {
        averageGameDuration /= recentGames.docs.length;
      }

      return {
        'player': player,
        'recentGames': recentGames.docs.length,
        'winRateAgainstAI': totalGamesAgainstAI > 0 ? (winsAgainstAI / totalGamesAgainstAI) * 100 : 0,
        'averageGameDuration': averageGameDuration,
        'recentScores': recentScores,
        'bestRecentScore': recentScores.isNotEmpty ? recentScores.reduce((a, b) => a > b ? a : b) : 0,
        'averageRecentScore': recentScores.isNotEmpty ? 
            recentScores.reduce((a, b) => a + b) / recentScores.length : 0,
      };
    } catch (e) {
      print('Erreur statistiques joueur: $e');
      rethrow;
    }
  }

  // ============================================
  // MISES À JOUR DES STATISTIQUES
  // ============================================

  // Mettre à jour les statistiques après une partie
  static Future<void> updatePlayerStatsAfterGame({
    required String playerId,
    required bool isWinner,
    required int pointsScored,
    required bool isAgainstAI,
    required String? aiDifficulty,
    required int gameDuration, // en secondes
  }) async {
    try {
      final playerDoc = await _playersCollection.doc(playerId).get();
      if (!playerDoc.exists) return;

      final playerData = playerDoc.data() as Map<String, dynamic>;
      final player = Player.fromMap(playerData);

      // Mettre à jour les statistiques de base
      final newTotalPoints = player.totalPoints + pointsScored;
      final newGamesPlayed = player.gamesPlayed + 1;
      final newGamesWon = player.gamesWon + (isWinner ? 1 : 0);
      final newGamesLost = player.gamesLost + (isWinner ? 0 : 1);
      final now = DateTime.now();

      // Mettre à jour les statistiques détaillées
      var newStats = player.stats.copyWith(
        bestGamePoints: pointsScored > player.stats.bestGamePoints ? pointsScored : player.stats.bestGamePoints,
        winStreak: isWinner ? player.stats.winStreak + 1 : 0,
        bestWinStreak: isWinner ? 
            (player.stats.winStreak + 1 > player.stats.bestWinStreak ? 
             player.stats.winStreak + 1 : player.stats.bestWinStreak) : 
            player.stats.bestWinStreak,
      );

      final updatedPlayer = player.copyWith(
        totalPoints: newTotalPoints,
        gamesPlayed: newGamesPlayed,
        gamesWon: newGamesWon,
        gamesLost: newGamesLost,
        lastLoginAt: now,
        stats: newStats,
      );

      await _playersCollection.doc(playerId).update(updatedPlayer.toMap());

    } catch (e) {
      print('Erreur mise à jour statistiques: $e');
      rethrow;
    }
  }

  // ============================================
  // FONCTIONS UTILITAIRES POUR L'UI
  // ============================================

  // Formater les données pour l'affichage dans l'UI
  static Map<String, dynamic> formatRankingData(List<Player> players, String period) {
    final formattedData = players.asMap().entries.map((entry) {
      final index = entry.key;
      final player = entry.value;
      
      String avatarEmoji = player.displayAvatar;

      // Déterminer la tendance (simulée pour l'exemple)
      final trend = ['up', 'down', 'stable'][index % 3];

      // Score (toujours totalPoints maintenant)
      int score = player.totalPoints;

      return {
        'name': player.username,
        'score': score,
        'avatar': avatarEmoji,
        'trend': trend,
        'playerId': player.id,
        'rank': index + 1, // Rang calculé localement
      };
    }).toList();

    return {
      'period': period,
      'players': formattedData,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };
  }

  // Vérifier si un joueur est dans le top
  static Future<bool> isPlayerInTop(String playerId, int topCount) async {
    try {
      final ranking = await getGlobalRanking(limit: topCount).first;
      return ranking.any((player) => player.id == playerId);
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // GESTION DU CACHE
  // ============================================

  /// Rafraîchir le cache du top 10
  static Future<void> refreshTop10Cache() async {
    try {
      final snapshot = await _playersCollection
          .where('totalPoints', isGreaterThan: 0)
          .orderBy('totalPoints', descending: true)
          .limit(10)
          .get();
      
      _top10Cache = snapshot.docs.map((doc) {
        return Player.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
      
      _lastTop10Update = DateTime.now();
      print('✅ Cache top 10 rafraîchi (${_top10Cache.length} joueurs)');
    } catch (e) {
      print('❌ Erreur rafraîchissement cache top 10: $e');
    }
  }

  /// Démarrer le scheduler pour rafraîchir le cache
  static void startRankScheduler() {
    // Rafraîchir le cache toutes les 5 minutes (en backup)
    Timer.periodic(Duration(minutes: 5), (timer) {
      refreshTop10Cache();
    });
    
    // Rafraîchir au démarrage
    refreshTop10Cache();
    
    print('⏰ Scheduler du cache démarré (rafraîchissement toutes les 5 min)');
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeu_carre/models/ai_player.dart';
import 'package:jeu_carre/models/player.dart';

class RankingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static final CollectionReference _playersCollection = 
      _firestore.collection('users');
  static final CollectionReference _gamesCollection = 
      _firestore.collection('games');
  static final CollectionReference _dailyStatsCollection = 
      _firestore.collection('daily_stats');
  static final CollectionReference _weeklyStatsCollection = 
      _firestore.collection('weekly_stats');
  static final CollectionReference _monthlyStatsCollection = 
      _firestore.collection('monthly_stats');

  // ============================================
  // CLASSEMENTS TEMPORELS
  // ============================================

  // Récupérer le classement du jour
  static Stream<List<Player>> getDailyRanking({int limit = 10}) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    return _playersCollection
        .where('lastLoginAt', isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch)
        .orderBy('lastLoginAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Player.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();
        });
  }

  // Récupérer le classement de la semaine
  static Stream<List<Player>> getWeeklyRanking({int limit = 10}) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    return _playersCollection
        .where('stats.weeklyPoints', isGreaterThan: 0)
        .orderBy('stats.weeklyPoints', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Player.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();
        });
  }

  // Récupérer le classement du mois
  static Stream<List<Player>> getMonthlyRanking({int limit = 10}) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    return _playersCollection
        .where('stats.monthlyPoints', isGreaterThan: 0)
        .orderBy('stats.monthlyPoints', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Player.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();
        });
  }

  // Récupérer le classement global (tous les temps)
  static Stream<List<Player>> getGlobalRanking({int limit = 10}) {
    return _playersCollection
        .where('totalPoints', isGreaterThan: 0)
        .orderBy('totalPoints', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Player.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();
        });
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
        final pts = playerData['totalPoints'] as num?;
        totalPoints += pts?.toInt() ?? 0;
        
        final lastLogin = playerData['lastLoginAt'];
        if (lastLogin != null && lastLogin >= startOfDay.millisecondsSinceEpoch) {
          activeToday++;
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
        final createdAt = gameData['createdAt'];
        final finishedAt = gameData['finishedAt'];
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
          recentScores.add((scores[playerId] as num).toInt());
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
    required AIDifficulty? aiDifficulty,
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

      // Mettre à jour les statistiques détaillées
      var newStats = player.stats.copyWith(
        dailyPoints: player.stats.dailyPoints + pointsScored,
        weeklyPoints: player.stats.weeklyPoints + pointsScored,
        monthlyPoints: player.stats.monthlyPoints + pointsScored,
        bestGamePoints: pointsScored > player.stats.bestGamePoints ? pointsScored : player.stats.bestGamePoints,
        winStreak: isWinner ? player.stats.winStreak + 1 : 0,
        bestWinStreak: isWinner ? 
            (player.stats.winStreak + 1 > player.stats.bestWinStreak ? 
             player.stats.winStreak + 1 : player.stats.bestWinStreak) : 
            player.stats.bestWinStreak,
      );

      // Mettre à jour le record contre IA si applicable
      if (isAgainstAI && aiDifficulty != null) {
        final difficultyKey = aiDifficulty.toString().split('.').last;
        final currentRecord = Map<String, int>.from(player.stats.vsAIRecord);
        currentRecord[difficultyKey] = (currentRecord[difficultyKey] ?? 0) + (isWinner ? 1 : 0);
        newStats = newStats.copyWith(vsAIRecord: currentRecord);
      }

      final updatedPlayer = player.copyWith(
        totalPoints: newTotalPoints,
        gamesPlayed: newGamesPlayed,
        gamesWon: newGamesWon,
        gamesLost: newGamesLost,
        stats: newStats,
        lastLoginAt: DateTime.now(),
      );

      await _playersCollection.doc(playerId).update(updatedPlayer.toMap());

      // Mettre à jour les statistiques globales
      await _updateGlobalStats(pointsScored, isWinner);

    } catch (e) {
      print('Erreur mise à jour statistiques: $e');
      rethrow;
    }
  }

  // Mettre à jour les statistiques globales de la plateforme
  static Future<void> _updateGlobalStats(int pointsScored, bool isWinner) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Statistiques du jour
      final dailyDocRef = _dailyStatsCollection.doc('${today.year}-${today.month}-${today.day}');
      final dailyDoc = await dailyDocRef.get();
      
      if (dailyDoc.exists) {
        await dailyDocRef.update({
          'totalPoints': FieldValue.increment(pointsScored),
          'totalGames': FieldValue.increment(1),
          'totalWins': FieldValue.increment(isWinner ? 1 : 0),
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        await dailyDocRef.set({
          'date': today.millisecondsSinceEpoch,
          'totalPoints': pointsScored,
          'totalGames': 1,
          'totalWins': isWinner ? 1 : 0,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Statistiques de la semaine (méthode similaire pour weeklyStatsCollection)
      // Statistiques du mois (méthode similaire pour monthlyStatsCollection)

    } catch (e) {
      print('Erreur mise à jour stats globales: $e');
    }
  }

  // ============================================
  // RÉINITIALISATION DES STATISTIQUES TEMPORELLES
  // ============================================

  // Réinitialiser les points quotidiens (à appeler une fois par jour)
  static Future<void> resetDailyStats() async {
    try {
      final playersSnapshot = await _playersCollection.get();
      
      for (final doc in playersSnapshot.docs) {
        final playerData = doc.data() as Map<String, dynamic>;
        final stats = playerData['stats'] as Map<String, dynamic>;
        
        await doc.reference.update({
          'stats.dailyPoints': 0,
        });
      }
    } catch (e) {
      print('Erreur réinitialisation stats quotidiennes: $e');
    }
  }

  // Réinitialiser les points hebdomadaires (à appeler une fois par semaine)
  static Future<void> resetWeeklyStats() async {
    try {
      final playersSnapshot = await _playersCollection.get();
      
      for (final doc in playersSnapshot.docs) {
        final playerData = doc.data() as Map<String, dynamic>;
        final stats = playerData['stats'] as Map<String, dynamic>;
        
        await doc.reference.update({
          'stats.weeklyPoints': 0,
        });
      }
    } catch (e) {
      print('Erreur réinitialisation stats hebdomadaires: $e');
    }
  }

  // Réinitialiser les points mensuels (à appeler une fois par mois)
  static Future<void> resetMonthlyStats() async {
    try {
      final playersSnapshot = await _playersCollection.get();
      
      for (final doc in playersSnapshot.docs) {
        final playerData = doc.data() as Map<String, dynamic>;
        final stats = playerData['stats'] as Map<String, dynamic>;
        
        await doc.reference.update({
          'stats.monthlyPoints': 0,
        });
      }
    } catch (e) {
      print('Erreur réinitialisation stats mensuelles: $e');
    }
  }

  // ============================================
  // FONCTIONS UTILITAIRES
  // ============================================

  // Formater les données pour l'affichage dans l'UI
  static Map<String, dynamic> formatRankingData(List<Player> players, String period) {
    final formattedData = players.asMap().entries.map((entry) {
      final index = entry.key;
      final player = entry.value;
      
      // Déterminer l'emoji en fonction du rang
    String avatarEmoji = player.displayAvatar; // ← Ça utilise avatarUrl OU defaultEmoji

      // Déterminer la tendance (simulée pour l'exemple)
      final trend = ['up', 'down', 'stable'][index % 3];

      // Déterminer le score en fonction de la période
      int score;
      switch (period) {
        case 'daily':
          score = player.stats.dailyPoints;
          break;
        case 'weekly':
          score = player.stats.weeklyPoints;
          break;
        case 'monthly':
          score = player.stats.monthlyPoints;
          break;
        default:
          score = player.totalPoints;
      }

      return {
        'name': player.username,
        'score': score,
        'avatar': avatarEmoji,
        'trend': trend,
        'playerId': player.id,
      };
    }).toList();

    return {
      'period': period,
      'players': formattedData,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };
  }

  // Vérifier si un joueur est dans le top
  static Future<bool> isPlayerInTop(String playerId, String period, int topCount) async {
    try {
      List<Player> ranking;
      
      switch (period) {
        case 'daily':
          ranking = await getDailyRanking(limit: topCount).first;
          break;
        case 'weekly':
          ranking = await getWeeklyRanking(limit: topCount).first;
          break;
        case 'monthly':
          ranking = await getMonthlyRanking(limit: topCount).first;
          break;
        default:
          ranking = await getGlobalRanking(limit: topCount).first;
      }

      return ranking.any((player) => player.id == playerId);
    } catch (e) {
      return false;
    }
  }
}
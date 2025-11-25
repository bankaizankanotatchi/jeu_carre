import 'dart:async';

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

  static Stream<List<Player>> getAllGlobalRanking() {
    return _playersCollection
        .where('totalPoints', isGreaterThan: 0)
        .orderBy('totalPoints', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Player.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();
        });
  }

  // ============================================
  // CALCUL ET MISE À JOUR DES RANGS GLOBAUX
  // ============================================

  /// Calculer et mettre à jour le rang global de TOUS les joueurs
  static Future<void> updateAllGlobalRanks() async {
    try {
      print('🔄 Début calcul des rangs globaux...');
      
      // 1. Récupérer tous les joueurs triés par points (décroissant)
      final playersSnapshot = await _playersCollection
          .where('totalPoints', isGreaterThan: 0)
          .orderBy('totalPoints', descending: true)
          .get();

      final totalPlayers = playersSnapshot.size;
      print('📊 $totalPlayers joueurs à classer');

      if (totalPlayers == 0) {
        print('ℹ️ Aucun joueur à classer');
        return;
      }

      // 2. Préparer le batch update
      final batch = _firestore.batch();
      int rank = 1;

      // 3. Attribuer les rangs (1 = meilleur)
      for (final doc in playersSnapshot.docs) {
        batch.update(doc.reference, {
          'globalRank': rank,
          'lastRankUpdate': DateTime.now().millisecondsSinceEpoch,
        });
        rank++;
      }

      // 4. Exécuter la mise à jour
      await batch.commit();
      print('✅ Rangs globaux mis à jour pour $totalPlayers joueurs');

    } catch (e) {
      print('❌ Erreur calcul rangs globaux: $e');
      rethrow;
    }
  }

  /// Mettre à jour le rang global d'UN joueur spécifique
  static Future<void> updatePlayerGlobalRank(String playerId) async {
    try {
      // 1. Récupérer le joueur
      final playerDoc = await _playersCollection.doc(playerId).get();
      if (!playerDoc.exists) {
        print('❌ Joueur non trouvé: $playerId');
        return;
      }

      final playerData = playerDoc.data() as Map<String, dynamic>;
      final playerPoints = playerData['totalPoints'] as int? ?? 0;

      // 2. Si le joueur n'a pas de points, le mettre en dernier
      if (playerPoints == 0) {
        final totalPlayersCount = await _playersCollection
            .where('totalPoints', isGreaterThan: 0)
            .count()
            .get();
        
        final rank = totalPlayersCount.count! + 1; // Dernière position
        
        await playerDoc.reference.update({
          'globalRank': rank,
          'lastRankUpdate': DateTime.now().millisecondsSinceEpoch
        });
        
        print('📝 Joueur sans points mis en position $rank: $playerId');
        return;
      }

      // 3. Compter combien de joueurs ont PLUS de points que lui
      final betterPlayersCount = await _playersCollection
          .where('totalPoints', isGreaterThan: playerPoints)
          .count()
          .get();

      // 4. Le rang = nombre de joueurs avec plus de points + 1
      final rank = betterPlayersCount.count! + 1;

      // 5. Mettre à jour le rang
      await playerDoc.reference.update({
        'globalRank': rank,
        'lastRankUpdate': DateTime.now().millisecondsSinceEpoch
      });

      print('✅ Rang mis à jour: $playerId → #$rank');

    } catch (e) {
      print('❌ Erreur mise à jour rang joueur $playerId: $e');
    }
  }

  /// Mettre à jour les rangs de plusieurs joueurs après une partie
  static Future<void> updateRanksAfterGame(List<String> playerIds) async {
    try {
      print('🔄 Mise à jour des rangs après partie pour ${playerIds.length} joueurs...');
      
      for (final playerId in playerIds) {
        if (!playerId.startsWith('ai_')) { // Ignorer les IA
          await updatePlayerGlobalRank(playerId);
        }
      }
      
      print('✅ Rangs mis à jour pour tous les joueurs de la partie');
    } catch (e) {
      print('❌ Erreur mise à jour rangs après partie: $e');
    }
  }

  /// Fonction pour compter le nombre total de joueurs
  static Future<int?> getTotalPlayersCount() async {
    try {
      final countSnapshot = await _playersCollection.count().get();
      return countSnapshot.count;
    } catch (e) {
      print('❌ Erreur comptage joueurs: $e');
      return 0;
    }
  }

  /// Fonction pour compter le nombre de joueurs actifs (avec points)
  static Future<int?> getActivePlayersCount() async {
    try {
      final countSnapshot = await _playersCollection
          .where('totalPoints', isGreaterThan: 0)
          .count()
          .get();
      return countSnapshot.count;
    } catch (e) {
      print('❌ Erreur comptage joueurs actifs: $e');
      return 0;
    }
  }

  /// Récupérer le rang d'un joueur spécifique
  static Future<int> getPlayerRank(String playerId) async {
    try {
      final playerDoc = await _playersCollection.doc(playerId).get();
      if (!playerDoc.exists) return 0;
      
      final playerData = playerDoc.data() as Map<String, dynamic>;
      return playerData['globalRank'] ?? 0;
    } catch (e) {
      print('❌ Erreur récupération rang joueur: $e');
      return 0;
    }
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

  // ============================================
  // PROGRAMMATION AUTOMATIQUE DES MISES À JOUR
  // ============================================

  /// Démarrer le scheduler pour les mises à jour automatiques
  static void startRankScheduler() {
    // Mettre à jour tous les rangs toutes les 6 heures
    Timer.periodic(Duration(hours: 6), (timer) {
      updateAllGlobalRanks();
    });
    
    print('⏰ Scheduler des rangs démarré (mise à jour toutes les 6h)');
  }

  /// Forcer la mise à jour immédiate de tous les rangs
  static Future<void> forceUpdateAllRanks() async {
    await updateAllGlobalRanks();
  }
}
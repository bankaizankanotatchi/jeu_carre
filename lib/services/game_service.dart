import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeu_carre/models/ai_player.dart';
import 'package:jeu_carre/models/game_model.dart';
import 'package:jeu_carre/models/game_request.dart';
import 'package:jeu_carre/models/game_result.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/services/ranking_service.dart';

class GameService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static CollectionReference get gamesCollection => _firestore.collection('games');
  static CollectionReference get usersCollection => _firestore.collection('users');
  static CollectionReference get matchRequestsCollection => _firestore.collection('match_requests');
  static CollectionReference get gameResultsCollection => _firestore.collection('game_results');
  static CollectionReference get notificationsCollection => _firestore.collection('notifications');
  static CollectionReference get spectatorsCollection => _firestore.collection('spectators');

  // ============================================================
  // GESTION DES PARTIES - AMÉLIORATIONS
  // ============================================================

  /// Créer une nouvelle partie avec validation
  static Future<Game> createGame(Game game) async {
    try {
      if (game.players.isEmpty) {
        throw Exception('Une partie doit avoir au moins un joueur');
      }

      await gamesCollection.doc(game.id).set(game.toMap());
      
      // Mettre à jour le statut des joueurs EXISTANTS seulement
      for (final playerId in game.players) {
        if (!playerId.startsWith('ai_')) { // Ignorer l'IA
          try {
            await _updatePlayerGameStatus(playerId, true, game.id);
          } catch (e) {
            print('Erreur mise à jour statut joueur $playerId: $e');
          }
        }
      }

      return game;
    } catch (e) {
      throw Exception('Erreur création partie: $e');
    }
  }

  /// Créer une partie contre l'IA
  static Future<Game> createAIGame({
    required int gridSize,
    required AIDifficulty difficulty,
    required int gameDuration,
    required int reflexionTime,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Utilisateur non connecté');

    final game = Game(
      id: generateId(),
      players: [currentUser.uid, 'ai_${difficulty.toString()}'],
      currentPlayer: currentUser.uid,
      scores: {currentUser.uid: 0, 'ai_${difficulty.toString()}': 0},
      gridSize: gridSize,
      points: [],
      squares: [],
      status: GameStatus.playing,
      player1Id: currentUser.uid,
      player2Id: null,
      isAgainstAI: true,
      aiDifficulty: difficulty.toString().split('.').last,
      gameDuration: gameDuration,
      reflexionTime: reflexionTime,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      startedAt: DateTime.now(),
      timeRemaining: gameDuration,
      reflexionTimeRemaining: {
        currentUser.uid: reflexionTime,
        'ai_${difficulty.toString()}': reflexionTime,
      },
      consecutiveMissedTurns: {
        currentUser.uid: 0,
        'ai_${difficulty.toString()}': 0,
      },
      gameSettings: {
        'allowSpectators': false,
        'isRanked': false,
        'maxSpectators': 0,
      },
    );

    return await createGame(game);
  }

  /// Rejoindre une partie existante avec validation
  static Future<void> joinGame(String gameId, String playerId) async {
    try {
      final gameDoc = await gamesCollection.doc(gameId).get();
      if (!gameDoc.exists) throw Exception('Partie non trouvée');

      final game = Game.fromMap(gameDoc.data() as Map<String, dynamic>);
      
      if (game.players.contains(playerId)) {
        throw Exception('Vous êtes déjà dans cette partie');
      }

      if (game.players.length >= 2 && !game.isAgainstAI) {
        throw Exception('Partie complète');
      }

      if (game.status != GameStatus.waiting) {
        throw Exception('Partie déjà commencée');
      }

      await gamesCollection.doc(gameId).update({
        'players': FieldValue.arrayUnion([playerId]),
        'player2Id': playerId,
        'status': GameStatus.playing.toString(),
        'startedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'reflexionTimeRemaining.$playerId': game.reflexionTime,
        'consecutiveMissedTurns.$playerId': 0,
      });

      await _updatePlayerGameStatus(playerId, true, gameId);
    } catch (e) {
      throw Exception('Erreur rejoindre partie: $e');
    }
  }

  // ============================================================
  // MÉTHODES ATOMIQUES POUR MISE À JOUR TEMPS RÉEL
  // ============================================================
  

  /// Mettre à jour le temps de réflexion de manière atomique
  static Future<void> updateReflexionTimeAtomic(String gameId, String playerId, int newTime) async {
    try {
      await gamesCollection.doc(gameId).update({
        'reflexionTimeRemaining.$playerId': newTime,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Erreur mise à jour temps réflexion atomique: $e');
    }
  }

  /// Mettre à jour le temps global de la partie
  static Future<void> updateGameTime(String gameId, int timeRemaining) async {
    try {
      await gamesCollection.doc(gameId).update({
        'timeRemaining': timeRemaining,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Vérifier si le temps est écoulé
      if (timeRemaining <= 0) {
        await _checkAndFinishGame(gameId);
      }
    } catch (e) {
      print('Erreur mise à jour temps jeu: $e');
    }
  }

  /// Mettre à jour le joueur actif
  static Future<void> updateCurrentPlayer(String gameId, String currentPlayerId) async {
    try {
      await gamesCollection.doc(gameId).update({
        'currentPlayer': currentPlayerId,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Erreur mise à jour joueur actif: $e');
    }
  }

  /// Changer de joueur avec réinitialisation du temps
  static Future<void> switchPlayer(String gameId, String nextPlayerId, int reflexionTime) async {
    try {
      await gamesCollection.doc(gameId).update({
        'currentPlayer': nextPlayerId,
        'reflexionTimeRemaining.$nextPlayerId': reflexionTime,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Erreur changement joueur: $e');
    }
  }

/// Mettre à jour les tours manqués consécutifs - VERSION CORRIGÉE
static Future<void> updateConsecutiveMissedTurns(String gameId, Map<String, int> consecutiveMissedTurns) async {
  try {
    print('🔄 updateConsecutiveMissedTurns appelé');
    print('📊 Tours manqués reçus: $consecutiveMissedTurns');
    
    await gamesCollection.doc(gameId).update({
      'consecutiveMissedTurns': consecutiveMissedTurns,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    
    // 🎯 RÉCUPÉRER LA PARTIE POUR VÉRIFICATION
    final gameDoc = await gamesCollection.doc(gameId).get();
    if (!gameDoc.exists) return;
    
    final game = Game.fromMap(gameDoc.data() as Map<String, dynamic>);
    print('📊 Tours manqués dans Firestore: ${game.consecutiveMissedTurns}');
    
    // Vérifier si un joueur a manqué 3 tours
    for (final entry in consecutiveMissedTurns.entries) {
      print('🔍 Vérification joueur ${entry.key}: ${entry.value}/3 tours manqués');
      
      if (entry.value >= 3) {
        print('🎯🚨 3 TOURS MANQUÉS DÉTECTÉS pour le joueur: ${entry.key}');
        print('🎯🚨 Déclenchement fin de partie...');
        
        // 🎯 IDENTIFIER LE JOUEUR QUI A MANQUÉ LES TOURS
        final playerWhoMissed = entry.key;
        await _finishGameByMissedTurns(gameId, playerWhoMissed);
        return; // 🚫 ON S'ARRÊTE APRÈS AVOIR TRAITÉ LE PREMIER JOUEUR À 3 TOURS
      }
    }
    
    print('✅ Aucun joueur n\'a atteint 3 tours manqués');
  } catch (e) {
    print('❌ Erreur mise à jour tours manqués: $e');
  }
}
  
  // ============================================================
  // GESTION DES POINTS ET CARRÉS
  // ============================================================

  /// Ajouter un point à la partie avec gestion du prochain joueur
  static Future<void> addPointToGame(String gameId, GridPoint point) async {
    try {
      final gameDoc = await gamesCollection.doc(gameId).get();
      if (!gameDoc.exists) throw Exception('Partie non trouvée');
      
      final game = Game.fromMap(gameDoc.data() as Map<String, dynamic>);
      final nextPlayerId = _getNextPlayerId(game, point.playerId!);

      await gamesCollection.doc(gameId).update({
        'points': FieldValue.arrayUnion([point.toMap()]),
        'currentPlayer': nextPlayerId,
        'consecutiveMissedTurns.${point.playerId}': 0, // Réinitialiser les tours manqués
        'reflexionTimeRemaining.$nextPlayerId': game.reflexionTime,
        'lastMoveAt': DateTime.now().millisecondsSinceEpoch, 
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Vérifier si la grille est pleine
      final updatedGameDoc = await gamesCollection.doc(gameId).get();
      final updatedGame = Game.fromMap(updatedGameDoc.data() as Map<String, dynamic>);
      if (updatedGame.points.length >= updatedGame.gridSize * updatedGame.gridSize) {
        await _finishGameByGridFull(gameId);
      }
    } catch (e) {
      throw Exception('Erreur ajout point: $e');
    }
  }

  /// Ajouter un carré complété
  static Future<void> addSquareToGame(String gameId, Square square) async {
    try {
      await gamesCollection.doc(gameId).update({
        'squares': FieldValue.arrayUnion([square.toMap()]),
        'scores.${square.playerId}': FieldValue.increment(1),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Erreur ajout carré: $e');
    }
  }

  // ============================================================
  // GESTION DE LA FIN DE PARTIE - CORRECTIONS APPLIQUÉES
  // ============================================================

/// Marquer la partie comme terminée avec raison
static Future<void> finishGameWithReason(String gameId, {String? winnerId, required GameEndReason endReason}) async {
  try {
    print('🎯 Début finishGameWithReason: $gameId, winner: $winnerId, raison: $endReason');
    
    // 🎯 CORRECTION: TOUT FAIRE EN UNE SEULE OPÉRATION ATOMIQUE
    final updates = {
      'status': GameStatus.finished.toString(),
      'finishedAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'endReason': endReason.toString(),
      'winnerId': winnerId, // 🎯 TOUJOURS définir winnerId (même si null)
    };

    print('📝 Mise à jour Firestore: $updates');
    
    // 🎯 UNE SEULE OPÉRATION POUR TOUT METTRE À JOUR
    await gamesCollection.doc(gameId).update(updates);
    print('✅ Partie terminée dans Firestore avec winnerId: $winnerId');

    // 🎯 ATTENDRE QUE FIRESTORE SYNCHRONISE
    await Future.delayed(Duration(milliseconds: 1000));
    
    // 🎯 MAINTENANT RÉCUPÉRER LA PARTIE MISE À JOUR
    final gameDoc = await gamesCollection.doc(gameId).get();
    if (!gameDoc.exists) {
      print('❌ Partie non trouvée après mise à jour: $gameId');
      return;
    }

    final game = Game.fromMap(gameDoc.data() as Map<String, dynamic>);
    
    // 🎯 VÉRIFICATION DES DONNÉES MISE À JOUR
    print('🔍 Vérification après mise à jour:');
    print('  - status: ${game.status}');
    print('  - winnerId: ${game.winnerId}');
    print('  - endReason: ${game.endReason}');
    
    if (game.status != GameStatus.finished) {
      print('❌ ERREUR: Partie pas encore terminée après update!');
      return;
    }

    // SAUVEGARDER LES RÉSULTATS
    print('💾 Sauvegarde résultats pour ${game.players.length} joueurs');
    
    for (final playerId in game.players) {
      if (!playerId.startsWith('ai_')) {
        await _updatePlayerGameStatus(playerId, false, null);
      }
    }
    
    await _saveGameResults(game);
    print('✅ Tous les résultats sauvegardés pour partie $gameId');
    
  } catch (e) {
    print('❌ Erreur fin de partie: $e');
  }
}
  /// Vérifier et terminer une partie si nécessaire
  static Future<void> _checkAndFinishGame(String gameId) async {
    try {
      print('⏰ Vérification fin de partie: $gameId');
      final gameDoc = await gamesCollection.doc(gameId).get();
      if (!gameDoc.exists) {
        print('❌ Partie non trouvée: $gameId');
        return;
      }

      final game = Game.fromMap(gameDoc.data() as Map<String, dynamic>);
      if (game.status == GameStatus.finished) {
        print('ℹ️ Partie déjà terminée: $gameId');
        return;
      }

      await _finishGameByTime(gameId);
    } catch (e) {
      print('❌ Erreur vérification fin de partie: $e');
    }
  }

  /// Fin de partie par temps écoulé
  static Future<void> _finishGameByTime(String gameId) async {
    try {
      print('⏰ Tentative fin de partie par temps: $gameId');
      final gameDoc = await gamesCollection.doc(gameId).get();
      if (!gameDoc.exists) {
        print('❌ Partie non trouvée: $gameId');
        return;
      }

      final game = Game.fromMap(gameDoc.data() as Map<String, dynamic>);
      
      if (game.status == GameStatus.finished) {
        print('ℹ️ Partie déjà terminée: $gameId');
        return;
      }

      final blueScore = game.scores[game.player1Id] ?? 0;
      final redScore = game.scores[game.player2Id] ?? 0;
      
      String? winnerId;
      GameEndReason endReason;

      if (blueScore > redScore) {
        winnerId = game.player1Id;
        endReason = GameEndReason.timeUpWinBlue;
        print('🏆 Victoire bleu par temps: $blueScore vs $redScore');
      } else if (redScore > blueScore) {
        winnerId = game.player2Id;
        endReason = GameEndReason.timeUpWinRed;
        print('🏆 Victoire rouge par temps: $redScore vs $blueScore');
      } else {
        winnerId = null;
        endReason = GameEndReason.timeUpDraw;
        print('🤝 Match nul par temps: $blueScore - $redScore');
      }

      await finishGameWithReason(gameId, winnerId: winnerId, endReason: endReason);
      print('✅ Fin de partie par temps traitée: $gameId');
      
    } catch (e) {
      print('❌ Erreur fin de partie par temps: $e');
    }
  }

  /// Fin de partie par grille pleine
  static Future<void> _finishGameByGridFull(String gameId) async {
    try {
      print('🔲 Tentative fin de partie par grille pleine: $gameId');
      final gameDoc = await gamesCollection.doc(gameId).get();
      if (!gameDoc.exists) {
        print('❌ Partie non trouvée: $gameId');
        return;
      }

      final game = Game.fromMap(gameDoc.data() as Map<String, dynamic>);
      
      if (game.status == GameStatus.finished) {
        print('ℹ️ Partie déjà terminée: $gameId');
        return;
      }

      final blueScore = game.scores[game.player1Id] ?? 0;
      final redScore = game.scores[game.player2Id] ?? 0;
      
      String? winnerId;
      GameEndReason endReason;

      if (blueScore > redScore) {
        winnerId = game.player1Id;
        endReason = GameEndReason.gridFullWinBlue;
        print('🏆 Victoire bleu par grille pleine: $blueScore vs $redScore');
      } else if (redScore > blueScore) {
        winnerId = game.player2Id;
        endReason = GameEndReason.gridFullWinRed;
        print('🏆 Victoire rouge par grille pleine: $redScore vs $blueScore');
      } else {
        winnerId = null;
        endReason = GameEndReason.gridFullDraw;
        print('🤝 Match nul par grille pleine: $blueScore - $redScore');
      }

      await finishGameWithReason(gameId, winnerId: winnerId, endReason: endReason);
      print('✅ Fin de partie par grille pleine traitée: $gameId');
    } catch (e) {
      print('❌ Erreur fin de partie par grille pleine: $e');
    }
  }

/// Fin de partie par tours manqués - VERSION COMPLÈTEMENT CORRIGÉE
static Future<void> _finishGameByMissedTurns(String gameId, String playerWhoMissed) async {
  try {
    print('🎯 DÉBUT _finishGameByMissedTurns pour $playerWhoMissed');
    
    // 🎯 RÉCUPÉRER LA PARTIE ACTUALISÉE
    final gameDoc = await gamesCollection.doc(gameId).get();
    if (!gameDoc.exists) {
      print('❌ Partie non trouvée: $gameId');
      return;
    }

    final game = Game.fromMap(gameDoc.data() as Map<String, dynamic>);
    
    // 🚫 VÉRIFIER QUE LA PARTIE N'EST PAS DÉJÀ TERMINÉE
    if (game.status == GameStatus.finished) {
      print('ℹ️ Partie déjà terminée: $gameId');
      return;
    }

    print('🔍 État de la partie AVANT transfert:');
    print('  - Player1 (${game.player1Id}): ${game.scores[game.player1Id]} points');
    print('  - Player2 (${game.player2Id}): ${game.scores[game.player2Id]} points');
    print('  - Joueur qui a manqué: $playerWhoMissed');

    // 🎯 IDENTIFIER LE GAGNANT (l'adversaire)
    final winnerId = playerWhoMissed == game.player1Id ? game.player2Id : game.player1Id;
    
    if (winnerId == null) {
      print('❌ Impossible de déterminer le gagnant');
      return;
    }

    // 🎯 CALCULER LES NOUVEAUX SCORES
    final loserScore = game.scores[playerWhoMissed] ?? 0;
    final winnerScore = game.scores[winnerId] ?? 0;
    final newWinnerScore = winnerScore + loserScore + 1;
    
    print('💰 CALCUL SCORES:');
    print('  - Score gagnant initial: $winnerScore');
    print('  - Score perdant: $loserScore');
    print('  - Score gagnant final: $newWinnerScore (avec bonus +1)');

    // 🎯 CRÉER LES SCORES FINAUX
    final finalScores = {
      winnerId: newWinnerScore,
      playerWhoMissed: 0, // 🎯 PERDANT À 0 POINTS
    };

    print('🏆 SCORES FINAUX: $finalScores');

    // 🎯 METTRE À JOUR LA PARTIE EN UNE SEULE OPÉRATION ATOMIQUE
    final updateData = {
      'scores': finalScores,
      'status': GameStatus.finished.toString(),
      'winnerId': winnerId,
      'endReason': GameEndReason.consecutiveMissedTurns.toString(),
      'finishedAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    print('📝 MISE À JOUR FIRESTORE: $updateData');

    // 🎯 UNE SEULE OPÉRATION POUR TOUT METTRE À JOUR
    await gamesCollection.doc(gameId).update(updateData);
    print('✅ Partie mise à jour dans Firestore');

    // 🎯 ATTENDRE LA SYNCHRONISATION PUIS RÉCUPÉRER LA PARTIE MISE À JOUR
    await Future.delayed(Duration(milliseconds: 500));
    
    final updatedGameDoc = await gamesCollection.doc(gameId).get();
    final updatedGame = Game.fromMap(updatedGameDoc.data() as Map<String, dynamic>);
    
    print('🔍 État de la partie APRÈS transfert:');
    print('  - Player1 (${updatedGame.player1Id}): ${updatedGame.scores[updatedGame.player1Id]} points');
    print('  - Player2 (${updatedGame.player2Id}): ${updatedGame.scores[updatedGame.player2Id]} points');
    print('  - Status: ${updatedGame.status}');
    print('  - Gagnant: ${updatedGame.winnerId}');

    // 🎯 SAUVEGARDER LES RÉSULTATS AVEC LA PARTIE MISE À JOUR
    if (updatedGame.status == GameStatus.finished) {
      await _saveGameResults(updatedGame);
      print('✅ Résultats sauvegardés avec les scores transférés');
    } else {
      print('❌ ERREUR: La partie n\'est pas marquée comme terminée après update!');
    }

  } catch (e) {
    print('❌ Erreur critique dans _finishGameByMissedTurns: $e');
    print('❌ Stack trace: ${e.toString()}');
  }
}

// ============================================================
  // GESTION DES SPECTATEURS
  // ============================================================

//   /// Récupérer les spectateurs d'une partie en temps réel
//   static Stream<List<String>> getGameSpectators(String gameId) {
//     return gamesCollection.doc(gameId).snapshots().map((snapshot) {
//       if (snapshot.exists) {
//         final data = snapshot.data() as Map<String, dynamic>;
//         return List<String>.from(data['spectators'] ?? []);
//       }
//       return [];
//     });
//   }

//   /// Récupérer les informations des spectateurs avec leurs profils
//   static Stream<List<Player>> getSpectatorsWithProfiles(String gameId) {
//     return getGameSpectators(gameId).asyncMap((spectatorIds) async {
//       final spectators = <Player>[];
//       for (final id in spectatorIds) {
//         final player = await getPlayer(id);
//         if (player != null) {
//           spectators.add(player);
//         }
//       }
//       return spectators;
//     });
//   }

//   /// Rejoindre une partie en tant que spectateur
//   static Future<void> joinAsSpectator(String gameId, String userId) async {
//     try {
//       final gameDoc = await gamesCollection.doc(gameId).get();
//       if (!gameDoc.exists) throw Exception('Partie non trouvée');

//       final game = Game.fromMap(gameDoc.data() as Map<String, dynamic>);
      
//       if (!(game.gameSettings['allowSpectators'] ?? false)) {
//         throw Exception('Les spectateurs ne sont pas autorisés pour cette partie');
//       }

//       final maxSpectators = game.gameSettings['maxSpectators'] ?? 50;
//       if (game.spectators.length >= maxSpectators) {
//         throw Exception('Limite de spectateurs atteinte');
//       }

//       if (game.players.contains(userId)) {
//         throw Exception('Vous êtes déjà dans cette partie');
//       }

//       if (game.spectators.contains(userId)) {
//         throw Exception('Vous observez déjà cette partie');
//       }

//       await gamesCollection.doc(gameId).update({
//         'spectators': FieldValue.arrayUnion([userId]),
//         'updatedAt': DateTime.now().millisecondsSinceEpoch,
//       });

//       await spectatorsCollection.doc(gameId).set({
//         'gameId': gameId,
//         'spectators': FieldValue.arrayUnion([userId]),
//         'updatedAt': DateTime.now().millisecondsSinceEpoch,
//       }, SetOptions(merge: true));
//     } catch (e) {
//       throw Exception('Erreur rejoindre spectateur: $e');
//     }
//   }

// /// Quitter une partie en tant que spectateur
// static Future<void> leaveAsSpectator(String gameId, String userId) async {
//   try {
//     // Mettre à jour le document de jeu
//     await gamesCollection.doc(gameId).update({
//       'spectators': FieldValue.arrayRemove([userId]),
//       'updatedAt': DateTime.now().millisecondsSinceEpoch,
//     });

//     // Mettre à jour la collection spectateurs avec gestion d'erreur
//     try {
//       final spectatorDoc = await spectatorsCollection.doc(gameId).get();
//       if (spectatorDoc.exists) {
//         await spectatorsCollection.doc(gameId).update({
//           'spectators': FieldValue.arrayRemove([userId]),
//           'updatedAt': DateTime.now().millisecondsSinceEpoch,
//         });
//       } else {
//         print('ℹ️ Document spectateurs non trouvé, création non nécessaire');
//       }
//     } catch (e) {
//       print('⚠️ Erreur document spectateurs: $e');
//     }
//   } catch (e) {
//     print('❌ Erreur quitter spectateur: $e');
//     // Ne pas relancer l'exception pour éviter les crashs
//   }
// }
  
  // ============================================================
  // RÉCUPÉRATION DES PARTIES - STREAMS OPTIMISÉS
  // ============================================================

  /// Récupérer une partie par ID avec gestion d'erreur
  static Stream<Game?> getGameById(String gameId) {
    return gamesCollection
        .doc(gameId)
        .snapshots()
        .handleError((error) => print('Erreur stream partie: $error'))
        .map((snapshot) {
          if (snapshot.exists) {
            try {
              return Game.fromMap(snapshot.data() as Map<String, dynamic>);
            } catch (e) {
              print('Erreur parsing partie: $e');
              return null;
            }
          }
          return null;
        });
  }

  /// Récupérer les parties actives de l'utilisateur avec userId explicite
  static Stream<List<Game>> getMyActiveGames(String userId) {
    return gamesCollection
        .where('players', arrayContains: userId)
        .where('status', whereIn: [
          GameStatus.playing.toString(),
          GameStatus.waiting.toString(),
        ])
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .handleError((error) => print('Erreur stream mes parties: $error'))
        .map((snapshot) => snapshot.docs
            .map((doc) {
              try {
                return Game.fromMap(doc.data() as Map<String, dynamic>);
              } catch (e) {
                print('Erreur parsing partie: $e');
                return null;
              }
            })
            .where((game) => game != null)
            .cast<Game>()
            .toList());
  }

  /// Récupérer toutes les parties publiques actives
  // static Stream<List<Game>> getAllActiveGames() {
  //   return gamesCollection
  //       .where('status', isEqualTo: GameStatus.playing.toString())
  //       .where('gameSettings.allowSpectators', isEqualTo: true)
  //       .orderBy('updatedAt', descending: true)
  //       .limit(50)
  //       .snapshots()
  //       .handleError((error) => print('Erreur stream parties publiques: $error'))
  //       .map((snapshot) => snapshot.docs
  //           .map((doc) {
  //             try {
  //               return Game.fromMap(doc.data() as Map<String, dynamic>);
  //             } catch (e) {
  //               print('Erreur parsing partie publique: $e');
  //               return null;
  //             }
  //           })
  //           .where((game) => game != null)
  //           .cast<Game>()
  //           .toList());
  // }

  /// Récupérer l'historique des parties
  static Stream<List<Game>> getGameHistory({int limit = 20}) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return gamesCollection
        .where('players', arrayContains: currentUserId)
        .where('status', isEqualTo: GameStatus.finished.toString())
        .orderBy('finishedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Game.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // ============================================================
  // GESTION DES DEMANDES DE MATCH
  // ============================================================

  /// Récupérer les demandes de match reçues
  static Stream<List<MatchRequest>> getReceivedMatchRequests(String userId) {
    return matchRequestsCollection
        .where('toUserId', isEqualTo: userId)
        .where('status', whereIn: [
          MatchRequestStatus.pending.toString(),
          MatchRequestStatus.accepted.toString(),
        ])
        .orderBy('createdAt', descending: true)
        .limit(10) 
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MatchRequest.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Récupérer les demandes de match envoyées
  static Stream<List<MatchRequest>> getSentMatchRequests(String userId) {
    return matchRequestsCollection
        .where('fromUserId', isEqualTo: userId)
        .where('status', whereIn: [
          MatchRequestStatus.pending.toString(),
          MatchRequestStatus.accepted.toString(),
        ])
        .orderBy('createdAt', descending: true)
        .limit(10) 
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MatchRequest.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }
  

 static bool _isRequestExpired(dynamic request) {
    final now = DateTime.now();
    
    // CORRECTION: Vérifier si createdAt est un Timestamp ou DateTime
    DateTime createdAt;
    if (request.createdAt is Timestamp) {
      createdAt = (request.createdAt as Timestamp).toDate();
    } else if (request.createdAt is DateTime) {
      createdAt = request.createdAt as DateTime;
    } else {
      // Si c'est un int (millisecondsSinceEpoch)
      createdAt = DateTime.fromMillisecondsSinceEpoch(request.createdAt);
    }
    
    final difference = now.difference(createdAt).inHours;
    return difference >= 24;
  }

/// Envoyer une demande de match avec notification
static Future<void> sendMatchRequest(MatchRequest request) async {
  try {
    // Vérifier s'il existe une demande PENDING NON EXPIRÉE entre ces joueurs
    final existingRequests = await matchRequestsCollection
        .where('fromUserId', isEqualTo: request.fromUserId)
        .where('toUserId', isEqualTo: request.toUserId)
        .where('status', isEqualTo: MatchRequestStatus.pending.toString())
        .get();

    // Vérifier si une des demandes existantes n'est pas expirée
    final hasValidPendingRequest = existingRequests.docs.any((doc) {
            final data = doc.data() as Map<String, dynamic>; // Conversion explicite
      final existingRequest = MatchRequest.fromMap(data);
      return !_isRequestExpired(existingRequest);
    });

    if (hasValidPendingRequest) {
      throw Exception('Vous avez déjà une demande en attente avec ce joueur');
    }

    await matchRequestsCollection.doc(request.id).set(request.toMap());
    await _sendMatchRequestNotification(request);
  } catch (e) {
    throw Exception('Erreur envoi demande: $e');
  }
}

/// Accepter une demande de match avec userId - AVEC LOADER
static Future<Game> acceptMatchRequest(String requestId, String currentUserId) async {
  try {
    print('🔄 Début acceptation demande $requestId par $currentUserId');
    
    final requestDoc = await matchRequestsCollection.doc(requestId).get();
    if (!requestDoc.exists) throw Exception('Demande non trouvée');

    final request = MatchRequest.fromMap(requestDoc.data() as Map<String, dynamic>);
    
    if (request.toUserId != currentUserId) {
      throw Exception('Vous ne pouvez pas accepter cette demande');
    }
    
    if (GameService.isMatchRequestExpired(request)) {
      throw Exception('Cette demande de match a expiré');
    }

    // 🆕 MARQUER LA DEMANDE COMME ACCEPTÉE
    await matchRequestsCollection.doc(requestId).update({
      'status': MatchRequestStatus.accepted.toString(),
      'respondedAt': DateTime.now().millisecondsSinceEpoch,
    });

    // 🆕 CRÉER LA PARTIE
    final gameId = generateId();
    final game = Game(
      id: gameId,
      players: [request.fromUserId, request.toUserId],
      currentPlayer: request.fromUserId,
      scores: {request.fromUserId: 0, request.toUserId: 0},
      gridSize: request.gridSize,
      points: [],
      squares: [],
      status: GameStatus.playing,
      player1Id: request.fromUserId,
      player2Id: request.toUserId,
      isAgainstAI: false,
      gameDuration: request.gameDuration,
      reflexionTime: request.reflexionTime,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      startedAt: DateTime.now(),
      timeRemaining: request.gameDuration,
      reflexionTimeRemaining: {
        request.fromUserId: request.reflexionTime,
        request.toUserId: request.reflexionTime,
      },
      consecutiveMissedTurns: {
        request.fromUserId: 0,
        request.toUserId: 0,
      },
      gameSettings: {
        'allowSpectators': true,
        'isRanked': true,
        'maxSpectators': 50,
      },
    );

    print('🎮 Création de la partie $gameId...');
    await createGame(game);
    print('✅ Partie créée avec succès');

    // 🆕 ENVOYER LES NOTIFICATIONS (en arrière-plan, ne pas bloquer)
    _sendMatchAcceptedNotification(request, gameId);
    _sendGameStartedNotification(request, gameId);

    return game;
  } catch (e) {
    print('❌ Erreur acceptation demande: $e');
    throw Exception('Erreur acceptation demande: $e');
  }
}
  /// Refuser une demande de match avec userId
  static Future<void> rejectMatchRequest(String requestId, String currentUserId, {String reason = 'Refusé par le joueur'}) async {
    try {
      final requestDoc = await matchRequestsCollection.doc(requestId).get();
      if (!requestDoc.exists) throw Exception('Demande non trouvée');

      final request = MatchRequest.fromMap(requestDoc.data() as Map<String, dynamic>);
      
      if (request.toUserId != currentUserId) {
        throw Exception('Vous ne pouvez pas refuser cette demande');
      }

      await matchRequestsCollection.doc(requestId).update({
        'status': MatchRequestStatus.declined.toString(),
        'declinedReason': reason,
        'respondedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await _sendMatchRejectedNotification(request, reason);
    } catch (e) {
      throw Exception('Erreur refus demande: $e');
    }
  }

  /// Annuler une demande de match avec userId
  static Future<void> cancelMatchRequest(String requestId, String currentUserId) async {
    try {
      final requestDoc = await matchRequestsCollection.doc(requestId).get();
      if (!requestDoc.exists) throw Exception('Demande non trouvée');

      final request = MatchRequest.fromMap(requestDoc.data() as Map<String, dynamic>);
      
      if (request.fromUserId != currentUserId) {
        throw Exception('Vous ne pouvez pas annuler cette demande');
      }

      await matchRequestsCollection.doc(requestId).update({
        'status': MatchRequestStatus.cancelled.toString(),
        'respondedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Erreur annulation demande: $e');
    }
  }

  // ============================================================
// MÉTHODE POUR RÉCUPÉRER TOUTES LES DEMANDES DE MATCH
// ============================================================

/// Récupérer toutes les demandes de match (reçues et envoyées) pour un utilisateur
static Stream<List<dynamic>> getMatchRequests(String userId) {
  return matchRequestsCollection
      .where('status', whereIn: [
        MatchRequestStatus.pending.toString(),
        MatchRequestStatus.accepted.toString(),
        MatchRequestStatus.declined.toString(),
      ])
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .handleError((error) => print('Erreur stream demandes de match: $error'))
      .map((snapshot) {
        final requests = <dynamic>[];
        
        for (final doc in snapshot.docs) {
          try {
            final request = MatchRequest.fromMap(doc.data() as Map<String, dynamic>);
            
            // Filtrer pour n'inclure que les demandes de l'utilisateur courant
            if (request.fromUserId == userId || request.toUserId == userId) {
              requests.add(request);
            }
          } catch (e) {
            print('Erreur parsing demande de match: $e');
          }
        }
        
        return requests;
      });
}

/// Récupérer les demandes de match avec les informations des joueurs
static Stream<List<Map<String, dynamic>>> getMatchRequestsWithPlayers(String userId) {
  return getMatchRequests(userId).asyncMap((requests) async {
    final requestsWithPlayers = <Map<String, dynamic>>[];
    
    for (final request in requests) {
      try {
        final opponentId = request.fromUserId == userId ? request.toUserId : request.fromUserId;
        final opponent = await getPlayer(opponentId);
        
        requestsWithPlayers.add({
          'request': request,
          'opponent': opponent,
          'isMyRequest': request.fromUserId == userId,
        });
      } catch (e) {
        print('Erreur récupération joueur pour demande: $e');
      }
    }
    
    return requestsWithPlayers;
  });
}

/// Vérifier si une demande de match existe déjà entre deux joueurs
static Future<bool> checkExistingMatchRequest(String fromUserId, String toUserId) async {
  try {
    final existingRequest = await matchRequestsCollection
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: MatchRequestStatus.pending.toString())
        .limit(1)
        .get();

    return existingRequest.docs.isNotEmpty;
  } catch (e) {
    print('Erreur vérification demande existante: $e');
    return false;
  }
}

/// Récupérer le nombre de demandes en attente
static Stream<int> getPendingRequestsCount(String userId) {
  return matchRequestsCollection
      .where('toUserId', isEqualTo: userId)
      .where('status', isEqualTo: MatchRequestStatus.pending.toString())
      .orderBy('createdAt', descending: true)
      .limit(10) //
      .snapshots()
      .map((snapshot) => snapshot.docs.length)
      .handleError((error) {
        print('Erreur stream compteur demandes: $error');
        return 0;
      });
}

  // ============================================================
  // GESTION DES RÉSULTATS ET STATISTIQUES - CORRECTIONS APPLIQUÉES
  // ============================================================

  /// Sauvegarder le résultat d'une partie
static Future<void> saveGameResult(GameResult result) async {
  try {
    print('💾 Début sauvegarde GameResult pour ${result.userId}: ${result.outcome}');
    
    // GÉNÉRER UN ID UNIQUE POUR LE RÉSULTAT
    final resultId = generateId();
    
    await gameResultsCollection.doc(resultId).set(result.toMap());
    
    // METTRE À JOUR LES STATS (optionnel)
    try {
      await _updatePlayerStats(result);
    } catch (e) {
      print('⚠️ Erreur stats non critique: $e');
    }
    
    print('✅ GameResult sauvegardé avec succès pour ${result.userId}');
  } catch (e) {
    print('❌ Erreur sauvegarde GameResult: $e');
    // NE PAS RELANCER POUR ÉVITER DE BLOQUER LE PROCESSUS
  }
}

  /// Mettre à jour les statistiques du joueur
  static Future<void> _updatePlayerStats(GameResult result) async {
    try {
      print('📊 Mise à jour stats pour ${result.userId}');
      final userDoc = await usersCollection.doc(result.userId).get();
      if (!userDoc.exists) {
        print('❌ Utilisateur non trouvé: ${result.userId}');
        return;
      }

      final player = Player.fromMap(userDoc.data() as Map<String, dynamic>);
      final isWin = result.outcome == GameOutcome.win;
      final isDraw = result.outcome == GameOutcome.draw;

      final updates = <String, dynamic>{
        'totalPoints': player.totalPoints + result.pointsScored,
        'gamesPlayed': FieldValue.increment(1),
        'gamesWon': FieldValue.increment(isWin ? 1 : 0),
        'gamesLost': FieldValue.increment(!isWin && !isDraw ? 1 : 0),
        'gamesDraw': FieldValue.increment(isDraw ? 1 : 0),
        'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (isWin) {
        final newWinStreak = (player.stats.winStreak) + 1;
        updates['stats.winStreak'] = newWinStreak;
        if (newWinStreak > player.stats.bestWinStreak) {
          updates['stats.bestWinStreak'] = newWinStreak;
        }
        print('🏆 Victoire détectée - Série: $newWinStreak');
      } else {
        updates['stats.winStreak'] = 0;
        print('💔 Défaite ou nul - Série remise à 0');
      }

      if (result.pointsScored > player.stats.bestGamePoints) {
        updates['stats.bestGamePoints'] = result.pointsScored;
        print('🎯 Nouveau record de points: ${result.pointsScored}');
      }

      final now = DateTime.now();
      // updates['stats.dailyPoints'] = player.stats.dailyPoints + result.pointsScored;
      // updates['stats.weeklyPoints'] = player.stats.weeklyPoints + result.pointsScored;
      // updates['stats.monthlyPoints'] = player.stats.monthlyPoints + result.pointsScored;

      await usersCollection.doc(result.userId).update(updates);
      print('✅ Stats mises à jour pour ${result.userId}');
    } catch (e) {
      print('❌ Erreur mise à jour stats: $e');
    }
  }

/// Sauvegarder les résultats de tous les joueurs d'une partie
static Future<void> _saveGameResults(Game game) async {
  try {
    print('💾 Début sauvegarde résultats pour partie ${game.id}');
    
    // 🎯 AJOUT DE LOGS POUR DEBUG
    print('🔍 Données de la partie:');
    print('  - winnerId: ${game.winnerId}');
    print('  - player1Id: ${game.player1Id}, score: ${game.scores[game.player1Id]}');
    print('  - player2Id: ${game.player2Id}, score: ${game.scores[game.player2Id]}');
    print('  - endReason: ${game.endReason}');
    print('  - status: ${game.status}');
    
    // VÉRIFIER QUE LA PARTIE A BIEN UN WINNER_ID
    final winnerId = game.winnerId;
    final isDraw = winnerId == null;
    
    print('🏆 WinnerId: $winnerId, Draw: $isDraw');
    
    for (final playerId in game.players) {
      if (playerId.startsWith('ai_')) {
        print('🤖 Ignoré IA: $playerId');
        continue;
      }

      final playerScore = game.scores[playerId] ?? 0;
      
      // DÉTERMINER L'OUTCOME CORRECTEMENT
      final GameOutcome outcome;
      if (isDraw) {
        outcome = GameOutcome.draw;
      } else if (playerId == winnerId) {
        outcome = GameOutcome.win;
      } else {
        outcome = GameOutcome.loss;
      }

      print('👤 Traitement joueur $playerId: score=$playerScore, outcome=$outcome');

      final result = GameResult(
        userId: playerId,
        gameId: game.id,
        pointsScored: playerScore,
        outcome: outcome,
        playedAt: game.finishedAt ?? DateTime.now(),
        opponentId: _getOpponentId(game, playerId),
        gridSize: game.gridSize,
      );

      await saveGameResult(result);
    }
    
    print('✅ Tous les résultats sauvegardés pour partie ${game.id}');
        // 🎯 METTRE À JOUR LES RANGS APRÈS LA PARTIE
    await RankingService.updateRanksAfterGame(game.players);
    
    print('✅ Rangs mis à jour après la partie');
  } catch (e) {
    print('❌ Erreur sauvegarde résultats: $e');
  }
} 
  // ============================================================
  // FONCTIONS UTILITAIRES
  // ============================================================

  /// Obtenir l'ID de l'adversaire
static String? _getOpponentId(Game game, String currentPlayerId) {
  if (game.players.length < 2) return null;
  
  for (final playerId in game.players) {
    if (playerId != currentPlayerId && !playerId.startsWith('ai_')) {
      return playerId;
    }
  }
  return null;
}

  /// Vérifier si une demande de match est expirée
  static bool isMatchRequestExpired(MatchRequest request) {
    return request.expiresAt != null && 
           DateTime.now().isAfter(request.expiresAt!);
  }

  /// Générer un ID unique
  static String generateId() {
    return _firestore.collection('temp').doc().id;
  }

  /// Récupérer les informations d'un joueur
  static Future<Player?> getPlayer(String userId) async {
    try {
      final doc = await usersCollection.doc(userId).get();
      if (doc.exists) {
        return Player.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Erreur récupération joueur: $e');
      return null;
    }
  }

  // ============================================================
  // FONCTIONS PRIVÉES
  // ============================================================

  /// Obtenir le prochain joueur (CORRIGÉ)
  static String _getNextPlayerId(Game game, String currentPlayerId) {
    if (game.player1Id == currentPlayerId) {
      return game.player2Id!;
    } else {
      return game.player1Id!;
    }
  }

  /// Mettre à jour le statut de jeu d'un joueur
  static Future<void> _updatePlayerGameStatus(String playerId, bool inGame, String? gameId) async {
    try {
      final updates = <String, dynamic>{
        'inGame': inGame,
        'currentGameId': gameId,
        'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (!inGame) {
        updates['currentGameId'] = null;
      }

      await usersCollection.doc(playerId).update(updates);
    } catch (e) {
      print('Erreur mise à jour statut jeu: $e');
    }
  }

  /// Envoyer une notification de demande de match
  static Future<void> _sendMatchRequestNotification(MatchRequest request) async {
    try {
      final fromUser = await getPlayer(request.fromUserId);
      if (fromUser == null) return;

      await notificationsCollection.add({
        'userId': request.toUserId,
        'title': 'Nouveau défi ! 🎮',
        'message': '${fromUser.username} vous a défié sur une grille ${request.gridSize}×${request.gridSize}',
        'type': 'match_request',
        'data': {
          'requestId': request.id,
          'fromUserId': request.fromUserId,
          'fromUsername': fromUser.username,
          'gridSize': request.gridSize,
          'gameDuration': request.gameDuration,
        },
        'isRead': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Erreur notification demande: $e');
    }
  }

  /// Envoyer une notification d'acceptation
  static Future<void> _sendMatchAcceptedNotification(MatchRequest request, String gameId) async {
    try {
      final toUser = await getPlayer(request.toUserId);
      if (toUser == null) return;

      await notificationsCollection.add({
        'userId': request.fromUserId,
        'title': 'Défi accepté ! ✅',
        'message': '${toUser.username} a accepté votre défi',
        'type': 'match_accepted',
        'data': {
          'gameId': gameId,
          'opponentId': request.toUserId,
          'opponentUsername': toUser.username,
        },
        'isRead': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Erreur notification acceptation: $e');
    }
  }

  /// Envoyer une notification de début de jeu
  static Future<void> _sendGameStartedNotification(MatchRequest request, String gameId) async {
    try {
      final toUser = await getPlayer(request.toUserId);
      if (toUser == null) return;

      await notificationsCollection.add({
        'userId': request.fromUserId,
        'title': 'Défi accepté ! 🎮',
        'message': '${toUser.username} a accepté votre défi - La partie commence !',
        'type': 'game_started',
        'data': {
          'gameId': gameId,
          'opponentId': request.toUserId,
          'opponentUsername': toUser.username,
          'gridSize': request.gridSize,
          'gameDuration': request.gameDuration,
          'reflexionTime': request.reflexionTime,
        },
        'isRead': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Erreur notification début jeu: $e');
    }
  }

  /// Envoyer une notification de refus
  static Future<void> _sendMatchRejectedNotification(MatchRequest request, String reason) async {
    try {
      final toUser = await getPlayer(request.toUserId);
      if (toUser == null) return;

      await notificationsCollection.add({
        'userId': request.fromUserId,
        'title': 'Défi refusé ❌',
        'message': '${toUser.username} a refusé votre défi${reason.isNotEmpty ? ': $reason' : ''}',
        'type': 'match_rejected',
        'data': {
          'opponentId': request.toUserId,
          'opponentUsername': toUser.username,
          'reason': reason,
        },
        'isRead': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Erreur notification refus: $e');
    }
  }

  // ============================================================
// MÉTHODE POUR L'ABANDON AVEC MISE À JOUR DES SCORES
// ============================================================

/// Mettre à jour les scores d'une partie
static Future<void> updateGameScores(String gameId, Map<String, int> newScores) async {
  try {
    await gamesCollection.doc(gameId).update({
      'scores': newScores,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    print('✅ Scores mis à jour pour partie $gameId: $newScores');
  } catch (e) {
    print('❌ Erreur mise à jour scores: $e');
    throw Exception('Erreur mise à jour scores: $e');
  }
}

// ============================================================
// GESTION DES MESSAGES RAPIDES - SYNCHRONISATION FIREBASE
// ============================================================

/// Envoyer un message rapide
static Future<void> sendQuickMessage(String gameId, String message, String senderId, String senderName) async {
  try {
    final messagesRef = gamesCollection.doc(gameId).collection('quickMessages').doc();
    
    await messagesRef.set({
      'text': message,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now().add(Duration(seconds: 10)).millisecondsSinceEpoch, // Auto-nettoyage
    });
    
    print('💬 Message rapide envoyé: "$message" par $senderName');
  } catch (e) {
    print('❌ Erreur envoi message rapide: $e');
  }
}

/// Écouter les messages rapides d'une partie
static Stream<Map<String, dynamic>> getQuickMessages(String gameId) {
  return gamesCollection
      .doc(gameId)
      .collection('quickMessages')
      .orderBy('timestamp', descending: true)
      .limit(1) // Seulement le dernier message
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          final data = doc.data();
          
          // Vérifier si le message n'est pas expiré
          final expiresAt = data['expiresAt'] as int?;
          if (expiresAt != null && DateTime.now().millisecondsSinceEpoch > expiresAt) {
            return {};
          }
          
          return data;
        }
        return {};
      });
}

// Dans GameService
static Future<void> checkAndPenalizeInactivePlayers(String gameId) async {
  try {
    final gameDoc = await gamesCollection.doc(gameId).get();
    if (!gameDoc.exists) return;
    
    final game = Game.fromMap(gameDoc.data() as Map<String, dynamic>);
    if (game.status == GameStatus.finished) return;
    
    final lastPoint = game.points.isNotEmpty ? game.points.last : null;
    if (lastPoint == null) return;

    // 🆕 CORRECTION : GESTION SÉCURISÉE DU TIMESTAMP
    final lastMoveTimestamp = _getSafeTimestamp(lastPoint);
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeSinceLastMove = (now - lastMoveTimestamp) ~/ 1000;
    
    print('🔍 Vérification inactivité: $timeSinceLastMove secondes depuis dernier coup');
    
    if (timeSinceLastMove >= 45) {
      final currentPlayerId = game.currentPlayer;
      print('⏰🚨 JOUEUR INACTIF DÉTECTÉ: $currentPlayerId ($timeSinceLastMove secondes)');
      
      await _finishGameByInactivity(gameId, currentPlayerId);
    }
  } catch (e) {
    print('❌ Erreur vérification inactivité: $e');
  }
}

// 🆕 MÉTHODE UTILITAIRE POUR OBTENIR UN TIMESTAMP SÉCURISÉ
static int _getSafeTimestamp(GridPoint point) {

  try {
    // Vérifier le type du timestamp et le convertir en int
    if (point.timestamp is bool) {
      return point.timestamp;
    } else if (point.timestamp is String) {
      return int.tryParse(point.timestamp as String) ?? DateTime.now().millisecondsSinceEpoch;
    } else if (point.timestamp is double) {
      return (point.timestamp as double).round();
    } else {
      print('⚠️ Type de timestamp non géré: ${point.timestamp.runtimeType}');
      return DateTime.now().millisecondsSinceEpoch;
    }
  } catch (e) {
    print('⚠️ Erreur conversion timestamp: $e');
    return DateTime.now().millisecondsSinceEpoch;
  }
}

static Future<void> _finishGameByInactivity(String gameId, String inactivePlayerId) async {
  try {
    print('🎯 DÉBUT _finishGameByInactivity pour $inactivePlayerId');
    
    // 🎯 RÉCUPÉRER LA PARTIE ACTUALISÉE
    final gameDoc = await gamesCollection.doc(gameId).get();
    if (!gameDoc.exists) {
      print('❌ Partie non trouvée: $gameId');
      return;
    }

    final game = Game.fromMap(gameDoc.data() as Map<String, dynamic>);
    
    // 🚫 VÉRIFIER QUE LA PARTIE N'EST PAS DÉJÀ TERMINÉE
    if (game.status == GameStatus.finished) {
      print('ℹ️ Partie déjà terminée: $gameId');
      return;
    }

    print('🔍 État de la partie AVANT transfert:');
    print('  - Player1 (${game.player1Id}): ${game.scores[game.player1Id]} points');
    print('  - Player2 (${game.player2Id}): ${game.scores[game.player2Id]} points');
    print('  - Joueur inactif: $inactivePlayerId');

    // 🎯 IDENTIFIER LE GAGNANT (l'adversaire)
    final winnerId = inactivePlayerId == game.player1Id ? game.player2Id : game.player1Id;
    
    if (winnerId == null) {
      print('❌ Impossible de déterminer le gagnant');
      return;
    }

    // 🎯 CALCULER LES NOUVEAUX SCORES (MÊME LOGIQUE QUE 3 TOURS MANQUÉS)
    final loserScore = game.scores[inactivePlayerId] ?? 0;
    final winnerScore = game.scores[winnerId] ?? 0;
    final newWinnerScore = winnerScore + loserScore + 1; // +1 point bonus
    
    print('💰 CALCUL SCORES:');
    print('  - Score gagnant initial: $winnerScore');
    print('  - Score perdant: $loserScore');
    print('  - Score gagnant final: $newWinnerScore (avec bonus +1)');

    // 🎯 CRÉER LES SCORES FINAUX
    final finalScores = {
      winnerId: newWinnerScore,
      inactivePlayerId: 0, // 🎯 PERDANT À 0 POINTS
    };

    print('🏆 SCORES FINAUX: $finalScores');

    // 🎯 METTRE À JOUR LA PARTIE EN UNE SEULE OPÉRATION ATOMIQUE
    final updateData = {
      'scores': finalScores,
      'status': GameStatus.finished.toString(),
      'winnerId': winnerId,
      'endReason': GameEndReason.timeout.toString(), // 🆕 RAISON "TIMEOUT"
      'finishedAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    print('📝 MISE À JOUR FIRESTORE: $updateData');

    // 🎯 UNE SEULE OPÉRATION POUR TOUT METTRE À JOUR
    await gamesCollection.doc(gameId).update(updateData);
    print('✅ Partie mise à jour dans Firestore');

    // 🎯 ATTENDRE LA SYNCHRONISATION PUIS RÉCUPÉRER LA PARTIE MISE À JOUR
    await Future.delayed(Duration(milliseconds: 500));
    
    final updatedGameDoc = await gamesCollection.doc(gameId).get();
    final updatedGame = Game.fromMap(updatedGameDoc.data() as Map<String, dynamic>);
    
    print('🔍 État de la partie APRÈS transfert:');
    print('  - Player1 (${updatedGame.player1Id}): ${updatedGame.scores[updatedGame.player1Id]} points');
    print('  - Player2 (${updatedGame.player2Id}): ${updatedGame.scores[updatedGame.player2Id]} points');
    print('  - Status: ${updatedGame.status}');
    print('  - Gagnant: ${updatedGame.winnerId}');

    // 🎯 SAUVEGARDER LES RÉSULTATS AVEC LA PARTIE MISE À JOUR
    if (updatedGame.status == GameStatus.finished) {
      await _saveGameResults(updatedGame);
      print('✅ Résultats sauvegardés avec les scores transférés');
    } else {
      print('❌ ERREUR: La partie n\'est pas marquée comme terminée après update!');
    }

  } catch (e) {
    print('❌ Erreur critique dans _finishGameByInactivity: $e');
    print('❌ Stack trace: ${e.toString()}');
  }
}

}
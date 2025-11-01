import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeu_carre/models/game_model.dart';
import 'package:jeu_carre/models/game_request.dart';
import 'package:jeu_carre/models/game_result.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/models/ai_player.dart';

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
      });

      await _updatePlayerGameStatus(playerId, true, gameId);
    } catch (e) {
      throw Exception('Erreur rejoindre partie: $e');
    }
  }

    // NOUVEAU: Mettre à jour le temps de réflexion en temps réel
  static Future<void> updateReflexionTime(String gameId, String playerId, int timeRemaining) async {
    try {
      await gamesCollection.doc(gameId).update({
        'reflexionTimeRemaining.$playerId': timeRemaining,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Erreur mise à jour temps réflexion: $e');
    }
  }

  // NOUVEAU: Mettre à jour le temps global de la partie
  static Future<void> updateGameTime(String gameId, int timeRemaining) async {
    try {
      await gamesCollection.doc(gameId).update({
        'timeRemaining': timeRemaining,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Erreur mise à jour temps jeu: $e');
    }
  }

  // NOUVEAU: Changer de joueur
  static Future<void> switchPlayer(String gameId, String nextPlayerId) async {
    try {
      await gamesCollection.doc(gameId).update({
        'currentPlayer': nextPlayerId,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Erreur changement joueur: $e');
    }
  }


  /// Mettre à jour l'état d'une partie de manière optimisée
  static Future<void> updateGameState(String gameId, Game game) async {
    try {
      final updates = game.toMap();
      updates['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      
      await gamesCollection.doc(gameId).update(updates);
    } catch (e) {
      throw Exception('Erreur mise à jour partie: $e');
    }
  }

  /// Ajouter un point à la partie
  static Future<void> addPointToGame(String gameId, GridPoint point) async {
    try {
      await gamesCollection.doc(gameId).update({
        'points': FieldValue.arrayUnion([point.toMap()]),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'currentPlayer': _getNextPlayer(gameId, point.playerId!),
      });
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

  /// Terminer une partie
  static Future<void> finishGame(String gameId, {String? winnerId, GameEndReason? endReason}) async {
    try {
      final updates = {
        'status': GameStatus.finished.toString(),
        'finishedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (winnerId != null) {
        updates['winnerId'] = winnerId;
      }

      if (endReason != null) {
        updates['endReason'] = endReason.toString();
      }

      await gamesCollection.doc(gameId).update(updates);

      // Mettre à jour le statut des joueurs
      final gameDoc = await gamesCollection.doc(gameId).get();
      final game = Game.fromMap(gameDoc.data() as Map<String, dynamic>);
      
      for (final playerId in game.players) {
        await _updatePlayerGameStatus(playerId, false, null);
      }

      // Sauvegarder les résultats
      await _saveGameResults(game);
    } catch (e) {
      throw Exception('Erreur fin de partie: $e');
    }
  }

  // ============================================================
  // GESTION DES SPECTATEURS - NOUVELLES MÉTHODES
  // ============================================================

  /// Récupérer les spectateurs d'une partie en temps réel
  static Stream<List<String>> getGameSpectators(String gameId) {
    return gamesCollection.doc(gameId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        return List<String>.from(data['spectators'] ?? []);
      }
      return [];
    });
  }

  /// Récupérer les informations des spectateurs avec leurs profils
  static Stream<List<Player>> getSpectatorsWithProfiles(String gameId) {
    return getGameSpectators(gameId).asyncMap((spectatorIds) async {
      final spectators = <Player>[];
      for (final id in spectatorIds) {
        final player = await getPlayer(id);
        if (player != null) {
          spectators.add(player);
        }
      }
      return spectators;
    });
  }


  /// Quitter une partie en tant que spectateur
  static Future<void> leaveAsSpectator(String gameId, String userId) async {
    try {
      await gamesCollection.doc(gameId).update({
        'spectators': FieldValue.arrayRemove([userId]),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Retirer des spectateurs globaux
      await spectatorsCollection.doc(gameId).update({
        'spectators': FieldValue.arrayRemove([userId]),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Erreur quitter spectateur: $e');
    }
  }

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

  // ============================================================
// MÉTHODES SPÉCIFIQUES POUR MATCHSCREEN - À AJOUTER
// ============================================================

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

/// Récupérer les demandes de match reçues
static Stream<List<MatchRequest>> getReceivedMatchRequests(String userId) {
  return matchRequestsCollection
      .where('toUserId', isEqualTo: userId)
      .where('status', whereIn: [
        MatchRequestStatus.pending.toString(),
        MatchRequestStatus.accepted.toString(),
      ])
      .orderBy('createdAt', descending: true)
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
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => MatchRequest.fromMap(doc.data() as Map<String, dynamic>))
          .toList());
}

/// Accepter une demande de match avec userId
static Future<Game> acceptMatchRequest(String requestId, String currentUserId) async {
  try {
    final requestDoc = await matchRequestsCollection.doc(requestId).get();
    if (!requestDoc.exists) throw Exception('Demande non trouvée');

    final request = MatchRequest.fromMap(requestDoc.data() as Map<String, dynamic>);
    
    // Vérifications existantes...
    if (request.toUserId != currentUserId) {
      throw Exception('Vous ne pouvez pas accepter cette demande');
    }
    
    if (GameService.isMatchRequestExpired(request)) {
      throw Exception('Cette demande de match a expiré');
    }

    // Mettre à jour la demande
    await matchRequestsCollection.doc(requestId).update({
      'status': MatchRequestStatus.accepted.toString(),
      'respondedAt': DateTime.now().millisecondsSinceEpoch,
    });

    // Créer la partie
    final gameId = generateId();
    final game = Game(
      id: gameId,
      players: [request.fromUserId, request.toUserId],
      currentPlayer: request.fromUserId, // Celui qui a envoyé le défi commence
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
      gameSettings: {
        'allowSpectators': true,
        'isRanked': true,
        'maxSpectators': 50,
      },
    );

    await createGame(game);

    // 🔥 ENVOYER LES DEUX NOTIFICATIONS
    await _sendMatchAcceptedNotification(request, gameId); // Pour l'accepteur
    await _sendGameStartedNotification(request, gameId);   // 🔥 POUR LE DEMANDEUR

    return game;
  } catch (e) {
    throw Exception('Erreur acceptation demande: $e');
  }
}

/// Dans GameService - AJOUTER cette méthode
static Future<void> _sendGameStartedNotification(MatchRequest request, String gameId) async {
  try {
    final toUser = await getPlayer(request.toUserId);
    if (toUser == null) return;

    await notificationsCollection.add({
      'userId': request.fromUserId, // 🔥 Le demandeur reçoit la notification
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

    print('🔔 Notification de début de jeu envoyée à ${request.fromUserId}');
  } catch (e) {
    print('Erreur notification début jeu: $e');
  }
}


/// Refuser une demande de match avec userId
static Future<void> rejectMatchRequest(String requestId, String currentUserId, {String reason = 'Refusé par le joueur'}) async {
  try {
    final requestDoc = await matchRequestsCollection.doc(requestId).get();
    if (!requestDoc.exists) throw Exception('Demande non trouvée');

    final request = MatchRequest.fromMap(requestDoc.data() as Map<String, dynamic>);
    
    // Vérifier que l'utilisateur peut refuser cette demande
    if (request.toUserId != currentUserId) {
      throw Exception('Vous ne pouvez pas refuser cette demande');
    }

    await matchRequestsCollection.doc(requestId).update({
      'status': MatchRequestStatus.declined.toString(),
      'declinedReason': reason,
      'respondedAt': DateTime.now().millisecondsSinceEpoch,
    });

    // Envoyer une notification de refus
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
    
    // Vérifier que l'utilisateur peut annuler cette demande
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

/// Rejoindre une partie en tant que spectateur
static Future<void> joinAsSpectator(String gameId, String userId) async {
  try {
    // Vérifier que la partie existe
    final gameDoc = await gamesCollection.doc(gameId).get();
    if (!gameDoc.exists) throw Exception('Partie non trouvée');

    final game = Game.fromMap(gameDoc.data() as Map<String, dynamic>);
    
    // Vérifier que les spectateurs sont autorisés
    if (!(game.gameSettings['allowSpectators'] ?? false)) {
      throw Exception('Les spectateurs ne sont pas autorisés pour cette partie');
    }

    // Vérifier la limite de spectateurs
    final maxSpectators = game.gameSettings['maxSpectators'] ?? 50;
    if (game.spectators.length >= maxSpectators) {
      throw Exception('Limite de spectateurs atteinte');
    }

    // Vérifier que l'utilisateur n'est pas déjà dans la partie
    if (game.players.contains(userId)) {
      throw Exception('Vous êtes déjà dans cette partie');
    }

    if (game.spectators.contains(userId)) {
      throw Exception('Vous observez déjà cette partie');
    }

    await gamesCollection.doc(gameId).update({
      'spectators': FieldValue.arrayUnion([userId]),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    // Ajouter aux spectateurs globaux
    await spectatorsCollection.doc(gameId).set({
      'gameId': gameId,
      'spectators': FieldValue.arrayUnion([userId]),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  } catch (e) {
    throw Exception('Erreur rejoindre spectateur: $e');
  }
}


  /// Récupérer toutes les parties publiques actives
  static Stream<List<Game>> getAllActiveGames() {
    return gamesCollection
        .where('status', isEqualTo: GameStatus.playing.toString())
        .where('gameSettings.allowSpectators', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .limit(50) // Limite pour performance
        .snapshots()
        .handleError((error) => print('Erreur stream parties publiques: $error'))
        .map((snapshot) => snapshot.docs
            .map((doc) {
              try {
                return Game.fromMap(doc.data() as Map<String, dynamic>);
              } catch (e) {
                print('Erreur parsing partie publique: $e');
                return null;
              }
            })
            .where((game) => game != null)
            .cast<Game>()
            .toList());
  }

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
  // GESTION DES DEMANDES DE MATCH - COMPLÈTE
  // ============================================================

  /// Envoyer une demande de match avec notification
  static Future<void> sendMatchRequest(MatchRequest request) async {
    try {
      // Vérifier si une demande similaire existe déjà
      final existingRequest = await matchRequestsCollection
          .where('fromUserId', isEqualTo: request.fromUserId)
          .where('toUserId', isEqualTo: request.toUserId)
          .where('status', isEqualTo: MatchRequestStatus.pending.toString())
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Vous avez déjà une demande en attente avec ce joueur');
      }

      await matchRequestsCollection.doc(request.id).set(request.toMap());

      // Envoyer une notification
      await _sendMatchRequestNotification(request);
    } catch (e) {
      throw Exception('Erreur envoi demande: $e');
    }
  }


  /// Récupérer toutes les demandes de match (reçues + envoyées)
  static Stream<List<MatchRequest>> getAllMatchRequests() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return matchRequestsCollection
        .where('status', whereIn: [
          MatchRequestStatus.pending.toString(),
          MatchRequestStatus.accepted.toString(),
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MatchRequest.fromMap(doc.data() as Map<String, dynamic>))
            .where((request) => 
                request.fromUserId == currentUserId || 
                request.toUserId == currentUserId)
            .toList());
  }

  // ============================================================
  // GESTION DES RÉSULTATS ET STATISTIQUES - AMÉLIORÉE
  // ============================================================

  /// Sauvegarder le résultat d'une partie
  static Future<void> saveGameResult(GameResult result) async {
    try {
      await gameResultsCollection.doc().set(result.toMap());
      await _updatePlayerStats(result);
    } catch (e) {
      throw Exception('Erreur sauvegarde résultat: $e');
    }
  }

  /// Mettre à jour les statistiques du joueur de manière complète
  static Future<void> _updatePlayerStats(GameResult result) async {
    try {
      final userDoc = await usersCollection.doc(result.userId).get();
      if (!userDoc.exists) return;

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

      // Mettre à jour les séries
      if (isWin) {
        final newWinStreak = (player.stats.winStreak ) + 1;
        updates['stats.winStreak'] = newWinStreak;
        if (newWinStreak > player.stats.bestWinStreak) {
          updates['stats.bestWinStreak'] = newWinStreak;
        }
      } else {
        updates['stats.winStreak'] = 0;
      }

      // Mettre à jour le meilleur score
      if (result.pointsScored > player.stats.bestGamePoints) {
        updates['stats.bestGamePoints'] = result.pointsScored;
      }

      // Mettre à jour les points mensuels/hebdomadaires/quotidiens
      final now = DateTime.now();
      updates['stats.dailyPoints'] = player.stats.dailyPoints + result.pointsScored;
      updates['stats.weeklyPoints'] = player.stats.weeklyPoints + result.pointsScored;
      updates['stats.monthlyPoints'] = player.stats.monthlyPoints + result.pointsScored;

      await usersCollection.doc(result.userId).update(updates);
    } catch (e) {
      print('Erreur mise à jour stats: $e');
    }
  }

  /// Sauvegarder les résultats de tous les joueurs d'une partie
  static Future<void> _saveGameResults(Game game) async {
    try {
      for (final playerId in game.players) {
        if (playerId.startsWith('ai_')) continue; // Ignorer l'IA

        final playerScore = game.scores[playerId] ?? 0;
        final isWinner = game.winnerId == playerId;
        final isDraw = game.winnerId == null;

        final outcome = isWinner 
            ? GameOutcome.win 
            : isDraw 
                ? GameOutcome.draw 
                : GameOutcome.loss;

        final result = GameResult(
          userId: playerId,
          pointsScored: playerScore,
          outcome: outcome,
          playedAt: game.finishedAt ?? DateTime.now(),
        );

        await saveGameResult(result);
      }
    } catch (e) {
      print('Erreur sauvegarde résultats: $e');
    }
  }

  // ============================================================
  // FONCTIONS UTILITAIRES - COMPLÈTES
  // ============================================================

  /// Vérifier si une demande de match est expirée
  static bool isMatchRequestExpired(MatchRequest request) {
    return request.expiresAt != null && 
           DateTime.now().isAfter(request.expiresAt!);
  }

  /// Générer un ID unique
  static String generateId() {
    return _firestore.collection('temp').doc().id;
  }

  /// Récupérer les informations d'un joueur avec cache
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

  /// Obtenir le prochain joueur
  static String _getNextPlayer(String gameId, String currentPlayerId) {
    // Implémentation simplifiée - à adapter selon ta logique de jeu
    final currentUser = _auth.currentUser;
    return currentUser?.uid == currentPlayerId ? 'opponent' : currentUser?.uid ?? '';
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
}
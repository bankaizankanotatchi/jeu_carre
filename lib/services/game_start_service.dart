// services/game_start_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jeu_carre/models/game_model.dart';
import 'package:jeu_carre/screens/game_screen/game_screen.dart';

class GameStartService {
  static final GameStartService _instance = GameStartService._internal();
  factory GameStartService() => _instance;
  GameStartService._internal();

  StreamSubscription? _gameStartSubscription;
  BuildContext? _context;

  void initialize(BuildContext context) {
    _context = context;
    _startListeningGameStarts();
  }

  void _startListeningGameStarts() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    print('🎯 Début écoute des parties pour: ${currentUser.uid}');

    _gameStartSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: currentUser.uid)
        .where('type', isEqualTo: 'game_started')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      print('📨 Notification reçue: ${snapshot.docChanges.length} changement(s)');
      
      for (final doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final notification = doc.doc;
          final data = notification.data()!;
          print('🎮 Notification partie: ${data['data']}');
          
          _handleGameStartNotification(data);
          
          // Marquer comme lu
          notification.reference.update({'isRead': true});
        }
      }
    }, onError: (error) {
      print('❌ Erreur écoute parties: $error');
    });
  }

  void _handleGameStartNotification(Map<String, dynamic> data) {
    try {
      final gameData = data['data'] as Map<String, dynamic>;
      final gameId = gameData['gameId'] as String;
      final opponentId = gameData['opponentId'] as String;

      print('🚀 Redirection vers partie: $gameId');

      // 🔥 CHARGER LA PARTIE COMPLÈTE AVANT REDIRECTION
      _loadAndRedirectToGame(gameId, opponentId);
    } catch (e) {
      print('❌ Erreur traitement notification: $e');
    }
  }
// Dans GameStartService - MODIFIER _loadAndRedirectToGame
void _loadAndRedirectToGame(String gameId, String opponentId) async {
  try {
    print('📥 Chargement partie: $gameId');
    print('👤 OpponentId: $opponentId');
    
    final gameDoc = await FirebaseFirestore.instance
        .collection('games')
        .doc(gameId)
        .get();
    
    if (gameDoc.exists) {
      final gameData = gameDoc.data();
      print('📊 Données partie: $gameData');
      
      // 🔥 VÉRIFICATION NULL SAFETY
      if (gameData == null) {
        print('❌ Données partie nulles');
        return;
      }
      
      final existingGame = Game.fromMap(gameData);
      
      // 🔥 VÉRIFICATIONS DES CHAMPS OBLIGATOIRES
      print('🔍 Vérification des champs:');
      print('   - gridSize: ${existingGame.gridSize}');
      print('   - player1Id: ${existingGame.player1Id}');
      print('   - player2Id: ${existingGame.player2Id}');
      print('   - gameDuration: ${existingGame.gameDuration}');
      print('   - reflexionTime: ${existingGame.reflexionTime}');
      
      // Vérifier que tous les champs requis sont valides
      if (existingGame.gridSize <= 0) {
        print('❌ gridSize invalide: ${existingGame.gridSize}');
        return;
      }
      if (existingGame.player1Id!.isEmpty) {
        print('❌ player1Id vide');
        return;
      }
      if (existingGame.gameDuration <= 0) {
        print('❌ gameDuration invalide: ${existingGame.gameDuration}');
        return;
      }
      if (existingGame.reflexionTime <= 0) {
        print('❌ reflexionTime invalide: ${existingGame.reflexionTime}');
        return;
      }

      print('✅ Partie valide - Redirection...');

      // 🔥 REDIRECTION AVEC GESTION D'ERREUR
      if (_context != null && _context!.mounted) {
        _redirectToGame(existingGame, opponentId);
      } else {
        print('❌ Context non disponible ou pas mounted');
      }
    } else {
      print('❌ Partie non trouvée: $gameId');
    }
  } catch (e, stackTrace) {
    print('❌ Erreur critique chargement partie: $e');
    print('📋 Stack trace: $stackTrace');
  }
}
  void _redirectToGame(Game existingGame, String opponentId) {
    print('🎯 Navigation vers GameScreen...');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(_context!).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => GameScreen(
            gridSize: existingGame.gridSize,
            isAgainstAI: false,
            gameDuration: existingGame.gameDuration,
            reflexionTime: existingGame.reflexionTime,
            opponentId: opponentId,
            existingGame: existingGame, // 🔥 OBJET COMPLET
          ),
        ),
        (route) => false,
      );
      
      print('✅ Navigation réussie vers la partie');
    });
  }

  void restart() {
    _startListeningGameStarts();
  }

  void stop() {
    _gameStartSubscription?.cancel();
  }

  void dispose() {
    _gameStartSubscription?.cancel();
    _context = null;
  }
}
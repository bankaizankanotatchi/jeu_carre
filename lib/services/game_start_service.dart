// services/game_start_service.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jeu_carre/models/ai_player.dart';
import 'package:jeu_carre/models/game_model.dart';
import 'package:jeu_carre/screens/game_screen/game_screen.dart';
import 'package:jeu_carre/services/game_service.dart';

class GameStartService {
  static final GameStartService _instance = GameStartService._internal();
  factory GameStartService() => _instance;
  GameStartService._internal();

  StreamSubscription? _activeGamesSubscription;
  BuildContext? _context;
  String? _currentUserId;
  bool _isAlreadyInGame = false;

  void initialize(BuildContext context) {
    _context = context;
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _startListeningToActiveGames();
  }

  void _startListeningToActiveGames() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    print('🎯 Début écoute des parties actives pour: ${currentUser.uid}');

    _activeGamesSubscription?.cancel();
    _activeGamesSubscription = GameService.getMyActiveGames(currentUser.uid).listen((games) {
      print('📊 Parties actives reçues: ${games.length}');

      // Filtrer les parties en cours où l'utilisateur est présent
      final activeGames = games.where((game) => 
        game.status == GameStatus.playing &&
        game.players.contains(currentUser.uid) &&
        game.startedAt != null // La partie a vraiment commencé
      ).toList();

      print('🎮 Parties en cours filtrées: ${activeGames.length}');

      if (activeGames.isNotEmpty && !_isAlreadyInGame) {
        // Prendre la partie la plus récente
        final latestGame = activeGames.first;
        print('🚀 Navigation vers partie: ${latestGame.id}');
        _navigateToGame(latestGame);
      }
    }, onError: (error) {
      print('❌ Erreur écoute parties actives: $error');
    });
  }

  void _navigateToGame(Game game) {
    if (_context == null || !_context!.mounted) {
      print('❌ Context non disponible pour navigation');
      return;
    }

    // Vérifier si nous sommes déjà sur un écran de jeu
    final currentRoute = ModalRoute.of(_context!)?.settings.name;
    if (currentRoute?.contains('GameScreen') == true) {
      print('⚠️ Déjà sur écran de jeu, navigation annulée');
      return;
    }

    try {
      print('🎯 Début navigation vers GameScreen...');
      
      // Marquer que nous sommes en jeu
      _isAlreadyInGame = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(_context!).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => GameScreen(
              gridSize: game.gridSize,
              isAgainstAI: game.isAgainstAI,
              aiDifficulty: _getAIDifficulty(game),
              gameDuration: game.gameDuration,
              reflexionTime: game.reflexionTime,
              opponentId: _getOpponentId(game),
              existingGame: game,
            ),
          ),
          (route) => route.isFirst, // Garder seulement la première route
        );
        
        print('✅ Navigation réussie vers la partie ${game.id}');
      });
    } catch (e) {
      print('❌ Erreur navigation: $e');
      _isAlreadyInGame = false;
    }
  }

  String? _getOpponentId(Game game) {
    if (_currentUserId == null) return null;
    
    if (game.isAgainstAI) {
      return null;
    }
    
    // Retourner l'ID de l'autre joueur
    final opponent = game.players.firstWhere(
      (playerId) => playerId != _currentUserId,
      orElse: () => '',
    );
    
    return opponent.isNotEmpty ? opponent : null;
  }

  AIDifficulty _getAIDifficulty(Game game) {
    if (game.aiDifficulty == null) return AIDifficulty.intermediate;
    
    switch (game.aiDifficulty!.toLowerCase()) {
      case 'easy':
        return AIDifficulty.beginner;
      case 'hard':
        return AIDifficulty.intermediate;
      case 'expert':
        return AIDifficulty.expert;
      default:
        return AIDifficulty.intermediate;
    }
  }

  void restart() {
    _isAlreadyInGame = false;
    _startListeningToActiveGames();
  }

  void stop() {
    _activeGamesSubscription?.cancel();
    _isAlreadyInGame = false;
  }

  void dispose() {
    _activeGamesSubscription?.cancel();
    _context = null;
    _currentUserId = null;
    _isAlreadyInGame = false;
  }

  // Méthode pour forcer la sortie du jeu (quand la partie se termine)
  void exitGame() {
    _isAlreadyInGame = false;
  }
}
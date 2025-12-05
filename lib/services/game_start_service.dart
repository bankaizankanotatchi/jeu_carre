// services/game_start_service.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jeu_carre/models/ai_player.dart';
import 'package:jeu_carre/models/game_model.dart';
import 'package:jeu_carre/screens/game_screen/game_screen.dart';
import 'package:jeu_carre/screens/loading_screen.dart';
import 'package:jeu_carre/services/game_service.dart';

class GameStartService {
  static final GameStartService _instance = GameStartService._internal();
  factory GameStartService() => _instance;
  GameStartService._internal();

  StreamSubscription? _activeGamesSubscription;
  BuildContext? _context;

  String? _currentUserId;

  bool _isAlreadyInGame = false;
  bool _loadingScreenShown = false;

  void initialize(BuildContext context) {
    _context = context;
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _startListeningToActiveGames();
  }

  // ---------------------------------------------------------
  // 🔥 ÉCOUTE DES PARTIES EN COURS
  // ---------------------------------------------------------
  void _startListeningToActiveGames() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _activeGamesSubscription?.cancel();
    _activeGamesSubscription =
        GameService.getMyActiveGames(currentUser.uid).listen((games) {

      final activeGames = games.where((g) =>
          g.status == GameStatus.playing &&
          g.players.contains(currentUser.uid) &&
          g.startedAt != null).toList();

      if (activeGames.isEmpty) return;

      final game = activeGames.first;

      // 🟡 Déjà dans la partie → ne rien faire
      if (_isAlreadyInGame) return;

      // 🟢 Afficher l'écran de loading
      _showLoadingScreen(game);

      // Ensuite → navigation vers l'écran de jeu
      _navigateToGame(game);

    }, onError: (error) {
      print("❌ Erreur écoute parties actives: $error");
    });
  }

  // ---------------------------------------------------------
  // 🟢 AFFICHER LE LOADING SCREEN EXACTEMENT COMME LA NOTIFICATION
  // ---------------------------------------------------------
  void _showLoadingScreen(Game game) {
    if (_context == null || !_context!.mounted) return;
    if (_loadingScreenShown) return;

    _loadingScreenShown = true;

    Navigator.push(
      _context!,
      MaterialPageRoute(
        builder: (_) => GameLoadingScreen(
          opponentName: _getOpponentName(game),
          gridSize: game.gridSize,
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 🔥 ENTRÉE DANS L'ÉCRAN DE JEU
  // ---------------------------------------------------------
  void _navigateToGame(Game game) {
    if (_context == null || !_context!.mounted) return;

    _isAlreadyInGame = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(_context!).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            gridSize: game.gridSize,
            isAgainstAI: game.isAgainstAI,
            aiDifficulty: _getAIDifficulty(game),
            gameDuration: game.gameDuration,
            reflexionTime: game.reflexionTime,
            opponentId: _getOpponentId(game),
            existingGame: game,
          ),
        ),
        (route) => route.isFirst,
      );
    });
  }

  // ---------------------------------------------------------
  // 🔧 UTILITAIRES
  // ---------------------------------------------------------
  String? _getOpponentId(Game game) {
    if (_currentUserId == null) return null;
    if (game.isAgainstAI) return null;

    return game.players.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => "",
    );
  }

  String _getOpponentName(Game game) {
    if (game.isAgainstAI) return "ShikakuBot";
    return _getOpponentId(game) ?? "Adversaire";
  }

  AIDifficulty _getAIDifficulty(Game game) {
    switch (game.aiDifficulty?.toLowerCase()) {
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

  // ---------------------------------------------------------
  // RESET / STOP
  // ---------------------------------------------------------
  void restart() {
    _isAlreadyInGame = false;
    _loadingScreenShown = false;
    _startListeningToActiveGames();
  }

  void stop() {
    _activeGamesSubscription?.cancel();
    _isAlreadyInGame = false;
    _loadingScreenShown = false;
  }

  void dispose() {
    _activeGamesSubscription?.cancel();
    _context = null;
    _currentUserId = null;
    _isAlreadyInGame = false;
    _loadingScreenShown = false;
  }

  void exitGame() {
    _isAlreadyInGame = false;
    _loadingScreenShown = false;
  }
}

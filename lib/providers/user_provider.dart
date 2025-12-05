// providers/user_provider.dart
import 'package:flutter/foundation.dart';
import 'package:jeu_carre/models/game_model.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/services/game_service.dart';
import 'package:jeu_carre/services/user_cache_service.dart';

class UserProvider with ChangeNotifier {
  Player? _currentUser;
  List<Game>? _gameHistory;
  bool _isLoading = false;
  bool _isCacheLoading = true; // NOUVEAU: pour le chargement cache
  Map<String, String> _opponentsNames = {}; // NOUVEAU: pour stocker les noms

  Player? get currentUser => _currentUser;
  List<Game>? get gameHistory => _gameHistory;
  bool get isLoading => _isLoading;
  bool get isCacheLoading => _isCacheLoading; // NOUVEAU GETTER

  Future<void> loadUserData() async {
    _isLoading = true;
    _isCacheLoading = true; // Commence le chargement cache
    notifyListeners();

    try {
      // Charger depuis le CACHE uniquement
      _currentUser = await UserCacheService().getUser();
      _gameHistory = await UserCacheService().getGameHistory();
      
      // Charger les noms des adversaires depuis le cache
      await _loadOpponentsFromCache();
      
      // PRÉCHARGER LES NOMS DES ADVERSAIRES
      if (_gameHistory != null && _currentUser != null) {
        await _preloadOpponents(_gameHistory!, _currentUser!.id);
      }
      
      print('✅ Données chargées depuis le cache');
    } catch (e) {
      print('❌ Erreur chargement données utilisateur: $e');
    } finally {
      _isLoading = false;
      _isCacheLoading = false; // Termine le chargement cache
      notifyListeners();
    }
  }

  // NOUVELLE MÉTHODE: Charger les noms des adversaires depuis le cache
  Future<void> _loadOpponentsFromCache() async {
    if (_gameHistory == null || _currentUser == null) return;

    _opponentsNames.clear();
    
    for (final game in _gameHistory!) {
      final opponentId = _getOpponentId(game, _currentUser!.id);
      
      if (opponentId.isNotEmpty && !opponentId.startsWith('ai_')) {
        final cachedName = UserCacheService().getOpponent(opponentId);
        if (cachedName != null) {
          _opponentsNames[opponentId] = cachedName;
        }
      }
    }
    
    print('📊 Noms adversaires chargés depuis cache: ${_opponentsNames.length}');
  }

  // NOUVELLE MÉTHODE: Obtenir le nom d'un adversaire
  String? getOpponentName(String opponentId) {
    return _opponentsNames[opponentId];
  }

  // NOUVELLE MÉTHODE: Obtenir l'ID de l'adversaire
  String _getOpponentId(Game game, String currentUserId) {
    return game.players.firstWhere(
      (id) => id != currentUserId && !id.startsWith('ai_'),
      orElse: () => '',
    );
  }

  Future<void> refreshUserData() async {
    // Forcer le rafraîchissement depuis Firebase
    _currentUser = await UserCacheService().getUser(forceRefresh: true);
    _gameHistory = await UserCacheService().getGameHistory(forceRefresh: true);
    
    // Recharger les adversaires
    await _loadOpponentsFromCache();
    
    notifyListeners();
  }

  Future<void> updateAfterGame(Player updatedPlayer) async {
    _currentUser = updatedPlayer;
    await UserCacheService().updateUserAfterGame(updatedPlayer);
    notifyListeners();
  }
  
  // NOUVELLE MÉTHODE pour précharger les adversaires
  Future<void> _preloadOpponents(List<Game> games, String currentUserId) async {
    final opponentIds = <String>{};
    
    // Collecter tous les ID d'adversaires uniques
    for (final game in games) {
      for (final playerId in game.players) {
        if (playerId != currentUserId && !playerId.startsWith('ai_')) {
          opponentIds.add(playerId);
        }
      }
    }
    
    // Pour chaque adversaire non présent dans le cache
    for (final opponentId in opponentIds) {
      if (UserCacheService().getOpponent(opponentId) == null) {
        try {
          final opponent = await GameService.getPlayer(opponentId);
          if (opponent != null) {
            await UserCacheService().saveOpponent(opponentId, opponent.username);
            // Mettre à jour le cache local
            _opponentsNames[opponentId] = opponent.username;
          }
        } catch (e) {
          print('⚠️ Erreur préchargement adversaire $opponentId: $e');
        }
      }
    }
    
    print('📊 Préchargement adversaires terminé: ${opponentIds.length} joueurs');
  }

  // NOUVELLE MÉTHODE: Vider le cache (pour debug)
  Future<void> clearCache() async {
    await UserCacheService().clearCache();
    await UserCacheService().clearOpponentsCache();
    _currentUser = null;
    _gameHistory = null;
    _opponentsNames.clear();
    notifyListeners();
    print('🧹 Cache complètement vidé');
  }
}
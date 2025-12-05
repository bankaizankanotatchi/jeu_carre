// services/user_cache_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeu_carre/models/game_model.dart';
import 'package:jeu_carre/services/game_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:jeu_carre/models/player.dart';

class UserCacheService {
  static final UserCacheService _instance = UserCacheService._internal();
  factory UserCacheService() => _instance;
  UserCacheService._internal();

  static const String _userCacheKey = 'user_cache_v1';
  static const String _historyCacheKey = 'game_history_v1';
  static const String _cacheTimestampKey = 'cache_timestamp';
    static const String _opponentsCacheKey = 'opponents_cache_v1';

  Map<String, String> _opponentsCache = {};

  Player? _cachedUser;
  List<Game>? _cachedHistory;
  DateTime? _lastCacheUpdate;

  /// Initialiser le cache au démarrage
  Future<void> initialize() async {
    await _loadFromStorage();
    await _loadOpponentsCache();
  }

    /// Effacer le cache adversaires
  Future<void> clearOpponentsCache() async {
    _opponentsCache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_opponentsCacheKey);
    print('🧹 Cache adversaires effacé');
  }

  /// Sauvegarder l'utilisateur dans le cache
  Future<void> saveUser(Player user) async {
    _cachedUser = user;
    _lastCacheUpdate = DateTime.now();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userCacheKey, json.encode(user.toMap()));
    await prefs.setInt(_cacheTimestampKey, _lastCacheUpdate!.millisecondsSinceEpoch);
    
    print('✅ Utilisateur sauvegardé dans le cache');
  }

    /// Sauvegarder un adversaire dans le cache
  Future<void> saveOpponent(String opponentId, String username) async {
    _opponentsCache[opponentId] = username;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_opponentsCacheKey, json.encode(_opponentsCache));
    
    print('✅ Adversaire sauvegardé dans le cache: $username ($opponentId)');
  }

  /// Récupérer le nom d'un adversaire depuis le cache
  String? getOpponent(String opponentId) {
    return _opponentsCache[opponentId];
  }


  /// Sauvegarder tous les adversaires d'une partie
  Future<void> saveOpponentsFromGame(Game game, String currentUserId) async {
    try {
      for (final playerId in game.players) {
        if (playerId != currentUserId && !playerId.startsWith('ai_')) {
          // Essayer de récupérer depuis Firebase une seule fois
          final opponent = await GameService.getPlayer(playerId);
          if (opponent != null) {
            await saveOpponent(playerId, opponent.username);
          } else {
            // Si pas trouvé, utiliser un nom par défaut
            await saveOpponent(playerId, 'Joueur');
          }
        }
      }
    } catch (e) {
      print('⚠️ Erreur sauvegarde adversaires: $e');
    }
  }

    /// Charger le cache des adversaires
  Future<void> _loadOpponentsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final opponentsJson = prefs.getString(_opponentsCacheKey);
      
      if (opponentsJson != null) {
        final opponentsMap = json.decode(opponentsJson);
        _opponentsCache = Map<String, String>.from(opponentsMap);
        print('📦 Cache adversaires chargé: ${_opponentsCache.length} joueurs');
      }
    } catch (e) {
      print('❌ Erreur chargement cache adversaires: $e');
    }
  }

  /// Sauvegarder l'historique dans le cache
  Future<void> saveGameHistory(List<Game> history) async {
    _cachedHistory = history;
    
    final prefs = await SharedPreferences.getInstance();
    final historyList = history.map((game) => game.toMap()).toList();
    await prefs.setString(_historyCacheKey, json.encode(historyList));
    
    print('✅ Historique sauvegardé dans le cache (${history.length} parties)');
  }

  /// Mettre à jour l'utilisateur APRÈS une partie
  Future<void> updateUserAfterGame(Player updatedUser) async {
    _cachedUser = updatedUser;
    await saveUser(updatedUser);
    print('✅ Cache utilisateur mis à jour après partie');
  }

  /// Ajouter une partie à l'historique
  Future<void> addGameToHistory(Game game) async {
    if (_cachedHistory == null) {
      _cachedHistory = [];
    }
    
    // Ajouter en début de liste
    _cachedHistory!.insert(0, game);
    
    // Garder seulement les 50 dernières parties
    if (_cachedHistory!.length > 50) {
      _cachedHistory = _cachedHistory!.sublist(0, 50);
    }
    
    await saveGameHistory(_cachedHistory!);
  }

  /// Récupérer l'utilisateur (priorité cache, sinon Firebase)
  Future<Player?> getUser({bool forceRefresh = false}) async {
    // Si on force le rafraîchissement ou pas de cache
    if (forceRefresh || _cachedUser == null) {
      final User? firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return null;
      
      // Récupérer depuis Firebase
      final player = await GameService.getPlayer(firebaseUser.uid);
      if (player != null) {
        await saveUser(player);
      }
      return player;
    }
    
    return _cachedUser;
  }

  /// Récupérer l'historique (priorité cache)
  Future<List<Game>> getGameHistory({bool forceRefresh = false}) async {
    if (forceRefresh || _cachedHistory == null) {
      // Récupérer depuis Firebase
      final history = await GameService.getGameHistory(limit: 20).first;
      await saveGameHistory(history);
      return history;
    }
    
    return _cachedHistory!;
  }

  /// Vérifier si le cache est frais (< 24h)
  bool isCacheFresh() {
    if (_lastCacheUpdate == null) return false;
    final difference = DateTime.now().difference(_lastCacheUpdate!);
    return difference.inHours < 24;
  }

  /// Effacer le cache
  Future<void> clearCache() async {
    _cachedUser = null;
    _cachedHistory = null;
    _lastCacheUpdate = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userCacheKey);
    await prefs.remove(_historyCacheKey);
    await prefs.remove(_cacheTimestampKey);
    
    print('🧹 Cache utilisateur effacé');
  }

  // Méthodes privées
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Charger l'utilisateur
      final userJson = prefs.getString(_userCacheKey);
      if (userJson != null) {
        final userMap = json.decode(userJson);
        _cachedUser = Player.fromMap(userMap);
      }
      
      // Charger l'historique
      final historyJson = prefs.getString(_historyCacheKey);
      if (historyJson != null) {
        final historyList = json.decode(historyJson) as List;
        _cachedHistory = historyList.map((map) => Game.fromMap(map)).toList();
      }
      
      // Charger le timestamp
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp != null) {
        _lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      
      print('📦 Cache chargé: ${_cachedUser?.username ?? "Aucun utilisateur"}');
    } catch (e) {
      print('❌ Erreur chargement cache: $e');
    }
  }
}
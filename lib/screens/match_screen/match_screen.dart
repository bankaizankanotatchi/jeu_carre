// screens/match_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeu_carre/models/game_model.dart';
import 'package:jeu_carre/models/game_request.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/services/game_service.dart';
import 'package:jeu_carre/screens/game_screen/game_screen.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Game>>? _myActiveGamesStream;
  Stream<List<Game>>? _allActiveGamesStream;
  
  // Nouveaux états pour les demandes
  bool _showReceivedRequests = true;
  Stream<List<dynamic>>? _matchRequestsStream;
  
  // Caches pour les noms des adversaires
  final Map<String, String> _opponentNameCache = {};
  final Map<String, Player?> _playerCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeStreams();
  }

  void _initializeStreams() {
    final currentUserId = _auth.currentUser?.uid;
    
    // Initialiser les streams
    _allActiveGamesStream = GameService.getAllActiveGames();
    
    if (currentUserId != null) {
      _myActiveGamesStream = GameService.getMyActiveGames(currentUserId);
      _matchRequestsStream = GameService.getMatchRequests(currentUserId);
    }
  }

  void _toggleRequestFilter() {
    setState(() {
      _showReceivedRequests = !_showReceivedRequests;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================
  // MÉTHODES DE CACHE
  // ============================================================

  // Méthode pour récupérer un joueur avec cache
  Future<Player?> _getPlayerWithCache(String playerId) async {
    if (_playerCache.containsKey(playerId)) {
      return _playerCache[playerId];
    }
    
    try {
      final player = await GameService.getPlayer(playerId);
      _playerCache[playerId] = player;
      return player;
    } catch (e) {
      _playerCache[playerId] = null;
      return null;
    }
  }

  // Méthode pour obtenir le nom de l'adversaire avec cache
  Future<String> _getOpponentNameWithCache(Game game) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 'Adversaire';
    
    final opponentId = _getOpponentId(game, currentUserId);
    final cacheKey = '${game.id}_$opponentId';
    
    // Retourner directement si déjà en cache
    if (_opponentNameCache.containsKey(cacheKey)) {
      return _opponentNameCache[cacheKey]!;
    }
    
    if (game.isAgainstAI) {
      final aiName = 'IA ${game.aiDifficulty ?? 'beginner'}';
      _opponentNameCache[cacheKey] = aiName;
      return aiName;
    } else if (opponentId.isNotEmpty) {
      _opponentNameCache[cacheKey] = 'Chargement...';
      
      try {
        final opponent = await _getPlayerWithCache(opponentId);
        final opponentName = opponent?.username ?? 'Joueur';
        _opponentNameCache[cacheKey] = opponentName;
        return opponentName;
      } catch (e) {
        _opponentNameCache[cacheKey] = 'Joueur';
        return 'Joueur';
      }
    } else {
      return 'Adversaire';
    }
  }

  // ============================================================
  // MÉTHODES DE GESTION DES PARTIES
  // ============================================================

  void _joinAsSpectator(Game game) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId != null) {
        await GameService.joinAsSpectator(game.id, currentUserId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vous observez maintenant la partie'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(
              gridSize: game.gridSize,
              isAgainstAI: game.isAgainstAI,
              gameDuration: game.gameDuration,
              reflexionTime: game.reflexionTime,
              existingGame: game,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resumeGame(Game game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          gridSize: game.gridSize,
          isAgainstAI: game.isAgainstAI,
          gameDuration: game.gameDuration,
          reflexionTime: game.reflexionTime,
          existingGame: game,
        ),
      ),
    );
  }

  // ============================================================
  // FONCTIONS POUR LES DEMANDES DE MATCH
  // ============================================================

  void _acceptMatchRequest(dynamic request) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      await GameService.acceptMatchRequest(request.id, currentUserId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Défi accepté !'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _rejectMatchRequest(dynamic request) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      await GameService.rejectMatchRequest(request.id, currentUserId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Défi refusé'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelMatchRequest(dynamic request) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      await GameService.cancelMatchRequest(request.id, currentUserId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demande annulée'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isRequestExpired(dynamic request) {
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

  String _formatTimeRemaining(dynamic createdAt) {
    final now = DateTime.now();
    
    // CORRECTION: Gérer les différents types de date
    DateTime created;
    if (createdAt is Timestamp) {
      created = createdAt.toDate();
    } else if (createdAt is DateTime) {
      created = createdAt;
    } else {
      // Si c'est un int (millisecondsSinceEpoch)
      created = DateTime.fromMillisecondsSinceEpoch(createdAt);
    }
    
    final difference = now.difference(created);
    final hoursLeft = 24 - difference.inHours;
    final minutesLeft = 60 - difference.inMinutes % 60;
    
    if (hoursLeft > 0) {
      return '${hoursLeft}h ${minutesLeft}m';
    } else {
      return '${minutesLeft}m';
    }
  }

  // ============================================================
  // WIDGETS D'AFFICHAGE
  // ============================================================

  Widget _buildAnimatedParticle(int index) {
    final random = (index * 123) % 100;
    final left = (random % 100).toDouble();
    final top = ((random * 7) % 100).toDouble();
    final size = 2.0 + (random % 4);
    final duration = 3 + (random % 5);
    
    return Positioned(
      left: left.clamp(0, 100) * MediaQuery.of(context).size.width / 100,
      top: top.clamp(0, 100) * 180 / 100,
      child: TweenAnimationBuilder(
        duration: Duration(seconds: duration),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, double value, child) {
          return Opacity(
            opacity: value,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFe040fb).withOpacity(0.6),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFe040fb).withOpacity(0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          );
        },
        onEnd: () {
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  Widget _buildMatchRequestCard(dynamic request, Player? opponent) {
    final isMyRequest = request.fromUserId == _auth.currentUser?.uid;
    final isExpired = _isRequestExpired(request);
    final isPending = request.status == MatchRequestStatus.pending && !isExpired;
    final isRejected = request.status == MatchRequestStatus.declined || isExpired;
    final isAccepted = request.status == MatchRequestStatus.accepted;
    final isCancelled = request.status == MatchRequestStatus.cancelled;
    
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isExpired) {
      statusColor = Color(0xFF666666);
      statusText = 'EXPIRÉE';
      statusIcon = Icons.timer_off;
    } else if (isRejected) {
      statusColor = Color(0xFFff006e);
      statusText = 'REFUSÉE';
      statusIcon = Icons.cancel;
    } else if (isAccepted) {
      statusColor = Color(0xFF00d4ff);
      statusText = 'ACCEPTÉE';
      statusIcon = Icons.check_circle;
    } else if (isCancelled) {
      statusColor = Color(0xFF666666);
      statusText = 'ANNULÉE';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Color(0xFFFFD700);
      statusText = 'EN ATTENTE';
      statusIcon = Icons.schedule;
    }

    final opponentName = _truncateName(opponent?.username ?? 'Joueur inconnu');
    final opponentAvatar = opponent?.displayAvatar ?? '👤';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1a0033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                            ),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              opponentAvatar,
                              fit: BoxFit.cover,
                              width: 50,
                              height: 50,
                              errorBuilder: (context, error, stackTrace) => 
                                Icon(Icons.person, size: 24, color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opponentName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              isMyRequest ? 'Vous avez défié' : 'Vous a défié',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 14),
                          SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF2d0052),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildConfigItem('Grille', '${request.gridSize}×${request.gridSize}', Icons.grid_on),
                          _buildConfigItem('Match', '${request.gameDuration ~/ 60} min', Icons.timer),
                          _buildConfigItem('Tour', '${request.reflexionTime}s', Icons.hourglass_empty),
                        ],
                      ),
                      SizedBox(height: 8),
                      if (isPending && !isMyRequest)
                        Text(
                          'Temps restant: ${_formatTimeRemaining(request.createdAt)}',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                
                SizedBox(height: 12),
                
                if(isRejected || isAccepted || isCancelled)
                  Container()
                else
                  // SI LA DEMANDE EST EN ATTENTE
                  isMyRequest 
                    ? 
                    // BOUTON POUR LES DEMANDES QUE VOUS AVEZ ENVOYÉES (ANNULER)
                    Container(
                      width: double.infinity,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(0xFF1a0033),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFFFFD700)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _cancelMatchRequest(request),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cancel, color: Color(0xFFFFD700), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'ANNULER LA DEMANDE',
                                  style: TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    : 
                    // BOUTONS POUR LES DEMANDES QUE VOUS AVEZ REÇUES (ACCEPTER + REFUSER)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _acceptMatchRequest(request),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check, color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'ACCEPTER',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(0xFF1a0033),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Color(0xFFff006e)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _rejectMatchRequest(request),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.close, color: Color(0xFFff006e), size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'REFUSER',
                                      style: TextStyle(
                                        color: Color(0xFFff006e),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )],
            ),
          ),
        ),
      ),
    );
  } 
  
  Widget _buildConfigItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Color(0xFF00d4ff), size: 16),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  String _getOpponentId(Game game, String currentUserId) {
    try {
      return game.players.firstWhere(
        (p) => p != currentUserId,
        orElse: () => game.players.isNotEmpty ? game.players.first : '',
      );
    } catch (e) {
      return game.players.isNotEmpty ? game.players.first : '';
    }
  }

  String _truncateName(String name) {
    if (name.length <= 10) return name;
    return '${name.substring(0, 9)}..';
  }

  Widget _buildMyMatchCard(Game game) {
    final currentUserId = _auth.currentUser?.uid;
    final isMyTurn = game.currentPlayer == currentUserId;
    final timeLeft = game.timeRemaining;
    final minutes = timeLeft ~/ 60;
    final seconds = timeLeft % 60;
    
    final opponentId = _getOpponentId(game, currentUserId!);
    final myScore = game.scores[currentUserId] ?? 0;
    final opponentScore = opponentId.isNotEmpty ? (game.scores[opponentId] ?? 0) : 0;

    return FutureBuilder<String>(
      key: Key('my_match_${game.id}'),
      future: _getOpponentNameWithCache(game),
      builder: (context, nameSnapshot) {
        final opponentName = _opponentNameCache.containsKey('${game.id}_$opponentId')
            ? _opponentNameCache['${game.id}_$opponentId']!
            : nameSnapshot.data ?? 'Adversaire';

        return FutureBuilder<Player?>(
          future: opponentId.isNotEmpty ? _getPlayerWithCache(opponentId) : Future.value(null),
          builder: (context, opponentSnapshot) {
            final opponent = opponentSnapshot.data;

            return Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Color(0xFF1a0033),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMyTurn ? Color(0xFF00d4ff) : Color(0xFF4a0080),
                  width: 2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _resumeGame(game),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                                    ),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      game.isAgainstAI ? '🤖' : opponent?.displayAvatar ?? '👤',
                                      fit: BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                      errorBuilder: (context, error, stackTrace) => 
                                        Icon(Icons.person, size: 20, color: Colors.white),
                                    )
                                  ),
                                ),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      opponentName,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Grille ${game.gridSize}×${game.gridSize}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isMyTurn ? Color(0xFF00d4ff).withOpacity(0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isMyTurn ? Color(0xFF00d4ff) : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                isMyTurn ? 'À VOTRE TOUR' : 'EN COURS',
                                style: TextStyle(
                                  color: isMyTurn ? Color(0xFF00d4ff) : Colors.white.withOpacity(0.6),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 16),
                        
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFF2d0052),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                                      ),
                                    ),
                                    child: Icon(Icons.person, color: Colors.white, size: 16),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '$myScore',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              
                              Column(
                                children: [
                                  Text(
                                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: Color(0xFFe040fb),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'TEMPS RESTANT',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              
                              Column(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                                      ),
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        game.isAgainstAI ? '🤖' : opponent?.displayAvatar ?? '👤',
                                        fit: BoxFit.cover,
                                        width: 32,
                                        height: 32,
                                        errorBuilder: (context, error, stackTrace) => 
                                          Icon(Icons.person, size: 20, color: Colors.white),
                                      )
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '$opponentScore',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 12),
                        
                        Container(
                          width: double.infinity,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isMyTurn
                                  ? [Color(0xFF00d4ff), Color(0xFF0099cc)]
                                  : [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _resumeGame(game),
                              child: Center(
                                child: Text(
                                  isMyTurn ? 'REPRENDRE' : 'OBSERVER',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPublicMatchCard(Game game) {
    final timeLeft = game.timeRemaining;
    final minutes = timeLeft ~/ 60;
    final seconds = timeLeft % 60;

    return FutureBuilder<List<Player?>>(
      future: Future.wait([
        if (game.player1Id != null && game.player1Id!.isNotEmpty)
          _getPlayerWithCache(game.player1Id!)
        else Future.value(null),
        if (game.player2Id != null && game.player2Id!.isNotEmpty)
          _getPlayerWithCache(game.player2Id!)
        else Future.value(null),
      ]),
      builder: (context, snapshot) {
        final player1 = snapshot.data?[0];
        final player2 = snapshot.data?[1];
        final score1 = game.scores[game.player1Id] ?? 0;
        final score2 = game.scores[game.player2Id] ?? 0;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Color(0xFF1a0033),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFF4a0080)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _joinAsSpectator(game),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPlayerInfo(
                          player1, 
                          [Color(0xFF00d4ff), Color(0xFF0099cc)]
                        ),
                        
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF4a0080),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        
                        _buildPlayerInfo(
                          player2, 
                          [Color(0xFFe040fb), Color(0xFF9c27b0)],
                          isRight: true
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF2d0052),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildScoreSection(score1, 'SCORE'),
                          
                          Column(
                            children: [
                              Text(
                                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: Color(0xFFe040fb),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Color(0xFF00d4ff).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Color(0xFF00d4ff)),
                                ),
                                child: Text(
                                  'TOUR DE ${_getCurrentPlayerName(game, player1, player2)}',
                                  style: TextStyle(
                                    color: Color(0xFF00d4ff),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          _buildScoreSection(score2, 'SCORE'),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.grid_on, color: Color(0xFF00d4ff), size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Grille ${game.gridSize}×${game.gridSize}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        
                        Row(
                          children: [
                            Icon(Icons.visibility, color: Color(0xFFe040fb), size: 12),
                            SizedBox(width: 4),
                            Text(
                              '${game.spectators.length} spectateurs',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        
                        Container(
                          width: 80,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _joinAsSpectator(game),
                              child: Center(
                                child: Text(
                                  'OBSERVER',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerInfo(Player? player, List<Color> colors, {bool isRight = false}) {
    return Expanded(
      child: Row(
        mainAxisAlignment: isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isRight) ...[
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                ),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipOval(
                child: Image.network(
                  player?.displayAvatar ?? '👤',
                  fit: BoxFit.cover,
                  width: 35,
                  height: 35,
                  errorBuilder: (context, error, stackTrace) => 
                    Icon(Icons.person, size: 20, color: Colors.white),
                )
              ),
            ),
            SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  _truncateName(player?.username ?? 'Joueur'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isRight) ...[
            SizedBox(width: 8),
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                ),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipOval(
                child: Image.network(
                  player?.displayAvatar ?? '👤',
                  fit: BoxFit.cover,
                  width: 35,
                  height: 35,
                  errorBuilder: (context, error, stackTrace) => 
                    Icon(Icons.person, size: 20, color: Colors.white),
                )
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreSection(int score, String label) {
    return Column(
      children: [
        Text(
          '$score',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _getCurrentPlayerName(Game game, Player? player1, Player? player2) {
    if (game.currentPlayer == game.player1Id) {
      return player1?.username ?? 'J1';
    } else if (game.currentPlayer == game.player2Id) {
      return player2?.username ?? 'J2';
    }
    return '?';
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF00d4ff)),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, color: Colors.red, size: 50),
          SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeStreams,
            child: Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF2d0052), Color(0xFF4a0080)]),
              border: Border.all(color: Color(0xFF9c27b0), width: 2),
            ),
            child: Icon(icon, color: Color(0xFF00d4ff), size: 40),
          ),
          SizedBox(height: 20),
          Text(title, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0a0015),
          
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, 50, 6, 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1a0033), Color(0xFF2d0052)],
              ),
            ),
            child: Stack(
              children: [
                ...List.generate(12, (index) => _buildAnimatedParticle(index)),
                Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF9c27b0), Color(0xFFe040fb)],
                            ),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF9c27b0).withOpacity(0.5),
                                blurRadius: 15,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Icon(Icons.sports_esports, color: Colors.white, size: 30),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ARÈNE DES MATCHS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Rejoignez la compétition et défiez les meilleurs',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
          
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF1a0033),
              border: Border(bottom: BorderSide(color: Color(0xFF4a0080))),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Color(0xFF00d4ff),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
              indicatorWeight: 3,
              tabs: [
                Tab(icon: Icon(Icons.public), text: 'TOUS LES MATCHS'),
                Tab(icon: Icon(Icons.person), text: 'MES MATCHS'),
                Tab(icon: Icon(Icons.notifications), text: 'DEMANDES'),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: TOUS LES MATCHS
                StreamBuilder<List<Game>>(
                  stream: _allActiveGamesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState('Recherche de matchs publics...');
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState('Erreur de chargement des matchs');
                    }

                    final games = snapshot.data ?? [];

                    if (games.isEmpty) {
                      return _buildEmptyState(
                        'AUCUN MATCH PUBLIC',
                        'Les matchs en cours apparaîtront ici\nLancez une partie en mode "Public"',
                        Icons.people,
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        return _buildPublicMatchCard(games[index]);
                      },
                    );
                  },
                ),
              
                // TAB 2: MES MATCHS
                StreamBuilder<List<Game>>(
                  stream: _myActiveGamesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState('Chargement de vos matchs...');
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState('Erreur de chargement');
                    }

                    final games = snapshot.data ?? [];

                    if (games.isEmpty) {
                      return _buildEmptyState(
                        'AUCUN MATCH EN COURS',
                        'Lancez un nouveau défi pour apparaître ici',
                        Icons.sports_esports,
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        final game = games[index];
                        return _buildMyMatchCard(game);
                      },
                    );
                  },
                ),

                // TAB 3: DEMANDES DE MATCH - AVEC BOUTON INTÉGRÉ
                StreamBuilder<List<dynamic>>(
                  stream: _matchRequestsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState('Chargement des demandes...');
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState('Erreur de chargement des demandes');
                    }

                    final requests = snapshot.data ?? [];

                    // Filtrer les demandes selon le bouton FAB
                    final filteredRequests = requests.where((request) {
                      final isMyRequest = request.fromUserId == _auth.currentUser?.uid;
                      final isExpired = _isRequestExpired(request);
                      
                      // Exclure les demandes expirées
                      if (isExpired) return false;
                      return _showReceivedRequests ? !isMyRequest : isMyRequest;
                    }).toList();

                    return Column(
                      children: [
                        // BOUTON DE FILTRE EN HAUT
                        Container(
                          margin: EdgeInsets.only(top:8,left: 16,right: 16,bottom: 4),
                          width: double.infinity,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF00d4ff).withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _toggleRequestFilter,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _showReceivedRequests ? Icons.download : Icons.upload,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    _showReceivedRequests ? 'DEMANDES REÇUES' : 'DEMANDES ENVOYÉES',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // LISTE DES DEMANDES
                        if (filteredRequests.isEmpty)
                          Expanded(
                            child: _buildEmptyState(
                              _showReceivedRequests 
                                  ? 'AUCUNE DEMANDE REÇUE' 
                                  : 'AUCUNE DEMANDE ENVOYÉE',
                              _showReceivedRequests
                                  ? 'Les défis que vous recevez apparaîtront ici'
                                  : 'Les défis que vous envoyez apparaîtront ici',
                              _showReceivedRequests ? Icons.download : Icons.upload,
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              itemCount: filteredRequests.length,
                              itemBuilder: (context, index) {
                                final request = filteredRequests[index];
                                final opponentId = _showReceivedRequests 
                                    ? request.fromUserId 
                                    : request.toUserId;
                                
                                return FutureBuilder<Player?>(
                                  future: _getPlayerWithCache(opponentId),
                                  builder: (context, opponentSnapshot) {
                                    return _buildMatchRequestCard(request, opponentSnapshot.data);
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
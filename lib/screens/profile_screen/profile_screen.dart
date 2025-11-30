// screens/profile_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/models/game_model.dart';
import 'package:jeu_carre/services/game_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:jeu_carre/services/minio_storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Player? _currentPlayer;
  bool _isLoading = true;
  final ImagePicker _imagePicker = ImagePicker();
  final MinioStorageService _minioStorage = MinioStorageService();
  bool _isUpdatingAvatar = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Variables pour la pagination
  Stream<List<Game>>? _gameHistoryStream;
  int _currentLimit = 10;
  bool _hasMoreGames = true;
  final int _initialLimit = 10;
  final int _stepLimit = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentPlayer();
    _initializeGameHistory();
  }

  // Initialiser l'historique des parties
  void _initializeGameHistory() {
    _gameHistoryStream = _getGameHistoryStream(_currentLimit);
  }

  // Stream pour l'historique des parties avec limite
  Stream<List<Game>> _getGameHistoryStream(int limit) {
    return GameService.getGameHistory(limit: limit);
  }

  // Charger plus de matchs
  void _loadMoreGames() {
    if (!_hasMoreGames) return;
    
    setState(() {
      _currentLimit += _stepLimit;
      _gameHistoryStream = _getGameHistoryStream(_currentLimit);
    });
  }

  Future<void> _updateAvatar() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );
      
      if (image != null && _currentPlayer != null) {
        setState(() => _isUpdatingAvatar = true);
        
        final File imageFile = File(image.path);
        
        // Upload vers MinIO
        final String newAvatarUrl = await _minioStorage.updateUserAvatar(
          imageFile, 
          _currentPlayer!.id
        );
        
        // Mettre à jour le profil dans Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentPlayer!.id)
            .update({
              'avatarUrl': newAvatarUrl,
            });
        
        // Mettre à jour l'état local
        setState(() {
          _currentPlayer = _currentPlayer!.copyWith(avatarUrl: newAvatarUrl);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo de profil mise à jour !'),
            backgroundColor: Color(0xFF00d4ff),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour de la photo'),
          backgroundColor: Color(0xFFff006e),
        ),
      );
    } finally {
      setState(() => _isUpdatingAvatar = false);
    }
  }

  Future<void> _loadCurrentPlayer() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final DocumentSnapshot playerDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (playerDoc.exists) {
          setState(() {
            _currentPlayer = Player.fromMap(playerDoc.data() as Map<String, dynamic>);
            _isLoading = false;
          });
        } else {
          _redirectToSignup();
        }
      } else {
        _redirectToSignup();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _redirectToSignup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/signup');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Méthode pour formater la date relative
  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) return 'À l\'instant';
    if (difference.inHours < 1) return 'Il y a ${difference.inMinutes} min';
    if (difference.inDays < 1) return 'Il y a ${difference.inHours} h';
    if (difference.inDays == 1) return 'Hier';
    if (difference.inDays < 7) return 'Il y a ${difference.inDays} jours';
    if (difference.inDays < 30) return 'Il y a ${(difference.inDays / 7).floor()} sem';
    return 'Il y a ${(difference.inDays / 30).floor()} mois';
  }

  // Méthode pour déterminer le résultat d'une partie pour l'utilisateur courant
  String _getGameResult(Game game) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 'draw';
    
    if (game.winnerId == null) return 'draw';
    if (game.winnerId == currentUserId) return 'win';
    return 'loss';
  }

  // Méthode pour obtenir le score formaté
  String _getGameScore(Game game) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return '0-0';
    
    final myScore = game.scores[currentUserId] ?? 0;
    final opponentId = game.players.firstWhere(
      (id) => id != currentUserId && !id.startsWith('ai_'),
      orElse: () => '',
    );
    
    if (opponentId.isEmpty) {
      // Partie contre IA
      final aiScore = game.scores.values.firstWhere(
        (score) => score != myScore,
        orElse: () => 0,
      );
      return '$myScore-$aiScore';
    } else {
      // Partie contre joueur
      final opponentScore = game.scores[opponentId] ?? 0;
      return '$myScore-$opponentScore';
    }
  }

  Widget _buildWinRateRing(double winPercentage, double lossPercentage, double drawPercentage) {
    final total = winPercentage + lossPercentage + drawPercentage;
    final win = total > 0 ? winPercentage / total * 100 : 0.0;
    final loss = total > 0 ? lossPercentage / total * 100 : 0.0;
    final draw = total > 0 ? drawPercentage / total * 100 : 0.0;

    const double size = 200;
    const double strokeWidth = 12;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: WinRatePainter(
              winPercent: win,
              lossPercent: loss,
              drawPercent: draw,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${winPercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Victoires',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              if (_currentPlayer != null)
                Text(
                  '${_currentPlayer!.gamesPlayed} parties',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 5),
        height: 100,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFF1a0033),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF4a0080)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameResultLegend() {
    if (_currentPlayer == null) return SizedBox();
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1a0033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF4a0080)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem('Victoires', _currentPlayer!.gamesWon, Color(0xFF00d4ff)),
          _buildLegendItem('Nuls', _currentPlayer!.gamesDraw, Color(0xFFFFD700)),
          _buildLegendItem('Défaites', _currentPlayer!.gamesLost, Color(0xFFff006e)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  final Map<String, String> _opponentNameCache = {};

  Future<String> _getOpponentName(Game game) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 'Adversaire';
    
    final opponentId = game.players.firstWhere(
      (id) => id != currentUserId && !id.startsWith('ai_'),
      orElse: () => '',
    );
    
    final cacheKey = '${game.id}_$opponentId';
    
    if (_opponentNameCache.containsKey(cacheKey)) {
      return _opponentNameCache[cacheKey]!;
    }
    
    if (opponentId.isEmpty) {
      final aiDifficulty = game.aiDifficulty ?? 'beginner';
      final aiName = 'IA ${aiDifficulty[0].toUpperCase()}${aiDifficulty.substring(1)}';
      _opponentNameCache[cacheKey] = aiName;
      return aiName;
    } else {
      _opponentNameCache[cacheKey] = 'Chargement...';
      
      try {
        final opponent = await GameService.getPlayer(opponentId);
        final opponentName = opponent?.username ?? 'Joueur';
        _opponentNameCache[cacheKey] = opponentName;
        return opponentName;
      } catch (e) {
        _opponentNameCache[cacheKey] = 'Joueur';
        return 'Joueur';
      }
    }
  }

  Widget _buildGameHistoryItem(Game game, int index) {
    return FutureBuilder<String>(
      key: Key('opponent_${game.id}'),
      future: _getOpponentName(game),
      builder: (context, opponentSnapshot) {
        final currentUserId = _auth.currentUser?.uid;
        final opponentId = game.players.firstWhere(
          (id) => id != currentUserId && !id.startsWith('ai_'),
          orElse: () => '',
        );
        final cacheKey = '${game.id}_$opponentId';
        
        final opponentName = _opponentNameCache.containsKey(cacheKey) 
            ? _opponentNameCache[cacheKey]!
            : opponentSnapshot.data ?? 'Chargement...';
        
        final result = _getGameResult(game);
        final score = _getGameScore(game);
        
        final myScore = currentUserId != null ? game.scores[currentUserId] ?? 0 : 0;
        
        final date = _formatRelativeDate(game.finishedAt ?? game.updatedAt);
        
        final Color color = result == 'win' 
          ? Color(0xFFFFD700)
          : result == 'loss' 
            ? Color(0xFFff006e)
            : Color(0xFF00d4ff);

        final IconData icon = result == 'win' 
          ? Icons.emoji_events
          : result == 'loss' 
            ? Icons.sentiment_dissatisfied 
            : Icons.handshake;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Color(0xFF1a0033),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFF4a0080)),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.2),
                border: Border.all(color: color),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              opponentName,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grille ${game.gridSize}×${game.gridSize}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  score,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '+ $myScore pts',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget pour le bouton "Voir plus"
  Widget _buildLoadMoreButton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ElevatedButton(
        onPressed: _hasMoreGames ? _loadMoreGames : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF4a0080),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: Size(double.infinity, 50),
        ),
        child: _hasMoreGames 
            ? Text('VOIR PLUS DE MATCHS')
            : Text('TOUS LES MATCHS AFFICHÉS'),
      ),
    );
  }

  Widget _buildStatsTab() {
    if (_currentPlayer == null) {
      return Center(child: CircularProgressIndicator());
    }

    final totalGames = _currentPlayer!.gamesPlayed;
    final double winPercentage = totalGames > 0 ? (_currentPlayer!.gamesWon / totalGames) * 100 : 0;
    final double lossPercentage = totalGames > 0 ? (_currentPlayer!.gamesLost / totalGames) * 100 : 0;
    final double drawPercentage = totalGames > 0 ? (_currentPlayer!.gamesDraw / totalGames) * 100 : 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF1a0033),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xFF9c27b0)),
            ),
            child: Column(
              children: [
                _buildWinRateRing(winPercentage, lossPercentage, drawPercentage),
                SizedBox(height: 20),
                _buildGameResultLegend(),
              ],
            ),
          ),
          
          SizedBox(height: 20),

          Row(
            children: [
              _buildStatItem('Points Total', _currentPlayer!.totalPoints.toString(), Color(0xFF00d4ff)),
              _buildStatItem('Meilleur Score', '${_currentPlayer!.stats.bestGamePoints}', Color(0xFFe040fb)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildStatItem('Série de Victoire', '${_currentPlayer!.stats.winStreak}', Color(0xFFFFD700)),
              _buildStatItem('Parties Jouées', _currentPlayer!.gamesPlayed.toString(), Color(0xFF9c27b0)),
            ],
          ),
          
          SizedBox(height: 20),
        ],
      ),
    );
  }

Widget _buildHistoryTab() {
  if (_gameHistoryStream == null) {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00d4ff)),
      ),
    );
  }

  return StreamBuilder<List<Game>>(
    stream: _gameHistoryStream,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00d4ff)),
          ),
        );
      }

      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 50),
              SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      }

      final games = snapshot.data ?? [];
      
      // Détermine s'il y a plus de données à charger
      final bool hasMoreData = games.length >= _currentLimit;
      
      // Mettre à jour l'état seulement si nécessaire
      if (hasMoreData != _hasMoreGames) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _hasMoreGames = hasMoreData;
          });
        });
      }

      if (games.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF2d0052), Color(0xFF4a0080)],
                  ),
                  border: Border.all(
                    color: Color(0xFF9c27b0),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.history,
                  color: Color(0xFFe040fb),
                  size: 40,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'AUCUNE PARTIE TERMINÉE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Jouez votre première partie pour voir l\'historique ici',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 16),
        itemCount: games.length + (games.isNotEmpty && _hasMoreGames ? 1 : 0),
        itemBuilder: (context, index) {
          // Si c'est le dernier index et qu'on a des jeux + plus de données, afficher le bouton
          if (index == games.length && games.isNotEmpty && _hasMoreGames) {
            return _buildLoadMoreButton();
          }
          
          // Sinon, afficher un élément d'historique normal
          if (index < games.length) {
            return _buildGameHistoryItem(games[index], index);
          }
          
          return SizedBox.shrink();
        },
      );
    },
  );
}
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF0a0015),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00d4ff)),
          ),
        ),
      );
    }

    if (_currentPlayer == null) {
      return Scaffold(
        backgroundColor: Color(0xFF0a0015),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 50),
              SizedBox(height: 20),
              Text(
                'Profil non trouvé',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadCurrentPlayer,
                child: Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFF0a0015),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1a0033),
                  Color(0xFF2d0052),
                ],
              ),
            ),
            child: Stack(
              children: [
                ...List.generate(15, (index) => _buildAnimatedParticle(index)),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Photo de profil
                    Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF9c27b0).withOpacity(0.5),
                                blurRadius: 15,
                                spreadRadius: 3,
                              ),
                            ],
                            image: _currentPlayer!.avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_currentPlayer!.avatarUrl!,),
                                    fit: BoxFit.cover,
                                  )
                                : DecorationImage(
                                    image: NetworkImage(_currentPlayer!.defaultEmoji),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          child: _currentPlayer!.avatarUrl == null && _currentPlayer!.defaultEmoji.isEmpty
                              ? Icon(Icons.person, size: 30, color: Colors.white)
                              : null,
                        ),
                        
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isUpdatingAvatar ? null : _updateAvatar,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF00d4ff),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF00d4ff).withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: _isUpdatingAvatar
                                  ? Center(
                                      child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPlayer!.username,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          SizedBox(height: 4),
                          
                          Text(
                            '${_currentPlayer!.totalPoints} points • ${_currentPlayer!.winRate.toStringAsFixed(1)}% victoires',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          
                          SizedBox(height: 4),
                          
                          _buildRankSection(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF1a0033),
              border: Border(
                bottom: BorderSide(color: Color(0xFF4a0080)),
              ),
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
                Tab(icon: Icon(Icons.bar_chart), text: 'STATS'),
                Tab(icon: Icon(Icons.history), text: 'HISTORIQUE'),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStatsTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankSection() {
    final rank = _currentPlayer?.globalRank ?? 0;

    return SizedBox(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank <= 3 && rank > 0)
            Icon(
              Icons.emoji_events,
              color: Color(0xFFFFD700),
              size: 16,
            )
          else
            Icon(
              Icons.leaderboard,
              color: Color(0xFF00d4ff),
              size: 16,
            ),
          
          SizedBox(width: 6),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RANG',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                rank > 0 ? '#$rank' : 'Non classé',
                style: TextStyle(
                  color: rank <= 3 ? Color(0xFFFFD700) : Color(0xFF00d4ff),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Poppins',
                  letterSpacing: 0.5,
                  shadows: rank <= 3 ? [
                    Shadow(
                      blurRadius: 10,
                      color: Color(0xFFFFD700).withOpacity(0.5),
                    )
                  ] : [],
                ),
              ),
            ],
          ),
          
          SizedBox(width: 8),
          
        ],
      ),
    );
  }
}

// Painter pour dessiner des segments d'anneau proportionnels
class WinRatePainter extends CustomPainter {
  final double winPercent;
  final double lossPercent;
  final double drawPercent;
  final double strokeWidth;

  WinRatePainter({
    required this.winPercent,
    required this.lossPercent,
    required this.drawPercent,
    this.strokeWidth = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final startAngleBase = -pi / 2;

    double lossSweep = (lossPercent / 100) * 2 * pi;
    double drawSweep = (drawPercent / 100) * 2 * pi;
    double winSweep = (winPercent / 100) * 2 * pi;

    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Color(0xFF2d0052);

    canvas.drawCircle(center, radius, backgroundPaint);

    final lossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = Color(0xFFff006e);

    final drawPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = Color(0xFFFFD700);

    final winPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = Color(0xFF00d4ff);

    double currentStart = startAngleBase;

    if (lossSweep > 0) {
      canvas.drawArc(rect, currentStart, lossSweep, false, lossPaint);
      currentStart += lossSweep;
    }

    if (drawSweep > 0) {
      canvas.drawArc(rect, currentStart, drawSweep, false, drawPaint);
      currentStart += drawSweep;
    }

    if (winSweep > 0) {
      canvas.drawArc(rect, currentStart, winSweep, false, winPaint);
    }

    final outerBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(0.03);
    canvas.drawCircle(center, radius, outerBorder);
  }

  @override
  bool shouldRepaint(covariant WinRatePainter old) {
    return old.winPercent != winPercent ||
        old.lossPercent != lossPercent ||
        old.drawPercent != drawPercent ||
        old.strokeWidth != strokeWidth;
  }
}
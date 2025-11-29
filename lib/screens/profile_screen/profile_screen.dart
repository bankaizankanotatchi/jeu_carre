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

  // Stream pour l'historique des parties
  Stream<List<Game>>? _gameHistoryStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Changé à 2 onglets
    _loadCurrentPlayer();
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
          
          // Initialiser le stream de l'historique des parties
          _gameHistoryStream = GameService.getGameHistory(limit: 20);
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
          itemCount: games.length,
          itemBuilder: (context, index) {
            return _buildGameHistoryItem(games[index], index);
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
                          
                          SizedBox(height: 8),
                          
                          // NOUVEAU: Utiliser globalRank du joueur
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

  // NOUVELLE MÉTHODE OPTIMISÉE: Utiliser globalRank du joueur
  Widget _buildRankSection() {
    // UTILISER LA PROPRIÉTÉ globalRank DU JOUEUR
    final rank = _currentPlayer?.globalRank ?? 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icône de couronne pour les top 3
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
          
          // Texte du rang avec style amélioré
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


// // screens/profile_screen.dart
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:jeu_carre/models/player.dart';
// import 'package:jeu_carre/models/game_model.dart';
// import 'package:jeu_carre/services/game_service.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'dart:io';
// import 'package:image_picker/image_picker.dart';
// import 'package:jeu_carre/services/minio_storage_service.dart';
// import 'package:jeu_carre/services/ranking_service.dart';

// class ProfileScreen extends StatefulWidget {
//   const ProfileScreen({super.key});

//   @override
//   State<ProfileScreen> createState() => _ProfileScreenState();
// }

// class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   Player? _currentPlayer;
//   bool _isLoading = true;
//   final ImagePicker _imagePicker = ImagePicker();
//   final MinioStorageService _minioStorage = MinioStorageService();
//   bool _isUpdatingAvatar = false;
//   int _globalRank = 0;
//   int _totalPlayers = 0;
//   bool _isLoadingRank = true;

//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   // Stream pour l'historique des parties
//   Stream<List<Game>>? _gameHistoryStream;

//   // Données fictives pour les succès
//   // final List<Map<String, dynamic>> _achievements = [
//   //   {'title': 'Première Victoire', 'description': 'Gagner votre première partie', 'icon': '🏆', 'unlocked': true, 'progress': 1.0},
//   //   {'title': 'Série de 10', 'description': 'Gagner 10 parties consécutives', 'icon': '🔥', 'unlocked': false, 'progress': 0.7},
//   //   {'title': 'Maître du Shikaku', 'description': 'Atteindre 1000 points', 'icon': '👑', 'unlocked': true, 'progress': 1.0},
//   //   {'title': 'Stratège Confirmé', 'description': 'Battre l\'IA Expert 5 fois', 'icon': '🎯', 'unlocked': false, 'progress': 0.4},
//   //   {'title': 'Invincible', 'description': 'Gagner 50 parties', 'icon': '⚡', 'unlocked': true, 'progress': 1.0},
//   // ];

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//     _loadCurrentPlayer();
//     _loadGlobalRanking();
//   }

//     Future<void> _loadGlobalRanking() async {
//     try {
//       setState(() {
//         _isLoadingRank = true;
//       });

//       final currentUserId = _auth.currentUser?.uid;
//       if (currentUserId == null) return;

//       // Récupérer le classement global
//       final globalRanking = await RankingService.getAllGlobalRanking().first;
      
//       // Trouver la position du joueur
//       final playerIndex = globalRanking.indexWhere((player) => player.id == currentUserId);
      
//       // Récupérer le nombre total de joueurs
//       final playersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      
//       if (mounted) {
//         setState(() {
//           _globalRank = playerIndex != -1 ? playerIndex + 1 : 0;
//           _totalPlayers = playersSnapshot.size;
//           _isLoadingRank = false;
//         });
//       }
//     } catch (e) {
//       print('Erreur chargement classement: $e');
//       if (mounted) {
//         setState(() {
//           _isLoadingRank = false;
//         });
//       }
//     }
//   }

//   Future<void> _updateAvatar() async {
//   try {
//     final XFile? image = await _imagePicker.pickImage(
//       source: ImageSource.gallery,
//       maxWidth: 500,
//       maxHeight: 500,
//       imageQuality: 80,
//     );
    
//     if (image != null && _currentPlayer != null) {
//       setState(() => _isUpdatingAvatar = true);
      
//       final File imageFile = File(image.path);
      
//       // Upload vers MinIO
//       final String newAvatarUrl = await _minioStorage.updateUserAvatar(
//         imageFile, 
//         _currentPlayer!.id
//       );
      
//       // Mettre à jour le profil dans Firestore
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(_currentPlayer!.id)
//           .update({
//             'avatarUrl': newAvatarUrl,
//           });
      
//       // Mettre à jour l'état local
//       setState(() {
//         _currentPlayer = _currentPlayer!.copyWith(avatarUrl: newAvatarUrl);
//       });
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Photo de profil mise à jour !'),
//           backgroundColor: Color(0xFF00d4ff),
//         ),
//       );
//     }
//   } catch (e) {
//     print('Erreur mise à jour avatar: $e');
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Erreur lors de la mise à jour de la photo'),
//         backgroundColor: Color(0xFFff006e),
//       ),
//     );
//   } finally {
//     setState(() => _isUpdatingAvatar = false);
//   }
// }

//   Future<void> _loadCurrentPlayer() async {
//     try {
//       final User? user = _auth.currentUser;
//       if (user != null) {
//         final DocumentSnapshot playerDoc = await _firestore.collection('users').doc(user.uid).get();
        
//         if (playerDoc.exists) {
//           setState(() {
//             _currentPlayer = Player.fromMap(playerDoc.data() as Map<String, dynamic>);
//             _isLoading = false;
//           });
          
//           // Initialiser le stream de l'historique des parties
//           _gameHistoryStream = GameService.getGameHistory(limit: 20);
//         } else {
//           print('ERREUR: Profil non trouvé pour utilisateur connecté');
//           _redirectToSignup();
//         }
//       } else {
//         _redirectToSignup();
//       }
//     } catch (e) {
//       print('Erreur chargement profil: $e');
//       setState(() => _isLoading = false);
//     }
//   }

//   void _redirectToSignup() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Navigator.pushReplacementNamed(context, '/signup');
//     });
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   // Méthode pour formater la date relative
//   String _formatRelativeDate(DateTime date) {
//     final now = DateTime.now();
//     final difference = now.difference(date);
    
//     if (difference.inMinutes < 1) return 'À l\'instant';
//     if (difference.inHours < 1) return 'Il y a ${difference.inMinutes} min';
//     if (difference.inDays < 1) return 'Il y a ${difference.inHours} h';
//     if (difference.inDays == 1) return 'Hier';
//     if (difference.inDays < 7) return 'Il y a ${difference.inDays} jours';
//     if (difference.inDays < 30) return 'Il y a ${(difference.inDays / 7).floor()} sem';
//     return 'Il y a ${(difference.inDays / 30).floor()} mois';
//   }

//   // Méthode pour déterminer le résultat d'une partie pour l'utilisateur courant
//   String _getGameResult(Game game) {
//     final currentUserId = _auth.currentUser?.uid;
//     if (currentUserId == null) return 'draw';
    
//     if (game.winnerId == null) return 'draw';
//     if (game.winnerId == currentUserId) return 'win';
//     return 'loss';
//   }

//   // Méthode pour obtenir le score formaté
//   String _getGameScore(Game game) {
//     final currentUserId = _auth.currentUser?.uid;
//     if (currentUserId == null) return '0-0';
    
//     final myScore = game.scores[currentUserId] ?? 0;
//     final opponentId = game.players.firstWhere(
//       (id) => id != currentUserId && !id.startsWith('ai_'),
//       orElse: () => '',
//     );
    
//     if (opponentId.isEmpty) {
//       // Partie contre IA
//       final aiScore = game.scores.values.firstWhere(
//         (score) => score != myScore,
//         orElse: () => 0,
//       );
//       return '$myScore-$aiScore';
//     } else {
//       // Partie contre joueur
//       final opponentScore = game.scores[opponentId] ?? 0;
//       return '$myScore-$opponentScore';
//     }
//   }

//   // Méthode pour obtenir les points gagnés
//   // int _getPointsEarned(Game game) {
//   //   final currentUserId = _auth.currentUser?.uid;
//   //   if (currentUserId == null) return 0;
    
//   //   final myScore = game.scores[currentUserId] ?? 0;
//   //   final result = _getGameResult(game);
    
//   //   // Logique de calcul des points (à adapter selon vos règles)
//   //   if (result == 'win') return myScore * 2; // Bonus pour victoire
//   //   if (result == 'draw') return myScore;
//   //   return myScore ~/ 2; // Réduction pour défaite
//   // }

//   Widget _buildWinRateRing(double winPercentage, double lossPercentage, double drawPercentage) {
//     final total = winPercentage + lossPercentage + drawPercentage;
//     final win = total > 0 ? winPercentage / total * 100 : 0.0;
//     final loss = total > 0 ? lossPercentage / total * 100 : 0.0;
//     final draw = total > 0 ? drawPercentage / total * 100 : 0.0;

//     const double size = 200;
//     const double strokeWidth = 12;

//     return SizedBox(
//       width: size,
//       height: size,
//       child: Stack(
//         alignment: Alignment.center,
//         children: [
//           CustomPaint(
//             size: Size(size, size),
//             painter: WinRatePainter(
//               winPercent: win,
//               lossPercent: loss,
//               drawPercent: draw,
//               strokeWidth: strokeWidth,
//             ),
//           ),
//           Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(
//                 '${winPercentage.toStringAsFixed(1)}%',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 24,
//                   fontWeight: FontWeight.w900,
//                 ),
//               ),
//               Text(
//                 'Victoires',
//                 style: TextStyle(
//                   color: Colors.white.withOpacity(0.8),
//                   fontSize: 14,
//                 ),
//               ),
//               if (_currentPlayer != null)
//                 Text(
//                   '${_currentPlayer!.gamesPlayed} parties',
//                   style: TextStyle(
//                     color: Colors.white.withOpacity(0.6),
//                     fontSize: 12,
//                   ),
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatItem(String label, String value, Color color) {
//     return Expanded(
//       child: Container(
//         margin: EdgeInsets.symmetric(horizontal: 5),
//         height: 100,
//         padding: EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Color(0xFF1a0033),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Color(0xFF4a0080)),
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               value,
//               style: TextStyle(
//                 color: color,
//                 fontSize: 18,
//                 fontWeight: FontWeight.w900,
//               ),
//             ),
//             SizedBox(height: 4),
//             Text(
//               label,
//               style: TextStyle(
//                 color: Colors.white.withOpacity(0.8),
//                 fontSize: 12,
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildGameResultLegend() {
//     if (_currentPlayer == null) return SizedBox();
    
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Color(0xFF1a0033),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Color(0xFF4a0080)),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceAround,
//         children: [
//           _buildLegendItem('Victoires', _currentPlayer!.gamesWon, Color(0xFF00d4ff)),
//           _buildLegendItem('Nuls', _currentPlayer!.gamesDraw, Color(0xFFFFD700)),
//           _buildLegendItem('Défaites', _currentPlayer!.gamesLost, Color(0xFFff006e)),
//         ],
//       ),
//     );
//   }

//   Widget _buildLegendItem(String label, int value, Color color) {
//     return Column(
//       children: [
//         Container(
//           width: 12,
//           height: 12,
//           decoration: BoxDecoration(
//             color: color,
//             shape: BoxShape.circle,
//           ),
//         ),
//         SizedBox(height: 4),
//         Text(
//           value.toString(),
//           style: TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//         Text(
//           label,
//           style: TextStyle(
//             color: Colors.white.withOpacity(0.7),
//             fontSize: 10,
//           ),
//         ),
//       ],
//     );
//   }
// // Ajoutez cette Map comme variable d'instance dans votre classe
// final Map<String, String> _opponentNameCache = {};

// // Modifiez la méthode _getOpponentName pour utiliser le cache
// Future<String> _getOpponentName(Game game) async {
//   final currentUserId = _auth.currentUser?.uid;
//   if (currentUserId == null) return 'Adversaire';
  
//   final opponentId = game.players.firstWhere(
//     (id) => id != currentUserId && !id.startsWith('ai_'),
//     orElse: () => '',
//   );
  
//   // Clé unique pour identifier cet adversaire dans cette partie
//   final cacheKey = '${game.id}_$opponentId';
  
//   // Retourner directement si déjà en cache
//   if (_opponentNameCache.containsKey(cacheKey)) {
//     return _opponentNameCache[cacheKey]!;
//   }
  
//   if (opponentId.isEmpty) {
//     // Partie contre IA
//     final aiDifficulty = game.aiDifficulty ?? 'beginner';
//     final aiName = 'IA ${aiDifficulty[0].toUpperCase()}${aiDifficulty.substring(1)}';
//     _opponentNameCache[cacheKey] = aiName;
//     return aiName;
//   } else {
//     // Partie contre joueur - mettre en cache même pendant le chargement
//     _opponentNameCache[cacheKey] = 'Chargement...';
    
//     try {
//       final opponent = await GameService.getPlayer(opponentId);
//       final opponentName = opponent?.username ?? 'Joueur';
//       _opponentNameCache[cacheKey] = opponentName;
//       return opponentName;
//     } catch (e) {
//       _opponentNameCache[cacheKey] = 'Joueur';
//       return 'Joueur';
//     }
//   }
// }

// // Modifiez le widget pour utiliser un FutureBuilder avec une clé stable
// Widget _buildGameHistoryItem(Game game, int index) {
//   // Utiliser l'ID du jeu comme clé pour le FutureBuilder
//   return FutureBuilder<String>(
//     key: Key('opponent_${game.id}'), // Clé stable basée sur l'ID du jeu
//     future: _getOpponentName(game),
//     builder: (context, opponentSnapshot) {
//       // Utiliser le cache si disponible, sinon utiliser les données du snapshot
//       final currentUserId = _auth.currentUser?.uid;
//       final opponentId = game.players.firstWhere(
//         (id) => id != currentUserId && !id.startsWith('ai_'),
//         orElse: () => '',
//       );
//       final cacheKey = '${game.id}_$opponentId';
      
//       final opponentName = _opponentNameCache.containsKey(cacheKey) 
//           ? _opponentNameCache[cacheKey]!
//           : opponentSnapshot.data ?? 'Chargement...';
      
//       final result = _getGameResult(game);
//       final score = _getGameScore(game);
      
//       // Récupérer le score de l'utilisateur courant
//       final myScore = currentUserId != null ? game.scores[currentUserId] ?? 0 : 0;
      
//       final date = _formatRelativeDate(game.finishedAt ?? game.updatedAt);
      
//       final Color color = result == 'win' 
//         ? Color(0xFFFFD700)
//         : result == 'loss' 
//           ? Color(0xFFff006e)
//           : Color(0xFF00d4ff);

//       final IconData icon = result == 'win' 
//         ? Icons.emoji_events
//         : result == 'loss' 
//           ? Icons.sentiment_dissatisfied 
//           : Icons.handshake;

//       return Container(
//         margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//         decoration: BoxDecoration(
//           color: Color(0xFF1a0033),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Color(0xFF4a0080)),
//         ),
//         child: ListTile(
//           leading: Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: color.withOpacity(0.2),
//               border: Border.all(color: color),
//             ),
//             child: Icon(icon, color: color, size: 20),
//           ),
//           title: Text(
//             opponentName,
//             style: TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           subtitle: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Grille ${game.gridSize}×${game.gridSize}',
//                 style: TextStyle(
//                   color: Colors.white.withOpacity(0.6),
//                   fontSize: 12,
//                 ),
//               ),
//               Text(
//                 date,
//                 style: TextStyle(
//                   color: Colors.white.withOpacity(0.6),
//                   fontSize: 10,
//                 ),
//               ),
//             ],
//           ),
//           trailing: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(
//                 score,
//                 style: TextStyle(
//                   color: color,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w900,
//                 ),
//               ),
//               Text(
//                 '+ $myScore pts',
//                 style: TextStyle(
//                   color: Colors.white.withOpacity(0.6),
//                   fontSize: 10,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     },
//   );
// }
//   // Widget _buildAchievementItem(Map<String, dynamic> achievement, int index) {
//   //   return Container(
//   //     margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//   //     padding: EdgeInsets.all(16),
//   //     decoration: BoxDecoration(
//   //       color: Color(0xFF1a0033),
//   //       borderRadius: BorderRadius.circular(12),
//   //       border: Border.all(
//   //         color: achievement['unlocked'] ? Color(0xFF00d4ff) : Color(0xFF4a0080),
//   //         width: 2,
//   //       ),
//   //     ),
//   //     child: Row(
//   //       children: [
//   //         Container(
//   //           width: 50,
//   //           height: 50,
//   //           decoration: BoxDecoration(
//   //             color: achievement['unlocked'] 
//   //               ? Color(0xFF00d4ff).withOpacity(0.2)
//   //               : Color(0xFF4a0080).withOpacity(0.2),
//   //             borderRadius: BorderRadius.circular(25),
//   //             border: Border.all(
//   //               color: achievement['unlocked'] ? Color(0xFF00d4ff) : Color(0xFF4a0080),
//   //             ),
//   //           ),
//   //           child: Center(
//   //             child: Text(
//   //               achievement['icon'],
//   //               style: TextStyle(fontSize: 20),
//   //             ),
//   //           ),
//   //         ),
//   //         SizedBox(width: 16),
//   //         Expanded(
//   //           child: Column(
//   //             crossAxisAlignment: CrossAxisAlignment.start,
//   //             children: [
//   //               Text(
//   //                 achievement['title'],
//   //                 style: TextStyle(
//   //                   color: Colors.white,
//   //                   fontWeight: FontWeight.w700,
//   //                   fontSize: 16,
//   //                 ),
//   //               ),
//   //               SizedBox(height: 4),
//   //               Text(
//   //                 achievement['description'],
//   //                 style: TextStyle(
//   //                   color: Colors.white.withOpacity(0.7),
//   //                   fontSize: 12,
//   //                 ),
//   //               ),
//   //               if (!achievement['unlocked']) ...[
//   //                 SizedBox(height: 8),
//   //                 LinearProgressIndicator(
//   //                   value: achievement['progress'],
//   //                   backgroundColor: Color(0xFF2d0052),
//   //                   color: Color(0xFFe040fb),
//   //                   borderRadius: BorderRadius.circular(10),
//   //                 ),
//   //               ],
//   //             ],
//   //           ),
//   //         ),
//   //         Icon(
//   //           achievement['unlocked'] ? Icons.verified : Icons.lock_outline,
//   //           color: achievement['unlocked'] ? Color(0xFF00d4ff) : Color(0xFFe040fb),
//   //         ),
//   //       ],
//   //     ),
//   //   );
//   // }

//   Widget _buildStatsTab() {
//     if (_currentPlayer == null) {
//       return Center(child: CircularProgressIndicator());
//     }

//     final totalGames = _currentPlayer!.gamesPlayed;
//     final double winPercentage = totalGames > 0 ? (_currentPlayer!.gamesWon / totalGames) * 100 : 0;
//     final double lossPercentage = totalGames > 0 ? (_currentPlayer!.gamesLost / totalGames) * 100 : 0;
//     final double drawPercentage = totalGames > 0 ? (_currentPlayer!.gamesDraw / totalGames) * 100 : 0;

//     return SingleChildScrollView(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         children: [
//           Container(
//             padding: EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Color(0xFF1a0033),
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(color: Color(0xFF9c27b0)),
//             ),
//             child: Column(
//               children: [
//                 _buildWinRateRing(winPercentage, lossPercentage, drawPercentage),
//                 SizedBox(height: 20),
//                 _buildGameResultLegend(),
//               ],
//             ),
//           ),
          
//           SizedBox(height: 20),

//           Row(
//             children: [
//               _buildStatItem('Points Total', _currentPlayer!.totalPoints.toString(), Color(0xFF00d4ff)),
//               _buildStatItem('Meilleur Score', '${_currentPlayer!.stats.bestGamePoints}', Color(0xFFe040fb)),
//             ],
//           ),
//           SizedBox(height: 8),
//           Row(
//             children: [
//               _buildStatItem('Série de Victoire', '${_currentPlayer!.stats.winStreak}', Color(0xFFFFD700)),
//               _buildStatItem('Parties Jouées', _currentPlayer!.gamesPlayed.toString(), Color(0xFF9c27b0)),
//             ],
//           ),
          
//           SizedBox(height: 20),
          
//           // Record contre l'IA
//           // Container(
//           //   padding: EdgeInsets.all(20),
//           //   decoration: BoxDecoration(
//           //     color: Color(0xFF1a0033),
//           //     borderRadius: BorderRadius.circular(20),
//           //     border: Border.all(color: Color(0xFF9c27b0)),
//           //   ),
//           //   child: Column(
//           //     crossAxisAlignment: CrossAxisAlignment.start,
//           //     children: [
//           //       Text(
//           //         'RECORD DE VICTOIRE CONTRE L\'IA',
//           //         style: TextStyle(
//           //           color: Color(0xFFe040fb),
//           //           fontSize: 16,
//           //           fontWeight: FontWeight.w900,
//           //           letterSpacing: 1.2,
//           //         ),
//           //       ),
//           //       SizedBox(height: 16),
//           //       Row(
//           //         mainAxisAlignment: MainAxisAlignment.spaceAround,
//           //         children: [
//           //           _buildIAStatItem('Débutant', _currentPlayer!.stats.vsAIRecord['beginner']!, Color(0xFF00d4ff)),
//           //           _buildIAStatItem('Intermédiaire', _currentPlayer!.stats.vsAIRecord['intermediate']!, Color(0xFF9c27b0)),
//           //           _buildIAStatItem('Expert', _currentPlayer!.stats.vsAIRecord['expert']!, Color(0xFFff006e)),
//           //         ],
//           //       ),
//           //     ],
//           //   ),
//           // ),
//         ],
//       ),
//     );
//   }

//   // Widget _buildIAStatItem(String level, int wins, Color color) {
//   //   return Column(
//   //     children: [
//   //       Container(
//   //         width: 60,
//   //         height: 60,
//   //         decoration: BoxDecoration(
//   //           shape: BoxShape.circle,
//   //           color: color.withOpacity(0.1),
//   //           border: Border.all(color: color, width: 2),
//   //         ),
//   //         child: Center(
//   //           child: Text(
//   //             wins.toString(),
//   //             style: TextStyle(
//   //               color: color,
//   //               fontSize: 18,
//   //               fontWeight: FontWeight.w900,
//   //             ),
//   //           ),
//   //         ),
//   //       ),
//   //       SizedBox(height: 8),
//   //       Text(
//   //         level,
//   //         style: TextStyle(
//   //           color: Colors.white.withOpacity(0.8),
//   //           fontSize: 12,
//   //           fontWeight: FontWeight.w600,
//   //         ),
//   //       ),
//   //     ],
//   //   );
//   // }

//   // TAB HISTORIQUE DYNAMIQUE
//   Widget _buildHistoryTab() {
//     if (_gameHistoryStream == null) {
//       return Center(
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00d4ff)),
//         ),
//       );
//     }

//     return StreamBuilder<List<Game>>(
//       stream: _gameHistoryStream,
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Center(
//             child: CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00d4ff)),
//             ),
//           );
//         }

//         if (snapshot.hasError) {
//           return Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.error, color: Colors.red, size: 50),
//                 SizedBox(height: 16),
//                 Text(
//                   'Erreur de chargement',
//                   style: TextStyle(color: Colors.white),
//                 ),
//               ],
//             ),
//           );
//         }

//         final games = snapshot.data ?? [];

//         if (games.isEmpty) {
//           return Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Container(
//                   width: 80,
//                   height: 80,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     gradient: LinearGradient(
//                       colors: [Color(0xFF2d0052), Color(0xFF4a0080)],
//                     ),
//                     border: Border.all(
//                       color: Color(0xFF9c27b0),
//                       width: 2,
//                     ),
//                   ),
//                   child: Icon(
//                     Icons.history,
//                     color: Color(0xFFe040fb),
//                     size: 40,
//                   ),
//                 ),
//                 SizedBox(height: 20),
//                 Text(
//                   'AUCUNE PARTIE TERMINÉE',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 18,
//                     fontWeight: FontWeight.w900,
//                   ),
//                 ),
//                 SizedBox(height: 12),
//                 Text(
//                   'Jouez votre première partie pour voir l\'historique ici',
//                   style: TextStyle(
//                     color: Colors.white.withOpacity(0.7),
//                     fontSize: 14,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//               ],
//             ),
//           );
//         }

//         return ListView.builder(
//           padding: EdgeInsets.symmetric(vertical: 16),
//           itemCount: games.length,
//           itemBuilder: (context, index) {
//             return _buildGameHistoryItem(games[index], index);
//           },
//         );
//       },
//     );
//   }

//   // Widget _buildAchievementsTab() {
//   //   return ListView.builder(
//   //     padding: EdgeInsets.symmetric(vertical: 16),
//   //     itemCount: _achievements.length,
//   //     itemBuilder: (context, index) {
//   //       return _buildAchievementItem(_achievements[index], index);
//   //     },
//   //   );
//   // }

//   Widget _buildAnimatedParticle(int index) {
//     final random = (index * 123) % 100;
//     final left = (random % 100).toDouble();
//     final top = ((random * 7) % 100).toDouble();
//     final size = 2.0 + (random % 4);
//     final duration = 3 + (random % 5);
    
//     return Positioned(
//       left: left.clamp(0, 100) * MediaQuery.of(context).size.width / 100,
//       top: top.clamp(0, 100) * 180 / 100,
//       child: TweenAnimationBuilder(
//         duration: Duration(seconds: duration),
//         tween: Tween<double>(begin: 0.0, end: 1.0),
//         builder: (context, double value, child) {
//           return Opacity(
//             opacity: value,
//             child: Container(
//               width: size,
//               height: size,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Color(0xFFe040fb).withOpacity(0.6),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Color(0xFFe040fb).withOpacity(0.4),
//                     blurRadius: 10,
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//         onEnd: () {
//           if (mounted) {
//             setState(() {});
//           }
//         },
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return Scaffold(
//         backgroundColor: Color(0xFF0a0015),
//         body: Center(
//           child: CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00d4ff)),
//           ),
//         ),
//       );
//     }

//     if (_currentPlayer == null) {
//       return Scaffold(
//         backgroundColor: Color(0xFF0a0015),
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(Icons.error, color: Colors.red, size: 50),
//               SizedBox(height: 20),
//               Text(
//                 'Profil non trouvé',
//                 style: TextStyle(color: Colors.white, fontSize: 18),
//               ),
//               SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: _loadCurrentPlayer,
//                 child: Text('Réessayer'),
//               ),
//             ],
//           ),
//         ),
//       );
//     }

//     return Scaffold(
//       backgroundColor: Color(0xFF0a0015),
//       body: Column(
//         children: [
//           Container(
//             padding: EdgeInsets.fromLTRB(16, 50, 16, 20),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//                 colors: [
//                   Color(0xFF1a0033),
//                   Color(0xFF2d0052),
//                 ],
//               ),
//             ),
//             child: Stack(
//               children: [
//                 ...List.generate(15, (index) => _buildAnimatedParticle(index)),
                
//                 // MODIFICATION: Remplacer la Column par un Row
//                 Row(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     // Photo de profil (premier enfant du Row)
//                     Stack(
//                       children: [
//                         Container(
//                           width: 80,
//                           height: 80,
//                           decoration: BoxDecoration(
//                             shape: BoxShape.circle,
//                             border: Border.all(color: Colors.white, width: 3),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Color(0xFF9c27b0).withOpacity(0.5),
//                                 blurRadius: 15,
//                                 spreadRadius: 3,
//                               ),
//                             ],
//                             image: _currentPlayer!.avatarUrl != null
//                                 ? DecorationImage(
//                                     image: NetworkImage(_currentPlayer!.avatarUrl!,),
//                                     fit: BoxFit.cover,
//                                   )
//                                 : DecorationImage(
//                                     image: NetworkImage(_currentPlayer!.defaultEmoji),
//                                     fit: BoxFit.cover,
//                                   ),
//                           ),
//                           child: _currentPlayer!.avatarUrl == null && _currentPlayer!.defaultEmoji.isEmpty
//                               ? Icon(Icons.person, size: 30, color: Colors.white)
//                               : null,
//                         ),
                        
//                         // Bouton crayon en bas à droite
//                         Positioned(
//                           bottom: 0,
//                           right: 0,
//                           child: GestureDetector(
//                             onTap: _isUpdatingAvatar ? null : _updateAvatar,
//                             child: Container(
//                               width: 28,
//                               height: 28,
//                               decoration: BoxDecoration(
//                                 shape: BoxShape.circle,
//                                 color: Color(0xFF00d4ff),
//                                 border: Border.all(color: Colors.white, width: 2),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Color(0xFF00d4ff).withOpacity(0.5),
//                                     blurRadius: 8,
//                                     spreadRadius: 1,
//                                   ),
//                                 ],
//                               ),
//                               child: _isUpdatingAvatar
//                                   ? Center(
//                                       child: SizedBox(
//                                         width: 12,
//                                         height: 12,
//                                         child: CircularProgressIndicator(
//                                           strokeWidth: 2,
//                                           valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                                         ),
//                                       ),
//                                     )
//                                   : Icon(
//                                       Icons.edit,
//                                       color: Colors.white,
//                                       size: 14,
//                                     ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),

//                     SizedBox(width: 16), // Espace entre la photo et le texte

//                     // Deuxième enfant du Row: Column avec les informations
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           // Nom du joueur
//                           Text(
//                             _currentPlayer!.username,
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 20,
//                               fontWeight: FontWeight.w900,
//                             ),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
                          
//                           SizedBox(height: 4),
                          
//                           // Points et taux de victoire
//                           Text(
//                             '${_currentPlayer!.totalPoints} points • ${_currentPlayer!.winRate.toStringAsFixed(1)}% victoires',
//                             style: TextStyle(
//                               color: Colors.white.withOpacity(0.8),
//                               fontSize: 14,
//                             ),
//                           ),
                          
//                           SizedBox(height: 8),
                          
//                           // NOUVEAU: Section Rang avec style amélioré
//                           _buildRankSection(),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
          
//           Container(
//             decoration: BoxDecoration(
//               color: Color(0xFF1a0033),
//               border: Border(
//                 bottom: BorderSide(color: Color(0xFF4a0080)),
//               ),
//             ),
//             child: TabBar(
//               controller: _tabController,
//               indicatorColor: Color(0xFF00d4ff),
//               labelColor: Colors.white,
//               unselectedLabelColor: Colors.white.withOpacity(0.6),
//               labelStyle: TextStyle(
//                 fontWeight: FontWeight.w700,
//                 fontSize: 12,
//                 letterSpacing: 1.0,
//               ),
//               indicatorWeight: 3,
//               tabs: [
//                 Tab(icon: Icon(Icons.bar_chart), text: 'STATS'),
//                 Tab(icon: Icon(Icons.history), text: 'HISTORIQUE'),
//                 // Tab(icon: Icon(Icons.emoji_events), text: 'SUCCÈS'),
//               ],
//             ),
//           ),
          
//           Expanded(
//             child: TabBarView(
//               controller: _tabController,
//               children: [
//                 _buildStatsTab(),
//                 _buildHistoryTab(),
//                 // _buildAchievementsTab(),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // NOUVELLE MÉTHODE: Construire la section Rang
//   Widget _buildRankSection() {
//     if (_isLoadingRank) {
//       return Row(
//         children: [
//           Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 16),
//           SizedBox(width: 6),
//           Text(
//             'Chargement du rang...',
//             style: TextStyle(
//               color: Colors.white.withOpacity(0.7),
//               fontSize: 12,
//             ),
//           ),
//         ],
//       );
//     }

//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [
//             Color(0xFF1a0033).withOpacity(0.8),
//             Color(0xFF2d0052).withOpacity(0.8),
//           ],
//         ),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: _globalRank <= 3 ? Color(0xFFFFD700) : Color(0xFF00d4ff),
//           width: 1.5,
//         ),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // Icône de couronne pour les top 3
//           if (_globalRank <= 3 && _globalRank > 0)
//             Icon(
//               Icons.emoji_events,
//               color: Color(0xFFFFD700),
//               size: 16,
//             )
//           else
//             Icon(
//               Icons.leaderboard,
//               color: Color(0xFF00d4ff),
//               size: 16,
//             ),
          
//           SizedBox(width: 6),
          
//           // Texte du rang avec style amélioré
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'RANG',
//                 style: TextStyle(
//                   color: Colors.white.withOpacity(0.7),
//                   fontSize: 10,
//                   fontWeight: FontWeight.w600,
//                   letterSpacing: 1.0,
//                 ),
//               ),
//               Text(
//                 _globalRank > 0 ? '#$_globalRank' : 'Non classé',
//                 style: TextStyle(
//                   color: _globalRank <= 3 ? Color(0xFFFFD700) : Color(0xFF00d4ff),
//                   fontSize: 18, // Taille plus grande
//                   fontWeight: FontWeight.w900, // Plus gras
//                   fontFamily: 'Poppins', // Belle police (assurez-vous de l'avoir dans pubspec.yaml)
//                   letterSpacing: 0.5,
//                   shadows: _globalRank <= 3 ? [
//                     Shadow(
//                       blurRadius: 10,
//                       color: Color(0xFFFFD700).withOpacity(0.5),
//                     )
//                   ] : [],
//                 ),
//               ),
//             ],
//           ),
          
//           SizedBox(width: 8),
          
//           // Séparateur
//           Container(
//             width: 1,
//             height: 20,
//             color: Colors.white.withOpacity(0.3),
//           ),
          
//           SizedBox(width: 8),
          
//           // Total des joueurs
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 '$_totalPlayers',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }



// // Painter pour dessiner des segments d'anneau proportionnels
// class WinRatePainter extends CustomPainter {
//   final double winPercent;
//   final double lossPercent;
//   final double drawPercent;
//   final double strokeWidth;

//   WinRatePainter({
//     required this.winPercent,
//     required this.lossPercent,
//     required this.drawPercent,
//     this.strokeWidth = 12,
//   });

//   @override
//   void paint(Canvas canvas, Size size) {
//     final center = Offset(size.width / 2, size.height / 2);
//     final radius = (size.width / 2) - strokeWidth / 2;

//     final rect = Rect.fromCircle(center: center, radius: radius);
//     final startAngleBase = -pi / 2;

//     double lossSweep = (lossPercent / 100) * 2 * pi;
//     double drawSweep = (drawPercent / 100) * 2 * pi;
//     double winSweep = (winPercent / 100) * 2 * pi;

//     final backgroundPaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = strokeWidth
//       ..color = Color(0xFF2d0052);

//     canvas.drawCircle(center, radius, backgroundPaint);

//     final lossPaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = strokeWidth
//       ..strokeCap = StrokeCap.butt
//       ..color = Color(0xFFff006e);

//     final drawPaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = strokeWidth
//       ..strokeCap = StrokeCap.butt
//       ..color = Color(0xFFFFD700);

//     final winPaint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = strokeWidth
//       ..strokeCap = StrokeCap.butt
//       ..color = Color(0xFF00d4ff);

//     double currentStart = startAngleBase;

//     if (lossSweep > 0) {
//       canvas.drawArc(rect, currentStart, lossSweep, false, lossPaint);
//       currentStart += lossSweep;
//     }

//     if (drawSweep > 0) {
//       canvas.drawArc(rect, currentStart, drawSweep, false, drawPaint);
//       currentStart += drawSweep;
//     }

//     if (winSweep > 0) {
//       canvas.drawArc(rect, currentStart, winSweep, false, winPaint);
//     }

//     final outerBorder = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1
//       ..color = Colors.white.withOpacity(0.03);
//     canvas.drawCircle(center, radius, outerBorder);
//   }

//   @override
//   bool shouldRepaint(covariant WinRatePainter old) {
//     return old.winPercent != winPercent ||
//         old.lossPercent != lossPercent ||
//         old.drawPercent != drawPercent ||
//         old.strokeWidth != strokeWidth;
//   }
// }
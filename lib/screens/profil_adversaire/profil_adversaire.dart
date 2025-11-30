import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/screens/game_mode_screen/game_mode_screen.dart';
import 'package:jeu_carre/services/ranking_service.dart';

class OpponentProfileScreen extends StatefulWidget {
  final Map<String, dynamic> opponent;

  const OpponentProfileScreen({super.key, required this.opponent});

  @override
  State<OpponentProfileScreen> createState() => _OpponentProfileScreenState();
}

class _OpponentProfileScreenState extends State<OpponentProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Player? _opponentPlayer;
  bool _isLoading = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadOpponentData();
  }


  Future<void> _loadOpponentData() async {
    try {
      final opponentId = widget.opponent['id'];
      if (opponentId != null) {
        final DocumentSnapshot playerDoc = await _firestore.collection('users').doc(opponentId).get();
        
        if (playerDoc.exists) {
          setState(() {
            _opponentPlayer = Player.fromMap(playerDoc.data() as Map<String, dynamic>);
            _isLoading = false;
          });
          return;
        }
      }
      // Si le joueur n'existe pas en base ou pas d'ID, on utilise juste les données de base
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Getters avec gestion null-safe améliorée
  String get _displayUsername {
    if (_opponentPlayer?.username != null) {
      return _opponentPlayer!.username!;
    }
    if (widget.opponent['username'] != null) {
      return widget.opponent['username'] as String;
    }
    return 'Joueur';
  }

  String get _displayAvatar {
    // Essayer d'abord l'avatar du player
    if (_opponentPlayer?.displayAvatar != null) {
      return _opponentPlayer!.displayAvatar!;
    }
    // Ensuite essayer avatarUrl de l'opponent
    if (widget.opponent['avatarUrl'] != null) {
      return widget.opponent['avatarUrl'] as String;
    }
    // Ensuite essayer defaultEmoji
    if (widget.opponent['defaultEmoji'] != null) {
      return widget.opponent['defaultEmoji'] as String;
    }
    // Fallback par défaut
    return 'https://via.placeholder.com/80?text=J';
  }

  int get _displayScore => _opponentPlayer?.totalPoints ?? (widget.opponent['score'] as int?) ?? 0;
  bool get _inGame => _opponentPlayer?.inGame ?? (widget.opponent['inGame'] as bool?) ?? false;
  double get _winRate => _opponentPlayer?.winRate ?? 0.0;
  int get _gamesPlayed => _opponentPlayer?.gamesPlayed ?? 0;
  int get _gamesWon => _opponentPlayer?.gamesWon ?? 0;
  int get _gamesLost => _opponentPlayer?.gamesLost ?? 0;
  int get _gamesDraw => _opponentPlayer?.gamesDraw ?? 0;
  int get _bestGamePoints => _opponentPlayer?.stats.bestGamePoints ?? 0;
  int get _winStreak => _opponentPlayer?.stats.winStreak ?? 0;

  // NOUVEAU GETTER: Utiliser globalRank du joueur
  int get _globalRank => _opponentPlayer?.globalRank ?? 0;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _challengeOpponent() {
    if (_inGame) {
      _showAlreadyInGameDialog();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameSetupScreen(
          isAgainstAI: false,
          isOnlineMatch: true,
          opponent: _opponentPlayer,
        ),
      ),
    );
  }

  void _showAlreadyInGameDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2d0052),
                  Color(0xFF1a0033),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Color(0xFF9c27b0),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sports_esports,
                  color: Colors.orange,
                  size: 50,
                ),
                SizedBox(height: 16),
                Text(
                  'JOUEUR OCCUPÉ',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '$_displayUsername est actuellement en partie.\nRevenez plus tard pour le défier !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () => Navigator.of(context).pop(),
                      child: Center(
                        child: Text(
                          'COMPRIS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // MÉTHODE OPTIMISÉE: Utiliser globalRank du joueur
  Widget _buildRankSection() {

    // UTILISER LA PROPRIÉTÉ globalRank DU JOUEUR
    final rank = _globalRank;

    return Container(
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
          ],
      ),
    );
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
              Text(
                '$_gamesPlayed parties',
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
          _buildLegendItem('Victoires', _gamesWon, Color(0xFF00d4ff)),
          _buildLegendItem('Nuls', _gamesDraw, Color(0xFFFFD700)),
          _buildLegendItem('Défaites', _gamesLost, Color(0xFFff006e)),
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

  Widget _buildStatsTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00d4ff)),
        ),
      );
    }

    final double winPercentage = _gamesPlayed > 0 ? (_gamesWon / _gamesPlayed) * 100 : 0;
    final double lossPercentage = _gamesPlayed > 0 ? (_gamesLost / _gamesPlayed) * 100 : 0;
    final double drawPercentage = _gamesPlayed > 0 ? (_gamesDraw / _gamesPlayed) * 100 : 0;

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
              _buildStatItem('Points Total', _displayScore.toString(), Color(0xFF00d4ff)),
              _buildStatItem('Meilleur Score', '$_bestGamePoints', Color(0xFFe040fb)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildStatItem('Série de Victoire', '$_winStreak', Color(0xFFFFD700)),
              _buildStatItem('Parties Jouées', '$_gamesPlayed', Color(0xFF9c27b0)),
            ],
          ),
          
          SizedBox(height: 10),
        ],
      ),
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
                
                Column(
                  children: [
                    // Bouton retour
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 10),
                    
                    // Row pour le profil
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Photo de profil
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF9c27b0), Color(0xFFe040fb)],
                            ),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF9c27b0).withOpacity(0.5),
                                blurRadius: 15,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _displayAvatar.startsWith('http')
                                ? Image.network(
                                    _displayAvatar,
                                    fit: BoxFit.cover,
                                    width: 80,
                                    height: 80,
                                    errorBuilder: (context, error, stackTrace) => 
                                      Icon(Icons.person, size: 30, color: Colors.white),
                                  )
                                : Center(
                                    child: Text(
                                      _displayAvatar,
                                      style: TextStyle(fontSize: 30),
                                    ),
                                  ),
                          ),
                        ),

                        SizedBox(width: 16),

                        // Informations du joueur
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Nom du joueur
                              Text(
                                _displayUsername,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              
                              SizedBox(height: 4),
                              
                              // Points et taux de victoire
                              Text(
                                '$_displayScore points • ${_winRate.toStringAsFixed(1)}% victoires',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                              
                              SizedBox(height: 4),
                              
                              // NOUVEAU: Section Rang optimisée
                              _buildRankSection(),
                            ],
                          ),
                        ),
                      ],
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
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStatsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
      ..strokeCap= StrokeCap.butt
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
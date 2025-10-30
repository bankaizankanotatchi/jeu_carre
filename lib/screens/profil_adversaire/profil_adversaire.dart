import 'dart:math';
import 'package:flutter/material.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/screens/game_mode_screen/game_mode_screen.dart';

class OpponentProfileScreen extends StatefulWidget {
  final Map<String, dynamic> opponent;

  const OpponentProfileScreen({super.key, required this.opponent});

  @override
  State<OpponentProfileScreen> createState() => _OpponentProfileScreenState();
}

class _OpponentProfileScreenState extends State<OpponentProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Créer un User à partir des données de l'adversaire
  User get _opponentUser => User(
    id: widget.opponent['id'] ?? '1',
    username: widget.opponent['username'] ?? 'Joueur',
    email: '',
    avatarUrl: null,
    defaultEmoji: widget.opponent['avatar'] ?? '👤',
    role: UserRole.player,
    totalPoints: widget.opponent['score'] ?? 0,
    gamesPlayed: 120,
    gamesWon: 65,
    gamesLost: 45,
    gamesDraw: 10,
    createdAt: DateTime.now().subtract(Duration(days: 90)),
    lastLoginAt: DateTime.now(),
    stats: UserStats(
      dailyPoints: 35,
      weeklyPoints: 280,
      monthlyPoints: 1100,
      bestGamePoints: 25,
      winStreak: 5,
      bestWinStreak: 10,
      vsAIRecord: {'beginner': 20, 'intermediate': 15, 'expert': 4},
      feedbacksSent: 8,
      feedbacksLiked: 6,
    ),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this); // Un seul tab maintenant
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _challengeOpponent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameSetupScreen(
          isAgainstAI: false,
          isOnlineMatch: true,
        ),
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
                '${_opponentUser.gamesPlayed} parties',
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
          _buildLegendItem('Victoires', _opponentUser.gamesWon, Color(0xFF00d4ff)),
          _buildLegendItem('Nuls', _opponentUser.gamesDraw, Color(0xFFFFD700)),
          _buildLegendItem('Défaites', _opponentUser.gamesLost, Color(0xFFff006e)),
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
    final totalGames = _opponentUser.gamesPlayed;
    final double winPercentage = totalGames > 0 ? (_opponentUser.gamesWon / totalGames) * 100 : 0;
    final double lossPercentage = totalGames > 0 ? (_opponentUser.gamesLost / totalGames) * 100 : 0;
    final double drawPercentage = totalGames > 0 ? (_opponentUser.gamesDraw / totalGames) * 100 : 0;

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
              _buildStatItem('Points Total', _opponentUser.totalPoints.toString(), Color(0xFF00d4ff)),
              _buildStatItem('Meilleur Score', '${_opponentUser.stats.bestGamePoints}', Color(0xFFe040fb)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildStatItem('Série de Victoire', '${_opponentUser.stats.winStreak}', Color(0xFFFFD700)),
              _buildStatItem('Parties Jouées', _opponentUser.gamesPlayed.toString(), Color(0xFF9c27b0)),
            ],
          ),
          
          SizedBox(height: 20),
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
          // Header du profil avec bouton Défier et flèche retour
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
                    // Avatar, nom et bouton Défier
                    Row(
                      children: [
                        // Flèche de retour
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
                        SizedBox(width: 12),
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
                          child: Center(
                            child: Text(
                              _opponentUser.displayAvatar,
                              style: TextStyle(fontSize: 30),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _opponentUser.username,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${_opponentUser.totalPoints} points • ${_opponentUser.winRate.toStringAsFixed(1)}% victoires',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ],
                    ),
                    SizedBox(height: 10),
                  ],
                ),
              ],
            ),
          ),
          
          // TabBar (un seul tab maintenant)
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
          
          // Contenu du tab STATS
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

// Painter pour les statistiques
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
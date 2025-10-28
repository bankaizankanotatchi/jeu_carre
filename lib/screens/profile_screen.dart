import 'dart:math';
import 'package:flutter/material.dart';
import 'package:jeu_carre/models/player.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Données fictives pour l'exemple
  final User _currentUser = User(
    id: '1',
    username: 'AlexPro',
    email: 'alex@example.com',
    avatarUrl: null,
    defaultEmoji: '🥇',
    role: UserRole.player,
    totalPoints: 2450,
    gamesPlayed: 156,
    gamesWon: 89,
    gamesLost: 52,
    gamesDraw: 15,
    createdAt: DateTime.now().subtract(Duration(days: 120)),
    lastLoginAt: DateTime.now(),
    stats: UserStats(
      dailyPoints: 45,
      weeklyPoints: 320,
      monthlyPoints: 1250,
      bestGamePoints: 28,
      winStreak: 8,
      bestWinStreak: 12,
      vsAIRecord: {'beginner': 25, 'intermediate': 18, 'expert': 6},
      feedbacksSent: 12,
      feedbacksLiked: 8,
    ),
  );

  final List<Map<String, dynamic>> _recentGames = [
    {'result': 'win', 'score': '15-12', 'opponent': 'SarahShik', 'date': 'Aujourd\'hui', 'points': 15},
    {'result': 'loss', 'score': '10-14', 'opponent': 'MikeMaster', 'date': 'Hier', 'points': 10},
    {'result': 'win', 'score': '18-9', 'opponent': 'IA Expert', 'date': '2 jours', 'points': 18},
    {'result': 'draw', 'score': '12-12', 'opponent': 'LunaPlay', 'date': '3 jours', 'points': 12},
    {'result': 'win', 'score': '16-11', 'opponent': 'TomStrategy', 'date': '4 jours', 'points': 16},
  ];

  final List<Map<String, dynamic>> _achievements = [
    {'title': 'Première Victoire', 'description': 'Gagner votre première partie', 'icon': '🏆', 'unlocked': true, 'progress': 1.0},
    {'title': 'Série de 10', 'description': 'Gagner 10 parties consécutives', 'icon': '🔥', 'unlocked': false, 'progress': 0.7},
    {'title': 'Maître du Shikaku', 'description': 'Atteindre 1000 points', 'icon': '👑', 'unlocked': true, 'progress': 1.0},
    {'title': 'Stratège Confirmé', 'description': 'Battre l\'IA Expert 5 fois', 'icon': '🎯', 'unlocked': false, 'progress': 0.4},
    {'title': 'Invincible', 'description': 'Gagner 50 parties', 'icon': '⚡', 'unlocked': true, 'progress': 1.0},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
Widget _buildWinRateRing(double winPercentage, double lossPercentage, double drawPercentage) {
  // Normaliser pour que la somme fasse 100 (ou 0 si tout est nul)
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
        // Le CustomPaint dessine les arcs (défaites -> nuls -> victoires)
        CustomPaint(
          size: Size(size, size),
          painter: WinRatePainter(
            winPercent: win,
            lossPercent: loss,
            drawPercent: draw,
            strokeWidth: strokeWidth,
          ),
        ),

        // Centre avec les pourcentages
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
              '${_currentUser.gamesPlayed} parties',
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
        height: 100, // Hauteur fixe pour uniformiser
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
          _buildLegendItem('Victoires', _currentUser.gamesWon, Color(0xFF00d4ff)),
          _buildLegendItem('Nuls', _currentUser.gamesDraw, Color(0xFFFFD700)),
          _buildLegendItem('Défaites', _currentUser.gamesLost, Color(0xFFff006e)),
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

  Widget _buildGameHistoryItem(Map<String, dynamic> game, int index) {
    final Color color = game['result'] == 'win' 
      ? Color(0xFF00d4ff)
      : game['result'] == 'loss' 
        ? Color(0xFFff006e)
        : Color(0xFFFFD700);

    final IconData icon = game['result'] == 'win' 
      ? Icons.emoji_events
      : game['result'] == 'loss' 
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
          game['opponent'],
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          game['date'],
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              game['score'],
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '+${game['points']} pts',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementItem(Map<String, dynamic> achievement, int index) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1a0033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: achievement['unlocked'] ? Color(0xFF00d4ff) : Color(0xFF4a0080),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // Icône
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: achievement['unlocked'] 
                ? Color(0xFF00d4ff).withOpacity(0.2)
                : Color(0xFF4a0080).withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: achievement['unlocked'] ? Color(0xFF00d4ff) : Color(0xFF4a0080),
              ),
            ),
            child: Center(
              child: Text(
                achievement['icon'],
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
          SizedBox(width: 16),
          // Contenu
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement['title'],
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  achievement['description'],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                if (!achievement['unlocked']) ...[
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: achievement['progress'],
                    backgroundColor: Color(0xFF2d0052),
                    color: Color(0xFFe040fb),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
              ],
            ),
          ),
          // Statut
          Icon(
            achievement['unlocked'] ? Icons.verified : Icons.lock_outline,
            color: achievement['unlocked'] ? Color(0xFF00d4ff) : Color(0xFFe040fb),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    final  totalGames = _currentUser.gamesPlayed;
    final double winPercentage = totalGames > 0 ? (_currentUser.gamesWon / totalGames) * 100 : 0;
    final double lossPercentage = totalGames > 0 ? (_currentUser.gamesLost / totalGames) * 100 : 0;
    final double drawPercentage = totalGames > 0 ? (_currentUser.gamesDraw / totalGames) * 100 : 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Anneau des statistiques
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
                _buildStatItem('Points Total', _currentUser.totalPoints.toString(), Color(0xFF00d4ff)),
                _buildStatItem('Meilleur Score', '${_currentUser.stats.bestGamePoints}', Color(0xFFe040fb)),
                ],
            ),
          SizedBox(height: 8),
            Row(
                children: [
                _buildStatItem('Série de Victoire', '${_currentUser.stats.winStreak}', Color(0xFFFFD700)),
                _buildStatItem('Parties Jouées', _currentUser.gamesPlayed.toString(), Color(0xFF9c27b0)),
                ],
                       ),
           
          
          SizedBox(height: 20),
          
          // Record contre l'IA
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF1a0033),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xFF9c27b0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RECORD DE VICTOIRE CONTRE L\'IA',
                  style: TextStyle(
                    color: Color(0xFFe040fb),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildIAStatItem('Débutant', _currentUser.stats.vsAIRecord['beginner']!, Color(0xFF00d4ff)),
                    _buildIAStatItem('Intermédiaire', _currentUser.stats.vsAIRecord['intermediate']!, Color(0xFF9c27b0)),
                    _buildIAStatItem('Expert', _currentUser.stats.vsAIRecord['expert']!, Color(0xFFff006e)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIAStatItem(String level, int wins, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              wins.toString(),
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          level,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 16),
      itemCount: _recentGames.length,
      itemBuilder: (context, index) {
        return _buildGameHistoryItem(_recentGames[index], index);
      },
    );
  }

  Widget _buildAchievementsTab() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 16),
      itemCount: _achievements.length,
      itemBuilder: (context, index) {
        return _buildAchievementItem(_achievements[index], index);
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
    return Scaffold(
      backgroundColor: Color(0xFF0a0015),
      body: Column(
        children: [
          // Header du profil avec particules
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
                // Particules animées en fond
                ...List.generate(15, (index) => _buildAnimatedParticle(index)),
                
                // Contenu du header
                Column(
                  children: [
                    // Avatar et nom
                    Row(
                      children: [
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
                              _currentUser.displayAvatar,
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
                                _currentUser.username,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${_currentUser.totalPoints} points • ${_currentUser.winRate.toStringAsFixed(1)}% victoires',
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
                    SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
          
          // TabBar
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
                Tab(icon: Icon(Icons.emoji_events), text: 'SUCCÈS'),
              ],
            ),
          ),
          
          // Contenu des tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStatsTab(),
                _buildHistoryTab(),
                _buildAchievementsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Painter pour dessiner des segments d'anneau proportionnels
class WinRatePainter extends CustomPainter {
  final double winPercent;  // attendu 0..100 (normalisé)
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
    final startAngleBase = -pi / 2; // commence en haut

    // Convertir pourcentages en radians (sweep angles)
    double lossSweep = (lossPercent / 100) * 2 * pi;
    double drawSweep = (drawPercent / 100) * 2 * pi;
    double winSweep = (winPercent / 100) * 2 * pi;

    // Peintures
    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Color(0xFF2d0052);

    // Fond complet (optionnel, pour voir l'anneau)
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

    // Dessiner les arcs dans l'ordre : défaites, nuls, victoires
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

    // Optionnel : contour fin autour pour "adoucir"
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

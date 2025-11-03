import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jeu_carre/screens/navigation_screen.dart';

class GameRulesScreen extends StatefulWidget {
  const GameRulesScreen({super.key});

  @override
  State<GameRulesScreen> createState() => _GameRulesScreenState();
}

class _GameRulesScreenState extends State<GameRulesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _rulesSections = [
    {
      'title': '🎯 OBJECTIF DU JEU',
      'description': 'Former le plus de carrés possible en connectant les points sur la grille. Chaque carré complet rapporte 1 point.',
      'illustration': 'grid_points',
    },
    {
      'title': '🔄 TOUR PAR TOUR',
      'description': 'Les joueurs bleu et rouge jouent alternativement. Chaque joueur place un point par tour.',
      'illustration': 'player_turns',
    },
    {
      'title': '📐 FORMATION DES CARRÉS',
      'description': 'Un carré se forme lorsque 4 points sont connectés pour former un carré parfait. Le joueur qui complète le carré le marque.',
      'illustration': 'square_formation',
    },
    {
      'title': '⭐ SCORING',
      'description': 'Chaque carré complet rapporte 1 point. Si un mouvement complète plusieurs carrés, le joueur marque tous les carrés formés.',
      'illustration': 'scoring',
    },
    {
      'title': '⏱️ TIMERS',
      'description': '15 secondes par coup • 3 minutes par partie totale • 3 tours manqués = défaite automatique • au debut de chaque partie vous pouvez changer ces paramètres sauf pour la pénalité',
      'illustration': 'timers',
    },
    {
      'title': '🏆 VICTOIRE',
      'description': 'Le joueur avec le plus de points à la fin de la partie gagne. En cas d\'égalité, c\'est un match nul.',
      'illustration': 'victory',
    },
  ];

  final List<Map<String, dynamic>> _strategyTips = [
    {
      'title': '🧠 STRATÉGIE DÉFENSIVE',
      'description': 'Bloquez les mouvements adverses en anticipant leurs coups. Empêchez la formation de carrés multiples.',
      'icon': Icons.shield,
      'color': Color(0xFF00d4ff),
    },
    {
      'title': '⚡ STRATÉGIE OFFENSIVE',
      'description': 'Priorisez les positions qui peuvent créer plusieurs carrés en un seul coup.',
      'icon': Icons.bolt,
      'color': Color(0xFFff006e),
    },
    {
      'title': '🔍 ANTICIPATION',
      'description': 'Regardez 2-3 coups à l\'avance. Analysez les opportunités de carrés potentiels.',
      'icon': Icons.search,
      'color': Color(0xFFe040fb),
    },
    {
      'title': '🎯 CONTRÔLE DU CENTRE',
      'description': 'Le centre de la grille offre plus d\'opportunités. Contrôlez-le pour maximiser vos chances.',
      'icon': Icons.center_focus_strong,
      'color': Color(0xFF9c27b0),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
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

  Widget _buildRuleIllustration(String type, int index) {
    switch (type) {
      case 'grid_points':
        return _buildGridPointsIllustration();
      case 'player_turns':
        return _buildPlayerTurnsIllustration();
      case 'square_formation':
        return _buildSquareFormationIllustration();
      case 'scoring':
        return _buildScoringIllustration();
      case 'timers':
        return _buildTimersIllustration();
      case 'victory':
        return _buildVictoryIllustration();
      default:
        return _buildGridPointsIllustration();
    }
  }

  Widget _buildGridPointsIllustration() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Color(0xFF1a0033),
        border: Border.all(color: Color(0xFF4a0080), width: 2),
      ),
      child: CustomPaint(
        painter: GridIllustrationPainter(),
      ),
    );
  }

  Widget _buildPlayerTurnsIllustration() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF00d4ff).withOpacity(0.8),
                      Color(0xFF00d4ff).withOpacity(0.3),
                    ],
                  ),
                  border: Border.all(color: Color(0xFF00d4ff), width: 3),
                ),
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
              SizedBox(height: 10),
              Text(
                'BLEU',
                style: TextStyle(
                  color: Color(0xFF00d4ff),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFFff006e).withOpacity(0.8),
                      Color(0xFFff006e).withOpacity(0.3),
                    ],
                  ),
                  border: Border.all(color: Color(0xFFff006e), width: 3),
                ),
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
              SizedBox(height: 10),
              Text(
                'ROUGE',
                style: TextStyle(
                  color: Color(0xFFff006e),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSquareFormationIllustration() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Color(0xFF1a0033),
        border: Border.all(color: Color(0xFF4a0080), width: 2),
      ),
      child: CustomPaint(
        painter: SquareFormationPainter(),
      ),
    );
  }

  Widget _buildScoringIllustration() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0xFFe040fb).withOpacity(0.8),
                  Color(0xFFe040fb).withOpacity(0.2),
                ],
              ),
              border: Border.all(color: Color(0xFFe040fb), width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '+1',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildScoreIndicator('BLEU', 3, Color(0xFF00d4ff)),
              SizedBox(width: 20),
              _buildScoreIndicator('ROUGE', 2, Color(0xFFff006e)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreIndicator(String player, int score, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withOpacity(0.8),
                color.withOpacity(0.3),
              ],
            ),
            border: Border.all(color: color, width: 2),
          ),
        ),
        SizedBox(height: 8),
        Text(
          '$score',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          player,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTimersIllustration() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTimerItem('⏱️ Tour', '15s', Color(0xFF00d4ff)),
          _buildTimerItem('⏰ Partie', '3:00', Color(0xFFe040fb)),
          _buildTimerItem('🚫 Pénalité', '3 tours', Color(0xFFff006e)),
        ],
      ),
    );
  }

  Widget _buildTimerItem(String label, String time, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          SizedBox(width: 12),
          Text(
            time,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVictoryIllustration() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0xFFFFD700).withOpacity(0.8),
                  Color(0xFFFFA000).withOpacity(0.3),
                ],
              ),
              border: Border.all(color: Color(0xFFFFD700), width: 3),
            ),
            child: Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 50,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'VICTOIRE !',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesPageView() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _rulesSections.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final rule = _rulesSections[index];
              return Container(
                padding: EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 30),
                      // Illustration
                      _buildRuleIllustration(rule['illustration'], index),
                      SizedBox(height: 30),
                      
                      // Titre
                      Text(
                        rule['title'],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      
                      // Description
                      Text(
                        rule['description'],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        // Indicateurs de page
        Container(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_rulesSections.length, (index) {
              return Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index 
                      ? Color(0xFF00d4ff)
                      : Colors.white.withOpacity(0.3),
                ),
              );
            }),
          ),
        ),
        
        // Boutons de navigation
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              _currentPage != 0 ? Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF9c27b0),
                        Color(0xFF7b1fa2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: _currentPage > 0 ? () {
                        _pageController.previousPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } : null,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_back,
                              color: _currentPage > 0 ? Colors.white : Colors.white.withOpacity(0.5),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'PRÉCÉDENT',
                              style: TextStyle(
                                color: _currentPage > 0 ? Colors.white : Colors.white.withOpacity(0.5),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ):SizedBox(),
              _currentPage !=0 ?const SizedBox(width: 12):const SizedBox(),
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF00d4ff),
                        Color(0xFF0099cc),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: _currentPage < _rulesSections.length - 1 ? () {
                        _pageController.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } : () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => NavigationScreen()),
                            );
                        Navigator.pop(context);
                      },
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage < _rulesSections.length - 1 ? 'SUIVANT' : 'TERMINER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              _currentPage < _rulesSections.length - 1 ? Icons.arrow_forward : Icons.check,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStrategyTips() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _strategyTips.length,
      itemBuilder: (context, index) {
        final tip = _strategyTips[index];
        return Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2d0052),
                Color(0xFF1a0033),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: tip['color'],
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: tip['color'].withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () {},
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            tip['color'].withOpacity(0.8),
                            tip['color'].withOpacity(0.3),
                          ],
                        ),
                        border: Border.all(
                          color: tip['color'],
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        tip['icon'],
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip['title'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            tip['description'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0a0015),
      body: Column(
        children: [
          // Header
          Container(
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
                ...List.generate(12, (index) => _buildAnimatedParticle(index)),
                
                Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          margin: EdgeInsets.fromLTRB(16, 65, 16, 10),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF9c27b0), Color(0xFFe040fb)],
                            ),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        SizedBox(width: 16),
                        Container(
                          padding: EdgeInsets.fromLTRB(2, 25, 6, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RÈGLES DU JEU',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Apprenez à maîtriser Shikaku comme un pro',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    
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
                        Tab(icon: Icon(Icons.menu_book), text: 'RÈGLES'),
                        Tab(icon: Icon(Icons.psychology), text: 'STRATÉGIES'),
                      ],
                    ),
                  ),
                  ],
                ),
              ],
            ),
          ),
          
          // Contenu des tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRulesPageView(),
                _buildStrategyTips(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Painters pour les illustrations
class GridIllustrationPainter extends CustomPainter {
  GridIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // On prend le plus petit côté pour garder des cases carrées
    final cellSize = min(size.width, size.height) / 4;
    final gridSize = cellSize * 4;

    // Centrer la grille si l'espace n'est pas carré
    final offsetX = (size.width - gridSize) / 2;
    final offsetY = (size.height - gridSize) / 2;

    final paint = Paint()
      ..color = Color(0xFF6200b3).withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Appliquer la translation pour dessiner la grille centrée
    canvas.save();
    canvas.translate(offsetX, offsetY);

    // Lignes verticales (5 lignes pour 4 colonnes)
    for (int i = 0; i <= 4; i++) {
      final x = i * cellSize;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, gridSize),
        paint,
      );
    }

    // Lignes horizontales (5 lignes pour 4 lignes)
    for (int i = 0; i <= 4; i++) {
      final y = i * cellSize;
      canvas.drawLine(
        Offset(0, y),
        Offset(gridSize, y),
        paint,
      );
    }

    // Points aux intersections
    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (int x = 0; x <= 4; x++) {
      for (int y = 0; y <= 4; y++) {
        pointPaint.color = Color(0xFF4a0080).withOpacity(0.5);
        canvas.drawCircle(
          Offset(x * cellSize, y * cellSize),
          4,
          pointPaint,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



class SquareFormationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 4;
    
    // 🧱 Grille
    final gridPaint = Paint()
      ..color = const Color(0xFF6200b3).withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 4; i++) {
      final x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, 4 * cellSize), gridPaint);
      canvas.drawLine(Offset(0, i * cellSize), Offset(4 * cellSize, i * cellSize), gridPaint);
    }

    // 🔵 Points de la grille
    final pointPaint = Paint()..style = PaintingStyle.fill;

    for (int x = 0; x <= 4; x++) {
      for (int y = 0; y <= 4; y++) {
        pointPaint.color = const Color(0xFF4a0080).withOpacity(0.5);
        canvas.drawCircle(Offset(x * cellSize, y * cellSize), 4, pointPaint);
      }
    }

    // 🎨 Peintures
    final squarePaintBlue = Paint()
      ..color = const Color(0xFF00d4ff).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final squarePaintRed = Paint()
      ..color = const Color(0xFFc4005a).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final squareBorderBlue = Paint()
      ..color = const Color(0xFF00d4ff)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final squareBorderRed = Paint()
      ..color = const Color(0xFFc4005a)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // 🟦 Carré bleu (1ʳᵉ colonne / 1ʳᵉ ligne)
    final squareRectBlue = Rect.fromPoints(
      Offset(0 * cellSize + 2, 0 * cellSize + 2),
      Offset(1 * cellSize - 2, 1 * cellSize - 2),
    );

    // 🔴 Carré rouge (3ᵉ colonne / 3ᵉ ligne)
    final squareRectRed = Rect.fromPoints(
      Offset(2 * cellSize + 2, 2 * cellSize + 2),
      Offset(3 * cellSize - 2, 3 * cellSize - 2),
    );

    // 🟦 Dessin carré bleu
    canvas.drawRect(squareRectBlue, squarePaintBlue);
    canvas.drawRect(squareRectBlue, squareBorderBlue);

    // 🔴 Dessin carré rouge
    canvas.drawRect(squareRectRed, squarePaintRed);
    canvas.drawRect(squareRectRed, squareBorderRed);

    // 🌟 Points de surbrillance (coins des carrés)
    final highlightPaintBlue = Paint()
      ..color = const Color(0xFF00d4ff)
      ..style = PaintingStyle.fill;

    final highlightPaintRed = Paint()
      ..color = const Color(0xFFc4005a)
      ..style = PaintingStyle.fill;

    // Points du carré bleu
    canvas.drawCircle(Offset(0 * cellSize, 0 * cellSize), 6, highlightPaintBlue);
    canvas.drawCircle(Offset(1 * cellSize, 0 * cellSize), 6, highlightPaintBlue);
    canvas.drawCircle(Offset(0 * cellSize, 1 * cellSize), 6, highlightPaintBlue);
    canvas.drawCircle(Offset(1 * cellSize, 1 * cellSize), 6, highlightPaintBlue);

    // Points du carré rouge
    canvas.drawCircle(Offset(2 * cellSize, 2 * cellSize), 6, highlightPaintRed);
    canvas.drawCircle(Offset(3 * cellSize, 2 * cellSize), 6, highlightPaintRed);
    canvas.drawCircle(Offset(2 * cellSize, 3 * cellSize), 6, highlightPaintRed);
    canvas.drawCircle(Offset(3 * cellSize, 3 * cellSize), 6, highlightPaintRed);

    // 🎲 Quelques points "aléatoires" autour pour simuler des blocages
    canvas.drawCircle(Offset(2 * cellSize, 0 * cellSize), 6, highlightPaintBlue);
    canvas.drawCircle(Offset(3 * cellSize, 1 * cellSize), 6, highlightPaintBlue);
    canvas.drawCircle(Offset(1 * cellSize, 3 * cellSize), 6, highlightPaintBlue);
    canvas.drawCircle(Offset(2 * cellSize, 1 * cellSize), 6, highlightPaintRed);
    canvas.drawCircle(Offset(3 * cellSize, 2 * cellSize), 6, highlightPaintRed);
    canvas.drawCircle(Offset(1 * cellSize, 2 * cellSize), 6, highlightPaintRed);

  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Modèle temporaire pour GridPoint
class GridPoint {
  final int x;
  final int y;
  final String? playerId;

  GridPoint({required this.x, required this.y, this.playerId});
}
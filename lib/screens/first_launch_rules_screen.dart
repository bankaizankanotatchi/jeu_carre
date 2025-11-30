// screens/first_launch_rules_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jeu_carre/screens/signup_screen.dart';
import 'package:jeu_carre/services/preferences_service.dart';

class FirstLaunchRulesScreen extends StatefulWidget {
  const FirstLaunchRulesScreen({super.key});

  @override
  State<FirstLaunchRulesScreen> createState() => _FirstLaunchRulesScreenState();
}

class _FirstLaunchRulesScreenState extends State<FirstLaunchRulesScreen> 
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _rulesSections = [
    {
      'title': '🎯 OBJECTIF DU JEU',
      'description': 'Former le plus de carrés possible en connectant les points sur la grille. Chaque carré complet rapporte 1 point.',
      'illustration': 'grid_points',
    },
        {
      'title': '🎮 MODES MULTIJOUEURS',
      'description': '• En ligne : Défiez d\'autres joueurs connectés\n• Local : Jouez sur le même écran avec un ami\n• Après "Testez vos capacités", allez dans "Multijoueur"',
      'illustration': 'multiplayer',
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
      'title': '🔌 RECONNEXION',
      'description': 'Si un joueur se déconnecte pendant une partie, il dispose de 30 secondes pour se reconnecter et reprendre la partie. Passé ce délai, la partie est perdue pour le joueur déconnecté.',
      'illustration': 'reconnection',
    },
    {
      'title': '🏆 VICTOIRE',
      'description': 'Le joueur avec le plus de points à la fin de la partie gagne. En cas d\'égalité, c\'est un match nul.',
      'illustration': 'victory',
    },
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
                color: const Color(0xFFe040fb).withOpacity(0.6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFe040fb).withOpacity(0.4),
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
      case 'reconnection':
        return _buildReconnectionIllustration();
      case 'multiplayer':
        return _buildMultiplayerIllustration();
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
        color: const Color(0xFF1a0033),
        border: Border.all(color: const Color(0xFF4a0080), width: 2),
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
                      const Color(0xFF00d4ff).withOpacity(0.8),
                      const Color(0xFF00d4ff).withOpacity(0.3),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFF00d4ff), width: 3),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 10),
              Text(
                'BLEU',
                style: TextStyle(
                  color: const Color(0xFF00d4ff),
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
                      const Color(0xFFff006e).withOpacity(0.8),
                      const Color(0xFFff006e).withOpacity(0.3),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFFff006e), width: 3),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 10),
              Text(
                'ROUGE',
                style: TextStyle(
                  color: const Color(0xFFff006e),
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
        color: const Color(0xFF1a0033),
        border: Border.all(color: const Color(0xFF4a0080), width: 2),
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
                  const Color(0xFFe040fb).withOpacity(0.8),
                  const Color(0xFFe040fb).withOpacity(0.2),
                ],
              ),
              border: Border.all(color: const Color(0xFFe040fb), width: 3),
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
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildScoreIndicator('BLEU', 3, const Color(0xFF00d4ff)),
              const SizedBox(width: 20),
              _buildScoreIndicator('ROUGE', 2, const Color(0xFFff006e)),
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
        const SizedBox(height: 8),
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
          _buildTimerItem('⏱️ Tour', '15s', const Color(0xFF00d4ff)),
          _buildTimerItem('⏰ Partie', '3:00', const Color(0xFFe040fb)),
          _buildTimerItem('🚫 Pénalité', '3 tours', const Color(0xFFff006e)),
        ],
      ),
    );
  }

  Widget _buildReconnectionIllustration() {
    return SizedBox(
      width: 200,
      height: 100,
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
                  const Color(0xFF4CAF50).withOpacity(0.8),
                  const Color(0xFF2E7D32).withOpacity(0.3),
                ],
              ),
              border: Border.all(color: const Color(0xFF4CAF50), width: 3),
            ),
            child: Icon(
              Icons.wifi_find_rounded,
              color: Colors.white,
              size: 50,
            ),
          ),
        

        ],
      ),
    );
  }

  Widget _buildMultiplayerIllustration() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icône multijoueur en ligne
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF00d4ff).withOpacity(0.8),
                          const Color(0xFF00d4ff).withOpacity(0.3),
                        ],
                      ),
                      border: Border.all(color: const Color(0xFF00d4ff), width: 2),
                    ),
                    child: Icon(Icons.people_alt, color: Colors.white, size: 30),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'En ligne',
                    style: TextStyle(
                      color: const Color(0xFF00d4ff),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFe040fb).withOpacity(0.8),
                          const Color(0xFFe040fb).withOpacity(0.3),
                        ],
                      ),
                      border: Border.all(color: const Color(0xFFe040fb), width: 2),
                    ),
                    child: Icon(Icons.phone_iphone, color: Colors.white, size: 30),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Local',
                    style: TextStyle(
                      color: const Color(0xFFe040fb),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),
          // Instructions
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2d0052),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4a0080), width: 1),
            ),
            child: Text(
              'Testez vos capacités → Multijoueur → Choisissez un mode',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerItem(String label, String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          const SizedBox(width: 12),
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
                  const Color(0xFFFFD700).withOpacity(0.8),
                  const Color(0xFFFFA000).withOpacity(0.3),
                ],
              ),
              border: Border.all(color: const Color(0xFFFFD700), width: 3),
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'VICTOIRE !',
            style: TextStyle(
              color: const Color(0xFFFFD700),
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
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),
                      // Illustration
                      _buildRuleIllustration(rule['illustration'], index),
                      const SizedBox(height: 30),
                      
                      // Titre
                      Text(
                        rule['title'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      
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
        SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_rulesSections.length, (index) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index 
                      ? const Color(0xFF00d4ff)
                      : Colors.white.withOpacity(0.3),
                ),
              );
            }),
          ),
        ),
        
        // Boutons de navigation
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _currentPage !=0 ? Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
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
                          duration: const Duration(milliseconds: 300),
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
                            const SizedBox(width: 8),
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
              ):const SizedBox(),
              _currentPage !=0 ?const SizedBox(width: 12):const SizedBox(),
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
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
                      onTap: () async {
                        if (_currentPage < _rulesSections.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          // Marquer le premier lancement comme terminé et rediriger vers la connexion
                          await PreferencesService.setFirstLaunchCompleted();
                          
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupScreen(),
                            ),
                          );
                        }
                      },
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage < _rulesSections.length - 1 ? 'SUIVANT' : 'COMMENCER',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentPage < _rulesSections.length - 1 ? Icons.arrow_forward : Icons.play_arrow,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0015),
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
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
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 65, 16, 20),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BIENVENUE DANS SHIKUKA!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Découvrez les règles du jeu',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Contenu des règles
          Expanded(
            child:  _buildRulesPageView(),
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
      ..color = const Color(0xFF6200b3).withOpacity(0.3)
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
        pointPaint.color = const Color(0xFF4a0080).withOpacity(0.5);
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
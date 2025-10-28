import 'package:flutter/material.dart';
import 'package:jeu_carre/models/ai_player.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  // Données fictives pour le classement
  final List<Map<String, dynamic>> _dailyRanking = [
    {'name': 'AlexPro', 'score': 2450, 'avatar': '🥇', 'trend': 'up'},
    {'name': 'SarahShik', 'score': 2380, 'avatar': '🥈', 'trend': 'up'},
    {'name': 'MikeMaster', 'score': 2310, 'avatar': '🥉', 'trend': 'down'},
    {'name': 'LunaPlay', 'score': 2250, 'avatar': '👑', 'trend': 'up'},
    {'name': 'TomStrategy', 'score': 2190, 'avatar': '⚡', 'trend': 'up'},
  ];

  final List<Map<String, dynamic>> _weeklyRanking = [
    {'name': 'ProPlayerX', 'score': 15600, 'avatar': '🥇', 'trend': 'up'},
    {'name': 'ShikakuQueen', 'score': 14850, 'avatar': '🥈', 'trend': 'stable'},
    {'name': 'GridMaster', 'score': 14200, 'avatar': '🥉', 'trend': 'down'},
    {'name': 'BrainStorm', 'score': 13800, 'avatar': '👑', 'trend': 'up'},
    {'name': 'LogicLegend', 'score': 13200, 'avatar': '⚡', 'trend': 'up'},
  ];

  final List<Map<String, dynamic>> _monthlyRanking = [
    {'name': 'UltimateGamer', 'score': 58900, 'avatar': '🥇', 'trend': 'up'},
    {'name': 'StrategyKing', 'score': 57400, 'avatar': '🥈', 'trend': 'stable'},
    {'name': 'MindMaster', 'score': 56200, 'avatar': '🥉', 'trend': 'up'},
    {'name': 'ShikakuPro', 'score': 55100, 'avatar': '👑', 'trend': 'down'},
    {'name': 'GridGenius', 'score': 53800, 'avatar': '⚡', 'trend': 'up'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Interval(0.0, 0.5)),
    );
    
    _animationController.forward();

    // Écouter le défilement pour les effets parallax
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showGameRules(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
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
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF9c27b0).withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RÈGLES DU JEU',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  _buildRuleItem('🎯 Objectif', 'Former le plus de carrés possible en connectant les points'),
                  _buildRuleItem('🔄 Tour par Tour', 'Les joueurs bleu et rouge jouent alternativement'),
                  _buildRuleItem('📐 Formation', 'Cliquez sur un point pour le relier et former des carrés'),
                  _buildRuleItem('⭐ Score', 'Chaque carré complet rapporte 1 point'),
                  _buildRuleItem('⏱️ Timer', '15 secondes par coup - 3 minutes par partie'),
                  _buildRuleItem('🚫 Pénalités', '3 tours manqués = défaite automatique'),
                  SizedBox(height: 20),
                  Text(
                    'CONSEILS STRATÉGIQUES',
                    style: TextStyle(
                      color: Color(0xFFe040fb),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 10),
                  _buildTipItem('Bloquez les mouvements adverses'),
                  _buildTipItem('Priorisez les carrés multiples'),
                  _buildTipItem('Anticipez 2-3 coups à l\'avance'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRuleItem(String title, String description) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Color(0xFF00d4ff),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF9c27b0), Color(0xFFe040fb)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF9c27b0).withOpacity(0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Icon(Icons.grid_on, color: Colors.white, size: 40),
                ),
                SizedBox(height: 20),
                Text(
                  'Shikaku Édition Ultime',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Le jeu de stratégie ultime où l\'intelligence et la rapidité font la différence. Défiez vos amis, affrontez l\'IA et devenez le maître du Shikaku!',
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
                          'FERMER',
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

  Widget _buildSimpleGameModeCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 30),
                  ),
                  SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double appBarHeight = 200 - (_scrollOffset * 0.5).clamp(0.0, 100.0);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // SliverAppBar avec effet parallax
         SliverAppBar(
        expandedHeight: 200.0,
        floating: false,
        pinned: true,
        backgroundColor: Color(0xFF1a0033), // Fond violet foncé
        flexibleSpace: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final top = constraints.biggest.height;
            final bool isExpanded = top == 200.0;
            
            return FlexibleSpaceBar(
              title: AnimatedOpacity(
                duration: Duration(milliseconds: 200),
                opacity: isExpanded ? 0.0 : 1.0,
                child: Text(
                  'Shikaku',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              centerTitle: true,
              background: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1a0033),
                          Color(0xFF2d0052),
                          Color(0xFF4a0080),
                          Color(0xFF6200b3),
                        ],
                      ),
                    ),),
                  // Effet de particules animées
                  ...List.generate(15, (index) => _buildAnimatedParticle(index)),
                ],
              ),
            );
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            color: Color(0xFF2d0052),
            onSelected: (value) {
              if (value == 'rules') {
                _showGameRules(context);
              } else if (value == 'about') {
                _showAboutDialog(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'rules',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: Color(0xFF00d4ff)),
                    SizedBox(width: 8),
                    Text('Règles du jeu',style: TextStyle(color: Colors.white),),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFe040fb)),
                    SizedBox(width: 8),
                    Text('À propos',style: TextStyle(color: Colors.white),),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
          // Contenu principal
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1a0033),
                    Color(0xFF2d0052),
                    Color(0xFF0a0015),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Section Slogan
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          children: [
                            Text(
                              'OÙ LA STRATÉGIE RENCONTRE LA RAPIDITÉ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                foreground: Paint()
                                  ..shader = LinearGradient(
                                    colors: [Color(0xFFe040fb), Color(0xFF00d4ff), Color(0xFFba68c8)],
                                  ).createShader(Rect.fromLTWH(0.0, 0.0, 300.0, 70.0)),
                                letterSpacing: 2,
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Affrontez l\'IA, défiez vos amis et dominez le classement mondial dans ce jeu de stratégie captivant',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Section Test des capacités vs IA
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TESTEZ VOS CAPACITÉS',
                          style: TextStyle(
                            color: Color(0xFF00d4ff),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Affrontez notre intelligence artificielle',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // Cartes des niveaux IA - MODIFIÉ EN ROW
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        _buildSimpleGameModeCard(
                          title: 'DÉBUTANT',
                          icon: Icons.school,
                          color: Color(0xFF00d4ff),
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (context) => GameScreen(
                                gridSize: 15,
                                isAgainstAI: true,
                                aiDifficulty: AIDifficulty.beginner,
                              ))),
                        ),
                        _buildSimpleGameModeCard(
                          title: 'INTERMÉDIAIRE',
                          icon: Icons.auto_awesome,
                          color: Color(0xFF9c27b0),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GameScreen(gridSize: 15,isAgainstAI: true,aiDifficulty: AIDifficulty.intermediate))),
                        ),
                       
                      ],
                    ),
                  ),
                  SizedBox(height: 10,),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                         _buildSimpleGameModeCard(
                          title: 'EXPERT',
                          icon: Icons.military_tech,
                          color: Color(0xFFff006e),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GameScreen(gridSize: 25,isAgainstAI: true,aiDifficulty: AIDifficulty.expert,))),
                        ),
                       
                      ],
                    ),
                  ),
                  

                  SizedBox(height: 40),

                  // Section Multijoueur - MODIFIÉ EN ROW
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MULTIJOUEUR',
                          style: TextStyle(
                            color: Color(0xFFe040fb),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            _buildSimpleGameModeCard(
                              title: 'AVEC UN AMI',
                              icon: Icons.people,
                              color: Color(0xFFe040fb),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GameScreen(gridSize: 15,isAgainstAI: false,))),
                            ),
                            _buildSimpleGameModeCard(
                              title: 'EN LIGNE',
                              icon: Icons.public,
                              color: Color(0xFF00b894),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Recherche d\'adversaires en ligne...'),
                                    backgroundColor: Color(0xFF00b894),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Section Classement
                  SizedBox(height: 40),

                  // Section Classement
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CLASSEMENT MONDIAL',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Découvrez les meilleurs joueurs',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 30),
                      ],
                    ),
                  ),

                  // Classement du jour
                  _buildRankingSection('DU JOUR', _dailyRanking, Color(0xFF00d4ff)),
                  SizedBox(height: 40),

                  // Classement de la semaine
                  _buildRankingSection('DE LA SEMAINE', _weeklyRanking, Color(0xFFe040fb)),
                  SizedBox(height: 40),

                  // Classement du mois
                  _buildRankingSection('DU MOIS', _monthlyRanking, Color(0xFFFFD700)),
                  SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingSection(String title, List<Map<String, dynamic>> ranking, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      SizedBox(height: 16),
      SizedBox(
        height: 140,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 20),
          children: ranking.asMap().entries.map((entry) {
            final index = entry.key;
            final player = entry.value;
            final rank = index + 1;
            
            return Container(
              margin: EdgeInsets.only(right: 20),
              child: Column(
                children: [
                  // Avatar avec double bordure et numéro
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Bordure externe
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              color.withOpacity(0.8),
                              color.withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                      // Bordure interne
                      Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2d0052),
                          border: Border.all(
                            color: color,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            player['avatar'],
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      // Numéro de classement qui déborde
                      Positioned(
                        left: 0,
                        bottom: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '$rank',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Indicateur de tendance
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Color(0xFF2d0052),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: player['trend'] == 'up' ? Colors.green : 
                                     player['trend'] == 'down' ? Colors.red : Colors.yellow,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              player['trend'] == 'up' ? Icons.arrow_upward : 
                              player['trend'] == 'down' ? Icons.arrow_downward : Icons.remove,
                              color: player['trend'] == 'up' ? Colors.green : 
                                     player['trend'] == 'down' ? Colors.red : Colors.yellow,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Nom du joueur avec ellipse si trop long
                  Container(
                    width: 90,
                    child: Column(
                      children: [
                        Text(
                          _truncateName(player['name']),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${player['score']} pts',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    ],
  );
}

  // Méthode utilitaire pour tronquer les noms longs
  String _truncateName(String name) {
    if (name.length <= 10) return name;
    return '${name.substring(0, 8)}..';
  }

  Widget _buildAnimatedParticle(int index) {
    final random = (index * 123) % 100;
    final left = (random % 100).toDouble();
    final top = ((random * 7) % 100).toDouble();
    final size = 2.0 + (random % 4);
    final duration = 3 + (random % 5);
    
    return Positioned(
      left: left.clamp(0, 100) * MediaQuery.of(context).size.width / 100,
      top: top.clamp(0, 100) * 200 / 100,
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
}
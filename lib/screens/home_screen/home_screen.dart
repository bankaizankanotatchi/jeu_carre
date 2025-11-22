import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jeu_carre/models/ai_player.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/screens/game_mode_screen/game_mode_screen.dart';
import 'package:jeu_carre/screens/game_rule_screen/gamerule_screen.dart';
import 'package:jeu_carre/screens/online_screen/online_screen.dart';
import 'package:jeu_carre/screens/profil_adversaire/profil_adversaire.dart';
import 'package:jeu_carre/services/ranking_service.dart';

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

  // Données de classement
  List<Map<String, dynamic>> _dailyRanking = [];
  List<Map<String, dynamic>> _weeklyRanking = [];
  List<Map<String, dynamic>> _monthlyRanking = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription? _dailySubscription;
  StreamSubscription? _weeklySubscription;
  StreamSubscription? _monthlySubscription;

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
    _loadRankings();

    // Écouter le défilement pour les effets parallax
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  Future<void> _loadRankings() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Charger les classements depuis Firebase en temps réel
      _loadRealTimeRankings();

    } catch (e) {
      print('Erreur initialisation classements: $e');
      _handleError('Erreur de chargement des classements');
    }
  }

  void _loadRealTimeRankings() {
    try {
      // Classement du jour
      _dailySubscription = RankingService.getDailyRanking(limit: 5).listen(
        (players) {
          try {
            final formatted = RankingService.formatRankingData(players, 'daily');
            if (mounted) {
              setState(() {
                _dailyRanking = formatted['players'];
                _isLoading = false;
              });
            }
          } catch (e) {
            print('Erreur formatage classement jour: $e');
            _handleError('Erreur de formatage des données');
          }
        },
        onError: (error) {
          print('Erreur stream classement jour: $error');
          _handleError('Erreur connexion classement jour');
        },
        cancelOnError: false,
      );

      // Classement de la semaine
      _weeklySubscription = RankingService.getWeeklyRanking(limit: 5).listen(
        (players) {
          try {
            final formatted = RankingService.formatRankingData(players, 'weekly');
            if (mounted) {
              setState(() {
                _weeklyRanking = formatted['players'];
                _isLoading = false;
              });
            }
          } catch (e) {
            print('Erreur formatage classement semaine: $e');
            _handleError('Erreur de formatage des données');
          }
        },
        onError: (error) {
          print('Erreur stream classement semaine: $error');
          _handleError('Erreur connexion classement semaine');
        },
        cancelOnError: false,
      );

      // Classement du mois
      _monthlySubscription = RankingService.getMonthlyRanking(limit: 5).listen(
        (players) {
          try {
            final formatted = RankingService.formatRankingData(players, 'monthly');
            if (mounted) {
              setState(() {
                _monthlyRanking = formatted['players'];
                _isLoading = false;
              });
            }
          } catch (e) {
            print('Erreur formatage classement mois: $e');
            _handleError('Erreur de formatage des données');
          }
        },
        onError: (error) {
          print('Erreur stream classement mois: $error');
          _handleError('Erreur connexion classement mois');
        },
        cancelOnError: false,
      );

    } catch (e) {
      print('Erreur initialisation streams: $e');
      _handleError('Erreur de connexion aux serveurs');
    }
  }

//   void _viewUserProfile(Map<String, dynamic> user) {
//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => OpponentProfileScreen(opponent: {
//         'id': user['id'],
//         'username': user['username'],
//         'avatar': user['displayAvatar'],
//         'score': user['totalPoints'],
//       }),
//     ),
//   );
// }


  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
    
    // Afficher un snackbar d'erreur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _retryLoadRankings() {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    _loadRankings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _dailySubscription?.cancel();
    _weeklySubscription?.cancel();
    _monthlySubscription?.cancel();
    super.dispose();
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
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

  // Widget _buildLoadingStats() {
  //   return Column(
  //     children: [
  //       _buildStatItemShimmer('Joueurs inscrits'),
  //       _buildStatItemShimmer('Parties jouées'),
  //       _buildStatItemShimmer('Actifs aujourd\'hui'),
  //       _buildStatItemShimmer('Points totaux'),
  //     ],
  //   );
  // }

  // Widget _buildStatsError() {
  //   return Column(
  //     children: [
  //       _buildStatItem('Joueurs inscrits', '--'),
  //       _buildStatItem('Parties jouées', '--'),
  //       _buildStatItem('Actifs aujourd\'hui', '--'),
  //       _buildStatItem('Points totaux', '--'),
  //     ],
  //   );
  // }

  // Widget _buildStatItemShimmer(String label) {
  //   return Container(
  //     margin: EdgeInsets.symmetric(vertical: 4),
  //     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //     decoration: BoxDecoration(
  //       color: Colors.white.withOpacity(0.1),
  //       borderRadius: BorderRadius.circular(10),
  //     ),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //       children: [
  //         Text(
  //           label,
  //           style: TextStyle(
  //             color: Colors.white.withOpacity(0.8),
  //             fontSize: 12,
  //           ),
  //         ),
  //         Container(
  //           width: 40,
  //           height: 12,
  //           color: Colors.white.withOpacity(0.3),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildStatItem(String label, String value) {
  //   return Container(
  //     margin: EdgeInsets.symmetric(vertical: 4),
  //     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //     decoration: BoxDecoration(
  //       color: Colors.white.withOpacity(0.1),
  //       borderRadius: BorderRadius.circular(10),
  //     ),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //       children: [
  //         Text(
  //           label,
  //           style: TextStyle(
  //             color: Colors.white.withOpacity(0.8),
  //             fontSize: 12,
  //           ),
  //         ),
  //         Text(
  //           value,
  //           style: TextStyle(
  //             color: Color(0xFF00d4ff),
  //             fontSize: 12,
  //             fontWeight: FontWeight.w700,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1a0033),
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final top = constraints.biggest.height;
                final bool isExpanded = top == 200.0;

                return FlexibleSpaceBar(
                  title: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isExpanded ? 0.0 : 1.0,
                    child: const Text(
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
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
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
                        ),
                      ),
                      CustomPaint(
                        painter: SquareFormationPainter(),
                        size: Size.infinite,
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: const Color(0xFF2d0052),
                onSelected: (value) {
                  if (value == 'rules') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => GameRulesScreen()),
                    );
                  } else if (value == 'about') {
                    _showAboutDialog(context);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'rules',
                    child: Row(
                      children: [
                        Icon(Icons.help_outline, color: Color(0xFF00d4ff)),
                        SizedBox(width: 8),
                        Text('Règles du jeu', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'about',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFFe040fb)),
                        SizedBox(width: 8),
                        Text('À propos', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
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

                  // Cartes des niveaux IA
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
                              builder: (context) => GameSetupScreen(
                                isAgainstAI: true,
                                aiDifficulty: AIDifficulty.beginner,
                              ))),
                        ),
                        _buildSimpleGameModeCard(
                          title: 'INTERMÉDIAIRE',
                          icon: Icons.auto_awesome,
                          color: Color(0xFF9c27b0),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GameSetupScreen(isAgainstAI: true,aiDifficulty: AIDifficulty.intermediate))),
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
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GameSetupScreen(isAgainstAI: true,aiDifficulty: AIDifficulty.expert,))),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 40),

                  // Section Multijoueur
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
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GameSetupScreen(isAgainstAI: false,))),
                            ),
                            _buildSimpleGameModeCard(
                              title: 'EN LIGNE',
                              icon: Icons.public,
                              color: Color(0xFF00b894),
                                onTap: () => Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (context) => OnlineUsersScreen())
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Section Classement
                  SizedBox(height: 40),
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

                  // Classements
                  if (_errorMessage != null)
                    _buildErrorState()
                  else if (_isLoading)
                    _buildLoadingRankings()
                  else
                    Column(
                      children: [
                        _buildRankingSection('Meilleurs joueurs du jour', _dailyRanking, Color(0xFF00d4ff)),
                        SizedBox(height: 40),
                        _buildRankingSection('Meilleurs joueurs de la semaine', _weeklyRanking, Color(0xFFe040fb)),
                        SizedBox(height: 40),
                        _buildRankingSection('Meilleurs joueurs du mois', _monthlyRanking, Color(0xFFFFD700)),
                      ],
                    ),
                  
                  SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 50,
          ),
          SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Erreur de chargement',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 20),
          Container(
            width: 200,
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
                onTap: _retryLoadRankings,
                child: Center(
                  child: Text(
                    'RÉESSAYER',
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
    );
  }

  Widget _buildLoadingRankings() {
    return Column(
      children: [
        _buildRankingSectionShimmer('Meilleurs joueurs du jour', Color(0xFF00d4ff)),
        SizedBox(height: 40),
        _buildRankingSectionShimmer('Meilleurs joueurs de la semaine', Color(0xFFe040fb)),
        SizedBox(height: 40),
        _buildRankingSectionShimmer('Meilleurs joueurs du mois', Color(0xFFFFD700)),
      ],
    );
  }

  Widget _buildRankingSectionShimmer(String title, Color color) {
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
            children: List.generate(5, (index) => _buildRankingItemShimmer(color)),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingItemShimmer(Color color) {
    return Container(
      margin: EdgeInsets.only(right: 20),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.3),
            ),
          ),
          SizedBox(height: 12),
          Container(
            width: 90,
            height: 16,
            color: Colors.white.withOpacity(0.3),
          ),
          SizedBox(height: 4),
          Container(
            width: 60,
            height: 14,
            color: color.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

Widget _buildRankingSection(String title, List<Map<String, dynamic>> ranking, Color color) {
  final hasPlayers = ranking.isNotEmpty;
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      SizedBox(height: 16),
      
      if (!hasPlayers)
        // Message quand le classement est vide
        Container(
          width: double.infinity,
          height: 140,
          margin: EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                color: color.withOpacity(0.5),
                size: 40,
              ),
              SizedBox(height: 12),
              Text(
                'Aucun joueur pour le moment',
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Soyez le premier à marquer des points!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        )
      else
        // Classement normal quand il y a des joueurs
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
                      Stack(
                        alignment: Alignment.center,
                        children: [
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
                            child: ClipOval(
                              child: Image.network(
                                      player['avatar'],
                                      fit: BoxFit.cover,
                                      width: 75,
                                      height: 75,
                                      errorBuilder: (context, error, stackTrace) => 
                                      Icon(Icons.person, size: 30, color: Colors.white),
                                    ),
                            ),
                          ),
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
                      SizedBox(
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
  String _truncateName(String name) {
    if (name.length <= 15) return name;
    return '${name.substring(0, 14)}..';
  }
}

// [Garder la classe SquareFormationPainter exactement comme avant]
class SquareFormationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const int gridCount = 7;
    final cellSize = size.width / gridCount;

    final gridPaint = Paint()
      ..color = const Color(0xFF6200b3).withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= gridCount; i++) {
      final x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, gridCount * cellSize), gridPaint);
    }

    for (int j = 0; j <= gridCount; j++) {
      final y = j * cellSize;
      canvas.drawLine(Offset(0, y), Offset(gridCount * cellSize, y), gridPaint);
    }

    final pointPaint = Paint()..style = PaintingStyle.fill;
    for (int x = 0; x <= gridCount; x++) {
      for (int y = 0; y <= gridCount; y++) {
        pointPaint.color = const Color(0xFF4a0080).withOpacity(0.5);
        canvas.drawCircle(Offset(x * cellSize, y * cellSize), 3.5, pointPaint);
      }
    }

    final squarePaintBlue = Paint()
      ..color = const Color(0xFF00d4ff).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    final squarePaintRed = Paint()
      ..color = const Color(0xFFc4005a).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final squareBorderBlue = Paint()
      ..color = const Color(0xFF00d4ff)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final squareBorderRed = Paint()
      ..color = const Color(0xFFc4005a)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final squareRectBlue = Rect.fromPoints(
      Offset(cellSize * 1 + 2, cellSize * 1 + 2),
      Offset(cellSize * 2 - 2, cellSize * 2 - 2),
    );
    final squareRectBlue2 = Rect.fromPoints(
      Offset(cellSize * 5 + 2, cellSize * 0 + 2),
      Offset(cellSize * 6 - 2, cellSize * 1 - 2),
    );

    final squareRectRed = Rect.fromPoints(
      Offset(cellSize * 3 + 2, cellSize * 2 + 2),
      Offset(cellSize * 4 - 2, cellSize * 3 - 2),
    );
    final squareRectRed2 = Rect.fromPoints(
      Offset(cellSize * 4 - 2, cellSize * 2 + 2),
      Offset(cellSize * 5 - 2, cellSize * 3 - 2),
    );

    canvas.drawRect(squareRectBlue, squarePaintBlue);
    canvas.drawRect(squareRectBlue, squareBorderBlue);
    canvas.drawRect(squareRectBlue2, squarePaintBlue);
    canvas.drawRect(squareRectBlue2, squareBorderBlue);
    canvas.drawRect(squareRectRed, squarePaintRed);
    canvas.drawRect(squareRectRed, squareBorderRed);
    canvas.drawRect(squareRectRed2, squarePaintRed);
    canvas.drawRect(squareRectRed2, squareBorderRed);

    final highlightPaintBlue = Paint()..color = const Color(0xFF00d4ff);
    final highlightPaintRed = Paint()..color = const Color(0xFFc4005a);

    final blueCorners = [
      Offset(cellSize * 1, cellSize * 1),
      Offset(cellSize * 2, cellSize * 1),
      Offset(cellSize * 1, cellSize * 2),
      Offset(cellSize * 2, cellSize * 2),
    ];
    for (final c in blueCorners) {
      canvas.drawCircle(c, 5, highlightPaintBlue);
    }

    final redCorners = [
      Offset(cellSize * 3, cellSize * 2),
      Offset(cellSize * 4, cellSize * 2),
      Offset(cellSize * 3, cellSize * 3),
      Offset(cellSize * 4, cellSize * 3),
    ];
    for (final c in redCorners) {
      canvas.drawCircle(c, 5, highlightPaintRed);
    }

    canvas.drawCircle(Offset(cellSize * 3, cellSize * 1), 5, highlightPaintBlue);
    canvas.drawCircle(Offset(cellSize * 1, cellSize * 5), 5, highlightPaintBlue);
    canvas.drawCircle(Offset(cellSize * 5, cellSize * 0), 5, highlightPaintBlue);
    canvas.drawCircle(Offset(cellSize * 6, cellSize * 0), 5, highlightPaintBlue);
    canvas.drawCircle(Offset(cellSize * 6, cellSize * 1), 5, highlightPaintBlue);
    canvas.drawCircle(Offset(cellSize * 5, cellSize * 1), 5, highlightPaintBlue);
    canvas.drawCircle(Offset(cellSize * 6, cellSize * 3), 5, highlightPaintBlue);
    canvas.drawCircle(Offset(cellSize * 2, cellSize * 3), 5, highlightPaintRed);
    canvas.drawCircle(Offset(cellSize * 6, cellSize * 2), 5, highlightPaintRed);
    canvas.drawCircle(Offset(cellSize * 3, cellSize * 5), 5, highlightPaintRed);
    canvas.drawCircle(Offset(cellSize * 5, cellSize * 2), 5, highlightPaintRed);
    canvas.drawCircle(Offset(cellSize * 5, cellSize * 3), 5, highlightPaintRed);
    canvas.drawCircle(Offset(cellSize * 4, cellSize * 1), 5, highlightPaintRed);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
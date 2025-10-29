import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:jeu_carre/models/ai_player.dart';
import 'package:jeu_carre/models/radarpoint.dart';
import '../models/game_model.dart';
import '../utils/game_logic.dart';

class GameScreen extends StatefulWidget {
  final int gridSize;
  final bool isAgainstAI;
  final AIDifficulty aiDifficulty;
  

  GameScreen({required this.gridSize, required this.isAgainstAI, this.aiDifficulty = AIDifficulty.intermediate,});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // État du jeu
  List<GridPoint> points = [];
  List<Square> squares = [];
  String currentPlayer = 'bleu';
  Map<String, int> scores = {'bleu': 0, 'rouge': 0};
  bool isGameFinished = false;
  Map<String, int> consecutiveMissedTurns = {'bleu': 0, 'rouge': 0};
  bool _resultModalShown = false; // Contrôle d'affichage du modal

  // Animation pour l'effet radar
  late AnimationController _radarAnimationController;
  late Animation<double> _radarAnimation;
  GridPoint? _lastPlayedPoint;

    // Nouveaux paramètres pour le mode IA
  String aiPlayerId = 'rouge'; // L'IA joue avec les rouges par défaut
  bool isAITurn = false;

  // Timer du jeu entier
  late Timer _gameTimer;
  int _timeRemaining = 180; // 3 minutes en secondes
  double _progressValue = 0.0;

  // Timer de réflexion
  late Timer _reflexionTimer;
  int _reflexionTimeRemaining = 15; // 15 secondes par joueur

  // Contrôles de zoom et pan
  TransformationController _transformationController = TransformationController();
  late AnimationController _scoreAnimationController;
  late Animation<double> _scoreScaleAnimation;

  // Données fictives pour les spectateurs
  final List<Map<String, dynamic>> _spectators = [
    {'id': '1', 'avatar': '🥇', 'username': 'AlexPro'},
    {'id': '2', 'avatar': '🤖', 'username': 'IA_Master'},
    {'id': '3', 'avatar': '👑', 'username': 'ShikakuQueen'},
    {'id': '4', 'avatar': '⚡', 'username': 'SpeedRunner'},
    {'id': '5', 'avatar': '🎯', 'username': 'GridMaster'},
    {'id': '6', 'avatar': '🌟', 'username': 'StarPlayer'},
    {'id': '7', 'avatar': '🔥', 'username': 'FireSpirit'},
    {'id': '8', 'avatar': '💎', 'username': 'DiamondMind'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _startGameTimer();
    _startReflexionTimer();
    
    _scoreAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    
    _scoreScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scoreAnimationController, curve: Curves.easeInOut),
    );

        // Animation radar
    _radarAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    
    _radarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _radarAnimationController,
        curve: Curves.easeOut,
      ),
    );

  // Configurer l'IA si nécessaire
    if (widget.isAgainstAI) {
      //isAgainstAI = true;
      aiPlayerId = 'rouge'; // L'IA joue avec les rouges
      
      // Si l'IA commence, démarrer son tour
      if (currentPlayer == aiPlayerId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startAITurn();
        });
      }
    }
    // ✅ CORRECTION : Zoomer sur le centre après l'initialisation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerZoom();
    });
  }

  @override
  void dispose() {
    _gameTimer.cancel();
    _reflexionTimer.cancel();
    _transformationController.dispose();
    _scoreAnimationController.dispose();
    _radarAnimationController.dispose();
    super.dispose();
  }

  void _startRadarAnimation(GridPoint point) {
    _lastPlayedPoint = point;
    _radarAnimationController.reset();
    _radarAnimationController.forward();
  }

  void _startAITurn() {
  if (!widget.isAgainstAI || currentPlayer != aiPlayerId || isGameFinished) return;
  
  setState(() {
    isAITurn = true;
  });
  
  _playAIMove();
}

  // ✅ NOUVELLE MÉTHODE : Centrer le zoom
  void _centerZoom() {
    final screenSize = MediaQuery.of(context).size;
    final gridWidth = (widget.gridSize * 60.0) + 40;
    final gridHeight = (widget.gridSize * 60.0) + 40;

    // Calculer le zoom pour que la grille tienne dans l'écran
    final scaleX = screenSize.width / gridWidth;
    final scaleY = screenSize.height * 0.7 / gridHeight; // 0.7 pour la hauteur de la grille
    final scale = math.min(scaleX, scaleY) * 0.9; // 0.9 pour une petite marge

    // Calculer la translation pour centrer
    final translateX = (screenSize.width - (gridWidth * scale)) / 2;
    final translateY = (screenSize.height * 0.7 - (gridHeight * scale)) / 2;

    setState(() {
      _transformationController.value = Matrix4.identity()
        ..translate(translateX, translateY)
        ..scale(scale);
    });
  }

void _playAIMove() async {
  if (!widget.isAgainstAI || currentPlayer != aiPlayerId || isGameFinished) return;
  
  setState(() {
    isAITurn = true;
  });
  
  // L'IA doit jouer avant que le timer expire
  final aiMove = await AIPlayer.getBestMove(
    points,
    widget.gridSize,
    aiPlayerId,
    difficulty: widget.aiDifficulty, // ← ICI LA DIFFICULTÉ EST PASSÉE
  );
  
  // Vérifier que le timer n'a pas expiré pendant le calcul
  if (_reflexionTimeRemaining <= 0) {
    // Le temps est écoulé, l'IA a manqué son tour
    setState(() {
      isAITurn = false;
    });
    return;
  }
  
  if (aiMove != null && mounted) {
    setState(() {
      isAITurn = false;
    });
    
    _executeAIMove(aiMove);
  }
}

void _executeAIMove(GridPoint aiMove) {
  if (isGameFinished || !mounted) return;
  
  setState(() {
    points.add(aiMove);

      // Démarrer l'animation radar pour le coup de l'IA
      _startRadarAnimation(aiMove);
    
    final newSquares = GameLogic.checkSquares(
      points,
      widget.gridSize,
      aiPlayerId,
      aiMove.x,
      aiMove.y,
    );
    
    squares.addAll(newSquares);
    scores[aiPlayerId] = scores[aiPlayerId]! + newSquares.length;
    
    if (points.length >= widget.gridSize * widget.gridSize) {
      isGameFinished = true;
      _gameTimer.cancel();
      _reflexionTimer.cancel();
    } else {
      _resetReflexionTimer();
      _switchPlayer();
      
      // Si après avoir changé de joueur, c'est encore à l'IA de jouer
      if (widget.isAgainstAI && currentPlayer == aiPlayerId) {
        _startAITurn();
      }
    }
  });
}

  void _initializeGame() {
    points = [];
    squares = [];
    scores = {'bleu': 0, 'rouge': 0};
    currentPlayer = 'bleu';
    isGameFinished = false;
    _timeRemaining = 180;
    _progressValue = 0.0;
    _reflexionTimeRemaining = 15;
    _transformationController.value = Matrix4.identity();
    consecutiveMissedTurns = {'bleu': 0, 'rouge': 0};
  }

  void _startGameTimer() {
    _gameTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        setState(() {
          _timeRemaining--;
          _progressValue = 1.0 - (_timeRemaining / 180.0);
        });
      } else {
        _endGameByTime();
        timer.cancel();
      }
    });
  }

  void _startReflexionTimer() {
    _reflexionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_reflexionTimeRemaining > 0) {
        setState(() {
          _reflexionTimeRemaining--;
        });
      } else {
        // Temps écoulé - le joueur actuel a manqué son tour
        _handleMissedTurn();
        timer.cancel();
        _startReflexionTimer();
      }
    });
  }

  void _handleMissedTurn() {
    // Incrémenter le compteur pour le joueur actuel
    consecutiveMissedTurns[currentPlayer] = consecutiveMissedTurns[currentPlayer]! + 1;
    
    // Vérifier si le joueur a manqué 3 tours consécutifs
    if (consecutiveMissedTurns[currentPlayer]! >= 3) {
      _endGameByMissedTurns(currentPlayer);
      return;
    }
    
    // Réinitialiser le compteur pour l'autre joueur (puisqu'il va jouer)
    final otherPlayer = currentPlayer == 'bleu' ? 'rouge' : 'bleu';
    consecutiveMissedTurns[otherPlayer] = 0;
    
    // Passer au joueur suivant normalement
    _switchPlayer();
  }

  void _endGameByMissedTurns(String playerWhoMissed) {
    final loser = playerWhoMissed;
    final winner = playerWhoMissed == 'bleu' ? 'rouge' : 'bleu';

    setState(() {
      isGameFinished = true;
      _gameTimer.cancel();
      _reflexionTimer.cancel();

      // 🔹 Transfert des points du perdant au gagnant
      final lostPoints = scores[loser] ?? 0;
      scores[winner] = (scores[winner] ?? 0) + lostPoints + 1;
      scores[loser] = 0;
    });
  }


  void _resetReflexionTimer() {
    _reflexionTimer.cancel();
    setState(() {
      _reflexionTimeRemaining = 15;
    });
    _startReflexionTimer();
  }

  void _switchPlayer() {
    setState(() {
      currentPlayer = currentPlayer == 'bleu' ? 'rouge' : 'bleu';
      _reflexionTimeRemaining = 15;
    });
  }

  void _endGameByTime() {
    setState(() {
      isGameFinished = true;
      _reflexionTimer.cancel();
    });
  }

  void _onPointTap(int x, int y) {
  // Empêcher les clics pendant le tour de l'IA ou si le jeu est fini
  if (isGameFinished || (widget.isAgainstAI && currentPlayer == aiPlayerId)) return;
  
  if (points.any((point) => point.x == x && point.y == y)) {
    return;
  }
  
  setState(() {
    consecutiveMissedTurns[currentPlayer] = 0;
      final newPoint = GridPoint(x: x, y: y, playerId: currentPlayer);
      points.add(newPoint);
      
      // Démarrer l'animation radar pour ce point
      _startRadarAnimation(newPoint);
    
    final newSquares = GameLogic.checkSquares(
      points,
      widget.gridSize,
      currentPlayer,
      x,
      y,
    );
    
    squares.addAll(newSquares);
    
    if (newSquares.isNotEmpty) {
      _scoreAnimationController.forward().then((_) {
        _scoreAnimationController.reverse();
      });
    }
    
    scores[currentPlayer] = scores[currentPlayer]! + newSquares.length;
    
    if (points.length >= widget.gridSize * widget.gridSize) {
      isGameFinished = true;
      _gameTimer.cancel();
      _reflexionTimer.cancel();
    } else {
      _resetReflexionTimer();
      _switchPlayer();
      
      // Si on joue contre l'IA et que c'est son tour
      if (widget.isAgainstAI && currentPlayer == aiPlayerId) {
        _startAITurn();
      }
    }
  });
}

  Color _getPlayerColor(String playerId) {
    return playerId == 'bleu' 
        ? Color(0xFF00d4ff) 
        : Color(0xFFff006e);
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showResultModal() {
    if (_resultModalShown) return; // ← EMPÊCHE l'affichage multiple
    
    _resultModalShown = true;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _buildResultModal();
      },
    ).then((_) {
      // Quand le modal est fermé, réinitialiser le flag
      _resultModalShown = false;
    });
  }

  Widget _buildReflexionTimer() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 1, vertical: 2),
      child: Column(
        children: [
          // Timer de réflexion
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child:  Text(
                  '$_reflexionTimeRemaining',
                  style: TextStyle(
                    color: _getPlayerColor(currentPlayer),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
          )
         ],
      ),
    );
  }

  Widget _buildResultModal() {
    final isDraw = scores['bleu']! == scores['rouge']!;
    final winner = scores['bleu']! > scores['rouge']! ? 'bleu' : 'rouge';
    
    return Stack(
      children: [
        // Modal content
        Dialog(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Titre du résultat
                Text(
                  isDraw ? 'MATCH NUL !' : 'VICTOIRE !',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Profil du joueur gagnant (ou les deux joueurs en cas de match nul)
                if (!isDraw) _buildWinnerProfile(winner),
                if (isDraw) _buildDrawProfiles(),
                
                SizedBox(height: 20),
                
                // Trophée au centre
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFFFFD700).withOpacity(0.8),
                        Color(0xFFFFA000).withOpacity(0.3),
                      ],
                    ),
                    border: Border.all(
                      color: Color(0xFFFFD700),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFFD700).withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    isDraw ? Icons.handshake : Icons.emoji_events,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Scores finaux
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Color(0xFF2d0052).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Color(0xFF9c27b0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildModalScore('BLEU', scores['bleu']!, Color(0xFF00d4ff)),
                      Container(
                        width: 2,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFF9c27b0),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      _buildModalScore('ROUGE', scores['rouge']!, Color(0xFFff006e)),
                    ],
                  ),
                ),
                
                SizedBox(height: 30),
                
                // Boutons
                Column(
                  children: [
                    // Bouton nouvelle partie
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF9c27b0).withOpacity(0.5),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () {
                            Navigator.of(context).pop();
                            
                            setState(() => _initializeGame());
                            _startGameTimer();
                          },
                          child: Center(
                            child: Text(
                              'NOUVELLE PARTIE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    // Bouton revenir à l'accueil
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Color(0xFF9c27b0),
                          width: 2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () {
                            Navigator.of(context).pop(); // Fermer le modal
                            Navigator.of(context).pop(); // Revenir à l'accueil
                          },
                          child: Center(
                            child: Text(
                              'REVENIR À L\'ACCUEIL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
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
      ],
    );
  }

  Widget _buildWinnerProfile(String player) {
    final color = _getPlayerColor(player);
    return Column(
      children: [
        // Avatar du joueur
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withOpacity(0.8),
                color.withOpacity(0.3),
              ],
            ),
            border: Border.all(
              color: color,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Icon(
            Icons.person,
            color: Colors.white,
            size: 40,
          ),
        ),
        SizedBox(height: 12),
        // Nom du joueur
        Text(
          player.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawProfiles() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildDrawProfile('BLEU', Color(0xFF00d4ff)),
        _buildDrawProfile('ROUGE', Color(0xFFff006e)),
      ],
    );
  }

  Widget _buildDrawProfile(String player, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withOpacity(0.8),
                color.withOpacity(0.3),
              ],
            ),
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
          child: Icon(
            Icons.person,
            color: Colors.white,
            size: 30,
          ),
        ),
        SizedBox(height: 8),
        Text(
          player,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildModalScore(String player, int score, Color color) {
    return Column(
      children: [
        Text(
          player,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4),
        Text(
          score.toString(),
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTimerAndProgressBar() {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      children: [
        // Barre de progression avec timer superposé
        SizedBox(
          height: 40, // Plus grand pour accommoder le texte superposé
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Barre de progression
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Color(0xFF2d0052),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  children: [
                    // Background
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF2d0052),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Progress
                    AnimatedContainer(
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      width: MediaQuery.of(context).size.width * _progressValue,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getPlayerColor(currentPlayer),
                            _getPlayerColor(currentPlayer).withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: _getPlayerColor(currentPlayer).withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Timer superposé au centre - comme un grand frère qui protège
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1a0033).withOpacity(0.9),
                      Color(0xFF2d0052).withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getPlayerColor(currentPlayer),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _formatTime(_timeRemaining),
                  style: TextStyle(
                    color: _getPlayerColor(currentPlayer),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
 
  Widget _buildCompactHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Navigation et titre
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
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Row(
                children: [
                  Text(
                    'Shikaku ${widget.gridSize}×${widget.gridSize}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  if (widget.isAgainstAI && currentPlayer == aiPlayerId) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Text(
                        'IA réfléchit...',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
                
              ),
              // Dropdown pour terminer le match
              _buildGameMenuDropdown(),
            ],
          ),
          SizedBox(height: 10),
          
          // Statut et scores combinés
          Container(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF2d0052).withOpacity(0.8),
                  Color(0xFF4a0080).withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isGameFinished 
                    ? Color(0xFFe040fb) 
                    : _getPlayerColor(currentPlayer),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isGameFinished 
                      ? Color(0xFFe040fb) 
                      : _getPlayerColor(currentPlayer)).withOpacity(0.3),
                  blurRadius: 15,
                ),
              ],
            ),
            child: isGameFinished ? _buildWinnerStatus() : _buildScoresRow(),
          ),
          
          // Timer principal et barre de progression
          _buildTimerAndProgressBar(),
        ],
      ),
    );
  }

Widget _buildGameMenuDropdown() {
  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
      ),
    ),
    child: PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert, color: Colors.white, size: 20),
      color: Color(0xFF2d0052),
      surfaceTintColor: Color(0xFF2d0052),
      shadowColor: Color(0xFF9c27b0).withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: BorderSide(
          color: Color(0xFF9c27b0),
          width: 1,
        ),
      ),
      onSelected: (String value) {
        if (value == 'forfeit') {
          _showForfeitConfirmation();
        } else if (value == 'new_game') {
          _showNewGameConfirmation();
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'forfeit',
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFff006e), Color(0xFFc4005a)],
                  ),
                ),
                child: Icon(Icons.flag, color: Colors.white, size: 18),
              ),
              SizedBox(width: 12),
              Text(
                'Abandonner',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'new_game',
          child: Row(
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
                child: Icon(Icons.refresh, color: Colors.white, size: 18),
              ),
              SizedBox(width: 12),
              Text(
                'Nouvelle partie',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  void _showForfeitConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2d0052),
          title: Text(
            'Confirmer l\'abandon',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Voulez-vous vraiment abandonner la partie ? Votre adversaire gagnera.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annuler', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _endGameByForfeit();
              },
              child: Text('Abandonner', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showNewGameConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2d0052),
          title: Text(
            'Nouvelle partie',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Voulez-vous recommencer une nouvelle partie ? La partie en cours sera perdue.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annuler', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _gameTimer.cancel();
                _reflexionTimer.cancel();
                setState(() => _initializeGame());
                _startGameTimer();
                _startReflexionTimer();
              },
              child: Text('Nouvelle partie', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

void _endGameByForfeit() {
  // Le joueur qui abandonne perd
  final loser = currentPlayer; // celui qui abandonne
  final winner = currentPlayer == 'bleu' ? 'rouge' : 'bleu';

  setState(() {
    isGameFinished = true;
    _gameTimer.cancel();
    _reflexionTimer.cancel();

    // On transfère le score du perdant au gagnant
    final lostPoints = scores[loser] ?? 0; //(le ?? 0 veut dire "si jamais scores['bleu'] est null, on prend 0 à la place" — une sécurité)
    scores[winner] = (scores[winner] ?? 0) + lostPoints + 1;
    scores[loser] = 0;
  });
}


  Widget _buildWinnerStatus() {
    String winner;
    if (scores['bleu']! > scores['rouge']!) {
      winner = 'BLEU';
    } else if (scores['rouge']! > scores['bleu']!) {
      winner = 'ROUGE';
    } else {
      winner = 'ÉGALITÉ';
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              winner == 'ÉGALITÉ' ? Icons.handshake : Icons.emoji_events,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              winner == 'ÉGALITÉ' ? 'MATCH NUL !' : '$winner GAGNE !',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        _buildScoresRow(),
      ],
    );
  }

  Widget _buildScoresRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildCompactPlayerScore('bleu', scores['bleu']!),
        Container(
          width: 80,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Color(0xFF9c27b0),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: _buildReflexionTimer(),// Timer de réflexion au centre
        ),
        _buildCompactPlayerScore('rouge', scores['rouge']!),
      ],
    );
  }

  Widget _buildCompactPlayerScore(String player, int score) {
    final isActive = currentPlayer == player && !isGameFinished;
    final color = _getPlayerColor(player);

    return ScaleTransition(
      scale: isActive ? _scoreScaleAnimation : AlwaysStoppedAnimation(1.0),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(0.8),
                  color.withOpacity(0.3),
                ],
              ),
              border: Border.all(
                color: color,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            player.toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          Text(
            score.toString(),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // NOUVELLE MÉTHODE : Zone des spectateurs
  Widget _buildSpectatorsSection() {
    return Container(
      height: 90,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1a0033),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Color(0xFF4a0080),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // En-tête avec le nombre de spectateurs
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFF2d0052),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.visibility,
                  color: Color(0xFFe040fb),
                  size: 12,
                ),
                SizedBox(width: 8),
                Text(
                  '${_spectators.length} SPECTATEURS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          
          // Liste scrollable des avatars
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _spectators.length,
              itemBuilder: (context, index) {
                final spectator = _spectators[index];
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      // Avatar du spectateur
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF9c27b0),
                              Color(0xFF7b1fa2),
                            ],
                          ),
                          border: Border.all(
                            color: Color(0xFFe040fb),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF9c27b0).withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            spectator['avatar'],
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGameGrid() {
    final cellSize = 60.0;
    final gridWidth = (widget.gridSize * cellSize) + 40; // +40 pour les points aux bords
    final gridHeight = (widget.gridSize * cellSize) + 40; // +40 pour les points aux bords
    
    // Calcul dynamique de la boundaryMargin
    final screenSize = MediaQuery.of(context).size;
    final dynamicBoundaryMargin = EdgeInsets.all(
      math.max(screenSize.width, screenSize.height) * 0.8,
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.1,
        maxScale: 4.0,
        boundaryMargin: dynamicBoundaryMargin,
        panEnabled: true,
        scaleEnabled: true,
        constrained: false,
        child: Container(
          width: gridWidth,
          height: gridHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0a0015),
                Color(0xFF1a0033),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF9c27b0).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: CustomPaint(
            painter: GridPainter(
              gridSize: widget.gridSize,
              cellSize: cellSize,
            ),
            child: Stack(
              children: [
                 // Effet radar pour le dernier point joué
              if (_lastPlayedPoint != null)
                Positioned(
                  left: _lastPlayedPoint!.x * cellSize,
                  top: _lastPlayedPoint!.y * cellSize,
                  child: Container(
                    width: 40,
                    height: 40,
                    child: CustomPaint(
                      painter: RadarPointPainter(
                        x: 20, // Centre du container de 40px
                        y: 20, // Centre du container de 40px
                        color: _getPlayerColor(_lastPlayedPoint!.playerId!),
                        animationValue: _radarAnimation.value,
                      ),
                    ),
                  ),
                ),
                // Carrés complétés
                ...squares.map((square) {
                  return Positioned(
                    left: square.x * cellSize + 20, // +20 pour le décalage
                    top: square.y * cellSize + 20, // +20 pour le décalage
                    child: TweenAnimationBuilder(
                      duration: Duration(milliseconds: 300),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      builder: (context, double value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.scale(
                            scale: value,
                            child: Container(
                              width: cellSize * GameLogic.squareSize,
                              height: cellSize * GameLogic.squareSize,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    _getPlayerColor(square.playerId).withOpacity(0.6),
                                    _getPlayerColor(square.playerId).withOpacity(0.2),
                                  ],
                                ),
                                border: Border.all(
                                  color: _getPlayerColor(square.playerId),
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getPlayerColor(square.playerId).withOpacity(0.5),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),

                // Points positionnés aux intersections
                ...List.generate(widget.gridSize + 1, (x) {
                  return List.generate(widget.gridSize + 1, (y) {
                    final point = points.firstWhere(
                      (p) => p.x == x && p.y == y,
                      orElse: () => GridPoint(x: -1, y: -1),
                    );

                    return Positioned(
                      left: x * cellSize, // Position naturelle sans ajustement
                      top: y * cellSize, // Position naturelle sans ajustement
                      child: GestureDetector(
                        onTap: () => _onPointTap(x, y),
                        child: Container(
                          width: 40,
                          height: 40,
                          color: Colors.transparent,
                          alignment: Alignment.center,
                          child: TweenAnimationBuilder(
                            duration: Duration(milliseconds: 200),
                            tween: Tween<double>(begin: 0.8, end: 1.0),
                            builder: (context, double value, child) {
                              return Transform.scale(
                                scale: point.playerId != null ? value : 0.8,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    gradient: point.playerId != null
                                        ? RadialGradient(
                                            colors: [
                                              _getPlayerColor(point.playerId!),
                                              _getPlayerColor(point.playerId!).withOpacity(0.6),
                                            ],
                                          )
                                        : null,
                                    color: point.playerId == null
                                        ? Color(0xFF4a0080).withOpacity(0.3)
                                        : null,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: point.playerId != null
                                          ? _getPlayerColor(point.playerId!)
                                          : Color(0xFF6200b3),
                                      width: 2,
                                    ),
                                    boxShadow: point.playerId != null
                                        ? [
                                            BoxShadow(
                                              color: _getPlayerColor(point.playerId!).withOpacity(0.6),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  });
                }).expand((widgets) => widgets),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Afficher le modal quand le jeu est terminé
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isGameFinished && !_resultModalShown) {
        _showResultModal();
      }
    });

    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: Column(
            children: [
              // Header compact avec timer
              _buildCompactHeader(),
              
              // CADRE VERTICAL AVEC BORDURE pour la zone de jeu
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(top: 0, bottom: 8, left: 16, right: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Color(0xFF9c27b0),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF9c27b0).withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      color: Color(0xFF0a0015),
                      child: _buildGameGrid(),
                    ),
                  ),
                ),
              ),

              // NOUVELLE SECTION : Zone des spectateurs
              _buildSpectatorsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final int gridSize;
  final double cellSize;

  GridPainter({required this.gridSize, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFF6200b3).withOpacity(0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Lignes verticales - débordement de 20 pixels de chaque côté
    for (int i = 0; i <= gridSize; i++) {
      final x = i * cellSize + 20; // +20 pour le décalage
      canvas.drawLine(
        Offset(x, 20), // Commence à 20 pixels du haut
        Offset(x, gridSize * cellSize + 20), // Termine à 20 pixels du bas
        paint,
      );
    }

    // Lignes horizontales - débordement de 20 pixels de chaque côté
    for (int i = 0; i <= gridSize; i++) {
      final y = i * cellSize + 20; // +20 pour le décalage
      canvas.drawLine(
        Offset(20, y), // Commence à 20 pixels de la gauche
        Offset(gridSize * cellSize + 20, y), // Termine à 20 pixels de la droite
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeu_carre/models/ai_player.dart';
import 'package:jeu_carre/models/radarpoint.dart';
import 'package:jeu_carre/screens/navigation_screen.dart';
import 'package:jeu_carre/services/game_service.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/services/game_start_service.dart';
import '../../models/game_model.dart';
import '../../utils/game_logic.dart';

class GameScreen extends StatefulWidget {
  final int gridSize;
  final bool isAgainstAI;
  final AIDifficulty aiDifficulty;
  final int gameDuration;
  final int reflexionTime;
  final String? opponentId;
  final Game? existingGame;

  GameScreen({
    required this.gridSize,
    required this.isAgainstAI,
    this.aiDifficulty = AIDifficulty.intermediate,
    this.gameDuration = 180,
    this.reflexionTime = 15,
    this.opponentId,
    this.existingGame,
  });

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _QuickMessageModal extends StatefulWidget {
  final bool isOnlineGame;
  final Function(String) onMessageSent;

  const _QuickMessageModal({
    required this.isOnlineGame,
    required this.onMessageSent,
  });

  @override
  __QuickMessageModalState createState() => __QuickMessageModalState();
}

class __QuickMessageModalState extends State<_QuickMessageModal> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, dynamic>> _messages = [
    {'text': '😂', 'type': 'emoji'},
    {'text': '😢', 'type': 'emoji'},
    {'text': '😠', 'type': 'emoji'},
    {'text': '👍', 'type': 'emoji'},
    {'text': 'Ekieee!!', 'type': 'text'},
    {'text': 'tu es faible😂', 'type': 'text'},
    {'text': 'C\'est ton tour!', 'type': 'text'},
    {'text': 'Belle partie!', 'type': 'text'},
    {'text': 'Mais joue!', 'type': 'text'},
    {'text': 'Joue bien!', 'type': 'text'},
    {'text': 'Stp joue', 'type': 'text'},
    {'text': 'Bien joué!', 'type': 'text'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _closeModal() {
    _animationController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _sendMessage(String message) {
    widget.onMessageSent(message);
    _closeModal();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header du modal
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF2d0052),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border.all(color: Color(0xFF9c27b0)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Messages Rapides',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: _closeModal,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(width: 32, height: 32),
                    ),
                  ],
                ),
              ),
              
              // Contenu des messages
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF1a0033),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(
                    left: BorderSide(color: Color(0xFF9c27b0)),
                    right: BorderSide(color: Color(0xFF9c27b0)),
                    bottom: BorderSide(color: Color(0xFF9c27b0)),
                  ),
                ),
                child: SingleChildScrollView(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _sendMessage(message['text']),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color(0xFF2d0052),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFF4a0080)),
                            ),
                            child: Center(
                              child: Text(
                                message['text'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: message['type'] == 'emoji' ? 20 : 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  List<GridPoint> points = [];
  List<Square> squares = [];
  String currentPlayer = 'bleu';
  Map<String, int> scores = {'bleu': 0, 'rouge': 0};
  bool isGameFinished = false;
  bool _resultModalShown = false;
  bool _isSpectator = false;
  OverlayEntry? _messageOverlayEntry;

  bool _isPlayerOnLeft(String playerId) {
    if (!_isOnlineGame) return playerId == 'bleu';
    
    // Si je suis le joueur bleu, je suis à gauche
    if (_myPlayerColor == 'bleu') {
      return playerId == _currentUserId;
    } else {
      // Si je suis le joueur rouge, l'adversaire (bleu) est à gauche
      return playerId != _currentUserId;
    }
  }

  void _checkUserStatus() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && widget.existingGame != null) {
      // Vérifier si l'utilisateur est un joueur
      final isPlayer = widget.existingGame!.players.contains(currentUser.uid);
      
      // Si ce n'est pas un joueur, c'est un spectateur
      _isSpectator = !isPlayer;
      
      if (_isSpectator) {
        print('👀 Utilisateur connecté en tant que spectateur');
        _joinAsSpectator();
      } else {
        print('🎮 Utilisateur connecté en tant que joueur');
      }
    }
  }

  late AnimationController _radarAnimationController;
  late Animation<double> _radarAnimation;
  GridPoint? _lastPlayedPoint;

  String aiPlayerId = 'rouge';
  bool isAITurn = false;

  late Timer _gameTimer;
  int _timeRemaining = 180;
  double _progressValue = 0.0;
  late Timer _reflexionTimer;
  int _reflexionTimeRemaining = 15;
  bool _timerInitialized = false;

  TransformationController _transformationController = TransformationController();
  late AnimationController _scoreAnimationController;
  late Animation<double> _scoreScaleAnimation;

  Stream<List<Player>>? _spectatorsStream;
  Player? _currentUserPlayer;
  Player? _opponentPlayer;
  String? _gameId;
  List<Player> _spectators = [];
  
  StreamSubscription<Game?>? _gameStreamSubscription;
  String? _currentUserId;
  String? _myPlayerColor;
  bool _isMyTurn = false;
  bool _isOnlineGame = false;

  String get _bluePlayerName {
    String name;
    if (widget.isAgainstAI) {
      name = _currentUserPlayer?.username ?? 'VOUS';
    } else if (_isOnlineGame) {
      name = _myPlayerColor == 'bleu' 
          ? (_currentUserPlayer?.username ?? 'VOUS')
          : (_opponentPlayer?.username ?? 'ADVERSAIRE');
    } else {
      name = 'BLEU';
    }
    
    // Tronquer le nom si plus de 10 caractères
    if (name.length > 11) {
      return name.substring(0, 11) + "..";
    }
    return name;
  }

  String get _redPlayerName {
    String name;
    if (widget.isAgainstAI) {
      name = 'IA ${widget.aiDifficulty.toString().split('.').last.toUpperCase()}';
    } else if (_isOnlineGame) {
      name = _myPlayerColor == 'rouge' 
          ? (_currentUserPlayer?.username ?? 'VOUS')
          : (_opponentPlayer?.username ?? 'ADVERSAIRE');
    } else {
      name = 'ROUGE';
    }
    
    // Tronquer le nom si plus de 10 caractères
    if (name.length > 11) {
      return name.substring(0, 11) + "..";
    }
    return name;
  }

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _initializeGameData();
    _initializeGame();
    _checkUserStatus();
    
    _scoreAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    
    _scoreScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scoreAnimationController, curve: Curves.easeInOut),
    );

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

    // Initialiser les timers après un court délai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTimers();
      _centerZoom();
      
      if (widget.isAgainstAI) {
        aiPlayerId = 'rouge';
        if (currentPlayer == aiPlayerId) {
          _startAITurn();
        }
      }
    });
  }
    
void _initializeGameData() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    _currentUserPlayer = await GameService.getPlayer(currentUser.uid);
  }

  if (widget.existingGame != null && !widget.isAgainstAI) {
    _isOnlineGame = true;
    _gameId = widget.existingGame!.id;
    
    // Vérifier si l'utilisateur est un joueur ou spectateur
    final isPlayer = widget.existingGame!.players.contains(currentUser!.uid);
    _isSpectator = !isPlayer;
    
    if (isPlayer) {
      // Logique existante pour les joueurs
      if (widget.existingGame!.player1Id == _currentUserId) {
        _myPlayerColor = 'bleu';
      } else if (widget.existingGame!.player2Id == _currentUserId) {
        _myPlayerColor = 'rouge';
      }
      
      // Charger les deux joueurs pour avoir leurs avatars
      final opponentId = _myPlayerColor == 'bleu' 
          ? widget.existingGame!.player2Id 
          : widget.existingGame!.player1Id;
      
      if (opponentId != null) {
        _opponentPlayer = await GameService.getPlayer(opponentId);
      }
      
      // 🆕 Démarrer l'écoute des messages
      _startListeningToMessages();
        
    } else {
      // Logique pour les spectateurs - charger les deux joueurs
      print('👀 Initialisation en mode spectateur');
      
      if (widget.existingGame!.player1Id != null) {
        _currentUserPlayer = await GameService.getPlayer(widget.existingGame!.player1Id!);
      }
      if (widget.existingGame!.player2Id != null) {
        _opponentPlayer = await GameService.getPlayer(widget.existingGame!.player2Id!);
      }
      
      _joinAsSpectator();
    }
    
    _startListeningToGameUpdates();
    _loadSpectators();
  } else if (widget.opponentId != null) {
    _opponentPlayer = await GameService.getPlayer(widget.opponentId!);
  }

  setState(() {});
}
  void _initializeTimers() {
    if (_timerInitialized) return;
    
    _startGameTimer();
    _startReflexionTimer();
    _timerInitialized = true;
  }
    
  void _startListeningToGameUpdates() {
    if (_gameId == null) return;
    
    _gameStreamSubscription = GameService.getGameById(_gameId!).listen((game) {
      if (game == null || !mounted) return;
      
      print('🔄 Sync Firestore - Status: ${game.status}, Temps: ${game.timeRemaining}');
      
      setState(() {
        points = game.points;
        squares = game.squares;
        
        scores = {
          'bleu': game.scores[game.player1Id] ?? 0,
          'rouge': game.scores[game.player2Id] ?? 0,
        };
        
        // Synchroniser le currentPlayer
        if (game.currentPlayer == game.player1Id) {
          currentPlayer = 'bleu';
        } else if (game.currentPlayer == game.player2Id) {
          currentPlayer = 'rouge';
        }
        
        _isMyTurn = (currentPlayer == _myPlayerColor);
        _timeRemaining = game.timeRemaining;
        _progressValue = 1.0 - (_timeRemaining / widget.gameDuration);
        
        // SYNCHRONISATION DU TEMPS DE RÉFLEXION
        if (game.reflexionTimeRemaining != null) {
          final currentPlayerId = currentPlayer == 'bleu' 
              ? widget.existingGame!.player1Id! 
              : widget.existingGame!.player2Id!;
          
          final reflexionTime = game.reflexionTimeRemaining![currentPlayerId];
          if (reflexionTime != null && reflexionTime != _reflexionTimeRemaining) {
            print('🎯 Mise à jour temps réflexion: $reflexionTime');
            _reflexionTimeRemaining = reflexionTime;
          }
        }
        
        // Gestion fin de partie - AMÉLIORATION ICI
        final wasGameFinished = isGameFinished;
        isGameFinished = game.status == GameStatus.finished;
        
        if (isGameFinished && !wasGameFinished) {
          print('🎯 Partie terminée détectée via Firestore - Scores: $scores');
          _cancelAllTimers();
          
          // Mettre à jour les scores finaux depuis Firestore
          scores = {
            'bleu': game.scores[game.player1Id] ?? 0,
            'rouge': game.scores[game.player2Id] ?? 0,
          };
          
          if (!_resultModalShown) {
            print('🚀 Déclenchement modal de résultat...');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_resultModalShown) {
                _showResultModal();
              }
            });
          }
        }
      });
    }, onError: (error) {
      print('❌ Erreur écoute partie: $error');
    });
  }

  void _handleMissedTurnFromFirestore(String playerId) {
    if (!_isOnlineGame || _gameId == null) return;
    
    // Vérifier que c'est bien le tour de ce joueur
    final isCurrentPlayer = (playerId == widget.existingGame!.player1Id && currentPlayer == 'bleu') ||
                           (playerId == widget.existingGame!.player2Id && currentPlayer == 'rouge');
    
    if (isCurrentPlayer && !isGameFinished) {
      print('🔄 Tour manqué détecté depuis Firestore pour: $playerId');
      
      final currentMissedTurns = widget.existingGame?.consecutiveMissedTurns[playerId] ?? 0;
      final newMissedTurns = currentMissedTurns + 1;
      
      final updatedMissedTurns = {
        ...widget.existingGame!.consecutiveMissedTurns,
        playerId: newMissedTurns
      };
      
      // UTILISER UN TRY-CATCH POUR ÉVITER LES ERREURS BLOQUANTES
      try {
        GameService.updateConsecutiveMissedTurns(_gameId!, updatedMissedTurns);
      } catch (e) {
        print('⚠️ Erreur non critique mise à jour tours manqués: $e');
      }
      
      // Changer de joueur
      final nextPlayer = currentPlayer == 'bleu' ? 'rouge' : 'bleu';
      final nextPlayerId = nextPlayer == 'bleu' 
          ? widget.existingGame!.player1Id! 
          : widget.existingGame!.player2Id!;
      
      try {
        GameService.switchPlayer(_gameId!, nextPlayerId, widget.reflexionTime);
      } catch (e) {
        print('⚠️ Erreur non critique changement joueur: $e');
      }
    }
  }

  void _loadSpectators() {
    if (_gameId == null) return;
    
    _spectatorsStream = GameService.getSpectatorsWithProfiles(_gameId!);
    _spectatorsStream?.listen((spectators) {
      if (mounted) {
        setState(() {
          _spectators = spectators;
        });
      }
    });
  }

  void _joinAsSpectator() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && _gameId != null) {
      GameService.joinAsSpectator(_gameId!, currentUser.uid);
    }
  }

  void _leaveAsSpectator() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && _gameId != null) {
      GameService.leaveAsSpectator(_gameId!, currentUser.uid);
    }
  }

  @override
  void dispose() {
    _cancelAllTimers();
    _transformationController.dispose();
    _scoreAnimationController.dispose();
    _radarAnimationController.dispose();
    _gameStreamSubscription?.cancel();
    
    // 🆕 Nettoyer l'overlay de message s'il existe
    _messageOverlayEntry?.remove();
    
    // 🚪 QUITTER EN TANT QUE SPECTATEUR SEULEMENT SI ON ÉTAIT SPECTATEUR
    if (_isSpectator && _gameId != null && _currentUserId != null) {
      _leaveAsSpectator();
    }
    super.dispose();
  }

  void _cancelAllTimers() {
    _gameTimer.cancel();
    _reflexionTimer.cancel();
    _timerInitialized = false;
  }

  void _startRadarAnimation(GridPoint point) {
    _lastPlayedPoint = point;
    _radarAnimationController.reset();
    _radarAnimationController.forward();
  }

  void _startAITurn() {
    if (!widget.isAgainstAI || currentPlayer != aiPlayerId || isGameFinished) return;
    setState(() => isAITurn = true);
    _playAIMove();
  }

  void _centerZoom() {
    final screenSize = MediaQuery.of(context).size;
    final gridWidth = (widget.gridSize * 60.0) + 40;
    final gridHeight = (widget.gridSize * 60.0) + 40;
    final scaleX = screenSize.width / gridWidth;
    final scaleY = screenSize.height * 0.7 / gridHeight;
    final scale = math.min(scaleX, scaleY) * 0.9;
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
    setState(() => isAITurn = true);
    
    final aiMove = await AIPlayer.getBestMove(
      points,
      widget.gridSize,
      aiPlayerId,
      difficulty: widget.aiDifficulty,
    );
    
    if (_reflexionTimeRemaining <= 0) {
      setState(() => isAITurn = false);
      return;
    }
    
    if (aiMove != null && mounted) {
      setState(() => isAITurn = false);
      _executeAIMove(aiMove);
    }
  }

  void _executeAIMove(GridPoint aiMove) {
    if (isGameFinished || !mounted) return;
    
    setState(() {
      points.add(aiMove);
      _startRadarAnimation(aiMove);
      final newSquares = GameLogic.checkSquares(points, widget.gridSize, aiPlayerId, aiMove.x, aiMove.y);
      squares.addAll(newSquares);
      scores[aiPlayerId] = scores[aiPlayerId]! + newSquares.length;
      
      if (points.length >= widget.gridSize * widget.gridSize) {
        isGameFinished = true;
        _cancelAllTimers();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_resultModalShown) {
            _showResultModal();
          }
        });
      } else {
        _resetReflexionTimer();
        _switchPlayer();
      }
    });
  }

  void _initializeGame() {
    points = [];
    squares = [];
    scores = {'bleu': 0, 'rouge': 0};
    currentPlayer = 'bleu';
    isGameFinished = false;
    _timeRemaining = widget.gameDuration;
    _progressValue = 0.0;
    _reflexionTimeRemaining = widget.reflexionTime;
    _transformationController.value = Matrix4.identity();
  }

  void _startGameTimer() {
    _gameTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_timeRemaining > 0) {
        setState(() {
          _timeRemaining--;
          _progressValue = 1.0 - (_timeRemaining / widget.gameDuration);
        });
        
        if (_isOnlineGame && _gameId != null) {
          GameService.updateGameTime(_gameId!, _timeRemaining);
        }
      } else {
        print('⏰ TEMPS ÉCOULÉ - Fin de partie');
        _endGameByTime();
        timer.cancel();
      }
    });
  }

  void _startReflexionTimer() {
    _reflexionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_isOnlineGame && _isMyTurn) {
        // APPROCHE CLIENT MAÎTRE : Seul le client dont c'est le tour décrémente
        if (_reflexionTimeRemaining > 0) {
          setState(() => _reflexionTimeRemaining--);
          
          // Mettre à jour Firestore (sans attendre pour la fluidité)
          if (_gameId != null && _currentUserId != null) {
            GameService.updateReflexionTimeAtomic(_gameId!, _currentUserId!, _reflexionTimeRemaining);
          }
        } else {
          // Temps écoulé
          print('⏱️ Temps réflexion écoulé (maître)');
          _handleMissedTurnFromFirestore(_currentUserId!);
        }
      } else if (!_isOnlineGame) {
        // Logique locale pour les parties hors ligne
        if (_reflexionTimeRemaining > 0) {
          setState(() => _reflexionTimeRemaining--);
        } else {
          print('⏱️ Temps réflexion écoulé (local)');
          _handleMissedTurn();
          _resetReflexionTimer();
        }
      }
    });
  }

  void _handleMissedTurn() {
    if (_isOnlineGame && _gameId != null && _currentUserId != null) {
      // Pour les parties en ligne, utiliser la méthode Firestore
      _handleMissedTurnFromFirestore(_currentUserId!);
    } else {
      // Logique locale existante...
      final currentPlayerId = currentPlayer;
      final currentMissedTurns = 0;
      final newMissedTurns = currentMissedTurns + 1;
      
      if (newMissedTurns >= 3) {
        _endGameByMissedTurns(currentPlayerId);
        return;
      }
      
      _switchPlayer();
    }
  }

  void _endGameByMissedTurns(String playerWhoMissed) async {
    print('🏁 Fin de partie par tours manqués: $playerWhoMissed');
    
    if (_isOnlineGame && _gameId != null) {
      final winnerId = playerWhoMissed == widget.existingGame!.player1Id 
          ? widget.existingGame!.player2Id 
          : widget.existingGame!.player1Id;
      
      await GameService.finishGameWithReason(
        _gameId!,
        winnerId: winnerId,
        endReason: GameEndReason.consecutiveMissedTurns
      );
    } else {
      setState(() {
        isGameFinished = true;
        _cancelAllTimers();
        final loser = playerWhoMissed;
        final winner = playerWhoMissed == 'bleu' ? 'rouge' : 'bleu';
        final lostPoints = scores[loser] ?? 0;
        scores[winner] = (scores[winner] ?? 0) + lostPoints + 1;
        scores[loser] = 0;
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_resultModalShown) {
          _showResultModal();
        }
      });
    }
    GameStartService().exitGame();
  }

  void _resetReflexionTimer() {
    _reflexionTimer.cancel();
    
    if (_isOnlineGame) {
      // Pour les parties en ligne, réinitialiser via Firestore
      if (_gameId != null && _currentUserId != null && _isMyTurn) {
        setState(() => _reflexionTimeRemaining = widget.reflexionTime);
        GameService.updateReflexionTimeAtomic(_gameId!, _currentUserId!, widget.reflexionTime);
      }
      _startReflexionTimer();
    } else {
      // Logique locale
      setState(() => _reflexionTimeRemaining = widget.reflexionTime);
      _startReflexionTimer();
    }
  }

  void _switchPlayer() {
    if (_isOnlineGame) {
      if (_gameId != null && widget.existingGame != null) {
        final nextPlayer = currentPlayer == 'bleu' ? 'rouge' : 'bleu';
        final nextPlayerId = nextPlayer == 'bleu' 
            ? widget.existingGame!.player1Id! 
            : widget.existingGame!.player2Id!;
        
        print('🔄 Switch vers: $nextPlayer (ID: $nextPlayerId)');
        
        // Mettre à jour le currentPlayer dans Firestore
        GameService.switchPlayer(_gameId!, nextPlayerId, widget.reflexionTime);
      }
    } else {
      // Logique locale inchangée
      setState(() {
        currentPlayer = currentPlayer == 'bleu' ? 'rouge' : 'bleu';
        _reflexionTimeRemaining = widget.reflexionTime;
      });
      
      if (widget.isAgainstAI && currentPlayer == aiPlayerId) {
        _startAITurn();
      }
    }
  }

  void _endGameByTime() async {
    print('🏁 Fin de partie par temps écoulé');
    
    if (_isOnlineGame && _gameId != null) {
      try {
        // APPELER DIRECTEMENT LE SERVICE SANS ATTENDRE
        await GameService.updateGameTime(_gameId!, 0);
        print('✅ Temps mis à jour à 0 dans Firestore');
      } catch (e) {
        print('❌ Erreur mise à jour temps: $e');
        // FALLBACK: Marquer la partie comme terminée localement
        setState(() {
          isGameFinished = true;
          _cancelAllTimers();
        });
        _showResultModal();
      }
    } else {
      setState(() {
        isGameFinished = true;
        _cancelAllTimers();
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_resultModalShown) {
          _showResultModal();
        }
      });
    }
    GameStartService().exitGame();
  }

  void _onPointTap(int x, int y) async {
      // 🚫 BLOQUER L'INTERACTION POUR LES SPECTATEURS
    if (_isSpectator) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Les spectateurs ne peuvent pas jouer'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (isGameFinished) return;
    
    if (_isOnlineGame && !_isMyTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ce n\'est pas votre tour !'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    if (points.any((point) => point.x == x && point.y == y)) return;
    
    final playerId = _isOnlineGame 
        ? (_myPlayerColor == 'bleu' ? widget.existingGame!.player1Id! : widget.existingGame!.player2Id!)
        : currentPlayer;
    
    final newPoint = GridPoint(x: x, y: y, playerId: playerId);
    
    if (_isOnlineGame && _gameId != null) {
      try {
        await GameService.addPointToGame(_gameId!, newPoint);
        
        final allPoints = [...points, newPoint];
        final newSquares = GameLogic.checkSquares(allPoints, widget.gridSize, playerId!, x, y);
        
        if (newSquares.isNotEmpty) {
          for (final square in newSquares) {
            await GameService.addSquareToGame(_gameId!, square);
          }
          
          _startRadarAnimation(newPoint);
          
          if (newSquares.isNotEmpty) {
            _scoreAnimationController.forward().then((_) => _scoreAnimationController.reverse());
          }
        } else {
          _startRadarAnimation(newPoint);
        }
        
      } catch (e) {
        print('Erreur jouer coup: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du coup'), backgroundColor: Colors.red),
        );
      }
  } else {
    setState(() {
      points.add(newPoint);
      _startRadarAnimation(newPoint);
      final newSquares = GameLogic.checkSquares(points, widget.gridSize, currentPlayer, x, y);
      
      if (newSquares.isNotEmpty) {
        squares.addAll(newSquares);
        _scoreAnimationController.forward().then((_) => _scoreAnimationController.reverse());
      }
      
      scores[currentPlayer] = scores[currentPlayer]! + newSquares.length;
      
      if (points.length >= widget.gridSize * widget.gridSize) {
        isGameFinished = true;
        _cancelAllTimers();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_resultModalShown) {
            _showResultModal();
          }
        });
      } else {
        _resetReflexionTimer();
        _switchPlayer();
      }
    });
  }
}

  Color _getPlayerColor(String playerId) {
    if (_isOnlineGame && widget.existingGame != null) {
      if (playerId == widget.existingGame!.player1Id) return Color(0xFF00d4ff);
      if (playerId == widget.existingGame!.player2Id) return Color(0xFFff006e);
    }
    return playerId == 'bleu' ? Color(0xFF00d4ff) : Color(0xFFff006e);
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showResultModal() {
    if (_resultModalShown || !mounted) return;
    _resultModalShown = true;
    
    print('🎊 AFFICHAGE MODAL - Scores: $scores, En ligne: $_isOnlineGame');
    
    // S'assurer que tous les timers sont arrêtés
    _cancelAllTimers();
    
    Future.delayed(Duration(milliseconds: 500), () {
      if (!mounted) {
        print('❌ Modal non monté');
        return;
      }
      
      print('✅ Affichage du modal de résultat...');
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.9),
        barrierDismissible: false,
        builder: (BuildContext context) => _buildResultModal(),
      ).then((_) {
        _resultModalShown = false;
        print('🔒 Modal fermé');
      });
    });
  }

  Widget _buildReflexionTimer() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 1, vertical: 2),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
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
      )
    );
  }

  Widget _buildResultModal() {
    final isDraw = scores['bleu']! == scores['rouge']!;
    final winner = scores['bleu']! > scores['rouge']! ? 'bleu' : 'rouge';
    final winnerName = winner == 'bleu' ? _bluePlayerName : _redPlayerName;
    
    // Déterminer si l'utilisateur actuel a gagné (pour les parties en ligne)
    bool isCurrentUserWinner = false;
    String resultMessage = '';
    
    if (_isOnlineGame) {
      if (isDraw) {
        resultMessage = 'MATCH NUL';
      } else if (winner == 'bleu' && _myPlayerColor == 'bleu') {
        isCurrentUserWinner = true;
        resultMessage = '🎉 VOUS AVEZ GAGNÉ !';
      } else if (winner == 'rouge' && _myPlayerColor == 'rouge') {
        isCurrentUserWinner = true;
        resultMessage = '🎉 VOUS AVEZ GAGNÉ !';
      } else {
        resultMessage = '😔 VOUS AVEZ PERDU';
      }
    }
    
    return Stack(
      children: [
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2d0052), Color(0xFF1a0033)],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Color(0xFF9c27b0), width: 2),
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
                  if (!_isOnlineGame && !isDraw) ...[
                Text(
                      isDraw ? 'MATCH NUL !' : 'VICTOIRE !',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    ],
                SizedBox(height: 20),
                  if (_isOnlineGame && !isDraw) ...[
                    SizedBox(height: 10),
                    Text(
                      resultMessage,
                      style: TextStyle(
                        color: isCurrentUserWinner ? Colors.yellow : Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  SizedBox(height: 10),
                  if (!isDraw) _buildWinnerProfile(winner, winnerName),
                  if (isDraw) _buildDrawProfiles(),
                  SizedBox(height: 20),
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
                      border: Border.all(color: Color(0xFFFFD700), width: 3),
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
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Color(0xFF2d0052).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Color(0xFF9c27b0), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildModalScore(_bluePlayerName, scores['bleu']!, Color(0xFF00d4ff)),
                        Container(
                          width: 2,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Color(0xFF9c27b0), Colors.transparent],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        _buildModalScore(_redPlayerName, scores['rouge']!, Color(0xFFff006e)),
                      ],
                    ),
                  ),
                  SizedBox(height: 30),
                  Column(
                    children: [
                      if (!_isOnlineGame) ...[
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)]),
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
                                _initializeTimers();
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
                      ],
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Color(0xFF9c27b0), width: 2),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                            child: Center(
                              child: Text(
                                'Fermer',
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
        ),
      ],
    );
  }

Widget _buildWinnerProfile(String player, String playerName) {
  final color = _getPlayerColor(player);
  
  // Récupérer les données du joueur gagnant
  Player? winnerPlayer;
  if (_isOnlineGame) {
    if (player == 'bleu') {
      winnerPlayer = _myPlayerColor == 'bleu' ? _currentUserPlayer : _opponentPlayer;
    } else {
      winnerPlayer = _myPlayerColor == 'rouge' ? _currentUserPlayer : _opponentPlayer;
    }
  }

  return Column(
    children: [
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(0.8), color.withOpacity(0.3)],
          ),
          border: Border.all(color: color, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
        child: _isOnlineGame && winnerPlayer != null
            ? ClipOval(
                child: Image.network(
                  winnerPlayer.displayAvatar,
                  fit: BoxFit.cover,
                  width: 80,
                  height: 80,
                  errorBuilder: (context, error, stackTrace) => 
                    Icon(Icons.person, color: Colors.white, size: 40),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  },
                ),
              )
            : Icon(Icons.person, color: Colors.white, size: 40),
      ),
      SizedBox(height: 12),
      Text(
        playerName.toUpperCase(),
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
        _buildDrawProfile(_bluePlayerName, Color(0xFF00d4ff)),
        _buildDrawProfile(_redPlayerName, Color(0xFFff006e)),
      ],
    );
  }

Widget _buildDrawProfile(String playerName, Color color) {
  // Récupérer les données du joueur
  Player? playerData;
  if (_isOnlineGame) {
    if (playerName == _bluePlayerName) {
      playerData = _myPlayerColor == 'bleu' ? _currentUserPlayer : _opponentPlayer;
    } else {
      playerData = _myPlayerColor == 'rouge' ? _currentUserPlayer : _opponentPlayer;
    }
  }

  return Column(
    children: [
      Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(0.8), color.withOpacity(0.3)],
          ),
          border: Border.all(color: color, width: 2),
        ),
        child: _isOnlineGame && playerData != null
            ? ClipOval(
                child: Image.network(
                  playerData.displayAvatar,
                  fit: BoxFit.cover,
                  width: 60,
                  height: 60,
                  errorBuilder: (context, error, stackTrace) => 
                    Icon(Icons.person, color: Colors.white, size: 30),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Icon(Icons.person, color: Colors.white, size: 30);
                  },
                ),
              )
            : Icon(Icons.person, color: Colors.white, size: 30),
      ),
      SizedBox(height: 8),
      Text(
        playerName,
        style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

  Widget _buildModalScore(String playerName, int score, Color color) {
    return Column(
      children: [
        Text(playerName, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        SizedBox(height: 4),
        Text(score.toString(), style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
      ],
    );
  }
  
  Widget _buildTimerAndProgressBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Color(0xFF2d0052),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF2d0052),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
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
                    border: Border.all(color: _getPlayerColor(currentPlayer), width: 2),
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)]),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () {
                    // 🎯 ACTION DIFFÉRENTE POUR LES SPECTATEURS
                    if (_isSpectator) {
                      _leaveAsSpectatorAndExit();
                    } else {
                      Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NavigationScreen(),
                              ),
                            );
                    }
                  },
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
                    ),],
                ),
              ),
              // 🆕 AJOUT DE L'ICÔNE DE MESSAGE POUR LES PARTIES EN LIGNE
              if (_isOnlineGame && !_isSpectator) 
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF00d4ff), Color(0xFF0099cc)]),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                    onPressed: _showQuickMessageModal,
                  ),
                ),
              SizedBox(width: 8),
              _buildGameMenuDropdown(),
            ],
          ),
          SizedBox(height: 10),
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
                color: isGameFinished ? Color(0xFFe040fb) : _getPlayerColor(currentPlayer),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isGameFinished ? Color(0xFFe040fb) : _getPlayerColor(currentPlayer)).withOpacity(0.3),
                  blurRadius: 15,
                ),
              ],
            ),
            child: isGameFinished ? _buildWinnerStatus() : _buildScoresRow(),
          ),
          _buildTimerAndProgressBar(),
        ],
      ),
    );
  }

  void _leaveAsSpectatorAndExit() {
    _leaveAsSpectator();
    Navigator.pop(context);
  }

  Widget _buildGameMenuDropdown() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)]),
      ),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_vert, color: Colors.white, size: 20),
        color: Color(0xFF2d0052),
        onSelected: (String value) {
          if (value == 'forfeit' && !_isSpectator) {
            _showForfeitConfirmation();
          } else if (value == 'new_game' && !_isOnlineGame) {
            _showNewGameConfirmation();
          } else if (value == 'leave_spectator' && _isSpectator) {
            _leaveAsSpectatorAndExit();
          }
        },
        itemBuilder: (BuildContext context) => [
          // 🎯 OPTION POUR QUITTER EN TANT QUE SPECTATEUR
          if (_isSpectator)
            PopupMenuItem<String>(
              value: 'leave_spectator',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)]),
                    ),
                    child: Icon(Icons.exit_to_app, color: Colors.white, size: 18),
                  ),
                  SizedBox(width: 12),
                  Text('Quitter l\'observation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          // OPTIONS POUR LES JOUEURS SEULEMENT
          if (!_isSpectator)
            PopupMenuItem<String>(
              value: 'forfeit',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFFff006e), Color(0xFFc4005a)]),
                    ),
                    child: Icon(Icons.flag, color: Colors.white, size: 18),
                  ),
                  SizedBox(width: 12),
                  Text('Abandonner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          if (!_isOnlineGame && !_isSpectator)
            PopupMenuItem<String>(
              value: 'new_game',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFF00d4ff), Color(0xFF0099cc)]),
                    ),
                    child: Icon(Icons.refresh, color: Colors.white, size: 18),
                  ),
                  SizedBox(width: 12),
                  Text('Nouvelle partie', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showForfeitConfirmation() {
     if (_isSpectator) return; // 🚫 Bloqué pour les spectateurs
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2d0052),
          title: Text('Confirmer l\'abandon', style: TextStyle(color: Colors.white)),
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
              onPressed: () async {
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
    if (_isSpectator) return; // 🚫 Bloqué pour les spectateurs
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2d0052),
          title: Text('Nouvelle partie', style: TextStyle(color: Colors.white)),
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
                _cancelAllTimers();
                setState(() => _initializeGame());
                _initializeTimers();
              },
              child: Text('Nouvelle partie', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  void _endGameByForfeit() async {
    final loser = currentPlayer;
    final winner = currentPlayer == 'bleu' ? 'rouge' : 'bleu';
    
    if (_isOnlineGame && _gameId != null) {
      final winnerId = _myPlayerColor == 'bleu' 
          ? widget.existingGame!.player2Id 
          : widget.existingGame!.player1Id;
      final loserId = _myPlayerColor == 'bleu' 
          ? widget.existingGame!.player1Id 
          : widget.existingGame!.player2Id;
      
      try {
        // 1. CALCULER LES NOUVEAUX SCORES (même logique que local)
        final updatedScores = {
          winnerId!: (scores[winner] ?? 0) + (scores[loser] ?? 0) + 1,
          loserId!: 0
        };
        
        print('🎯 Mise à jour scores abandon - Gagnant: ${updatedScores[winnerId]}, Perdant: ${updatedScores[loserId]}');
        
        // 2. METTRE À JOUR LES SCORES DANS FIRESTORE
        await GameService.updateGameScores(_gameId!, updatedScores);
        
        // 3. MAINTENANT TERMINER LA PARTIE
        await GameService.finishGameWithReason(
          _gameId!,
          winnerId: winnerId,
          endReason: GameEndReason.playerSurrendered
        );
        
        print('✅ Abandon traité avec succès');
        
      } catch (e) {
        print('❌ Erreur lors de l\'abandon: $e');
        // Fallback: terminer la partie même si la mise à jour des scores échoue
        await GameService.finishGameWithReason(
          _gameId!,
          winnerId: winnerId,
          endReason: GameEndReason.playerSurrendered
        );
      }
      
    } else {
      // Logique locale inchangée
      setState(() {
        isGameFinished = true;
        _cancelAllTimers();
        final lostPoints = scores[loser] ?? 0;
        scores[winner] = (scores[winner] ?? 0) + lostPoints + 1;
        scores[loser] = 0;
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_resultModalShown) {
          _showResultModal();
        }
      });
    }
    GameStartService().exitGame();
  }

  Widget _buildWinnerStatus() {
    String winner;
    String winnerName;
    
    if (scores['bleu']! > scores['rouge']!) {
      winner = 'bleu';
      winnerName = _bluePlayerName;
    } else if (scores['rouge']! > scores['bleu']!) {
      winner = 'rouge';
      winnerName = _redPlayerName;
    } else {
      winner = 'ÉGALITÉ';
      winnerName = 'ÉGALITÉ';
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(winner == 'ÉGALITÉ' ? Icons.handshake : Icons.emoji_events, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              winner == 'ÉGALITÉ' ? 'MATCH NUL !' : '$winnerName GAGNE !',
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
        _buildCompactPlayerScore('bleu', scores['bleu']!, _bluePlayerName),
        Container(
          width: 80,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Color(0xFF9c27b0), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: _buildReflexionTimer(),
        ),
        _buildCompactPlayerScore('rouge', scores['rouge']!, _redPlayerName),
      ],
    );
  }

Widget _buildCompactPlayerScore(String player, int score, String playerName) {
  final isActive = currentPlayer == player && !isGameFinished;
  final color = _getPlayerColor(player);

  // Déterminer si c'est le joueur actuel ou l'adversaire
  bool isCurrentUser = false;
  Player? playerData;
  
  if (_isOnlineGame) {
    if (player == 'bleu' && _myPlayerColor == 'bleu') {
      isCurrentUser = true;
      playerData = _currentUserPlayer;
    } else if (player == 'rouge' && _myPlayerColor == 'rouge') {
      isCurrentUser = true;
      playerData = _currentUserPlayer;
    } else {
      playerData = _opponentPlayer;
    }
  }

  return ScaleTransition(
    scale: isActive ? _scoreScaleAnimation : AlwaysStoppedAnimation(1.0),
    child: Column(
      children: [
        // Avatar du joueur
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(0.8), color.withOpacity(0.3)],
            ),
            border: Border.all(color: color, width: isActive ? 2 : 1),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: _isOnlineGame && playerData != null
              ? ClipOval(
                  child: Image.network(
                    playerData.displayAvatar,
                    fit: BoxFit.cover,
                    width: 32,
                    height: 32,
                    errorBuilder: (context, error, stackTrace) => 
                      Icon(Icons.person, color: Colors.white, size: 16),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Icon(Icons.person, color: Colors.white, size: 16);
                    },
                  ),
                )
              : Icon(Icons.person, color: Colors.white, size: 16),
        ),
        SizedBox(height: 4),
        Text(
          playerName.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          score.toString(),
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}
  Widget _buildSpectatorsSection() {
    return StreamBuilder<List<Player>>(
      stream: _spectatorsStream,
      builder: (context, snapshot) {
        final spectators = snapshot.data ?? _spectators;
        
        return Container(
          height: 90,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Color(0xFF1a0033),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Color(0xFF4a0080), width: 2),
          ),
          child: Column(
            children: [
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
                    Icon(Icons.visibility, color: Color(0xFFe040fb), size: 12),
                    SizedBox(width: 8),
                    Text(
                      '${spectators.length} SPECTATEURS',
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
              Expanded(
                child: spectators.isEmpty 
                    ? _buildEmptySpectators()
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: spectators.length,
                        itemBuilder: (context, index) {
                          final spectator = spectators[index];
                          return Container(
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                  Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                                    ),
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF9c27b0).withOpacity(0.5),
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval( // Force le clip circulaire
                                    child:Image.network(
                                            spectator.displayAvatar,
                                            fit: BoxFit.cover,
                                            width: 40,
                                            height: 40,
                                            errorBuilder: (context, error, stackTrace) => 
                                              Icon(Icons.person, size: 20, color: Colors.white),
                                          )
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
      },
    );
  }

  Widget _buildEmptySpectators() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, color: Color(0xFF4a0080), size: 24),
          SizedBox(height: 4),
          Text('Aucun spectateur', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
        ],
      ),
    );
  }
  
  Widget _buildGameGrid() {
    final cellSize = 60.0;
    final gridWidth = (widget.gridSize * cellSize) + 40;
    final gridHeight = (widget.gridSize * cellSize) + 40;
    final screenSize = MediaQuery.of(context).size;
    final dynamicBoundaryMargin = EdgeInsets.all(math.max(screenSize.width, screenSize.height) * 0.8);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
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
              colors: [Color(0xFF0a0015), Color(0xFF1a0033)],
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
            painter: GridPainter(gridSize: widget.gridSize, cellSize: cellSize),
            child: Stack(
              children: [
                if (_lastPlayedPoint != null)
                  Positioned(
                    left: _lastPlayedPoint!.x * cellSize,
                    top: _lastPlayedPoint!.y * cellSize,
                    child: Container(
                      width: 40,
                      height: 40,
                      child: CustomPaint(
                        painter: RadarPointPainter(
                          x: 20,
                          y: 20,
                          color: _getPlayerColor(_lastPlayedPoint!.playerId!),
                          animationValue: _radarAnimation.value,
                        ),
                      ),
                    ),
                  ),
                ...squares.map((square) {
                  return Positioned(
                    left: square.x * cellSize + 20,
                    top: square.y * cellSize + 20,
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
                                border: Border.all(color: _getPlayerColor(square.playerId), width: 3),
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
                ...List.generate(widget.gridSize + 1, (x) {
                  return List.generate(widget.gridSize + 1, (y) {
                    final point = points.firstWhere(
                      (p) => p.x == x && p.y == y,
                      orElse: () => GridPoint(x: -1, y: -1),
                    );
                    return Positioned(
                      left: x * cellSize,
                      top: y * cellSize,
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

// 🆕 MÉTHODES POUR LE SYSTÈME DE MESSAGES AVEC SYNCHRONISATION FIREBASE
void _showQuickMessageModal() {
  if (!_isOnlineGame || _isSpectator) return;
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.7,
      builder: (context, scrollController) => _QuickMessageModal(
        isOnlineGame: _isOnlineGame,
        onMessageSent: _sendQuickMessage,
      ),
    ),
  );
}

void _sendQuickMessage(String message) {
  if (!_isOnlineGame || _gameId == null) return;
  
  // ✅ Mon message apparaît de mon côté
  _showMessageOverlay(message, senderId: _currentUserId!);
  
  GameService.sendQuickMessage(
    _gameId!,
    message,
    _currentUserId!,
    _currentUserPlayer?.username ?? 'Joueur'
  );
}

void _startListeningToMessages() {
  if (_gameId == null) return;
  
  GameService.getQuickMessages(_gameId!).listen((message) {
    if (message.isNotEmpty && 
        message['senderId'] != _currentUserId && 
        mounted) {
      // ✅ Message adverse apparaît de son côté
      _showMessageOverlay(message['text'], senderId: message['senderId']);
    }
  });
}

void _showMessageOverlay(String message, {required String senderId}) {
  _messageOverlayEntry?.remove();

  final isOnLeft = _isPlayerOnLeft(senderId);
  final isMyMessage = senderId == _currentUserId;

  // ✅ Position selon le côté du joueur
  final position = Positioned(
    top: MediaQuery.of(context).padding.top + 120,
    left: isOnLeft ? 16 : null,    // Joueur gauche → GAUCHE
    right: isOnLeft ? null : 16,   // Joueur droit → DROITE
    child: _buildMessageBubble(message, isOnLeft: isOnLeft, isMyMessage: isMyMessage),
  );

  final overlay = Overlay.of(context);
  _messageOverlayEntry = OverlayEntry(builder: (context) => position);
  overlay.insert(_messageOverlayEntry!);

  Future.delayed(Duration(seconds: 4), () {
    _messageOverlayEntry?.remove();
    _messageOverlayEntry = null;
  });
}

Widget _buildMessageBubble(String message, {required bool isOnLeft, required bool isMyMessage}) {
  // ✅ Couleur selon le joueur (bleu/rouge) et non pas "myMessage"
  final playerColor = isOnLeft ? Color(0xFF00d4ff) : Color(0xFFff006e);
  
  return Material(
    color: Colors.transparent,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: playerColor.withOpacity(0.9),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: isOnLeft ? Radius.circular(4) : Radius.circular(20),
          bottomRight: isOnLeft ? Radius.circular(20) : Radius.circular(4),
        ),
        border: Border.all(color: playerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isGameFinished && !_resultModalShown) {
        print('🏁 Build - Partie terminée, déclenchement modal...');
        _showResultModal();
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a0033), Color(0xFF2d0052), Color(0xFF0a0015)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildCompactHeader(),
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(top: 0, bottom: 8, left: 16, right: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Color(0xFF9c27b0), width: 2),
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

    for (int i = 0; i <= gridSize; i++) {
      final x = i * cellSize + 20;
      canvas.drawLine(Offset(x, 20), Offset(x, gridSize * cellSize + 20), paint);
    }

    for (int i = 0; i <= gridSize; i++) {
      final y = i * cellSize + 20;
      canvas.drawLine(Offset(20, y), Offset(gridSize * cellSize + 20, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
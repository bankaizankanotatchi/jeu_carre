import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jeu_carre/models/ai_player.dart';
import 'package:jeu_carre/models/game_request.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/screens/game_screen/game_screen.dart';
import 'package:jeu_carre/services/game_service.dart';

class GameSetupScreen extends StatefulWidget {
  final bool isAgainstAI;
  final AIDifficulty? aiDifficulty;
  final bool isOnlineMatch;
  final Player? opponent; // Nouveau paramètre

  const GameSetupScreen({
    Key? key,
    required this.isAgainstAI,
    this.aiDifficulty,
    this.isOnlineMatch = false,
    this.opponent, // Nouveau paramètre
  }) : super(key: key);

  @override
  _GameSetupScreenState createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Paramètres configurables
  int _selectedGridSize = 15;
  int _selectedGameDuration = 180; // en secondes
  int _selectedReflexionTime = 15; // en secondes

  // Options disponibles
  final List<int> _gridSizeOptions = [15, 20, 25, 30];
  final List<int> _gameDurationOptions = [180, 300, 600, 900]; // 1, 2, 3, 5 minutes
  final List<int> _reflexionTimeOptions = [5, 10, 15, 20]; // secondes

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Interval(0.3, 1.0)),
    );
    
    _animationController.forward();

  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }


  void _startGame() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          gridSize: _selectedGridSize,
          isAgainstAI: widget.isAgainstAI,
          aiDifficulty: widget.aiDifficulty ?? AIDifficulty.intermediate,
          gameDuration: _selectedGameDuration,
          reflexionTime: _selectedReflexionTime,
          opponentId: widget.opponent?.id, // Passer l'ID de l'adversaire
        ),
      ),
    );
  }
void _sendMatchRequest() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vous devez être connecté pour envoyer un défi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.opponent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aucun adversaire sélectionné'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Créer la demande de match avec les paramètres configurés
    final matchRequest = MatchRequest(
      id: GameService.generateId(),
      fromUserId: currentUser.uid,
      toUserId: widget.opponent!.id,
      gridSize: _selectedGridSize,
      gameDuration: _selectedGameDuration,
      reflexionTime: _selectedReflexionTime,
      status: MatchRequestStatus.pending,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(minutes: 30)), // Expire dans 30 minutes
    );

    // Envoyer la demande via GameService
    await GameService.sendMatchRequest(matchRequest);

    // Afficher le message de confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Défi envoyé à ${widget.opponent!.username} !'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    // Fermer cet écran et revenir en arrière
    Navigator.pop(context);

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

void _showChallengeSentDialog() {
  final opponentName = widget.opponent?.username ?? 'votre adversaire';
  
  showDialog(
    context: context,
    barrierDismissible: false,
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
              // Avatar de l'adversaire si disponible
              if (widget.opponent != null)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      widget.opponent!.displayAvatar,
                      style: TextStyle(fontSize: 30),
                    ),
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF00d4ff).withOpacity(0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Icon(Icons.send, color: Colors.white, size: 40),
                ),
              
              SizedBox(height: 16),
              
              Text(
                widget.opponent != null 
                  ? 'Votre défi sera envoyé à $opponentName\navec les paramètres suivants :'
                  : 'Recherche d\'un adversaire de niveau similaire...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),

              // Afficher les paramètres du défi
              if (widget.opponent != null) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFF00d4ff), width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildChallengeParam('Grille', '${_selectedGridSize}×${_selectedGridSize}'),
                      _buildChallengeParam('Durée', '${_selectedGameDuration ~/ 60} minutes'),
                      _buildChallengeParam('Temps par tour', '${_selectedReflexionTime} secondes'),
                    ],
                  ),
                ),
              ],
              
              SizedBox(height: 24),
              
              Row(
                children: [
                  // Bouton Annuler
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
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
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                          },
                          child: Center(
                            child: Text(
                              'ANNULER',
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
                  ),
                  
                  SizedBox(width: 12),
                  
                  // Bouton Envoyer
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () {
                            Navigator.of(context).pop(); // Fermer le dialog
                            _sendMatchRequest(); // Envoyer la demande
                          },
                          child: Center(
                            child: Text(
                              'CONFIRMER',
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
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildChallengeParam(String title, String value) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Color(0xFF00d4ff),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
 
  Widget _buildSettingCard({
    required String title,
    required String description,
    required Widget content,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2d0052).withOpacity(0.8),
            Color(0xFF1a0033).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFF4a0080),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildOptionChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    color ?? Color(0xFF00d4ff),
                    color?.withOpacity(0.7) ?? Color(0xFF0099cc),
                  ],
                )
              : null,
          color: isSelected ? null : Color(0xFF1a0033),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? color ?? Color(0xFF00d4ff) : Color(0xFF4a0080),
            width: 2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridSizeSelector() {
    return Row(
      children: _gridSizeOptions.map((size) {
        return _buildOptionChip(
          label: '${size}×${size}',
          isSelected: _selectedGridSize == size,
          onTap: () => setState(() => _selectedGridSize = size),
          color: Color(0xFF00d4ff),
        );
      }).toList(),
    );
  }

  Widget _buildGameDurationSelector() {
    return Row(
      children: _gameDurationOptions.map((duration) {
        final minutes = duration ~/ 60;
        return _buildOptionChip(
          label: '$minutes min',
          isSelected: _selectedGameDuration == duration,
          onTap: () => setState(() => _selectedGameDuration = duration),
          color: Color(0xFFe040fb),
        );
      }).toList(),
    );
  }

  Widget _buildReflexionTimeSelector() {
    return Row(
      children: _reflexionTimeOptions.map((time) {
        return _buildOptionChip(
          label: '$time s',
          isSelected: _selectedReflexionTime == time,
          onTap: () => setState(() => _selectedReflexionTime = time),
          color: Color(0xFFFFD700),
        );
      }).toList(),
    );
  }

  Widget _buildConfigurationScreen() {
    String difficultyText = '';

    switch (widget.aiDifficulty) {
      case AIDifficulty.beginner:
        difficultyText = 'DÉBUTANT';
        break;
      case AIDifficulty.intermediate:
        difficultyText = 'INTERMÉDIAIRE';
        break;
      case AIDifficulty.expert:
        difficultyText = 'EXPERT';
        break;
      default:
        difficultyText = 'INTERMÉDIAIRE';
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          children: [
            // En-tête
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF2d0052),
                    Color(0xFF1a0033),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Color(0xFF9c27b0),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    widget.isOnlineMatch 
                        ? widget.opponent != null 
                            ? 'DÉFI EN LIGNE'
                            : 'MATCH EN LIGNE'
                        : widget.isAgainstAI 
                            ? 'CONTRE L\'IA'
                            : 'AVEC UN AMI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.isOnlineMatch
                        ? widget.opponent != null
                            ? 'Configurez votre défi contre ${widget.opponent!.username}'
                            : 'Configurez votre match et défiez un adversaire en ligne'
                        : widget.isAgainstAI
                            ? 'Affrontez notre IA de niveau $difficultyText'
                            : 'Préparez-vous pour un match en local passionnant',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Paramètres de configuration
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildSettingCard(
                      title: 'TAILLE DE GRILLE',
                      description: 'Choisissez la dimension du plateau de jeu',
                      content: _buildGridSizeSelector(),
                    ),
                    
                    _buildSettingCard(
                      title: 'DURÉE DU MATCH',
                      description: 'Temps total pour la partie',
                      content: _buildGameDurationSelector(),
                    ),
                    
                    _buildSettingCard(
                      title: 'TEMPS DE RÉFLEXION',
                      description: 'Temps maximum par tour',
                      content: _buildReflexionTimeSelector(),
                    ),

                    // Résumé des paramètres
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF1a0033),
                            Color(0xFF2d0052),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Color(0xFF00d4ff),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem('Grille', '${_selectedGridSize}×${_selectedGridSize}'),
                          _buildSummaryItem('Match', '${_selectedGameDuration ~/ 60} min'),
                          _buildSummaryItem('Tour', '${_selectedReflexionTime} s'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bouton de démarrage
            Container(
              width: double.infinity,
              height: 60,
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF00d4ff),
                    Color(0xFF0099cc),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF00d4ff).withOpacity(0.5),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: widget.isOnlineMatch ? _showChallengeSentDialog : _startGame,
                  child: Center(
                    child: Text(
                      widget.isOnlineMatch 
                          ? widget.opponent != null 
                              ? 'ENVOYER LE DÉFI'
                              : 'CHERCHER UN ADVERSAIRE'
                          : 'COMMENCER LA PARTIE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
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
  }

  Widget _buildSummaryItem(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Color(0xFF00d4ff),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
              // Header avec bouton retour
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
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
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'CONFIGURATION',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenu principal
              Expanded(
                child:  _buildConfigurationScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
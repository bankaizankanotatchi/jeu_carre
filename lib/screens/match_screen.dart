import 'package:flutter/material.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Données fictives pour les matchs en cours
  final List<Map<String, dynamic>> _myActiveMatches = [
    {
      'id': '1',
      'opponent': 'AlexPro',
      'opponentAvatar': '🥇',
      'gridSize': 15,
      'myScore': 3,
      'opponentScore': 2,
      'currentPlayer': 'moi',
      'timeLeft': 120,
      'createdAt': DateTime.now().subtract(Duration(minutes: 5)),
      'isAgainstAI': false,
      'status': 'en_cours',
    },
    {
      'id': '2',
      'opponent': 'IA Expert',
      'opponentAvatar': '🤖',
      'gridSize': 25,
      'myScore': 1,
      'opponentScore': 4,
      'currentPlayer': 'IA',
      'timeLeft': 89,
      'createdAt': DateTime.now().subtract(Duration(minutes: 8)),
      'isAgainstAI': true,
      'aiDifficulty': 'expert',
      'status': 'en_cours',
    },
    {
      'id': '3',
      'opponent': 'SarahShik',
      'opponentAvatar': '🥈',
      'gridSize': 15,
      'myScore': 0,
      'opponentScore': 0,
      'currentPlayer': 'moi',
      'timeLeft': 180,
      'createdAt': DateTime.now().subtract(Duration(minutes: 2)),
      'isAgainstAI': false,
      'status': 'en_attente',
    },
  ];

  final List<Map<String, dynamic>> _allActiveMatches = [
    {
      'id': '4',
      'player1': 'MikeMaster',
      'player1Avatar': '🥉',
      'player2': 'LunaPlay',
      'player2Avatar': '👑',
      'gridSize': 15,
      'score1': 2,
      'score2': 3,
      'currentPlayer': 'LunaPlay',
      'timeLeft': 67,
      'createdAt': DateTime.now().subtract(Duration(minutes: 10)),
      'spectators': 12,
      'status': 'en_cours',
    },
    {
      'id': '5',
      'player1': 'ProPlayerX',
      'player1Avatar': '⚡',
      'player2': 'ShikakuQueen',
      'player2Avatar': '👑',
      'gridSize': 25,
      'score1': 5,
      'score2': 4,
      'currentPlayer': 'ProPlayerX',
      'timeLeft': 45,
      'createdAt': DateTime.now().subtract(Duration(minutes: 15)),
      'spectators': 28,
      'status': 'en_cours',
    },
    {
      'id': '6',
      'player1': 'GridMaster',
      'player1Avatar': '🎯',
      'player2': 'BrainStorm',
      'player2Avatar': '🌟',
      'gridSize': 15,
      'score1': 1,
      'score2': 1,
      'currentPlayer': 'BrainStorm',
      'timeLeft': 150,
      'createdAt': DateTime.now().subtract(Duration(minutes: 3)),
      'spectators': 5,
      'status': 'en_cours',
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

  Widget _buildMyMatchCard(Map<String, dynamic> match) {
    final isMyTurn = match['currentPlayer'] == 'moi';
    final timeLeft = match['timeLeft'];
    final minutes = timeLeft ~/ 60;
    final seconds = timeLeft % 60;
    final isWaiting = match['status'] == 'en_attente';
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1a0033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyTurn ? Color(0xFF00d4ff) : Color(0xFF4a0080),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Navigation vers le jeu
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // En-tête avec adversaire et statut
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: match['isAgainstAI'] 
                                ? [Color(0xFFff006e), Color(0xFFc4005a)]
                                : [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              match['opponentAvatar'],
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              match['isAgainstAI'] ? 'IA ${match['aiDifficulty']}' : match['opponent'],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Grille ${match['gridSize']}×${match['gridSize']}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isMyTurn ? Color(0xFF00d4ff).withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isMyTurn ? Color(0xFF00d4ff) : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        isWaiting ? 'EN ATTENTE' : (isMyTurn ? 'À VOTRE TOUR' : 'EN COURS'),
                        style: TextStyle(
                          color: isMyTurn ? Color(0xFF00d4ff) : Colors.white.withOpacity(0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Score et timer - Style Livescore
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF2d0052),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Score Joueur 1 (moi)
                      Column(
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
                            child: Icon(Icons.person, color: Colors.white, size: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${match['myScore']}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      
                      // Timer central
                      Column(
                        children: [
                          Text(
                            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: Color(0xFFe040fb),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'TEMPS RESTANT',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      
                      // Score Joueur 2 (adversaire)
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: match['isAgainstAI'] 
                                  ? [Color(0xFFff006e), Color(0xFFc4005a)]
                                  : [Color(0xFFe040fb), Color(0xFF9c27b0)],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                match['opponentAvatar'],
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${match['opponentScore']}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Bouton d'action
                Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isMyTurn
                          ? [Color(0xFF00d4ff), Color(0xFF0099cc)]
                          : [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        // Reprendre la partie
                      },
                      child: Center(
                        child: Text(
                          isWaiting ? 'REJOINDRE' : (isMyTurn ? 'REPRENDRE' : 'OBSERVER'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPublicMatchCard(Map<String, dynamic> match) {
    final timeLeft = match['timeLeft'];
    final minutes = timeLeft ~/ 60;
    final seconds = timeLeft % 60;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1a0033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF4a0080)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Observer le match
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // En-tête avec joueurs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                match['player1Avatar'],
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  match['player1'],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Joueur 1',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFF4a0080),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  match['player2'],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Joueur 2',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFFe040fb), Color(0xFF9c27b0)],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                match['player2Avatar'],
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Score et timer - Style Livescore
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF2d0052),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Score Joueur 1
                      Column(
                        children: [
                          Text(
                            '${match['score1']}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'SCORE',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      
                      // Timer central avec statut
                      Column(
                        children: [
                          Text(
                            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: Color(0xFFe040fb),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFF00d4ff).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Color(0xFF00d4ff),
                              ),
                            ),
                            child: Text(
                              'TOUR DE ${match['currentPlayer']}',
                              style: TextStyle(
                                color: Color(0xFF00d4ff),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Score Joueur 2
                      Column(
                        children: [
                          Text(
                            '${match['score2']}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'SCORE',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Informations supplémentaires
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.grid_on, color: Color(0xFF00d4ff), size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Grille ${match['gridSize']}×${match['gridSize']}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    
                    Row(
                      children: [
                        Icon(Icons.visibility, color: Color(0xFFe040fb), size: 12),
                        SizedBox(width: 4),
                        Text(
                          '${match['spectators']} spectateurs',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    
                    Container(
                      width: 80,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            // Rejoindre comme spectateur
                          },
                          child: Center(
                            child: Text(
                              'OBSERVER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0a0015),
      body: Column(
        children: [
          // Header avec particules
          Container(
            padding: EdgeInsets.fromLTRB(16, 25, 16, 10),
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
                ...List.generate(12, (index) => _buildAnimatedParticle(index)),
                
                // Contenu du header
                Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF9c27b0), Color(0xFFe040fb)],
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
                          child: Icon(Icons.sports_esports, color: Colors.white, size: 30),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ARÈNE DES MATCHS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Rejoignez la compétition et défiez les meilleurs',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
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
                Tab(icon: Icon(Icons.person), text: 'MES MATCHS'),
                Tab(icon: Icon(Icons.public), text: 'TOUS LES MATCHS'),
              ],
            ),
          ),
          
          // Contenu des tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Mes matchs
                _myActiveMatches.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF2d0052),
                                    Color(0xFF4a0080),
                                  ],
                                ),
                                border: Border.all(
                                  color: Color(0xFF9c27b0),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.sports_esports,
                                color: Color(0xFFe040fb),
                                size: 40,
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              'AUCUN MATCH EN COURS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Lancez un nouveau défi pour apparaître ici',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
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
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                  child: Center(
                                    child: Text(
                                      'NOUVEAU MATCH',
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
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        itemCount: _myActiveMatches.length,
                        itemBuilder: (context, index) {
                          return _buildMyMatchCard(_myActiveMatches[index]);
                        },
                      ),

                // Tab 2: Tous les matchs
                _allActiveMatches.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF2d0052),
                                    Color(0xFF4a0080),
                                  ],
                                ),
                                border: Border.all(
                                  color: Color(0xFF9c27b0),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.people,
                                color: Color(0xFF00d4ff),
                                size: 40,
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              'AUCUN MATCH PUBLIC',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Soyez le premier à lancer un match public !',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        itemCount: _allActiveMatches.length,
                        itemBuilder: (context, index) {
                          return _buildPublicMatchCard(_allActiveMatches[index]);
                        },
                      ),
              ],
            ),
          ),
        ],
      ),

   );
  }
}
// screens/online_users_screen.dart
import 'package:flutter/material.dart';
import 'package:jeu_carre/models/game_request.dart';
import 'package:jeu_carre/screens/game_mode_screen/game_mode_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/screens/profil_adversaire/profil_adversaire.dart';
import 'package:jeu_carre/services/game_service.dart';

class OnlineUsersScreen extends StatefulWidget {
  const OnlineUsersScreen({super.key});

  @override
  State<OnlineUsersScreen> createState() => _OnlineUsersScreenState();
}

class _OnlineUsersScreenState extends State<OnlineUsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Player>>? _onlineUsersStream;
  Stream<List<dynamic>>? _matchRequestsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadOnlineUsers();
    _loadMatchRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadOnlineUsers() {
    _onlineUsersStream = _firestore
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Player.fromMap(doc.data()))
            .where((player) => player.id != _getCurrentUserId())
            .toList());
  }

  void _loadMatchRequests() {
    final currentUserId = _getCurrentUserId();
    if (currentUserId.isNotEmpty) {
      _matchRequestsStream = GameService.getMatchRequests(currentUserId);
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  List<Player> _filterUsers(List<Player> users) {
    if (_searchQuery.isEmpty) {
      return users;
    }
    return users.where((user) {
      final username = user.username.toLowerCase();
      return username.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  String _getCurrentUserId() {
    return _auth.currentUser?.uid ?? '';
  }

  bool _isRequestExpired(dynamic request) {
    final now = DateTime.now();
    
    // CORRECTION: Vérifier si createdAt est un Timestamp ou DateTime
    DateTime createdAt;
    if (request.createdAt is Timestamp) {
      createdAt = (request.createdAt as Timestamp).toDate();
    } else if (request.createdAt is DateTime) {
      createdAt = request.createdAt as DateTime;
    } else {
      // Si c'est un int (millisecondsSinceEpoch)
      createdAt = DateTime.fromMillisecondsSinceEpoch(request.createdAt);
    }
    
    final difference = now.difference(createdAt).inHours;
    return difference >= 24;
  }


// NOUVELLE MÉTHODE : Vérifier s'il y a une demande de match en cours avec un utilisateur
Widget _buildChallengeButton(Player user, List<dynamic> matchRequests) {
  final currentUserId = _getCurrentUserId();
  
  // Rechercher une demande PENDING NON EXPIRÉE entre les deux joueurs
  final hasValidPendingRequest = matchRequests.any((request) {
    if (request is! MatchRequest) return false;
    
    final isBetweenThesePlayers = 
        (request.fromUserId == currentUserId && request.toUserId == user.id) ||
        (request.fromUserId == user.id && request.toUserId == currentUserId);
    
    final isPending = request.status == MatchRequestStatus.pending;
    final isExpired = _isRequestExpired(request);
    
    return isBetweenThesePlayers && isPending && !isExpired;
  });

  if (hasValidPendingRequest) {
    return _buildPendingRequestButton();
  } else if (user.inGame) {
    return _buildInGameButton();
  } else {
    return _buildChallengeActionButton(user);
  }
}
  Widget _buildPendingRequestButton() {
    return Container(
      width: 120,
      height: 50,
      decoration: BoxDecoration(
        color: Color(0xFFFFD700).withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Color(0xFFFFD700),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, color: Color(0xFFFFD700), size: 20),
          SizedBox(height: 4),
          Text(
            'EN ATTENTE',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInGameButton() {
    return Container(
      width: 120,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.orange,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_esports, color: Colors.orange, size: 20),
          SizedBox(height: 4),
          Text(
            'EN PARTIE',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeActionButton(Player user) {
    return Container(
      width: 120,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00d4ff), Color(0xFF00d4ff).withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _challengeUser(user),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_esports, color: Colors.white, size: 20),
              SizedBox(height: 4),
              Text(
                'DÉFIER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MODIFICATION DE LA MÉTHODE _showUserProfile POUR PRENDRE EN COMPTE LES DEMANDES
  void _showUserProfile(Player user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StreamBuilder<List<dynamic>>(
          stream: _matchRequestsStream,
          builder: (context, snapshot) {
            final matchRequests = snapshot.data ?? [];
            
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF00d4ff),
                                Color(0xFF0099cc),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 90,
                          height: 90,
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
                          child: ClipOval(
                            child: user.avatarUrl != null
                                ? Image.network(
                                    user.avatarUrl!,
                                    fit: BoxFit.cover,
                                    width: 90,
                                    height: 90,
                                    errorBuilder: (context, error, stackTrace) => 
                                      Icon(Icons.person, size: 30, color: Colors.white),
                                  )
                                : Image.network(
                                    user.defaultEmoji,
                                    fit: BoxFit.cover,
                                    width: 90,
                                    height: 90,
                                    errorBuilder: (context, error, stackTrace) => 
                                      Icon(Icons.person, size: 30, color: Colors.white),
                                  ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: user.inGame ? Colors.orange : Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text(
                      user.username,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${user.totalPoints} points',
                      style: TextStyle(
                        color: Color(0xFF00d4ff),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    
                    SizedBox(height: 10),
                    
                    // BOUTONS D'ACTION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildChallengeButton(user, matchRequests),
                        _buildProfileActionButton(user),
                      ],
                    ),
                    
                    SizedBox(height: 20),
                    Container(
                      width: double.infinity,
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
      },
    );
  }


  Widget _buildProfileActionButton(Player user) {
    return Container(
      width: 120,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFe040fb), Color(0xFFe040fb).withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            Navigator.of(context).pop();
            _viewUserProfile(user);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, color: Colors.white, size: 20),
              SizedBox(height: 4),
              Text(
                'PROFIL',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _challengeUser(Player user) {
    Navigator.of(context).pop(); // Fermer le dialog
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameSetupScreen(
          isAgainstAI: false,
          isOnlineMatch: true,
          opponent: user,
        ),
      ),
    );
  }

  void _viewUserProfile(Player user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OpponentProfileScreen(opponent: {
          'id': user.id,
          'username': user.username,
          'avatar': user.displayAvatar,
          'score': user.totalPoints,
        }),
      ),
    );
  }

  // [Les autres méthodes restent inchangées...]
  Widget _buildSearchBar() {
    // Même implémentation que précédemment
    return Container(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF2d0052).withOpacity(0.8),
            Color(0xFF1a0033).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
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
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: Color(0xFFe040fb),
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Rechercher un joueur...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
              cursorColor: Color(0xFF00d4ff),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.clear,
                color: Color(0xFFe040fb),
                size: 20,
              ),
              onPressed: _clearSearch,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsInfo(List<Player> filteredUsers) {
    // Même implémentation que précédemment
    if (_searchQuery.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${filteredUsers.length} résultat${filteredUsers.length > 1 ? 's' : ''} trouvé${filteredUsers.length > 1 ? 's' : ''}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (filteredUsers.isEmpty)
            Text(
              'Aucun joueur trouvé',
              style: TextStyle(
                color: Color(0xFFe040fb),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedParticle(int index) {
    // Même implémentation que précédemment
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

  Widget _buildUserAvatar(Player user) {
    // Même implémentation que précédemment
    return Container(
      margin: EdgeInsets.all(8),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF00d4ff),
                      Color(0xFF0099cc),
                    ],
                  ),
                ),
              ),
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
                child: ClipOval(
                  child: user.avatarUrl != null
                      ? Image.network(
                          user.avatarUrl!,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          errorBuilder: (context, error, stackTrace) => 
                            Icon(Icons.person, size: 30, color: Colors.white),
                        )
                      : Image.network(
                          user.defaultEmoji,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          errorBuilder: (context, error, stackTrace) => 
                            Icon(Icons.person, size: 30, color: Colors.white),
                        ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: user.inGame ? Colors.orange : Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          SizedBox(
            width: 90,
            child: Column(
              children: [
                Text(
                  _truncateName(user.username),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrid(List<Player> users) {
    // Même implémentation que précédemment
    final usersToDisplay = _filterUsers(users);

    if (usersToDisplay.isEmpty) {
      return Center(
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
                Icons.people_outline,
                color: Color(0xFFe040fb),
                size: 40,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'AUCUN JOUEUR DISPONIBLE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: usersToDisplay.length,
      itemBuilder: (context, index) {
        final user = usersToDisplay[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              _showUserProfile(user);
            },
            child: _buildUserAvatar(user),
          ),
        );
      },
    );
  }

  String _truncateName(String name) {
    if (name.length <= 15) return name;
    return '${name.substring(0, 14)}..';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0a0015),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, 40, 16, 10),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'JOUEURS EN LIGNE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              StreamBuilder<List<Player>>(
                                stream: _onlineUsersStream,
                                builder: (context, snapshot) {
                                  final onlineCount = snapshot.data?.length ?? 0;
                                  final inGameCount = snapshot.data?.where((user) => user.inGame).length ?? 0;
                                  
                                  return Text(
                                    '$onlineCount joueurs connectés • $inGameCount en match',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
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
                            icon: Icon(Icons.refresh, color: Colors.white, size: 20),
                            onPressed: () {
                              setState(() {
                                _loadOnlineUsers();
                                _loadMatchRequests();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    _buildSearchBar(),
                  ],
                ),
              ],
            ),
          ),
          
          StreamBuilder<List<Player>>(
            stream: _onlineUsersStream,
            builder: (context, snapshot) {
              // Même implémentation que précédemment pour le StreamBuilder principal
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00d4ff)),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                // Gestion d'erreur inchangée
                return Expanded(
                  child: Center(
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
                                Color(0xFF2d0052),
                                Color(0xFF1a0033),
                              ],
                            ),
                            border: Border.all(
                              color: Color(0xFFff006e),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFff006e).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFff006e),
                            size: 50,
                          ),
                        ),
                        SizedBox(height: 25),
                        Text(
                          'ERREUR DE CONNEXION',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final users = snapshot.data ?? [];
              final filteredUsers = _filterUsers(users);

              if (users.isEmpty) {
                return Expanded(
                  child: Center(
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
                            Icons.people_outline,
                            color: Color(0xFFe040fb),
                            size: 40,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'AUCUN JOUEUR EN LIGNE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Expanded(
                child: Column(
                  children: [
                    _buildSearchResultsInfo(filteredUsers),
                    Expanded(
                      child: filteredUsers.isEmpty && _searchQuery.isNotEmpty
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
                                      Icons.search_off,
                                      color: Color(0xFFe040fb),
                                      size: 40,
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    'AUCUN JOUEUR TROUVÉ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildUserGrid(users),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
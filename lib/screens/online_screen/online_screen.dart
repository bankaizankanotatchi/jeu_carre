// screens/online_users_screen.dart
import 'package:flutter/material.dart';
import 'package:jeu_carre/screens/game_mode_screen/game_mode_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/screens/profil_adversaire/profil_adversaire.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadOnlineUsers();
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
          .where((player) => player.id != _getCurrentUserId()) // Filtre côté client
          .toList());
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

  Widget _buildSearchBar() {
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
    return Container(
      margin: EdgeInsets.all(8),
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
                      Color(0xFF00d4ff),
                      Color(0xFF0099cc),
                    ],
                  ),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2d0052),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF00d4ff).withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user.displayAvatar,
                    style: TextStyle(fontSize: 24),
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
  final usersToDisplay = _filterUsers(users);

  // Cette condition ne devrait plus être nécessaire car gérée dans le StreamBuilder
  // Mais on la garde pour sécurité
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
  void _showUserProfile(Player user) {
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
                        color: Color(0xFF2d0052),
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          user.displayAvatar,
                          style: TextStyle(fontSize: 30),
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
                
                if (user.inGame) ...[
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.sports_esports, color: Colors.orange, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ce joueur est actuellement en partie.\nRevenez plus tard pour le défier !',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                SizedBox(height: 20),
                
                if (user.inGame) 
                  _buildProfileActionButton('PROFIL', Icons.person, Color(0xFFe040fb), user, true)
                else 
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildProfileActionButton('DÉFIER', Icons.sports_esports, Color(0xFF00d4ff), user, false),
                      _buildProfileActionButton('PROFIL', Icons.person, Color(0xFFe040fb), user, false),
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
  }

  Widget _buildProfileActionButton(String text, IconData icon, Color color, Player user, bool isInGame) {
    return Container(
      width: isInGame ? 200 : 120,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            Navigator.of(context).pop(); // Fermer le dialog
            if (text == 'DÉFIER') {
              _challengeUser(user);
            } else if (text == 'PROFIL') {
              _viewUserProfile(user);
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isInGame ? 14 : 12,
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
    
    // Redirige vers le screen de configuration pour un match en ligne
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameSetupScreen(
          isAgainstAI: false,
          isOnlineMatch: true,
          opponent: user, // Passer l'adversaire
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
  // DEBUG: Afficher l'erreur complète dans la console
  print('ERREUR OnlineUsersScreen: ${snapshot.error}');
  print('Type d\'erreur: ${snapshot.error.runtimeType}');
  print('Stack trace: ${snapshot.stackTrace}');

  String errorMessage = 'Problème de connexion';
  String errorDetail = 'Vérifiez votre connexion Internet';
  
  final errorString = snapshot.error.toString();
  
  // Diagnostic de l'erreur avec plus de cas
  if (errorString.contains('Firebase') || errorString.contains('firebase')) {
    errorMessage = 'ERREUR FIREBASE';
    errorDetail = 'Problème avec le serveur';
  } else if (errorString.contains('Network') || errorString.contains('network') || errorString.contains('socket') || errorString.contains('Internet')) {
    errorMessage = 'HORS LIGNE';
    errorDetail = 'Connexion Internet requise';
  } else if (errorString.contains('permission') || errorString.contains('Permission') || errorString.contains('access')) {
    errorMessage = 'ACCÈS REFUSÉ';
    errorDetail = 'Permissions insuffisantes';
  } else if (errorString.contains('timeout') || errorString.contains('Timeout')) {
    errorMessage = 'TIMEOUT';
    errorDetail = 'La connexion a expiré';
  } else if (errorString.contains('host') || errorString.contains('Host')) {
    errorMessage = 'HOST INACCESSIBLE';
    errorDetail = 'Serveur non disponible';
  }

  // Afficher aussi l'erreur exacte dans l'UI pour debug
  errorDetail += '\n\n(Erreur: ${errorString.length > 50 ? errorString.substring(0, 50) + '...' : errorString})';

    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône d'erreur
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
            
            // Message d'erreur
            Text(
              errorMessage,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            
            SizedBox(height: 12),
            
            // Détail de l'erreur
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                errorDetail,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
            ),
            
            SizedBox(height: 30),
            
            // Bouton retour
            Container(
              width: 160,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Color(0xFF00d4ff),
                  width: 2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => Navigator.pop(context),
                  child: Center(
                    child: Text(
                      'RETOUR',
                      style: TextStyle(
                        color: Color(0xFF00d4ff),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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

    final users = snapshot.data ?? [];
    final filteredUsers = _filterUsers(users);

    // AFFICHER "AUCUN JOUEUR" SI LA LISTE EST VIDE
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
              SizedBox(height: 12),
              Text(
                'Revenez plus tard pour trouver des adversaires',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
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
                        SizedBox(height: 12),
                        Text(
                          'Aucun résultat pour "$_searchQuery"',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 20),
                        Container(
                          width: 200,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFe040fb), Color(0xFF9c27b0)],
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: _clearSearch,
                              child: Center(
                                child: Text(
                                  'EFFACER LA RECHERCHE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
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
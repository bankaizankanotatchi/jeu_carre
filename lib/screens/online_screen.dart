import 'package:flutter/material.dart';

class OnlineUsersScreen extends StatefulWidget {
  const OnlineUsersScreen({super.key});

  @override
  State<OnlineUsersScreen> createState() => _OnlineUsersScreenState();
}

class _OnlineUsersScreenState extends State<OnlineUsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Données fictives pour les utilisateurs en ligne
  final List<Map<String, dynamic>> _onlineUsers = [
    {
      'id': '1',
      'username': 'AlexPro',
      'avatar': '🥇',
      'score': 2450,
      'status': 'en_ligne',
      'lastSeen': DateTime.now(),
      'inGame': false,
    },
    {
      'id': '2',
      'username': 'SarahShik',
      'avatar': '🥈',
      'score': 2380,
      'status': 'en_ligne',
      'lastSeen': DateTime.now(),
      'inGame': true,
    },
    {
      'id': '3',
      'username': 'MikeMaster',
      'avatar': '🥉',
      'score': 2310,
      'status': 'en_ligne',
      'lastSeen': DateTime.now(),
      'inGame': false,
    },
    {
      'id': '4',
      'username': 'LunaPlay',
      'avatar': '👑',
      'score': 2250,
      'status': 'en_ligne',
      'lastSeen': DateTime.now(),
      'inGame': true,
    },
    {
      'id': '5',
      'username': 'TomStrategy',
      'avatar': '⚡',
      'score': 2190,
      'status': 'en_ligne',
      'lastSeen': DateTime.now(),
      'inGame': false,
    },
    {
      'id': '6',
      'username': 'ProPlayerX',
      'avatar': '🔥',
      'score': 2150,
      'status': 'en_ligne',
      'lastSeen': DateTime.now(),
      'inGame': true,
    },
    {
      'id': '7',
      'username': 'ShikakuQueen',
      'avatar': '🌟',
      'score': 2100,
      'status': 'en_ligne',
      'lastSeen': DateTime.now(),
      'inGame': false,
    },
    {
      'id': '8',
      'username': 'GridMaster',
      'avatar': '🎯',
      'score': 2050,
      'status': 'en_ligne',
      'lastSeen': DateTime.now(),
      'inGame': false,
    },
    {
      'id': '9',
      'username': 'BrainStorm',
      'avatar': '💡',
      'score': 2000,
      'status': 'en_ligne',
      'lastSeen': DateTime.now(),
      'inGame': false,
    },
    {
      'id': '10',
      'username': 'LogicLegend',
      'avatar': '🧠',
      'score': 1950,
      'status': 'en_ligne',
      'lastSeen': DateTime.now(),
      'inGame': false,
    },
    {
      'id': '11',
      'username': 'UltimateGamer',
      'avatar': '🎮',
      'score': 1900,
      'status': 'en_ligne',
      'lastSeen': DateTime.now(),
      'inGame': false,
    },
    {
      'id': '12',
      'username': 'StrategyKing',
      'avatar': '♔',
      'score': 1850,
      'status': 'en_ligne',
      'lastSeen': DateTime.now(),
      'inGame': false,
    },
  ];

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _onlineUsers;
    }
    return _onlineUsers.where((user) {
      final username = user['username'].toString().toLowerCase();
      return username.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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

  Widget _buildSearchResultsInfo() {
    if (_searchQuery.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_filteredUsers.length} résultat${_filteredUsers.length > 1 ? 's' : ''} trouvé${_filteredUsers.length > 1 ? 's' : ''}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_filteredUsers.isEmpty)
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

  Widget _buildUserAvatar(Map<String, dynamic> user) {
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
                    user['avatar'],
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
                    color: user['inGame'] ? Colors.orange : Colors.green,
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
                  _truncateName(user['username']),
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

  Widget _buildUserGrid() {
    final usersToDisplay = _filteredUsers;

    if (usersToDisplay.isEmpty && _searchQuery.isNotEmpty) {
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

  void _showUserProfile(Map<String, dynamic> user) {
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
                          user['avatar'],
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
                          color: user['inGame'] ? Colors.orange : Colors.green,
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
                  user['username'],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '${user['score']} points',
                  style: TextStyle(
                    color: Color(0xFF00d4ff),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                
                if (user['inGame']) ...[
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
                
                if (user['inGame']) 
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

  Widget _buildProfileActionButton(String text, IconData icon, Color color, Map<String, dynamic> user, bool isInGame) {
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

  void _challengeUser(Map<String, dynamic> user) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Défi envoyé à ${user['username']} !'),
        backgroundColor: Color(0xFF00d4ff),
      ),
    );
  }

  void _viewUserProfile(Map<String, dynamic> user) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profil de ${user['username']}'),
        backgroundColor: Color(0xFFe040fb),
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
                              Text(
                                '${_onlineUsers.length} joueurs connectés • ${_onlineUsers.where((user) => user['inGame']).length} en match',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
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
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildSearchBar(),
                  ],
                ),
              ],
            ),
          ),
          
          _buildSearchResultsInfo(),
          
          Expanded(
            child: _filteredUsers.isEmpty && _searchQuery.isEmpty
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
                  )
                : _buildUserGrid(),
          ),
        ],
      ),
    );
  }
}
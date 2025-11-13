// ============================================
// MODÈLE UTILISATEUR
// ============================================
class Player {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;      // URL de l'image avatar (prioritaire)
  final String defaultEmoji;    // Emoji par défaut si pas d'image (ex: '🎮')
  final UserRole role;
  final int totalPoints;        // Total des carrés réalisés dans tous les jeux
  final int gamesPlayed;
  final int gamesWon;           // Nombre de victoires
  final int gamesLost;          // Nombre de défaites
  final int gamesDraw;          // Nombre de matchs nuls
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final UserStats stats;
  final bool isActive;
    // PROPRIÉTÉS CONSERVÉES (essentielles pour le frontend)
  final bool isOnline;          // Pour OnlineUsersScreen
  final bool inGame;           // Pour voir qui est en jeu
  final String? currentGameId; // Pour rejoindre une partie
  final List<String> achievements; // Pour ProfileScreen
  final String statusMessage;  // Optionnel pour le profil

  Player({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.defaultEmoji = '🎮',
    required this.role,
    this.totalPoints = 0,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.gamesLost = 0,
    this.gamesDraw = 0,
    required this.createdAt,
    required this.lastLoginAt,
    required this.stats,
    this.isActive = true,
   // Propriétés conservées
    this.isOnline = false,
    this.inGame = false,
    this.currentGameId,
    List<String>? achievements,
    this.statusMessage = '',
  }) : achievements = achievements ?? [];

  // Avatar à afficher (image prioritaire, sinon emoji)
  String get displayAvatar => avatarUrl ?? defaultEmoji;
  
  // Vérifier si l'utilisateur a une image avatar
  bool get hasAvatarImage => avatarUrl != null && avatarUrl!.isNotEmpty;

  // Calculer le taux de victoire
  double get winRate => gamesPlayed > 0 ? (gamesWon / gamesPlayed) * 100 : 0.0;
  
  // Calculer le taux de défaite
  double get lossRate => gamesPlayed > 0 ? (gamesLost / gamesPlayed) * 100 : 0.0;
  
  // Calculer le taux de match nul
  double get drawRate => gamesPlayed > 0 ? (gamesDraw / gamesPlayed) * 100 : 0.0;

  // Moyenne de points par partie
  double get averagePointsPerGame => gamesPlayed > 0 ? totalPoints / gamesPlayed : 0.0;

  // Vérifier si c'est un admin
  bool get isAdmin => role == UserRole.admin;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatarUrl': avatarUrl,
      'defaultEmoji': defaultEmoji,
      'role': role.toString(),
      'totalPoints': totalPoints,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'gamesLost': gamesLost,
      'gamesDraw': gamesDraw,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLoginAt': lastLoginAt.millisecondsSinceEpoch,
      'stats': stats.toMap(),
      'isActive': isActive,
      // Nouvelles propriétés conservées
      'isOnline': isOnline,
      'inGame': inGame,
      'currentGameId': currentGameId,
      'achievements': achievements,
      'statusMessage': statusMessage,
    };
  }

  static Player fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      avatarUrl: map['avatarUrl'],
      defaultEmoji: map['defaultEmoji'] ?? '🎮',
      role: UserRole.values.firstWhere((e) => e.toString() == map['role']),
      totalPoints: map['totalPoints'] ?? 0,
      gamesPlayed: map['gamesPlayed'] ?? 0,
      gamesWon: map['gamesWon'] ?? 0,
      gamesLost: map['gamesLost'] ?? 0,
      gamesDraw: map['gamesDraw'] ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      lastLoginAt: DateTime.fromMillisecondsSinceEpoch(map['lastLoginAt']),
      stats: UserStats.fromMap(map['stats']),
      isActive: map['isActive'] ?? true,
      // Nouvelles propriétés conservées
      isOnline: map['isOnline'] ?? false,
      inGame: map['inGame'] ?? false,
      currentGameId: map['currentGameId'],
      achievements: List<String>.from(map['achievements'] ?? []),
      statusMessage: map['statusMessage'] ?? '',
    );
  }

  // Créer une copie avec des modifications
  Player copyWith({
    String? username,
    String? email,
    String? avatarUrl,
    String? defaultEmoji,
    UserRole? role,
    int? totalPoints,
    int? gamesPlayed,
    int? gamesWon,
    int? gamesLost,
    int? gamesDraw,
    DateTime? lastLoginAt,
    UserStats? stats,
    bool? isActive,
  }) {
    return Player(
      id: this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      defaultEmoji: defaultEmoji ?? this.defaultEmoji,
      role: role ?? this.role,
      totalPoints: totalPoints ?? this.totalPoints,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      gamesLost: gamesLost ?? this.gamesLost,
      gamesDraw: gamesDraw ?? this.gamesDraw,
      createdAt: this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      stats: stats ?? this.stats,
      isActive: isActive ?? this.isActive,
  ) ;
  }
  // Créer un joueur à partir d'infos de base pour les notifications de messages
factory Player.fromBasicInfo({
  required String id,
  required String username,
  String? avatarUrl,
  String defaultEmoji = '👤',
  String? email,
  required createdAt,
}) {
  final now = DateTime.now();
  return Player(
    id: id,
    username: username,
    email: email ?? '',
    avatarUrl: avatarUrl,
    defaultEmoji: defaultEmoji,
    role: UserRole.player,
    totalPoints: 0,
    gamesPlayed: 0,
    gamesWon: 0,
    gamesLost: 0,
    gamesDraw: 0,
    createdAt: createdAt,
    lastLoginAt: now,
    stats: UserStats(),
    isActive: true,
    isOnline: false,
    inGame: false,
    currentGameId: null,
    achievements: [],
    statusMessage: '',
  );
}

}

// ============================================
// RÔLES D'UTILISATEUR
// ============================================
enum UserRole {
  player,  // Joueur normal
  admin,   // Administrateur
}

// ============================================
// STATISTIQUES UTILISATEUR
// ============================================
class UserStats {
  final int dailyPoints;        // Points du jour (carrés réalisés)
  final int weeklyPoints;       // Points de la semaine
  final int monthlyPoints;      // Points du mois
  final int bestGamePoints;     // Meilleur score en une partie
  final int winStreak;          // Série de victoires actuelles
  final int bestWinStreak;      // Meilleure série de victoires
  final Map<String, int> vsAIRecord; // {'beginner': 5, 'intermediate': 3, 'expert': 1}
  final int feedbacksSent;
  final int feedbacksLiked;     // Nombre de fois que ses feedbacks ont été aimés

  UserStats({
    this.dailyPoints = 0,
    this.weeklyPoints = 0,
    this.monthlyPoints = 0,
    this.bestGamePoints = 0,
    this.winStreak = 0,
    this.bestWinStreak = 0,
    Map<String, int>? vsAIRecord,
    this.feedbacksSent = 0,
    this.feedbacksLiked = 0,
  }) : vsAIRecord = vsAIRecord ?? {'beginner': 0, 'intermediate': 0, 'expert': 0};

  Map<String, dynamic> toMap() {
    return {
      'dailyPoints': dailyPoints,
      'weeklyPoints': weeklyPoints,
      'monthlyPoints': monthlyPoints,
      'bestGamePoints': bestGamePoints,
      'winStreak': winStreak,
      'bestWinStreak': bestWinStreak,
      'vsAIRecord': vsAIRecord,
      'feedbacksSent': feedbacksSent,
      'feedbacksLiked': feedbacksLiked,
    };
  }

  static UserStats fromMap(Map<String, dynamic> map) {
    return UserStats(
      dailyPoints: map['dailyPoints'] ?? 0,
      weeklyPoints: map['weeklyPoints'] ?? 0,
      monthlyPoints: map['monthlyPoints'] ?? 0,
      bestGamePoints: map['bestGamePoints'] ?? 0,
      winStreak: map['winStreak'] ?? 0,
      bestWinStreak: map['bestWinStreak'] ?? 0,
      vsAIRecord: Map<String, int>.from(map['vsAIRecord'] ?? {}),
      feedbacksSent: map['feedbacksSent'] ?? 0,
      feedbacksLiked: map['feedbacksLiked'] ?? 0,
    );
  }

  UserStats copyWith({
    int? dailyPoints,
    int? weeklyPoints,
    int? monthlyPoints,
    int? bestGamePoints,
    int? winStreak,
    int? bestWinStreak,
    Map<String, int>? vsAIRecord,
    int? feedbacksSent,
    int? feedbacksLiked,
  }) {
    return UserStats(
      dailyPoints: dailyPoints ?? this.dailyPoints,
      weeklyPoints: weeklyPoints ?? this.weeklyPoints,
      monthlyPoints: monthlyPoints ?? this.monthlyPoints,
      bestGamePoints: bestGamePoints ?? this.bestGamePoints,
      winStreak: winStreak ?? this.winStreak,
      bestWinStreak: bestWinStreak ?? this.bestWinStreak,
      vsAIRecord: vsAIRecord ?? this.vsAIRecord,
      feedbacksSent: feedbacksSent ?? this.feedbacksSent,
      feedbacksLiked: feedbacksLiked ?? this.feedbacksLiked,
    );
  }

  
}


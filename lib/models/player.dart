// ============================================
// MODÈLE UTILISATEUR
// ============================================
class Player {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String defaultEmoji;
  final UserRole role;
  final int totalPoints;
  final int gamesPlayed;
  final int gamesWon;
  final int gamesLost;
  final int gamesDraw;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final UserStats stats;
  final bool isActive;
  final bool isOnline;
  final bool inGame;
  final String? currentGameId;
  final String? lastProcessedGame;
  
  // NOUVELLE PROPRIÉTÉ : Messages de l'utilisateur
  final List<UserMessage> messages;

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
    this.isOnline = false,
    this.inGame = false,
    this.currentGameId,
    List<UserMessage>? messages, // NOUVEAU
     this.lastProcessedGame, 
  }) : messages = messages ?? [];

  // NOUVEAU GETTER : Vérifier si l'utilisateur peut encore envoyer des messages
  bool get canSendMessage => messages.length < 3;

  // NOUVEAU GETTER : Nombre de messages restants
  int get remainingMessages => 3 - messages.length;

  // NOUVEAU GETTER : Vérifier si l'utilisateur a des messages non répondus
  bool get hasUnansweredMessages => messages.any((message) => !message.hasResponse);

  // NOUVEAU GETTER : Dernier message envoyé
  UserMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;

  String get displayAvatar => avatarUrl ?? defaultEmoji;
  
  bool get hasAvatarImage => avatarUrl != null && avatarUrl!.isNotEmpty;

  double get winRate => gamesPlayed > 0 ? (gamesWon / gamesPlayed) * 100 : 0.0;
  
  double get lossRate => gamesPlayed > 0 ? (gamesLost / gamesPlayed) * 100 : 0.0;
  
  double get drawRate => gamesPlayed > 0 ? (gamesDraw / gamesPlayed) * 100 : 0.0;

  double get averagePointsPerGame => gamesPlayed > 0 ? totalPoints / gamesPlayed : 0.0;

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
      'isOnline': isOnline,
      'inGame': inGame,
      'currentGameId': currentGameId,
      'messages': messages.map((msg) => msg.toMap()).toList(), // NOUVEAU
       'lastProcessedGame': lastProcessedGame, 
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
      isOnline: map['isOnline'] ?? false,
      inGame: map['inGame'] ?? false,
      currentGameId: map['currentGameId'],
       lastProcessedGame: map['lastProcessedGame'],
      messages: List<UserMessage>.from( // NOUVEAU
        (map['messages'] ?? []).map((msgMap) => UserMessage.fromMap(msgMap))
        
      ),
    );
  }

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
    int? globalRank,
    DateTime? lastRankUpdate,
    List<UserMessage>? messages, // NOUVEAU
    String? lastProcessedGame, 
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
      messages: messages ?? this.messages, // NOUVEAU
       lastProcessedGame: lastProcessedGame ?? this.lastProcessedGame, 
    );
  }

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
      messages: [], // Initialisé avec une liste vide
    );
  }
}

// ============================================
// MODÈLE MESSAGE UTILISATEUR
// ============================================
class UserMessage {
  final String id;
  final FeedbackCategory category;
  final String content;
  final DateTime createdAt;
  final String? adminResponse;
  final DateTime? respondedAt;
  final bool isRead;

  UserMessage({
    required this.id,
    required this.category,
    required this.content,
    required this.createdAt,
    this.adminResponse,
    this.respondedAt,
    this.isRead = false,
  });

  bool get hasResponse => adminResponse != null && adminResponse!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category.toString(),
      'content': content,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'adminResponse': adminResponse,
      'respondedAt': respondedAt?.millisecondsSinceEpoch,
      'isRead': isRead,
    };
  }

  static UserMessage fromMap(Map<String, dynamic> map) {
    return UserMessage(
      id: map['id'] ?? '',
      category: FeedbackCategory.values.firstWhere(
        (e) => e.toString() == map['category'],
        orElse: () => FeedbackCategory.other,
      ),
      content: map['content'] ?? '',
      createdAt: map['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      adminResponse: map['adminResponse'],
      respondedAt: map['respondedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['respondedAt'])
          : null,
      isRead: map['isRead'] ?? false,
    );
  }

  UserMessage copyWith({
    String? adminResponse,
    DateTime? respondedAt,
    bool? isRead,
  }) {
    return UserMessage(
      id: this.id,
      category: this.category,
      content: this.content,
      createdAt: this.createdAt,
      adminResponse: adminResponse ?? this.adminResponse,
      respondedAt: respondedAt ?? this.respondedAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

// ============================================
// CATÉGORIES DE FEEDBACK
// ============================================
enum FeedbackCategory {
  bug,
  suggestion,
  question,
  complaint,
  compliment,
  other,
}

extension FeedbackCategoryExtension on FeedbackCategory {
  String get displayName {
    switch (this) {
      case FeedbackCategory.bug:
        return 'Bug';
      case FeedbackCategory.suggestion:
        return 'Suggestion';
      case FeedbackCategory.question:
        return 'Question';
      case FeedbackCategory.complaint:
        return 'Plainte';
      case FeedbackCategory.compliment:
        return 'Compliment';
      case FeedbackCategory.other:
        return 'Autre';
    }
  }

  String get emoji {
    switch (this) {
      case FeedbackCategory.bug:
        return '🐛';
      case FeedbackCategory.suggestion:
        return '💡';
      case FeedbackCategory.question:
        return '❓';
      case FeedbackCategory.complaint:
        return '😠';
      case FeedbackCategory.compliment:
        return '💖';
      case FeedbackCategory.other:
        return '📝';
    }
  }
}

// ============================================
// RÔLES D'UTILISATEUR
// ============================================
enum UserRole {
  player,
  admin,
}

// ============================================
// STATISTIQUES UTILISATEUR
// ============================================
class UserStats {
  final int bestGamePoints;
  final int winStreak;
  final int bestWinStreak;
  final int feedbacksSent;
  final int feedbacksLiked;

  UserStats({
    this.bestGamePoints = 0,
    this.winStreak = 0,
    this.bestWinStreak = 0,
    this.feedbacksSent = 0,
    this.feedbacksLiked = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'bestGamePoints': bestGamePoints,
      'winStreak': winStreak,
      'bestWinStreak': bestWinStreak,
      'feedbacksSent': feedbacksSent,
      'feedbacksLiked': feedbacksLiked,
    };
  }

  static UserStats fromMap(Map<String, dynamic> map) {
    return UserStats(
      bestGamePoints: map['bestGamePoints'] ?? 0,
      winStreak: map['winStreak'] ?? 0,
      bestWinStreak: map['bestWinStreak'] ?? 0,
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
      bestGamePoints: bestGamePoints ?? this.bestGamePoints,
      winStreak: winStreak ?? this.winStreak,
      bestWinStreak: bestWinStreak ?? this.bestWinStreak,
      feedbacksSent: feedbacksSent ?? this.feedbacksSent,
      feedbacksLiked: feedbacksLiked ?? this.feedbacksLiked,
    );
  }
}
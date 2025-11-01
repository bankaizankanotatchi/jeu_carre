// ============================================
// MODÈLE FEEDBACK
// ============================================
class Feedback {
  final String id;
  final String userId;          // ID de l'utilisateur qui envoie
  final String username;        // Nom de l'utilisateur (dénormalisé pour performance)
  final String? userAvatarUrl;  // URL de l'avatar de l'utilisateur
  final String userDefaultEmoji; // Emoji par défaut de l'utilisateur
  final FeedbackCategory category;
  final String message;
  final DateTime createdAt;
  
  // Interactions sociales
  final int likesCount;         // Nombre de "j'aime"
  final int dislikesCount;      // Nombre de "je n'aime pas"
  final List<String> likedBy;   // IDs des utilisateurs qui ont aimé
  final List<String> dislikedBy; // IDs des utilisateurs qui n'ont pas aimé
  
  // Réponse admin
  final String? adminResponseId; // ID de l'admin qui a répondu
  final String? adminResponse;   // Contenu de la réponse
  final DateTime? respondedAt;   // Date de la réponse
  
  // Metadata
  final bool isPublic;          // Si le feedback est visible publiquement

  Feedback({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
    this.userDefaultEmoji = '🎮',
    required this.category,
    required this.message,
    required this.createdAt,
    this.likesCount = 0,
    this.dislikesCount = 0,
    List<String>? likedBy,
    List<String>? dislikedBy,
    this.adminResponseId,
    this.adminResponse,
    this.respondedAt,
    this.isPublic = false,
  }) : likedBy = likedBy ?? [],
       dislikedBy = dislikedBy ?? [];

  // Avatar à afficher pour l'utilisateur (image prioritaire, sinon emoji)
  String get userDisplayAvatar => userAvatarUrl ?? userDefaultEmoji;
  
  // Vérifier si l'utilisateur a une image avatar
  bool get hasUserAvatarImage => userAvatarUrl != null && userAvatarUrl!.isNotEmpty;

  // Calculer le score de pertinence (likes - dislikes)
  int get relevanceScore => likesCount - dislikesCount;

  // Vérifier si un utilisateur a déjà réagi
  bool hasUserLiked(String userId) => likedBy.contains(userId);
  bool hasUserDisliked(String userId) => dislikedBy.contains(userId);

  // Vérifier si le feedback a une réponse
  bool get hasResponse => adminResponse != null && adminResponse!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
      'userDefaultEmoji': userDefaultEmoji,
      'category': category.toString(),
      'message': message,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'likesCount': likesCount,
      'dislikesCount': dislikesCount,
      'likedBy': likedBy,
      'dislikedBy': dislikedBy,
      'adminResponseId': adminResponseId,
      'adminResponse': adminResponse,
      'respondedAt': respondedAt?.millisecondsSinceEpoch,
      'isPublic': isPublic,
    };
  }

  static Feedback fromMap(Map<String, dynamic> map) {
    return Feedback(
      id: map['id'],
      userId: map['userId'],
      username: map['username'],
      userAvatarUrl: map['userAvatarUrl'],
      userDefaultEmoji: map['userDefaultEmoji'] ?? '🎮',
      category: FeedbackCategory.values.firstWhere((e) => e.toString() == map['category']),
      message: map['message'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      likesCount: map['likesCount'] ?? 0,
      dislikesCount: map['dislikesCount'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      dislikedBy: List<String>.from(map['dislikedBy'] ?? []),
      adminResponseId: map['adminResponseId'],
      adminResponse: map['adminResponse'],
      respondedAt: map['respondedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['respondedAt'])
          : null,
      isPublic: map['isPublic'] ?? false,
    );
  }

  Feedback copyWith({
    int? likesCount,
    int? dislikesCount,
    List<String>? likedBy,
    List<String>? dislikedBy,
    String? adminResponseId,
    String? adminResponse,
    DateTime? respondedAt,
    bool? isPublic,
  }) {
    return Feedback(
      id: this.id,
      userId: this.userId,
      username: this.username,
      userAvatarUrl: this.userAvatarUrl,
      userDefaultEmoji: this.userDefaultEmoji,
      category: this.category,
      message: this.message,
      createdAt: this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      dislikesCount: dislikesCount ?? this.dislikesCount,
      likedBy: likedBy ?? this.likedBy,
      dislikedBy: dislikedBy ?? this.dislikedBy,
      adminResponseId: adminResponseId ?? this.adminResponseId,
      adminResponse: adminResponse ?? this.adminResponse,
      respondedAt: respondedAt ?? this.respondedAt,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}

// ============================================
// CATÉGORIES DE FEEDBACK
// ============================================
enum FeedbackCategory {
  bug,           // Signalement de bug
  suggestion,    // Suggestion d'amélioration
  question,      // Question
  complaint,     // Plainte
  compliment,    // Compliment
  other,         // Autre
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
// MODÈLE D'INTERACTION (Like/Dislike)
// ============================================
class FeedbackInteraction {
  final String id;
  final String feedbackId;
  final String userId;
  final InteractionType type;
  final DateTime createdAt;

  FeedbackInteraction({
    required this.id,
    required this.feedbackId,
    required this.userId,
    required this.type,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'feedbackId': feedbackId,
      'userId': userId,
      'type': type.toString(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  static FeedbackInteraction fromMap(Map<String, dynamic> map) {
    return FeedbackInteraction(
      id: map['id'],
      feedbackId: map['feedbackId'],
      userId: map['userId'],
      type: InteractionType.values.firstWhere((e) => e.toString() == map['type']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }
}

enum InteractionType {
  like,
  dislike,
}
import 'package:jeu_carre/models/feedback.dart';

class Message {
  final String id;
  final String userId;
  final String username;
  final String? userAvatarUrl;
  final String userDefaultEmoji;
  final FeedbackCategory category;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  final int dislikesCount;
  final List<String> likedBy;
  final List<String> dislikedBy;
  final String? adminResponseId;
  final String? adminResponse;
  final DateTime? respondedAt;
  final bool isPublic;

  Message({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
    this.userDefaultEmoji = '🎮',
    required this.category,
    required this.content,
    required this.createdAt,
    this.likesCount = 0,
    this.dislikesCount = 0,
    List<String>? likedBy,
    List<String>? dislikedBy,
    this.adminResponseId,
    this.adminResponse,
    this.respondedAt,
    this.isPublic = true, // Par défaut public
  }) : likedBy = likedBy ?? [],
       dislikedBy = dislikedBy ?? [];

  bool get hasResponse => adminResponse != null && adminResponse!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
      'userDefaultEmoji': userDefaultEmoji,
      'category': category.toString(),
      'content': content,
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

  static Message fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'Utilisateur',
      userAvatarUrl: map['userAvatarUrl'],
      userDefaultEmoji: map['userDefaultEmoji'] ?? '🎮',
      category: FeedbackCategory.values.firstWhere(
        (e) => e.toString() == map['category'],
        orElse: () => FeedbackCategory.other,
      ),
      content: map['content'] ?? '',
      createdAt: map['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      likesCount: map['likesCount'] ?? 0,
      dislikesCount: map['dislikesCount'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      dislikedBy: List<String>.from(map['dislikedBy'] ?? []),
      adminResponseId: map['adminResponseId'],
      adminResponse: map['adminResponse'],
      respondedAt: map['respondedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['respondedAt'])
          : null,
      isPublic: map['isPublic'] ?? true,
    );
  }
}
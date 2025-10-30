// Modèle Message pour remplacer Feedback
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
    this.isPublic = false,
  }) : likedBy = likedBy ?? [],
       dislikedBy = dislikedBy ?? [];

  bool get hasResponse => adminResponse != null && adminResponse!.isNotEmpty;

  Message copyWith({
    int? likesCount,
    int? dislikesCount,
    List<String>? likedBy,
    List<String>? dislikedBy,
    String? adminResponseId,
    String? adminResponse,
    DateTime? respondedAt,
    bool? isPublic,
  }) {
    return Message(
      id: this.id,
      userId: this.userId,
      username: this.username,
      userAvatarUrl: this.userAvatarUrl,
      userDefaultEmoji: this.userDefaultEmoji,
      category: this.category,
      content: this.content,
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
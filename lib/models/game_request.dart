class MatchRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final int gridSize;
  final int gameDuration;
  final int reflexionTime;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final MatchRequestStatus status;
  final String? declinedReason;
  final DateTime? respondedAt;

  MatchRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.gridSize,
    required this.gameDuration,
    required this.reflexionTime,
    required this.createdAt,
    this.expiresAt,
    required this.status,
    this.declinedReason,
    this.respondedAt,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'gridSize': gridSize,
      'gameDuration': gameDuration,
      'reflexionTime': reflexionTime,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
      'status': status.toString(),
      'declinedReason': declinedReason,
      'respondedAt': respondedAt?.millisecondsSinceEpoch,
    };
  }

  static MatchRequest fromMap(Map<String, dynamic> map) {
    return MatchRequest(
      id: map['id'],
      fromUserId: map['fromUserId'],
      toUserId: map['toUserId'],
      gridSize: map['gridSize'],
      gameDuration: map['gameDuration'],
      reflexionTime: map['reflexionTime'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      expiresAt: map['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiresAt'])
          : null,
      status: MatchRequestStatus.values.firstWhere((e) => e.toString() == map['status']),
      declinedReason: map['declinedReason'],
      respondedAt: map['respondedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['respondedAt'])
          : null,
    );
  }
}

enum MatchRequestStatus {
  pending,
  accepted,
  declined,
  expired,
  cancelled,
}
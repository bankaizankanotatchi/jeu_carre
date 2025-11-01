import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference get notificationsCollection => 
      _firestore.collection('notifications');

  /// Envoyer une notification
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await notificationsCollection.add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'data': data ?? {},
        'isRead': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Erreur envoi notification: $e');
    }
  }

  /// Envoyer une notification de défi
  static Future<void> sendMatchChallengeNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUsername,
    required int gridSize,
  }) async {
    await sendNotification(
      userId: toUserId,
      title: 'Nouveau défi !',
      message: '$fromUsername vous a défié sur une grille ${gridSize}×$gridSize',
      type: 'match_challenge',
      data: {
        'fromUserId': fromUserId,
        'fromUsername': fromUsername,
        'gridSize': gridSize,
      },
    );
  }

  /// Récupérer les notifications de l'utilisateur
  static Stream<List<Map<String, dynamic>>> getUserNotifications() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return notificationsCollection
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                })
            .toList());
  }

  /// Marquer une notification comme lue
  static Future<void> markAsRead(String notificationId) async {
    try {
      await notificationsCollection.doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('Erreur marquer notification lue: $e');
    }
  }
}
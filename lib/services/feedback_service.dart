import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeu_carre/models/feedback.dart';
import 'package:jeu_carre/models/message.dart';

class FeedbackService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collections
  static final CollectionReference _messagesCollection = 
      _firestore.collection('messages');
  static final CollectionReference _interactionsCollection = 
      _firestore.collection('feedback_interactions');
  static final CollectionReference _usersCollection = 
      _firestore.collection('users');

  // ============================================
  // CRUD FEEDBACKS
  // ============================================

// Créer un nouveau feedback
static Future<Message> createFeedback({
  required FeedbackCategory category,
  required String content,
  bool isPublic = false,
}) async {
  try {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    // Récupérer les infos utilisateur
    final userDoc = await _usersCollection.doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;

    // Vérifier si l'utilisateur est admin
    final isAdmin = await isUserAdmin();

    final messageId = _messagesCollection.doc().id;
    final newMessage = Message(
      id: messageId,
      userId: user.uid,
      username: userData?['username'] ?? 'Utilisateur',
      userAvatarUrl: userData?['avatarUrl'],
      userDefaultEmoji: userData?['defaultEmoji'] ?? '🎮',
      category: category,
      content: content,
      createdAt: DateTime.now(),
      isPublic: isPublic,
      isAdminMessage: isAdmin, // SIMPLE : si admin, alors true
    );

    await _messagesCollection.doc(messageId).set(newMessage.toMap());

    return newMessage;
  } catch (e) {
    print('Erreur création feedback: $e');
    rethrow;
  }
}
  // Récupérer tous les messages publics avec pagination
  static Stream<List<Message>> getPublicMessages({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) {
    try {
      Query query = _messagesCollection
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          try {
            return Message.fromMap(doc.data() as Map<String, dynamic>);
          } catch (e) {
            print('Erreur parsing message ${doc.id}: $e');
            rethrow;
          }
        }).toList();
      });
    } catch (e) {
      print('Erreur récupération messages: $e');
      rethrow;
    }
  }

  // Récupérer les messages d'un utilisateur
  static Stream<List<Message>> getUserMessages(String userId) {
    return _messagesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Message.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();
        });
  }

  // Mettre à jour un message (admin response)
  static Future<void> updateMessageAdminResponse({
    required String messageId,
    required String adminResponse,
    required String adminId,
  }) async {
    try {
      // Vérifier que l'utilisateur est admin
      if (!await isUserAdmin()) {
        throw Exception('Accès admin requis');
      }

      await _messagesCollection.doc(messageId).update({
        'adminResponse': adminResponse,
        'adminResponseId': adminId,
        'respondedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Erreur mise à jour réponse admin: $e');
      rethrow;
    }
  }

  // Supprimer un message
  static Future<void> deleteMessage(String messageId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final messageDoc = await _messagesCollection.doc(messageId).get();
      final messageData = messageDoc.data() as Map<String, dynamic>?;

      if (messageData == null) {
        throw Exception('Message non trouvé');
      }

      // Vérifier que l'utilisateur est le propriétaire ou un admin
      if (messageData['userId'] != user.uid) {
        if (!await isUserAdmin()) {
          throw Exception('Non autorisé à supprimer ce message');
        }
      }

      await _messagesCollection.doc(messageId).delete();

      // Supprimer aussi les interactions associées
      final interactions = await _interactionsCollection
          .where('feedbackId', isEqualTo: messageId)
          .get();
      
      for (final doc in interactions.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Erreur suppression message: $e');
      rethrow;
    }
  }

  // ============================================
  // INTERACTIONS ULTRA-RAPIDES (Likes/Dislikes)
  // ============================================

  // NOUVELLE VERSION OPTIMISÉE - BEAUCOUP PLUS RAPIDE
  static Future<void> toggleInteraction({
    required String messageId,
    required InteractionType type,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final interactionId = '${messageId}_${user.uid}';
      final interactionRef = _interactionsCollection.doc(interactionId);

      // Utiliser une transaction pour tout gérer en une opération atomique
      await _firestore.runTransaction((transaction) async {
        // 1. Vérifier l'interaction existante
        final interactionDoc = await transaction.get(interactionRef);
        
        if (interactionDoc.exists) {
          final existingData = interactionDoc.data() as Map<String, dynamic>;
          final existingType = InteractionType.values
              .firstWhere((e) => e.toString() == existingData['type']);

          // Même type = supprimer l'interaction
          if (existingType == type) {
            transaction.delete(interactionRef);
            _updateCounter(transaction, messageId, type, -1);
          } 
          // Type différent = remplacer l'interaction
          else {
            transaction.update(interactionRef, {
              'type': type.toString(),
              'createdAt': DateTime.now().millisecondsSinceEpoch,
            });
            _updateCounter(transaction, messageId, existingType, -1);
            _updateCounter(transaction, messageId, type, 1);
          }
        } 
        // Nouvelle interaction = créer
        else {
          transaction.set(interactionRef, {
            'id': interactionId,
            'feedbackId': messageId,
            'userId': user.uid,
            'type': type.toString(),
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });
          _updateCounter(transaction, messageId, type, 1);
        }
      });

    } catch (e) {
      print('Erreur interaction: $e');
      rethrow;
    }
  }

  // Helper pour mettre à jour les compteurs avec FieldValue.increment (TRÈS RAPIDE)
  static void _updateCounter(
    Transaction transaction,
    String messageId,
    InteractionType type,
    int change,
  ) {
    final messageRef = _messagesCollection.doc(messageId);
    final field = type == InteractionType.like ? 'likesCount' : 'dislikesCount';
    transaction.update(messageRef, {
      field: FieldValue.increment(change),
    });
  }

  // Vérifier l'état d'interaction d'un utilisateur
  static Future<InteractionType?> getUserInteraction(String messageId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final interactionId = '${messageId}_${user.uid}';
      final interactionDoc = await _interactionsCollection.doc(interactionId).get();

      if (interactionDoc.exists) {
        final data = interactionDoc.data() as Map<String, dynamic>;
        return InteractionType.values
            .firstWhere((e) => e.toString() == data['type']);
      }

      return null;
    } catch (e) {
      print('Erreur vérification interaction: $e');
      return null;
    }
  }

  // ============================================
  // STATISTIQUES
  // ============================================

  // Récupérer les statistiques des feedbacks
  static Future<Map<String, dynamic>> getFeedbackStats() async {
    try {
      final messagesSnapshot = await _messagesCollection.get();
      final interactionsSnapshot = await _interactionsCollection.get();

      int totalMessages = messagesSnapshot.size;
      int totalResponses = 0;
      int totalLikes = 0;
      int totalDislikes = 0;
      Map<FeedbackCategory, int> categoryCounts = {};

      for (final doc in messagesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Compter les réponses admin
        if (data['adminResponse'] != null && data['adminResponse'].toString().isNotEmpty) {
          totalResponses++;
        }

        // Compter les likes/dislikes
        totalLikes += (data['likesCount'] as num? ?? 0).toInt();
        totalDislikes += (data['dislikesCount'] as num? ?? 0).toInt();

        // Compter par catégorie
        try {
          final categoryString = data['category'];
          final category = FeedbackCategory.values
              .firstWhere((e) => e.toString() == categoryString);
          categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
        } catch (e) {
          print('Erreur parsing catégorie: $e');
        }
      }

      return {
        'totalMessages': totalMessages,
        'totalResponses': totalResponses,
        'responseRate': totalMessages > 0 ? (totalResponses / totalMessages) * 100 : 0,
        'totalLikes': totalLikes,
        'totalDislikes': totalDislikes,
        'categoryCounts': categoryCounts,
        'totalInteractions': interactionsSnapshot.size,
      };
    } catch (e) {
      print('Erreur statistiques: $e');
      rethrow;
    }
  }

  // Récupérer les messages les plus populaires
  static Stream<List<Message>> getPopularMessages({int limit = 10}) {
    return _messagesCollection
        .where('isPublic', isEqualTo: true)
        .orderBy('likesCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Message.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();
        });
  }

  // ============================================
  // FONCTIONS ADMIN
  // ============================================

  // Vérifier si l'utilisateur est admin
  static Future<bool> isUserAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _usersCollection.doc(user.uid).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data() as Map<String, dynamic>?;
      final roleString = userData?['role'];
      
      // Vérifier si le rôle est admin
      return roleString == 'UserRole.admin';
    } catch (e) {
      print('Erreur vérification admin: $e');
      return false;
    }
  }

  // Récupérer tous les messages (admin seulement)
  static Stream<List<Message>> getAllMessages({bool includePrivate = false}) {
    Query query = _messagesCollection.orderBy('createdAt', descending: true);

    if (!includePrivate) {
      query = query.where('isPublic', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Message.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Marquer un message comme public/privé
  static Future<void> toggleMessageVisibility(String messageId, bool isPublic) async {
    try {
      if (!await isUserAdmin()) {
        throw Exception('Accès admin requis');
      }

      await _messagesCollection.doc(messageId).update({
        'isPublic': isPublic,
      });
    } catch (e) {
      print('Erreur changement visibilité: $e');
      rethrow;
    }
  }
}

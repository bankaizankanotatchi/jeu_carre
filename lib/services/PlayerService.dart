import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeu_carre/models/player.dart';

class PlayerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static final CollectionReference _playersCollection = 
      _firestore.collection('users');

  // ============================================
  // GESTION DES MESSAGES
  // ============================================

  // Ajouter un message à l'utilisateur
  static Future<void> addUserMessage({
    required FeedbackCategory category,
    required String content,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // Récupérer le joueur actuel
      final playerDoc = await _playersCollection.doc(user.uid).get();
      if (!playerDoc.exists) throw Exception('Joueur non trouvé');

      final playerData = playerDoc.data() as Map<String, dynamic>;
      final player = Player.fromMap(playerData);

      // Vérifier que l'utilisateur peut encore envoyer des messages
      if (!player.canSendMessage) {
        throw Exception('Vous avez atteint la limite de 3 messages');
      }

      // Créer le nouveau message
      final newMessage = UserMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        category: category,
        content: content,
        createdAt: DateTime.now(),
      );

      // Ajouter le message à la liste
      final updatedMessages = [...player.messages, newMessage];

      // Mettre à jour le joueur
      await _playersCollection.doc(user.uid).update({
        'messages': updatedMessages.map((msg) => msg.toMap()).toList(),
      });

    } catch (e) {
      print('Erreur ajout message: $e');
      rethrow;
    }
  }

  // Répondre à un message (admin seulement)
  static Future<void> respondToMessage({
    required String playerId,
    required String messageId,
    required String adminResponse,
  }) async {
    try {
      // Vérifier que l'utilisateur est admin
      if (!await isUserAdmin()) {
        throw Exception('Accès admin requis');
      }

      final playerDoc = await _playersCollection.doc(playerId).get();
      if (!playerDoc.exists) throw Exception('Joueur non trouvé');

      final playerData = playerDoc.data() as Map<String, dynamic>;
      final player = Player.fromMap(playerData);

      // Trouver et mettre à jour le message
      final updatedMessages = player.messages.map((message) {
        if (message.id == messageId) {
          return message.copyWith(
            adminResponse: adminResponse,
            respondedAt: DateTime.now(),
          );
        }
        return message;
      }).toList();

      // Mettre à jour le joueur
      await _playersCollection.doc(playerId).update({
        'messages': updatedMessages.map((msg) => msg.toMap()).toList(),
      });

    } catch (e) {
      print('Erreur réponse admin: $e');
      rethrow;
    }
  }

  // Supprimer un message
  static Future<void> deleteUserMessage(String messageId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final playerDoc = await _playersCollection.doc(user.uid).get();
      if (!playerDoc.exists) throw Exception('Joueur non trouvé');

      final playerData = playerDoc.data() as Map<String, dynamic>;
      final player = Player.fromMap(playerData);

      // Filtrer la liste pour supprimer le message
      final updatedMessages = player.messages
          .where((message) => message.id != messageId)
          .toList();

      // Mettre à jour le joueur
      await _playersCollection.doc(user.uid).update({
        'messages': updatedMessages.map((msg) => msg.toMap()).toList(),
      });

    } catch (e) {
      print('Erreur suppression message: $e');
      rethrow;
    }
  }

  // Récupérer le joueur actuel avec ses messages
  static Stream<Player> getCurrentPlayerStream() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    return _playersCollection.doc(user.uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw Exception('Joueur non trouvé');
      }
      return Player.fromMap(snapshot.data() as Map<String, dynamic>);
    });
  }

  // Récupérer tous les joueurs avec messages (admin seulement)
  static Stream<List<Player>> getAllPlayersWithMessages() {
    return _playersCollection
        .where('messages', isNotEqualTo: []) // Seulement ceux avec des messages
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Player.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();
        });
  }

  // ============================================
  // FONCTIONS ADMIN
  // ============================================

  static Future<bool> isUserAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _playersCollection.doc(user.uid).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data() as Map<String, dynamic>?;
      final roleString = userData?['role'];
      
      return roleString == 'UserRole.admin';
    } catch (e) {
      return false;
    }
  }
}
// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:jeu_carre/models/player.dart';
// import 'package:jeu_carre/widgets/match_request_declined_notification.dart';

// class MatchNotificationDeclinedService {
//   static final MatchNotificationDeclinedService _instance = MatchNotificationDeclinedService._internal();
//   factory MatchNotificationDeclinedService() => _instance;
//   MatchNotificationDeclinedService._internal();

//   OverlayEntry? _overlayEntry;
//   StreamSubscription? _matchRequestsSubscription;
//   BuildContext? _context;
//   String? _currentUserId;

//   final CollectionReference _matchRequestsCollection = FirebaseFirestore.instance.collection('match_requests');
//   final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');

//   String? _lastShownRequestId;
//   final Set<String> _processedRequests = {};

//   void initialize(BuildContext context) {
//     _context = context;
//     _currentUserId = FirebaseAuth.instance.currentUser?.uid;
//     //_startListening();
//   }

//   // Future<void> _startListening() async {
//   //   if (_currentUserId == null) {
//   //     print('❌ UserID null - impossible de démarrer l écoute');
//   //     return;
//   //   }

//   //   print('🎯 Écoute des matchs REFUSÉS pour l utilisateur qui a ENVOYÉ la demande: $_currentUserId');

//   //   _matchRequestsSubscription?.cancel();
    
//   //   _matchRequestsSubscription = _matchRequestsCollection
//   //       .where('fromUserId', isEqualTo: _currentUserId)
//   //       .snapshots()
//   //       .listen((snapshot) {
      
//   //     print('📡 SNAPSHOT COMPLET - ${snapshot.docs.length} documents trouvés');
      
//   //     // Debug: afficher tous les documents
//   //     for (final doc in snapshot.docs) {
//   //       final data = doc.data() as Map<String, dynamic>;
//   //       print('📄 Document ${doc.id}: status=${data['status']}, respondedAt=${data['respondedAt']}');
//   //     }
      
//   //     print('📡 CHANGEMENTS DÉTECTÉS - ${snapshot.docChanges.length} changements');
      
//   //     for (final change in snapshot.docChanges) {
//   //       if (change.type == DocumentChangeType.modified || change.type == DocumentChangeType.added) {
//   //         final requestData = change.doc.data() as Map<String, dynamic>;
//   //         final requestId = change.doc.id;
//   //         final status = requestData['status']?.toString() ?? '';
//   //         final respondedAt = requestData['respondedAt'];
          
//   //         print('🔄 Changement ${change.type} - Document: $requestId, Status: $status');
          
//   //         // ✅ CORRECTION : Vérifier si le statut contient "declined" (peu importe le format)
//   //         if (_isDeclinedStatus(status) && respondedAt != null) {
//   //           final isRecent = _isRecentNotification(respondedAt);
//   //           print('🔴 MATCH REFUSÉ DÉTECTÉ - Récent: $isRecent');
            
//   //           if (isRecent && !_processedRequests.contains(requestId)) {
//   //             _handleDeclinedMatchRequest(requestData, requestId);
//   //           }
//   //         }
//   //       }
//   //     }
//   //   }, onError: (error) {
//   //     print('❌ Erreur écoute matchs refusés: $error');
//   //   });
//   // }

//   /// Vérifie si le statut correspond à un match refusé (gère différents formats)
//   bool _isDeclinedStatus(String status) {
//     return status.toLowerCase().contains('declined');
//   }

//   bool _isRecentNotification(int respondedAtMillis) {
//     final respondedAt = DateTime.fromMillisecondsSinceEpoch(respondedAtMillis);
//     final isRecent = DateTime.now().difference(respondedAt).inSeconds < 30;
//     return isRecent;
//   }

//   void _handleDeclinedMatchRequest(Map<String, dynamic> requestData, String requestId) async {
//     try {
//       print('🔄 Traitement demande refusée: $requestId');
      
//       // Marquer comme traitée
//       _processedRequests.add(requestId);
//       _lastShownRequestId = requestId;

//       // Nettoyer les anciennes requêtes traitées
//       if (_processedRequests.length > 100) {
//         _processedRequests.clear();
//       }

//       // Récupérer les infos du joueur qui a REFUSÉ (toUserId)
//       final toUserId = requestData['toUserId'];
//       if (toUserId == null) {
//         print('❌ toUserId manquant');
//         return;
//       }

//       print('🔍 Récupération infos du joueur qui a refusé: $toUserId');
//       final userDoc = await _usersCollection.doc(toUserId).get();
      
//       if (!userDoc.exists) {
//         print('❌ Utilisateur $toUserId non trouvé');
//         return;
//       }

//       final userData = userDoc.data() as Map<String, dynamic>?;
//       final playerWhoDeclined = Player.fromBasicInfo(
//         id: toUserId,
//         username: userData?['username'] ?? 'Utilisateur',
//         email: userData?['email'] ?? '',
//         avatarUrl: userData?['avatarUrl'],
//         defaultEmoji: userData?['defaultEmoji'] ?? '👤',
//         createdAt: DateTime.now(),
//       );

//       final declinedReason = requestData['declinedReason'] ?? 'Raison non spécifiée';

//       print('🔴 NOTIFICATION: Match refusé par ${playerWhoDeclined.username}');
//       print('   ↳ Raison: $declinedReason');
      
//       _showMatchDeclinedNotification(playerWhoDeclined, declinedReason);
//     } catch (e) {
//       print('❌ Erreur gestion match refusé: $e');
//     }
//   }

//   void _showMatchDeclinedNotification(Player playerWhoDeclined, String reason) {
//     if (_context == null || !_context!.mounted) {
//       print('❌ Contexte non disponible pour notification');
//       return;
//     }
    
//     _hideNotification();

//     _overlayEntry = OverlayEntry(
//       builder: (context) => Material(
//         color: Colors.transparent,
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.start,
//           children: [
//             const SizedBox(height: 50),
//             MatchRequestDeclinedNotification(
//               player: playerWhoDeclined,
//               type: MatchRequestDeclinedNotificationType.declined,
//               reason: reason,
//               onTap: () => _hideNotification(),
//               onSwipe: () => _hideNotification(),
//             ),
//           ],
//         ),
//       ),
//     );

//     try {
//       Overlay.of(_context!).insert(_overlayEntry!);
//       print('✅ Notification match refusé affichée avec succès');

//       // Masquer automatiquement après 5 secondes
//       Timer(const Duration(seconds: 5), () {
//         _hideNotification();
//       });
//     } catch (e) {
//       print('❌ Erreur affichage notification: $e');
//     }
//   }

//   void _hideNotification() {
//     if (_overlayEntry != null) {
//       _overlayEntry?.remove();
//       _overlayEntry = null;
//       print('🔒 Notification masquée');
//     }
//   }

//   void dispose() {
//     _matchRequestsSubscription?.cancel();
//     _hideNotification();
//     _context = null;
//     _lastShownRequestId = null;
//     _processedRequests.clear();
//     print('♻️ Service matchs refusés nettoyé');
//   }

//   void restart() {
//     print('🔄 Redémarrage écoute matchs refusés');
//     _matchRequestsSubscription?.cancel();
//     //_startListening();
//   }

//   void stop() {
//     print('⏹️ Arrêt écoute matchs refusés');
//     _matchRequestsSubscription?.cancel();
//     _hideNotification();
//   }
// }
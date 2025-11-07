// services/match_notification_service.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jeu_carre/models/game_request.dart';
import 'package:jeu_carre/services/game_service.dart';
import 'package:jeu_carre/widgets/match_request_notification.dart';

class MatchNotificationService {
  static final MatchNotificationService _instance = MatchNotificationService._internal();
  factory MatchNotificationService() => _instance;
  MatchNotificationService._internal();

  OverlayEntry? _overlayEntry;
  StreamSubscription? _matchRequestSubscription;
  BuildContext? _context;

  /// Initialiser le service avec le contexte de navigation
  void initialize(BuildContext context) {
    _context = context;
    _startListening();
  }

  /// Démarrer l'écoute des demandes de match
  void _startListening() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _matchRequestSubscription?.cancel();
    _matchRequestSubscription = GameService.getReceivedMatchRequests(currentUser.uid).listen((requests) {
      final pendingRequests = requests.where((request) => 
        request.status == MatchRequestStatus.pending &&
        !GameService.isMatchRequestExpired(request)
      ).toList();

      if (pendingRequests.isNotEmpty) {
        _showNotification(pendingRequests.first);
      } else {
        _hideNotification();
      }
    });
  }

  /// Afficher la notification
  void _showNotification(MatchRequest request) async {
    if (_context == null || !_context!.mounted) return;
    
    // Supprimer l'overlay existant s'il y en a un
    _hideNotification();

    // Charger les infos du joueur
    final fromPlayer = await GameService.getPlayer(request.fromUserId);
    if (fromPlayer == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black.withOpacity(0.4),
        child: Column(
          children: [
            const Spacer(),
            MatchRequestNotification(
              request: request,
              fromPlayer: fromPlayer,
              onAccept: () => _acceptMatch(request),
              onDecline: () => _declineMatch(request),
            ),
          ],
        ),
      ),
    );

    Overlay.of(_context!).insert(_overlayEntry!);
  }

  /// Masquer la notification
  void _hideNotification() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

 
  /// Accepter le match et naviguer vers le jeu
  Future<void> _acceptMatch(MatchRequest request) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Accepter la demande via GameService
      await GameService.acceptMatchRequest(request.id, currentUser.uid);
      _hideNotification();
      
    } catch (e) {
      print('Erreur acceptation match: $e');
      _hideNotification();
      
      if (_context != null && _context!.mounted) {
        ScaffoldMessenger.of(_context!).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Refuser le match
  Future<void> _declineMatch(MatchRequest request) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await GameService.rejectMatchRequest(
        request.id,
        currentUser.uid,
        reason: 'Refusé par le joueur',
      );
      _hideNotification();
    } catch (e) {
      print('Erreur refus match: $e');
      _hideNotification();
    }
  }

  /// Nettoyer les ressources
  void dispose() {
    _matchRequestSubscription?.cancel();
    _hideNotification();
    _context = null;
  }

  /// Redémarrer l'écoute (après connexion par exemple)
  void restart() {
    _matchRequestSubscription?.cancel();
    _startListening();
  }

  /// Arrêter l'écoute (après déconnexion par exemple)
  void stop() {
    _matchRequestSubscription?.cancel();
    _hideNotification();
  }
}
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jeu_carre/models/feedback.dart';
import 'package:jeu_carre/models/message.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/widgets/feedback_notification.dart';

class FeedbackNotificationService {
  static final FeedbackNotificationService _instance = FeedbackNotificationService._internal();
  factory FeedbackNotificationService() => _instance;
  FeedbackNotificationService._internal();

  OverlayEntry? _overlayEntry;
  StreamSubscription? _newMessagesSubscription;
  StreamSubscription? _interactionsSubscription;
  BuildContext? _context;
  String? _currentUserId;

  // Collections Firestore
  final CollectionReference _messagesCollection = FirebaseFirestore.instance.collection('messages');
  final CollectionReference _interactionsCollection = FirebaseFirestore.instance.collection('feedback_interactions');
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');

  // Prévention des doublons
  String? _lastShownMessageId;
  String? _lastShownInteractionId;
  DateTime? _lastNotificationTime;

  /// Initialiser le service avec le contexte de navigation
  void initialize(BuildContext context) {
    _context = context;
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _startListening();
  }

  /// Démarrer l'écoute des nouveaux messages et interactions
  Future<void> _startListening() async {
    if (_currentUserId == null) return;


    // 1. Écouter les NOUVEAUX messages publics en temps réel
    _newMessagesSubscription?.cancel();
    _newMessagesSubscription = _messagesCollection
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docChanges.isNotEmpty) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final message = Message.fromMap(change.doc.data() as Map<String, dynamic>);
            _handleNewMessage(message);
          }
        }
      }
    });

    // 2. Écouter les NOUVELLES interactions en temps réel
    _interactionsSubscription?.cancel();
    _interactionsSubscription = _interactionsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docChanges.isNotEmpty) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final interaction = FeedbackInteraction.fromMap(change.doc.data() as Map<String, dynamic>);
            _handleNewInteraction(interaction);
          }
        }
      }
    });
  }

  /// Gérer un nouveau message
  void _handleNewMessage(Message message) async {
    // Vérifier si le message est récent (moins de 30 secondes)
    final isRecent = DateTime.now().difference(message.createdAt).inSeconds < 30;
    
    // Ne pas afficher pour l'utilisateur qui a posté le message
    if (message.userId != _currentUserId && isRecent) {
      // Éviter les doublons
      if (_lastShownMessageId == message.id) return;
      
      _lastShownMessageId = message.id;
      _lastNotificationTime = DateTime.now();
      
      _showNewMessageNotification(message);
    }
  }

  /// Gérer une nouvelle interaction
  void _handleNewInteraction(FeedbackInteraction interaction) async {
    try {
      // Vérifier si l'interaction est récente (moins de 30 secondes)
      final isRecent = DateTime.now().difference(interaction.createdAt).inSeconds < 30;
      
      if (!isRecent) return;

      // Récupérer le message correspondant
      final messageDoc = await _messagesCollection.doc(interaction.feedbackId).get();
      if (!messageDoc.exists) return;
      
      final message = Message.fromMap(messageDoc.data() as Map<String, dynamic>);

      // Ne notifier que si l'interaction concerne un message de l'utilisateur courant
      // ET que ce n'est pas l'utilisateur courant qui a interagi
      if (message.userId == _currentUserId && interaction.userId != _currentUserId) {
        // Éviter les doublons
        final interactionId = '${interaction.feedbackId}_${interaction.userId}';
        if (_lastShownInteractionId == interactionId) return;
        
        _lastShownInteractionId = interactionId;
        _lastNotificationTime = DateTime.now();

        _showInteractionNotification(interaction, message);
      }
    } catch (e) {
      print('❌ Erreur gestion interaction: $e');
    }
  }

  /// Afficher la notification pour un nouveau message
  void _showNewMessageNotification(Message message) async {
    if (_context == null || !_context!.mounted) return;
    
    _hideNotification();

    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.transparent,
        child: Column(
          children: [
            FeedbackNotification(
              type: FeedbackNotificationType.newMessage,
              message: message,
              onTap: () => _hideNotification(),
              onSwipe: () => _hideNotification(),
            ),
          ],
        ),
      ),
    );

    Overlay.of(_context!).insert(_overlayEntry!);

    // Masquer automatiquement après 5 secondes
    Timer(const Duration(seconds: 5), () {
      _hideNotification();
    });
  }

  /// Afficher la notification pour une interaction
  void _showInteractionNotification(FeedbackInteraction interaction, Message message) async {
    if (_context == null || !_context!.mounted) return;
    
    _hideNotification();

    // Récupérer les infos de l'utilisateur qui a interagi
    final userDoc = await _usersCollection.doc(interaction.userId).get();
    if (!userDoc.exists) return;

    final userData = userDoc.data() as Map<String, dynamic>?;
    final interactor = Player.fromBasicInfo(
      id: interaction.userId,
      username: userData?['username'] ?? 'Utilisateur',
      email: userData?['email'] ?? '',
      avatarUrl: userData?['avatarUrl'],
      defaultEmoji: userData?['defaultEmoji'] ?? '👤',
      createdAt: DateTime.now(),
    );

    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.transparent,
        child: Column(
          children: [
            FeedbackNotification(
              type: FeedbackNotificationType.interaction,
              message: message,
              interactor: interactor,
              interactionType: interaction.type,
              onTap: () => _hideNotification(),
              onSwipe: () => _hideNotification(),
            ),
          ],
        ),
      ),
    );

    Overlay.of(_context!).insert(_overlayEntry!);

    // Masquer automatiquement après 5 secondes
    Timer(const Duration(seconds: 5), () {
      _hideNotification();
    });
  }

  /// Masquer la notification
  void _hideNotification() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Nettoyer les ressources
  void dispose() {
    _newMessagesSubscription?.cancel();
    _interactionsSubscription?.cancel();
    _hideNotification();
    _context = null;
    _lastShownMessageId = null;
    _lastShownInteractionId = null;
    _lastNotificationTime = null;
  }

  /// Redémarrer l'écoute
  void restart() {
    _newMessagesSubscription?.cancel();
    _interactionsSubscription?.cancel();
    _startListening();
  }

  /// Arrêter l'écoute
  void stop() {
    _newMessagesSubscription?.cancel();
    _interactionsSubscription?.cancel();
    _hideNotification();
  }
}
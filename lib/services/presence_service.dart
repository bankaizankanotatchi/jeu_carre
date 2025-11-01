import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceService with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _heartbeatTimer;

  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  /// 🔧 Initialise la surveillance automatique (à appeler au lancement de l’app)
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _startAutoHeartbeat();
  }

  /// 🧹 Nettoyage quand l’app se ferme
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
  }

  // -------------------------------
  // 🔵 MÉTHODES PRINCIPALES
  // -------------------------------

  /// Quand l'utilisateur est connecté → marqué en ligne
  Future<void> setUserOnline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Quand il quitte ou passe en arrière-plan → hors ligne
  Future<void> setUserOffline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Envoi d’un "heartbeat" (signal de vie) toutes les 20 secondes
  void _startAutoHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// 👁️ Stream pour suivre le statut d’un utilisateur
  Stream<bool> getUserOnlineStatus(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data()!;
      final isOnline = data['isOnline'] ?? false;
      final lastSeen = (data['lastSeen'] as Timestamp?)?.toDate();

      if (lastSeen == null) return false;
      final diff = DateTime.now().difference(lastSeen).inSeconds;
      return isOnline && diff < 30; // Considéré "en ligne" si activité < 30s
    });
  }

  // -------------------------------
  // 🧠 DÉTECTION AUTOMATIQUE DU STATUT
  // -------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = _auth.currentUser;
    if (user == null) return;

    if (state == AppLifecycleState.resumed) {
      setUserOnline();
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.inactive ||
               state == AppLifecycleState.detached) {
      setUserOffline();
    }
  }
}

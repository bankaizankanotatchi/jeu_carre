import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatsMigrationScreen extends StatefulWidget {
  const StatsMigrationScreen({super.key});

  @override
  State<StatsMigrationScreen> createState() => _StatsMigrationScreenState();
}

class _StatsMigrationScreenState extends State<StatsMigrationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isRunning = false;
  bool _isSendingMessages = false;
  String _log = '';
  int _currentUser = 0;
  int _totalUsers = 0;
  double _progress = 0.0;

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _log += '$message\n';
    });
    print(message);
  }

  Future<void> _migrateUserStats(String userId) async {
    try {
      _addLog('🔍 Récupération des parties pour $userId...');
      
      final gamesSnapshot = await _firestore
          .collection('games')
          .where('players', arrayContains: userId)
          .where('status', isEqualTo: 'GameStatus.finished')
          .get();

      _addLog('🎮 Parties trouvées: ${gamesSnapshot.docs.length}');

      if (gamesSnapshot.docs.isEmpty) {
        _addLog('ℹ️ Aucune partie - réinitialisation des stats');
        await _resetUserStats(userId);
        return;
      }

      int totalPoints = 0;
      int gamesPlayed = 0;
      int gamesWon = 0;
      int gamesLost = 0;
      int gamesDraw = 0;
      int currentWinStreak = 0;
      int bestWinStreak = 0;
      int bestGamePoints = 0;

      for (final gameDoc in gamesSnapshot.docs) {
        try {
          final gameData = gameDoc.data();
          final scores = Map<String, int>.from(gameData['scores'] ?? {});
          final winnerId = gameData['winnerId'];

          final userScore = scores[userId] ?? 0;
          totalPoints += userScore;

          if (userScore > bestGamePoints) {
            bestGamePoints = userScore;
          }

          gamesPlayed++;

          final isDraw = winnerId == null;
          final isWin = winnerId == userId;
          final isLoss = !isDraw && !isWin;

          if (isWin) {
            gamesWon++;
            currentWinStreak++;
            if (currentWinStreak > bestWinStreak) {
              bestWinStreak = currentWinStreak;
            }
          } else if (isLoss) {
            gamesLost++;
            currentWinStreak = 0;
          } else if (isDraw) {
            gamesDraw++;
            currentWinStreak = 0;
          }

        } catch (e) {
          _addLog('⚠️ Erreur sur une partie: $e');
        }
      }

      final statsUpdate = {
        'stats.winStreak': currentWinStreak,
        'stats.bestWinStreak': bestWinStreak,
        'stats.bestGamePoints': bestGamePoints,
        'totalPoints': totalPoints,
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'gamesLost': gamesLost,
        'gamesDraw': gamesDraw,
        'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
      };

      _addLog('📊 Stats calculées:');
      _addLog('   - Parties: $gamesPlayed, Victoires: $gamesWon');
      _addLog('   - Points: $totalPoints, Meilleure série: $bestWinStreak');

      await _firestore.collection('users').doc(userId).update(statsUpdate);
      _addLog('✅ Stats mises à jour pour $userId\n');

    } catch (e) {
      _addLog('❌ Erreur pour $userId: $e\n');
      rethrow;
    }
  }

  Future<void> _resetUserStats(String userId) async {
    try {
      final resetStats = {
        'stats.winStreak': 0,
        'stats.bestWinStreak': 0,
        'stats.bestGamePoints': 0,
        'totalPoints': 0,
        'gamesPlayed': 0,
        'gamesWon': 0,
        'gamesLost': 0,
        'gamesDraw': 0,
        'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _firestore.collection('users').doc(userId).update(resetStats);
      _addLog('🔄 Stats réinitialisées pour $userId\n');
    } catch (e) {
      _addLog('❌ Erreur réinitialisation: $e\n');
    }
  }

  // NOUVELLE FONCTION : Envoyer un message à tous les utilisateurs
  Future<void> _sendAnnouncementToAllUsers() async {
    if (_isSendingMessages) return;

    setState(() {
      _isSendingMessages = true;
      _log = '📣 Démarrage de l\'envoi des annonces...\n';
      _currentUser = 0;
      _progress = 0.0;
    });

    try {
      // 1. Récupérer tous les utilisateurs (sauf l'admin)
      final usersSnapshot = await _firestore.collection('users').get();
      final adminId = 'cG2OJZKbcVRFJIhWjN6hRdWj1ty1';
      
      final filteredUsers = usersSnapshot.docs
          .where((doc) => doc.id != adminId)
          .toList();
      
      final totalUsers = filteredUsers.length;
      
      setState(() {
        _totalUsers = totalUsers;
      });

      _addLog('👥 Nombre d\'utilisateurs à notifier: $totalUsers');
      _addLog('🤖 Admin répondant: $adminId\n');

      int successCount = 0;
      int errorCount = 0;

      // 2. Message du joueur
      final userMessage = {
        'category': 'FeedbackCategory.suggestion',
        'content': '''🎮✨ Bonjour la communauté Shikaku ! 

🎉 INCROYABLE ! La mise à jour tant attendue est FINALEMENT DISPONIBLE ! 

🔥 QUOI DE NEUF ? Voici les bugs résolus :

🐛 1. Quand un joueur quitte une partie, son temps de réflexion était bloqué, affectant injustement l'autre joueur. MAINTENANT RÉSOLU ! 
   → Le temps de réflexion est correctement géré pour les deux joueurs !

🐛 2. Pendant une partie, si ton temps arrive à zéro sans jouer, un point aléatoire est placé !

🐛 3. Bug de classement ÉLIMINÉ !
   → Le classement se met à jour automatiquement en temps réel !
   → Ton profil affiche maintenant ton VRAI rang !

🌟 NOUVELLES FONCTIONNALITÉS :

🎯 Dans Shikaku, seul le TOP 10 compte ! 
   → Si tu n'es pas dans le top 10, tu seras "non classé" !

🖼️ ADMIRE les photos de profil des joueurs en FULLSCREEN !
   → Si une image t'intéresse par sa beauté ou son art, clique dessus !

🤝 SYSTÈME DE DEMANDE DE MATCH amélioré :
   → Va dans Menu > Match > Onglet "Demandes"
   → Voir les demandes reçues (bouton bleu en haut pour les demandes envoyées)

📢 RAPPEL : Cette mise à jour a été faite POUR VOUS, à votre retour !

🚀 ALORS ?? QU'ATTENDS-TU ? 
📲 Télécharge la nouvelle version MAINTENANT et deviens le MAÎTRE de Shikaku !

👉 COPIE ce lien : https://site-telechargement-shikaku.vercel.app/
👉 COLLE-le dans ton navigateur
👉 TÉLÉCHARGE et JOUE !

À très vite sur le nouveau Shikaku ! 🎮💫

#ShikakuUpdate #NouvelleVersion #JeuGratuit''',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'adminResponse': null,
        'respondedAt': null,
        'isRead': false,
      };

      // 3. Réponse de l'admin
      final adminResponseText = '''🎮💬 ADMIN SHIKAKU répond :

ET DONC ??? VOUS AVEZ QUOI ???

😄 Aller vite ! Téléchargez la mise à jour de Shikaku et devenez le MAÎTRE !

👉 Lien : https://site-telechargement-shikaku.vercel.app/
👉 Copiez > Collez > Téléchargez > Jouez !

🌟 C'est fait spécialement pour vous, joueurs fidèles !

On vous attend sur le nouveau Shikaku ! 🚀

#UpdateDisponible #ShikakuMaster #TéléchargementGratuit''';

      // 4. Envoyer à chaque utilisateur
      for (final userDoc in filteredUsers) {
        try {
          final userId = userDoc.id;
          final userData = userDoc.data();
          
          _addLog('📨 [${_currentUser + 1}/$totalUsers] Envoi à: ${userData['username'] ?? userId}');

          // Récupérer les messages existants
          final currentMessages = List<Map<String, dynamic>>.from(
              userData['messages'] ?? []);
          
          // Créer le message avec la réponse directement
          final messageWithResponse = Map<String, dynamic>.from(userMessage);
          messageWithResponse['adminResponse'] = adminResponseText;
          messageWithResponse['respondedAt'] = DateTime.now().millisecondsSinceEpoch;
          
          // Ajouter le message à la liste
          currentMessages.add(messageWithResponse);
          
          // Mettre à jour l'utilisateur
          await _firestore.collection('users').doc(userId).update({
            'messages': currentMessages,
            'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
          });

          _addLog('   ✅ Message envoyé et répondu !');
          successCount++;

        } catch (e) {
          _addLog('   ❌ Erreur: $e');
          errorCount++;
        }

        setState(() {
          _currentUser++;
          _progress = _currentUser / totalUsers;
        });

        // Délai pour éviter de surcharger Firestore
        await Future.delayed(const Duration(milliseconds: 200));
      }

      _addLog('\n✅ ANNONCE TERMINÉE !');
      _addLog('📊 Résultats :');
      _addLog('   - Utilisateurs notifiés: $successCount');
      _addLog('   - Erreurs: $errorCount');
      _addLog('   - Total: $_currentUser/$totalUsers');
      _addLog('\n🎯 Tous les joueurs ont reçu :');
      _addLog('   1. Le message d\'annonce de mise à jour');
      _addLog('   2. La réponse automatique de l\'admin');
      _addLog('   3. Le lien de téléchargement : https://site-telechargement-shikaku.vercel.app/');

    } catch (e) {
      _addLog('❌ Erreur critique pendant l\'envoi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessages = false;
        });
      }
    }
  }

  Future<void> _testSingleMessage() async {
    const testUserId = 'cG2OJZKbcVRFJIhWjN6hRdWj1ty1'; // ID admin
    
    setState(() {
      _log = '🧪 Test d\'envoi de message...\n';
    });

    try {
      // Créer un message test
      final testMessage = {
        'category': 'FeedbackCategory.suggestion',
        'content': '🎮 Test message : Mise à jour disponible ! https://site-telechargement-shikaku.vercel.app/',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'adminResponse': '🎯 Test réponse admin : Téléchargez maintenant !',
        'respondedAt': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      };

      final userDoc = await _firestore.collection('users').doc(testUserId).get();
      final currentMessages = List<Map<String, dynamic>>.from(
          userDoc.data()?['messages'] ?? []);
      
      currentMessages.add(testMessage);
      
      await _firestore.collection('users').doc(testUserId).update({
        'messages': currentMessages,
      });

      _addLog('✅ Message test envoyé à $testUserId');
      _addLog('📝 Contenu : Mise à jour disponible');
      _addLog('🔗 Lien : https://site-telechargement-shikaku.vercel.app/');
    } catch (e) {
      _addLog('❌ Test échoué: $e');
    }
  }

  Future<void> _runMigration() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _log = '🚀 Démarrage de la migration...\n';
      _currentUser = 0;
      _progress = 0.0;
    });

    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final totalUsers = usersSnapshot.docs.length;
      
      setState(() {
        _totalUsers = totalUsers;
      });

      _addLog('👥 Nombre d\'utilisateurs: $totalUsers');

      int successCount = 0;
      int errorCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        try {
          final userId = userDoc.id;
          _addLog('\n📊 [${_currentUser + 1}/$totalUsers] Traitement: $userId');

          await _migrateUserStats(userId);
          successCount++;

        } catch (e) {
          _addLog('❌ Erreur: $e');
          errorCount++;
        }

        setState(() {
          _currentUser++;
          _progress = _currentUser / totalUsers;
        });

        await Future.delayed(const Duration(milliseconds: 100));
      }

      _addLog('\n✅ MIGRATION TERMINÉE');
      _addLog('📈 Résultats:');
      _addLog('   - Utilisateurs traités: $_currentUser');
      _addLog('   - Réussites: $successCount');
      _addLog('   - Erreurs: $errorCount');

    } catch (e) {
      _addLog('❌ Erreur critique: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a0033),
      appBar: AppBar(
        title: const Text(
          'Migration des Statistiques',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2d0052),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avertissement
            Card(
              color: Colors.orange[100],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚠️ MIGRATION DES STATS DES JOUEURS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ces actions mettrons a jour les vrai données de stats basées sur les parties terminées. ',
                      style: TextStyle(color: Colors.orange[900]),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Barre de progression
            if (_isRunning || _isSendingMessages) ...[
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[800],
                color: _isSendingMessages ? Colors.blue : Colors.green,
              ),
              const SizedBox(height: 8),
              Text(
                'Progression: $_currentUser/$_totalUsers (${(_progress * 100).toStringAsFixed(1)}%)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                _isSendingMessages ? '📣 Envoi des annonces...' : '📊 Migration des stats...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isSendingMessages ? Colors.blue[300] : Colors.green[300],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // // SECTION : ENVOYER L'ANNONCE
            // Card(
            //   color: const Color(0xFF2d0052),
            //   child: Padding(
            //     padding: const EdgeInsets.all(16.0),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.stretch,
            //       children: [
            //         const Text(
            //           '📣 ANNONCE DE MISE À JOUR',
            //           style: TextStyle(
            //             color: Colors.white,
            //             fontWeight: FontWeight.bold,
            //             fontSize: 16,
            //           ),
            //         ),
            //         const SizedBox(height: 8),
            //         const Text(
            //           'Envoie un message à tous les joueurs pour annoncer la nouvelle version',
            //           style: TextStyle(color: Colors.white70),
            //         ),
            //         const SizedBox(height: 16),
                    
            //         ElevatedButton(
            //           onPressed: _isSendingMessages ? null : _sendAnnouncementToAllUsers,
            //           style: ElevatedButton.styleFrom(
            //             backgroundColor: Colors.purple,
            //             padding: const EdgeInsets.symmetric(vertical: 16),
            //           ),
            //           child: _isSendingMessages
            //               ? const Row(
            //                   mainAxisAlignment: MainAxisAlignment.center,
            //                   children: [
            //                     CircularProgressIndicator(color: Colors.white),
            //                     SizedBox(width: 12),
            //                     Text(
            //                       'ENVOI EN COURS...',
            //                       style: TextStyle(color: Colors.white),
            //                     ),
            //                   ],
            //                 )
            //               : const Row(
            //                   mainAxisAlignment: MainAxisAlignment.center,
            //                   children: [
            //                     Icon(Icons.announcement, color: Colors.white),
            //                     SizedBox(width: 8),
            //                     Text(
            //                       'ENVOYER L\'ANNONCE À TOUS',
            //                       style: TextStyle(color: Colors.white),
            //                     ),
            //                   ],
            //                 ),
            //         ),
                    
            //         const SizedBox(height: 12),
                    
            //         OutlinedButton(
            //           onPressed: _isSendingMessages ? null : _testSingleMessage,
            //           style: OutlinedButton.styleFrom(
            //             side: const BorderSide(color: Colors.blue),
            //             padding: const EdgeInsets.symmetric(vertical: 12),
            //           ),
            //           child: const Text(
            //             'TESTER SUR L\'ADMIN',
            //             style: TextStyle(color: Colors.blue),
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            
            // const SizedBox(height: 20),
            
            // SECTION : MIGRATION DES STATS
            Card(
              color: const Color(0xFF2d0052),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '📊 MIGRATION DES STATISTIQUES',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Recalcule les stats basées sur les parties terminées',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    
                    ElevatedButton(
                      onPressed: _isRunning ? null : _runMigration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isRunning
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(width: 12),
                                Text(
                                  'MIGRATION EN COURS...',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            )
                          : const Text(
                              'LANCER LA MIGRATION DES STATS',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Zone de logs
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    _log,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Bouton pour effacer les logs
            if (_log.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _log = '';
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                      ),
                      child: const Text(
                        'EFFACER LES LOGS',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
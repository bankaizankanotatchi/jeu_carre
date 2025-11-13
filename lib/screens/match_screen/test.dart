import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeu_carre/models/game_model.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/services/game_service.dart';
import 'package:jeu_carre/screens/game_screen/game_screen.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Streams pour les données en temps réel
  Stream<List<Game>>? _myActiveGamesStream;
  Stream<List<Game>>? _allActiveGamesStream;
  // Stream<List<MatchRequest>>? _receivedRequestsStream;
  // Stream<List<MatchRequest>>? _sentRequestsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeStreams();
  }

void _initializeStreams() {
  final currentUserId = _auth.currentUser?.uid;
  if (currentUserId != null) {
    try {
      _myActiveGamesStream = GameService.getMyActiveGames(currentUserId);
      _allActiveGamesStream = GameService.getAllActiveGames();
      // _receivedRequestsStream = GameService.getReceivedMatchRequests(currentUserId);
      // _sentRequestsStream = GameService.getSentMatchRequests(currentUserId);
    } catch (e) {
      print('Erreur initialisation streams: $e');
    }
  }
}

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================
  // FONCTIONS DE GESTION DES DEMANDES
  // ============================================================

// void _acceptMatchRequest(MatchRequest request) async {
//   try {
//     final currentUserId = _auth.currentUser?.uid;
//     if (currentUserId == null) return;

//     await GameService.acceptMatchRequest(request.id, currentUserId);
    
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Défi accepté !'),
//         backgroundColor: Colors.green,
//       ),
//     );
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Erreur: ${e.toString()}'),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }
// }

// void _rejectMatchRequest(MatchRequest request) async {
//   try {
//     final currentUserId = _auth.currentUser?.uid;
//     if (currentUserId == null) return;

//     await GameService.rejectMatchRequest(request.id, currentUserId);
    
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Défi refusé'),
//         backgroundColor: Colors.orange,
//       ),
//     );
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Erreur: ${e.toString()}'),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }
// }

// void _cancelMatchRequest(MatchRequest request) async {
//   try {
//     final currentUserId = _auth.currentUser?.uid;
//     if (currentUserId == null) return;

//     await GameService.cancelMatchRequest(request.id, currentUserId);
    
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Demande annulée'),
//         backgroundColor: Colors.blue,
//       ),
//     );
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Erreur: ${e.toString()}'),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }
// }


//   void _createNewChallenge(String opponentId) {
//     // Navigation vers l'écran de défi
//     // TODO: Implémenter la navigation
//   }

  void _joinAsSpectator(Game game) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId != null) {
        await GameService.joinAsSpectator(game.id, currentUserId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vous observez maintenant la partie'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resumeGame(Game game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          gridSize: game.gridSize,
          isAgainstAI: game.isAgainstAI,
          gameDuration: game.gameDuration,
          reflexionTime: game.reflexionTime,
          existingGame: game, // Passer la partie existante
        ),
      ),
    );
  }

  // ============================================================
  // WIDGETS D'AFFICHAGE
  // ============================================================

  Widget _buildAnimatedParticle(int index) {
    final random = (index * 123) % 100;
    final left = (random % 100).toDouble();
    final top = ((random * 7) % 100).toDouble();
    final size = 2.0 + (random % 4);
    final duration = 3 + (random % 5);
    
    return Positioned(
      left: left.clamp(0, 100) * MediaQuery.of(context).size.width / 100,
      top: top.clamp(0, 100) * 180 / 100,
      child: TweenAnimationBuilder(
        duration: Duration(seconds: duration),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, double value, child) {
          return Opacity(
            opacity: value,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFe040fb).withOpacity(0.6),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFe040fb).withOpacity(0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          );
        },
        onEnd: () {
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  // Widget _buildMatchRequestCard(MatchRequest request, Player? opponent) {
  //   final isExpired = GameService.isMatchRequestExpired(request);
  //   final isRejected = request.status == MatchRequestStatus.declined;
  //   final isPending = request.status == MatchRequestStatus.pending && !isExpired;
  //   final isMyRequest = request.fromUserId == _auth.currentUser?.uid;
    
  //   Color statusColor;
  //   String statusText;
  //   IconData statusIcon;

  //   if (isExpired) {
  //     statusColor = Color(0xFF666666);
  //     statusText = 'EXPIRÉE';
  //     statusIcon = Icons.timer_off;
  //   } else if (isRejected) {
  //     statusColor = Color(0xFFff006e);
  //     statusText = 'REFUSÉE';
  //     statusIcon = Icons.cancel;
  //   } else if (request.status == MatchRequestStatus.accepted) {
  //     statusColor = Color(0xFF00d4ff);
  //     statusText = 'ACCEPTÉE';
  //     statusIcon = Icons.check_circle;
  //   } else {
  //     statusColor = Color(0xFFFFD700);
  //     statusText = 'EN ATTENTE';
  //     statusIcon = Icons.schedule;
  //   }

  //   final opponentName = opponent?.username ?? 'Joueur inconnu';
  //   final opponentAvatar = opponent?.displayAvatar ?? '👤';

  //   return Container(
  //     margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //     decoration: BoxDecoration(
  //       color: Color(0xFF1a0033),
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(
  //         color: statusColor.withOpacity(0.5),
  //         width: 2,
  //       ),
  //     ),
  //     child: Material(
  //       color: Colors.transparent,
  //       child: InkWell(
  //         borderRadius: BorderRadius.circular(12),
  //         onTap: () {
  //           // Voir les détails de la demande
  //         },
  //         child: Padding(
  //           padding: EdgeInsets.all(16),
  //           child: Column(
  //             children: [
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   Row(
  //                     children: [
  //                       Container(
  //                         width: 50,
  //                         height: 50,
  //                         decoration: BoxDecoration(
  //                           shape: BoxShape.circle,
  //                           gradient: LinearGradient(
  //                             colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
  //                           ),
  //                         ),
  //                         child: Center(
  //                           child: Text(
  //                             opponentAvatar,
  //                             style: TextStyle(fontSize: 20),
  //                           ),
  //                         ),
  //                       ),
  //                       SizedBox(width: 12),
  //                       Column(
  //                         crossAxisAlignment: CrossAxisAlignment.start,
  //                         children: [
  //                           Text(
  //                             opponentName,
  //                             style: TextStyle(
  //                               color: Colors.white,
  //                               fontSize: 16,
  //                               fontWeight: FontWeight.w700,
  //                             ),
  //                           ),
  //                           Text(
  //                             isMyRequest ? 'Vous avez défié' : 'Vous a défié',
  //                             style: TextStyle(
  //                               color: Colors.white.withOpacity(0.6),
  //                               fontSize: 12,
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     ],
  //                   ),
  //                   Container(
  //                     padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //                     decoration: BoxDecoration(
  //                       color: statusColor.withOpacity(0.2),
  //                       borderRadius: BorderRadius.circular(12),
  //                       border: Border.all(color: statusColor),
  //                     ),
  //                     child: Row(
  //                       children: [
  //                         Icon(statusIcon, color: statusColor, size: 14),
  //                         SizedBox(width: 6),
  //                         Text(
  //                           statusText,
  //                           style: TextStyle(
  //                             color: statusColor,
  //                             fontSize: 10,
  //                             fontWeight: FontWeight.w900,
  //                             letterSpacing: 1,
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 ],
  //               ),
                
  //               SizedBox(height: 16),
                
  //               Container(
  //                 padding: EdgeInsets.all(12),
  //                 decoration: BoxDecoration(
  //                   color: Color(0xFF2d0052),
  //                   borderRadius: BorderRadius.circular(8),
  //                 ),
  //                 child: Column(
  //                   children: [
  //                     Row(
  //                       mainAxisAlignment: MainAxisAlignment.spaceAround,
  //                       children: [
  //                         _buildConfigItem('Grille', '${request.gridSize}×${request.gridSize}', Icons.grid_on),
  //                         _buildConfigItem('Match', '${request.gameDuration ~/ 60} min', Icons.timer),
  //                         _buildConfigItem('Tour', '${request.reflexionTime}s', Icons.hourglass_empty),
  //                       ],
  //                     ),
  //                     SizedBox(height: 8),
  //                     if (isPending && !isMyRequest)
  //                       Text(
  //                         'Temps restant: ${_formatTimeRemaining(request.createdAt)}',
  //                         style: TextStyle(
  //                           color: Color(0xFFFFD700),
  //                           fontSize: 12,
  //                           fontWeight: FontWeight.w600,
  //                         ),
  //                       ),
  //                   ],
  //                 ),
  //               ),
                
  //               SizedBox(height: 12),
                
  //               if (isPending && !isMyRequest)
  //                 Row(
  //                   children: [
  //                     Expanded(
  //                       child: Container(
  //                         height: 40,
  //                         decoration: BoxDecoration(
  //                           gradient: LinearGradient(
  //                             colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
  //                           ),
  //                           borderRadius: BorderRadius.circular(8),
  //                         ),
  //                         child: Material(
  //                           color: Colors.transparent,
  //                           child: InkWell(
  //                             borderRadius: BorderRadius.circular(8),
  //                             onTap: () => _acceptMatchRequest(request),
  //                             child: Center(
  //                               child: Row(
  //                                 mainAxisAlignment: MainAxisAlignment.center,
  //                                 children: [
  //                                   Icon(Icons.check, color: Colors.white, size: 16),
  //                                   SizedBox(width: 6),
  //                                   Text(
  //                                     'ACCEPTER',
  //                                     style: TextStyle(
  //                                       color: Colors.white,
  //                                       fontSize: 12,
  //                                       fontWeight: FontWeight.w900,
  //                                     ),
  //                                   ),
  //                                 ],
  //                               ),
  //                             ),
  //                           ),
  //                         ),
  //                       ),
  //                     ),
  //                     SizedBox(width: 8),
  //                     Expanded(
  //                       child: Container(
  //                         height: 40,
  //                         decoration: BoxDecoration(
  //                           color: Color(0xFF1a0033),
  //                           borderRadius: BorderRadius.circular(8),
  //                           border: Border.all(color: Color(0xFFff006e)),
  //                         ),
  //                         child: Material(
  //                           color: Colors.transparent,
  //                           child: InkWell(
  //                             borderRadius: BorderRadius.circular(8),
  //                             onTap: () => _rejectMatchRequest(request),
  //                             child: Center(
  //                               child: Row(
  //                                 mainAxisAlignment: MainAxisAlignment.center,
  //                                 children: [
  //                                   Icon(Icons.close, color: Color(0xFFff006e), size: 16),
  //                                   SizedBox(width: 6),
  //                                   Text(
  //                                     'REFUSER',
  //                                     style: TextStyle(
  //                                       color: Color(0xFFff006e),
  //                                       fontSize: 12,
  //                                       fontWeight: FontWeight.w900,
  //                                     ),
  //                                   ),
  //                                 ],
  //                               ),
  //                             ),
  //                           ),
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 )
  //               else if (isPending && isMyRequest)
  //                 Container(
  //                   width: double.infinity,
  //                   height: 40,
  //                   decoration: BoxDecoration(
  //                     color: Color(0xFF1a0033),
  //                     borderRadius: BorderRadius.circular(8),
  //                     border: Border.all(color: Color(0xFFFFD700)),
  //                   ),
  //                   child: Material(
  //                     color: Colors.transparent,
  //                     child: InkWell(
  //                       borderRadius: BorderRadius.circular(8),
  //                       onTap: () => _cancelMatchRequest(request),
  //                       child: Center(
  //                         child: Row(
  //                           mainAxisAlignment: MainAxisAlignment.center,
  //                           children: [
  //                             Icon(Icons.cancel, color: Color(0xFFFFD700), size: 16),
  //                             SizedBox(width: 6),
  //                             Text(
  //                               'ANNULER LA DEMANDE',
  //                               style: TextStyle(
  //                                 color: Color(0xFFFFD700),
  //                                 fontSize: 12,
  //                                 fontWeight: FontWeight.w900,
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                       ),
  //                     ),
  //                   ),
  //                 )
  //               else if (isExpired || isRejected)
  //                 Container(
  //                   width: double.infinity,
  //                   height: 40,
  //                   decoration: BoxDecoration(
  //                     color: Color(0xFF1a0033),
  //                     borderRadius: BorderRadius.circular(8),
  //                     border: Border.all(color: statusColor),
  //                   ),
  //                   child: Material(
  //                     color: Colors.transparent,
  //                     child: InkWell(
  //                       borderRadius: BorderRadius.circular(8),
  //                       onTap: () => _createNewChallenge(request.fromUserId),
  //                       child: Center(
  //                         child: Text(
  //                           'REDÉFIER',
  //                           style: TextStyle(
  //                             color: statusColor,
  //                             fontSize: 12,
  //                             fontWeight: FontWeight.w900,
  //                           ),
  //                         ),
  //                       ),
  //                     ),
  //                   ),
  //                 ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildConfigItem(String title, String value, IconData icon) {
  //   return Column(
  //     children: [
  //       Icon(icon, color: Color(0xFF00d4ff), size: 16),
  //       SizedBox(height: 4),
  //       Text(
  //         value,
  //         style: TextStyle(
  //           color: Colors.white,
  //           fontSize: 12,
  //           fontWeight: FontWeight.w700,
  //         ),
  //       ),
  //       Text(
  //         title,
  //         style: TextStyle(
  //           color: Colors.white.withOpacity(0.6),
  //           fontSize: 8,
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // String _formatTimeRemaining(DateTime createdAt) {
  //   final difference = DateTime.now().difference(createdAt);
  //   final hoursLeft = 24 - difference.inHours;
  //   final minutesLeft = 60 - difference.inMinutes % 60;
    
  //   if (hoursLeft > 0) {
  //     return '${hoursLeft}h ${minutesLeft}m';
  //   } else {
  //     return '${minutesLeft}m';
  //   }
  // }
  
  String _getOpponentId(Game game, String currentUserId) {
  try {
    return game.players.firstWhere(
      (p) => p != currentUserId,
      orElse: () => game.players.isNotEmpty ? game.players.first : '',
    );
  } catch (e) {
    return game.players.isNotEmpty ? game.players.first : '';
  }
}
  String _truncateName(String name) {
    if (name.length <= 15) return name;
    return '${name.substring(0, 14)}..';
  }
  Widget _buildMyMatchCard(Game game, Player? opponent) {
    final currentUserId = _auth.currentUser?.uid;
    final isMyTurn = game.currentPlayer == currentUserId;
    final timeLeft = game.timeRemaining;
    final minutes = timeLeft ~/ 60;
    final seconds = timeLeft % 60;
    
    final opponentId = _getOpponentId(game, currentUserId!);
    final myScore = game.scores[currentUserId] ?? 0;
    final opponentScore = opponentId.isNotEmpty ? (game.scores[opponentId] ?? 0) : 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1a0033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyTurn ? Color(0xFF00d4ff) : Color(0xFF4a0080),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _resumeGame(game),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: game.isAgainstAI 
                                ? [Color(0xFFff006e), Color(0xFFc4005a)]
                                : [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              game.isAgainstAI ? '🤖' : opponent?.displayAvatar ?? '👤',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game.isAgainstAI
                                  ? 'IA ${game.aiDifficulty}'
                                  : _truncateName(opponent?.username ?? 'Adversaire'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Grille ${game.gridSize}×${game.gridSize}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isMyTurn ? Color(0xFF00d4ff).withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isMyTurn ? Color(0xFF00d4ff) : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        isMyTurn ? 'À VOTRE TOUR' : 'EN COURS',
                        style: TextStyle(
                          color: isMyTurn ? Color(0xFF00d4ff) : Colors.white.withOpacity(0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF2d0052),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                              ),
                            ),
                            child: Icon(Icons.person, color: Colors.white, size: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '$myScore',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      
                      Column(
                        children: [
                          Text(
                            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: Color(0xFFe040fb),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'TEMPS RESTANT',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: game.isAgainstAI 
                                  ? [Color(0xFFff006e), Color(0xFFc4005a)]
                                  : [Color(0xFFe040fb), Color(0xFF9c27b0)],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                game.isAgainstAI ? '🤖' : opponent?.displayAvatar ?? '👤',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '$opponentScore',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 12),
                
                Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isMyTurn
                          ? [Color(0xFF00d4ff), Color(0xFF0099cc)]
                          : [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _resumeGame(game),
                      child: Center(
                        child: Text(
                          isMyTurn ? 'REPRENDRE' : 'OBSERVER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPublicMatchCard(Game game) {
    final timeLeft = game.timeRemaining;
    final minutes = timeLeft ~/ 60;
    final seconds = timeLeft % 60;
    
    return FutureBuilder(
      future: Future.wait([
        GameService.getPlayer(game.player1Id ?? ''),
        GameService.getPlayer(game.player2Id ?? ''),
      ]),
      builder: (context, AsyncSnapshot<List<Player?>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildMatchSkeleton();
        }

        final player1 = snapshot.data?[0];
        final player2 = snapshot.data?[1];
        final score1 = game.scores[game.player1Id] ?? 0;
        final score2 = game.scores[game.player2Id] ?? 0;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Color(0xFF1a0033),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFF4a0080)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _joinAsSpectator(game),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    player1?.displayAvatar ?? '👤',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      player1?.username ?? 'Joueur 1',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Joueur 1',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF4a0080),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      player2?.username ?? 'Joueur 2',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Joueur 2',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xFFe040fb), Color(0xFF9c27b0)],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    player2?.displayAvatar ?? '👤',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF2d0052),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              Text(
                                '$score1',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'SCORE',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          
                          Column(
                            children: [
                              Text(
                                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: Color(0xFFe040fb),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Color(0xFF00d4ff).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Color(0xFF00d4ff),
                                  ),
                                ),
                                child: Text(
                                  'TOUR DE ${game.currentPlayer == game.player1Id ? player1?.username ?? 'J1' : player2?.username ?? 'J2'}',
                                  style: TextStyle(
                                    color: Color(0xFF00d4ff),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          Column(
                            children: [
                              Text(
                                '$score2',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'SCORE',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.grid_on, color: Color(0xFF00d4ff), size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Grille ${game.gridSize}×${game.gridSize}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        
                        Row(
                          children: [
                            Icon(Icons.visibility, color: Color(0xFFe040fb), size: 12),
                            SizedBox(width: 4),
                            Text(
                              '${game.spectators.length} spectateurs',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        
                        Container(
                          width: 80,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _joinAsSpectator(game),
                              child: Center(
                                child: Text(
                                  'OBSERVER',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatchSkeleton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1a0033),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 16,
                  color: Colors.grey[800],
                ),
                SizedBox(height: 4),
                Container(
                  width: 60,
                  height: 12,
                  color: Colors.grey[800],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0a0015),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, 50, 6, 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1a0033),
                  Color(0xFF2d0052),
                ],
              ),
            ),
            child: Stack(
              children: [
                ...List.generate(12, (index) => _buildAnimatedParticle(index)),
                
                Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF9c27b0), Color(0xFFe040fb)],
                            ),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF9c27b0).withOpacity(0.5),
                                blurRadius: 15,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Icon(Icons.sports_esports, color: Colors.white, size: 30),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ARÈNE DES MATCHS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Rejoignez la compétition et défiez les meilleurs',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
          
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF1a0033),
              border: Border(
                bottom: BorderSide(color: Color(0xFF4a0080)),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Color(0xFF00d4ff),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
              indicatorWeight: 3,
              tabs: [
                Tab(icon: Icon(Icons.person), text: 'MES MATCHS'),
                Tab(icon: Icon(Icons.public), text: 'TOUS LES MATCHS'),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: MES MATCHS
                StreamBuilder<List<Game>>(
                  stream: _myActiveGamesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState('Chargement de vos matchs...');
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState('Erreur de chargement');
                    }

                    final games = snapshot.data ?? [];

                    if (games.isEmpty) {
                      return _buildEmptyState(
                        'AUCUN MATCH EN COURS',
                        'Lancez un nouveau défi pour apparaître ici',
                        Icons.sports_esports,
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        final game = games[index];
                        final opponentId = game.players.firstWhere(
                          (p) => p != _auth.currentUser?.uid,
                          orElse: () => '',
                        );
                        
                        return FutureBuilder<Player?>(
                          future: GameService.getPlayer(opponentId),
                          builder: (context, opponentSnapshot) {
                            return _buildMyMatchCard(
                              game, 
                              opponentSnapshot.data
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                // TAB 2: TOUS LES MATCHS
                StreamBuilder<List<Game>>(
                  stream: _allActiveGamesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState('Chargement des matchs publics...');
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState('Erreur de chargement');
                    }

                    final games = snapshot.data ?? [];

                    if (games.isEmpty) {
                      return _buildEmptyState(
                        'AUCUN MATCH PUBLIC',
                        'Soyez le premier à lancer un match public !',
                        Icons.people,
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        return _buildPublicMatchCard(games[index]);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF00d4ff),
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, color: Colors.red, size: 50),
          SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeStreams,
            child: Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFF2d0052),
                  Color(0xFF4a0080),
                ],
              ),
              border: Border.all(
                color: Color(0xFF9c27b0),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: Color(0xFF00d4ff),
              size: 40,
            ),
          ),
          SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
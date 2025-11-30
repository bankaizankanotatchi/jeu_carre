// // match_request_notification.dart
// import 'package:flutter/material.dart';
// import 'package:jeu_carre/models/player.dart';

// enum MatchRequestDeclinedNotificationType {
//   declined,
//   // Vous pouvez ajouter d'autres types plus tard (accepted, etc.)
// }

// class MatchRequestDeclinedNotification extends StatefulWidget {
//   final Player player;
//   final MatchRequestDeclinedNotificationType type;
//   final String reason;
//   final VoidCallback onTap;
//   final VoidCallback onSwipe;

//   const MatchRequestDeclinedNotification({
//     Key? key,
//     required this.player,
//     required this.type,
//     required this.reason,
//     required this.onTap,
//     required this.onSwipe,
//   }) : super(key: key);

//   @override
//   _MatchRequestDeclinedNotificationState createState() => _MatchRequestDeclinedNotificationState();
// }

// class _MatchRequestDeclinedNotificationState extends State<MatchRequestDeclinedNotification>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<Offset> _slideAnimation;
//   late Animation<double> _opacityAnimation;

//   @override
//   void initState() {
//     super.initState();
    
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 600),
//       vsync: this,
//     );

//     _slideAnimation = Tween<Offset>(
//       begin: const Offset(0, -1),
//       end: const Offset(0, 0.1),
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.elasticOut,
//     ));

//     _opacityAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: const Interval(0.3, 1.0),
//     ));

//     Future.delayed(const Duration(milliseconds: 50), () {
//       if (mounted) {
//         _animationController.forward();
//       }
//     });

//     _setupGestureDetector();
//   }

//   void _setupGestureDetector() {
//     // Logique de swipe si nécessaire
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   String _getNotificationText() {
//     switch (widget.type) {
//       case MatchRequestDeclinedNotificationType.declined:
//         return 'a refusé votre demande de match';
//     }
//   }

//   Color _getNotificationColor() {
//     switch (widget.type) {
//       case MatchRequestDeclinedNotificationType.declined:
//         return const Color(0xFFff006e); // Rouge pour le refus
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: widget.onTap,
//       onVerticalDragUpdate: (details) {
//         if (details.primaryDelta! < -5) {
//           widget.onSwipe();
//         }
//       },
//       child: SlideTransition(
//         position: _slideAnimation,
//         child: FadeTransition(
//           opacity: _opacityAnimation,
//           child: Container(
//             margin: const EdgeInsets.fromLTRB(16, 50, 16, 0),
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//                 colors: [
//                   _getNotificationColor(),
//                   _getNotificationColor().withOpacity(0.8),
//                 ],
//               ),
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(
//                 color: Colors.white.withOpacity(0.3),
//                 width: 2,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.5),
//                   blurRadius: 20,
//                   spreadRadius: 2,
//                 ),
//                 BoxShadow(
//                   color: _getNotificationColor().withOpacity(0.3),
//                   blurRadius: 15,
//                   spreadRadius: 1,
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 // Avatar du joueur qui a refusé
//                                                     Container(
//   width: 50,
//   height: 50,
//   decoration: BoxDecoration(
//     shape: BoxShape.circle,
//     gradient: LinearGradient(
//       colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
//     ),
//     border: Border.all(color: Colors.white, width: 2),
//   ),
//   child: ClipOval( // Force le clip circulaire
//     child:Image.network(
//            widget.player.displayAvatar,
//             fit: BoxFit.cover,
//             width: 50,
//             height: 50,
//             errorBuilder: (context, error, stackTrace) => 
//               Icon(Icons.person, size: 20, color: Colors.white),
//           )
//   ),
// ),
                
//                 const SizedBox(width: 12),
                
//                 // Contenu de la notification
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         widget.player.username,
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 16,
//                           fontWeight: FontWeight.w900,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         _getNotificationText(),
//                         style: TextStyle(
//                           color: Colors.white.withOpacity(0.9),
//                           fontSize: 14,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                       if (widget.reason.isNotEmpty) ...[
//                         const SizedBox(height: 4),
//                         Text(
//                           '"${_truncateReason(widget.reason)}"',
//                           style: TextStyle(
//                             color: Colors.white.withOpacity(0.8),
//                             fontSize: 12,
//                             fontStyle: FontStyle.italic,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
                
//                 // Bouton de fermeture
//                 IconButton(
//                   onPressed: widget.onTap,
//                   icon: const Icon(
//                     Icons.close,
//                     color: Colors.white,
//                     size: 20,
//                   ),
//                   padding: EdgeInsets.zero,
//                   constraints: const BoxConstraints(
//                     minWidth: 30,
//                     minHeight: 30,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   String _truncateReason(String reason) {
//     if (reason.length <= 25) return reason;
//     return '${reason.substring(0, 25)}...';
//   }
// }
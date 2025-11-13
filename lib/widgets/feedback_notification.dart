import 'package:flutter/material.dart';
import 'package:jeu_carre/models/feedback.dart';
import 'package:jeu_carre/models/message.dart';
import 'package:jeu_carre/models/player.dart';

enum FeedbackNotificationType {
  newMessage,
  interaction,
}

class FeedbackNotification extends StatefulWidget {
  final FeedbackNotificationType type;
  final Message message;
  final Player? interactor;
  final InteractionType? interactionType;
  final VoidCallback onTap;
  final VoidCallback onSwipe;

  const FeedbackNotification({
    Key? key,
    required this.type,
    required this.message,
    this.interactor,
    this.interactionType,
    required this.onTap,
    required this.onSwipe,
  }) : super(key: key);

  @override
  _FeedbackNotificationState createState() => _FeedbackNotificationState();
}

class _FeedbackNotificationState extends State<FeedbackNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1), // Descend du haut
      end: const Offset(0, 0.1), // S'arrête légèrement en dessous du bord supérieur
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0),
    ));

    // Démarrer l'animation immédiatement
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _animationController.forward();
      }
    });

    // Gesture detector pour le swipe
    _setupGestureDetector();
  }

  void _setupGestureDetector() {
    // Vous pouvez ajouter la logique de swipe ici si nécessaire
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getNotificationText() {
    switch (widget.type) {
      case FeedbackNotificationType.newMessage:
        return 'vient de laisser une recommandation';
      case FeedbackNotificationType.interaction:
        if (widget.interactionType == InteractionType.like) {
          return 'aime votre recommandation';
        } else {
          return "n'aime pas votre recommandation";
        }
    }
  }

  Color _getNotificationColor() {
    switch (widget.type) {
      case FeedbackNotificationType.newMessage:
        return const Color(0xFF2d0052);
      case FeedbackNotificationType.interaction:
        if (widget.interactionType == InteractionType.like) {
          return const Color(0xFF2d0052);
        } else {
          return const Color(0xFFff006e);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.type == FeedbackNotificationType.newMessage 
        ? _getMessagePlayer()
        : widget.interactor;

    if (player == null) return const SizedBox();

    return GestureDetector(
      onTap: widget.onTap,
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! < -5) { // Swipe vers le haut
          widget.onSwipe();
        }
      },
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 50, 16, 0), // Positionné en haut
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getNotificationColor(),
                  _getNotificationColor().withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: _getNotificationColor().withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar du joueur
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      player.displayAvatar,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Contenu de la notification
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getNotificationText(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (widget.type == FeedbackNotificationType.newMessage) ...[
                        const SizedBox(height: 4),
                        Text(
                          _truncateContent(widget.message.content),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Bouton de fermeture
                IconButton(
                  onPressed: widget.onTap,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Player _getMessagePlayer() {
    return Player.fromBasicInfo(
      id: widget.message.userId,
      username: widget.message.username,
      email: '',
      avatarUrl: widget.message.userAvatarUrl,
      defaultEmoji: widget.message.userDefaultEmoji,
      createdAt: DateTime.now(),
    );
  }

  String _truncateContent(String content) {
    if (content.length <= 30) return content;
    return '${content.substring(0, 30)}...';
  }
}
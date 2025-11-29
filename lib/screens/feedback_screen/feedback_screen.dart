import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeu_carre/models/feedback.dart';
import 'package:jeu_carre/models/message.dart';
import 'package:jeu_carre/services/feedback_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  FeedbackCategory? _selectedCategory;
  final ScrollController _scrollController = ScrollController();
  bool _showCategoryAboveInput = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAdmin = false;

  // Stream pour les messages
  Stream<List<Message>>? _messagesStream;
  
  // Cache local pour les interactions (optimisation likes/dislikes)
  final Map<String, Map<InteractionType, bool>> _localInteractions = {};
  final Map<String, int> _localLikesCount = {};
  final Map<String, int> _localDislikesCount = {};

@override
void initState() {
  super.initState();
  _loadMessages();
  _checkAdminStatus();
  
  // Écouter le focus pour afficher le modal de catégorie (uniquement pour les non-admins)
  _messageFocusNode.addListener(() {
    if (_messageFocusNode.hasFocus && _selectedCategory == null && !_isAdmin) {
      _showCategoryModal();
    }
  });

  // Scroll to bottom when messages load
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _scrollToBottom();
  });
}

  void _loadMessages() {
    setState(() {
      _messagesStream = FeedbackService.getPublicMessages(limit: 50);
    });
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await FeedbackService.isUserAdmin();
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  void _showCategoryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2d0052),
                Color(0xFF1a0033),
              ],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4a0080), Color(0xFF2d0052)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Color(0xFF9c27b0)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.category, color: Color(0xFF00d4ff), size: 40),
                      SizedBox(height: 12),
                      Text(
                        'Choisissez une catégorie',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Cela nous aide à mieux traiter votre message',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                GridView.count(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  padding: EdgeInsets.all(16),
                  childAspectRatio: 2.5,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: FeedbackCategory.values.map((category) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedCategory = category;
                          _showCategoryAboveInput = true;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF4a0080),
                              Color(0xFF2d0052),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Color(0xFF9c27b0),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              category.emoji,
                              style: TextStyle(fontSize: 20),
                            ),
                            SizedBox(width: 8),
                            Text(
                              category.displayName,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

Future<void> _sendMessage() async {
  // Si ce n'est pas un admin ET qu'aucune catégorie n'est sélectionnée, afficher le modal
  if (!_isAdmin && _selectedCategory == null) {
    _showCategoryModal();
    return;
  }

  if (_messageController.text.trim().isEmpty) {
    _showError('Veuillez écrire un message');
    return;
  }

  if (_isLoading) return;

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    await FeedbackService.createFeedback(
      category: _selectedCategory ?? FeedbackCategory.other, // Utiliser "other" par défaut si admin
      content: _messageController.text.trim(),
      isPublic: true,
    );

    setState(() {
      _messageController.clear();
      _selectedCategory = null;
      _showCategoryAboveInput = false;
    });

    // Scroll vers le bas pour voir le nouveau message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  } catch (e) {
    _showError('Erreur lors de l\'envoi: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
  Future<void> _likeMessage(String messageId, int currentLikes, int currentDislikes) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userInteractionKey = '${currentUser.uid}_$messageId';
    final isCurrentlyLiked = _localInteractions[userInteractionKey]?[InteractionType.like] ?? false;
    final isCurrentlyDisliked = _localInteractions[userInteractionKey]?[InteractionType.dislike] ?? false;

    // Mise à jour immédiate de l'UI
    setState(() {
      // Initialiser les compteurs locaux si nécessaire
      if (!_localLikesCount.containsKey(messageId)) {
        _localLikesCount[messageId] = currentLikes;
      }
      if (!_localDislikesCount.containsKey(messageId)) {
        _localDislikesCount[messageId] = currentDislikes;
      }

      // Gérer la logique des interactions
      if (isCurrentlyLiked) {
        // Retirer le like
        _localLikesCount[messageId] = _localLikesCount[messageId]! - 1;
        _localInteractions[userInteractionKey] = {
          InteractionType.like: false,
          InteractionType.dislike: isCurrentlyDisliked,
        };
      } else {
        // Ajouter le like
        _localLikesCount[messageId] = _localLikesCount[messageId]! + 1;
        
        // Retirer le dislike si présent
        if (isCurrentlyDisliked) {
          _localDislikesCount[messageId] = _localDislikesCount[messageId]! - 1;
        }
        
        _localInteractions[userInteractionKey] = {
          InteractionType.like: true,
          InteractionType.dislike: false,
        };
      }
    });

    // Appel Firebase en arrière-plan
    try {
      await FeedbackService.toggleInteraction(
        messageId: messageId,
        type: InteractionType.like,
      );
    } catch (e) {
      // En cas d'erreur, on revert les changements locaux
      setState(() {
        if (isCurrentlyLiked) {
          _localLikesCount[messageId] = currentLikes;
        } else {
          _localLikesCount[messageId] = currentLikes;
          if (isCurrentlyDisliked) {
            _localDislikesCount[messageId] = currentDislikes;
          }
        }
        _localInteractions.remove(userInteractionKey);
      });
      _showError('Erreur like: $e');
    }
  }

  Future<void> _dislikeMessage(String messageId, int currentLikes, int currentDislikes) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userInteractionKey = '${currentUser.uid}_$messageId';
    final isCurrentlyLiked = _localInteractions[userInteractionKey]?[InteractionType.like] ?? false;
    final isCurrentlyDisliked = _localInteractions[userInteractionKey]?[InteractionType.dislike] ?? false;

    // Mise à jour immédiate de l'UI
    setState(() {
      // Initialiser les compteurs locaux si nécessaire
      if (!_localLikesCount.containsKey(messageId)) {
        _localLikesCount[messageId] = currentLikes;
      }
      if (!_localDislikesCount.containsKey(messageId)) {
        _localDislikesCount[messageId] = currentDislikes;
      }

      // Gérer la logique des interactions
      if (isCurrentlyDisliked) {
        // Retirer le dislike
        _localDislikesCount[messageId] = _localDislikesCount[messageId]! - 1;
        _localInteractions[userInteractionKey] = {
          InteractionType.like: isCurrentlyLiked,
          InteractionType.dislike: false,
        };
      } else {
        // Ajouter le dislike
        _localDislikesCount[messageId] = _localDislikesCount[messageId]! + 1;
        
        // Retirer le like si présent
        if (isCurrentlyLiked) {
          _localLikesCount[messageId] = _localLikesCount[messageId]! - 1;
        }
        
        _localInteractions[userInteractionKey] = {
          InteractionType.like: false,
          InteractionType.dislike: true,
        };
      }
    });

    // Appel Firebase en arrière-plan
    try {
      await FeedbackService.toggleInteraction(
        messageId: messageId,
        type: InteractionType.dislike,
      );
    } catch (e) {
      // En cas d'erreur, on revert les changements locaux
      setState(() {
        if (isCurrentlyDisliked) {
          _localDislikesCount[messageId] = currentDislikes;
        } else {
          _localDislikesCount[messageId] = currentDislikes;
          if (isCurrentlyLiked) {
            _localLikesCount[messageId] = currentLikes;
          }
        }
        _localInteractions.remove(userInteractionKey);
      });
      _showError('Erreur dislike: $e');
    }
  }

  // Méthode pour obtenir le compteur local ou le compteur d'origine
  int _getLocalLikesCount(String messageId, int originalLikes) {
    return _localLikesCount[messageId] ?? originalLikes;
  }

  int _getLocalDislikesCount(String messageId, int originalDislikes) {
    return _localDislikesCount[messageId] ?? originalDislikes;
  }

  // Méthode pour vérifier l'état local des interactions
  bool _isLikedByCurrentUser(String messageId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;
    final userInteractionKey = '${currentUser.uid}_$messageId';
    return _localInteractions[userInteractionKey]?[InteractionType.like] ?? false;
  }

  bool _isDislikedByCurrentUser(String messageId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;
    final userInteractionKey = '${currentUser.uid}_$messageId';
    return _localInteractions[userInteractionKey]?[InteractionType.dislike] ?? false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showAdminResponseDialog(String messageId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdminResponseDialog(
        messageId: messageId,
        onSuccess: () {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text('Réponse envoyée avec succès'),
          //     backgroundColor: Colors.green,
          //     duration: Duration(seconds: 2),
          //   ),
          // );
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $error'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Color(0xFF2d0052),
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Supprimer le message',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Êtes-vous sûr de vouloir supprimer ce message ? Cette action est irréversible.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Annuler', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Supprimer'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await FeedbackService.deleteMessage(messageId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message supprimé avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showError('Erreur lors de la suppression: $e');
    }
  }

  // NOUVELLE MÉTHODE POUR LES MESSAGES ADMIN
  Widget _buildAdminMessage(Message message, int displayLikes, int displayDislikes, bool isLiked, bool isDisliked) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16, horizontal: MediaQuery.of(context).size.width * 0.05),
      width: MediaQuery.of(context).size.width * 0.9,
      child: Column(
        children: [
          // En-tête admin avec photo et nom
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Photo de l'admin
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipOval(
                  child: message.userAvatarUrl != null
                      ? Image.network(
                          message.userAvatarUrl!,
                          fit: BoxFit.cover,
                          width: 40,
                          height: 40,
                          errorBuilder: (context, error, stackTrace) => 
                            Icon(Icons.admin_panel_settings, size: 16, color: Colors.white),
                        )
                      : Icon(Icons.admin_panel_settings, size: 16, color: Colors.white),
                ),
              ),
              SizedBox(width: 8),
              // Nom de l'admin
              Text(
                'Équipe Shikaku',
                style: TextStyle(
                  color: Color(0xFF00d4ff),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          
          // Bulle de message admin (même design que les réponses admin)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF00d4ff).withOpacity(0.15),
                  Color(0xFF0099cc).withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Color(0xFF00d4ff),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contenu du message
                Text(
                  message.content,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 8),
                
                // Date et heure
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTime(message.createdAt),
                      style: TextStyle(
                        color: Color(0xFF00d4ff).withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),],
                ),
              ],
            ),
          ),
          
          // Interactions (likes/dislikes) - optionnel pour les messages admin
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Bouton Like
              GestureDetector(
                onTap: () => _likeMessage(message.id, message.likesCount, message.dislikesCount),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLiked ? Color(0xFF00d4ff).withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isLiked ? Color(0xFF00d4ff) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.thumb_up, 
                        color: isLiked ? Color(0xFF00d4ff) : Color(0xFF00d4ff).withOpacity(0.7), 
                        size: 16
                      ),
                      SizedBox(width: 6),
                      Text(
                        displayLikes.toString(),
                        style: TextStyle(
                          color: isLiked ? Color(0xFF00d4ff) : Color(0xFF00d4ff).withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16),
              
              // Bouton Dislike
              GestureDetector(
                onTap: () => _dislikeMessage(message.id, message.likesCount, message.dislikesCount),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDisliked ? Color(0xFFff006e).withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDisliked ? Color(0xFFff006e) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.thumb_down, 
                        color: isDisliked ? Color(0xFFff006e) : Color(0xFFff006e).withOpacity(0.7), 
                        size: 16
                      ),
                      SizedBox(width: 6),
                      Text(
                        displayDislikes.toString(),
                        style: TextStyle(
                          color: isDisliked ? Color(0xFFff006e) : Color(0xFFff006e).withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: isDisliked ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      SizedBox(width:8),
                                          // Bouton Suppression pour admin (à côté des interactions)
                    if (_isAdmin) ...[
                      SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _deleteMessage(message.id),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: Colors.red.withOpacity(0.7),
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Message message) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCurrentUser = message.userId == currentUser?.uid;
    final isAdminMessage = message.isAdminMessage ?? false; // Vérifier si c'est un message admin
    
    // Utiliser les compteurs locaux si disponibles
    final displayLikes = _getLocalLikesCount(message.id, message.likesCount);
    final displayDislikes = _getLocalDislikesCount(message.id, message.dislikesCount);
    final isLiked = _isLikedByCurrentUser(message.id);
    final isDisliked = _isDislikedByCurrentUser(message.id);
    
    // Si c'est un message admin, afficher au centre avec le design spécial
    if (isAdminMessage) {
      return _buildAdminMessage(message, displayLikes, displayDislikes, isLiked, isDisliked);
    }
    
    // Sinon, afficher le message normal
    return Container(
      margin: EdgeInsets.only(bottom: 16, left: isCurrentUser ? 50 : 0, right: isCurrentUser ? 0 : 50),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF9c27b0), Color(0xFFe040fb)],
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF9c27b0).withOpacity(0.5),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: ClipOval( // Force le clip circulaire
                child: message.userAvatarUrl != null
                    ? Image.network(
                        message.userAvatarUrl!,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        errorBuilder: (context, error, stackTrace) => 
                          Icon(Icons.person, size: 20, color: Colors.white),
                      )
                    : Image.network(
                        message.userDefaultEmoji,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        errorBuilder: (context, error, stackTrace) => 
                          Icon(Icons.person, size: 20, color: Colors.white),
                      ),
              ),
            ),
            
            SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // En-tête du message
                Row(
                  mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Text(
                      message.username,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(0xFF9c27b0).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        message.category.emoji,
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                
                // Bulle de message
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isCurrentUser
                          ? [Color(0xFF9c27b0), Color(0xFF7b1fa2)]
                          : [Color(0xFF2d0052), Color(0xFF1a0033)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                      bottomLeft: isCurrentUser ? Radius.circular(15) : Radius.circular(5),
                      bottomRight: isCurrentUser ? Radius.circular(5) : Radius.circular(15),
                    ),
                    border: Border.all(
                      color: isCurrentUser ? Color(0xFFe040fb) : Color(0xFF6200b3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        _formatDateTime(message.createdAt),
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Réponse admin si disponible
                if (message.hasResponse) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF00d4ff).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF00d4ff)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.admin_panel_settings, color: Color(0xFF00d4ff), size: 12),
                            SizedBox(width: 6),
                            Text(
                              'Équipe Shikaku',
                              style: TextStyle(
                                color: Color(0xFF00d4ff),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              _formatDateTime(message.respondedAt!),
                              style: TextStyle(
                                color: Color(0xFF00d4ff).withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          message.adminResponse!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Interactions et actions admin
                SizedBox(height: 6),
                Row(
                  mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    // Bouton Like
                    GestureDetector(
                      onTap: () => _likeMessage(message.id, message.likesCount, message.dislikesCount),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLiked ? Color(0xFF00d4ff).withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isLiked ? Color(0xFF00d4ff) : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.thumb_up, 
                              color: isLiked ? Color(0xFF00d4ff) : Color(0xFF00d4ff).withOpacity(0.7), 
                              size: 14
                            ),
                            SizedBox(width: 4),
                            Text(
                              displayLikes.toString(),
                              style: TextStyle(
                                color: isLiked ? Color(0xFF00d4ff) : Color(0xFF00d4ff).withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    
                    // Bouton Dislike
                    GestureDetector(
                      onTap: () => _dislikeMessage(message.id, message.likesCount, message.dislikesCount),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDisliked ? Color(0xFFff006e).withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDisliked ? Color(0xFFff006e) : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.thumb_down, 
                              color: isDisliked ? Color(0xFFff006e) : Color(0xFFff006e).withOpacity(0.7), 
                              size: 14
                            ),
                            SizedBox(width: 4),
                            Text(
                              displayDislikes.toString(),
                              style: TextStyle(
                                color: isDisliked ? Color(0xFFff006e) : Color(0xFFff006e).withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: isDisliked ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Bouton Suppression pour admin (à côté des interactions)
                    if (_isAdmin) ...[
                      SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _deleteMessage(message.id),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: Colors.red.withOpacity(0.7),
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                // Bouton réponse admin (en dessous)
                if (_isAdmin && !message.hasResponse) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showAdminResponseDialog(message.id),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFF00d4ff).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(0xFF00d4ff)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.reply, color: Color(0xFF00d4ff), size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Répondre',
                                style: TextStyle(
                                  color: Color(0xFF00d4ff),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isCurrentUser) ...[
            SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF9c27b0), Color(0xFFe040fb)],
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF9c27b0).withOpacity(0.5),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: ClipOval( // Force le clip circulaire
                child: message.userAvatarUrl != null
                    ? Image.network(
                        message.userAvatarUrl!,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        errorBuilder: (context, error, stackTrace) => 
                          Icon(Icons.person, size: 20, color: Colors.white),
                      )
                    : Image.network(
                        message.userDefaultEmoji,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        errorBuilder: (context, error, stackTrace) => 
                          Icon(Icons.person, size: 20, color: Colors.white),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    
    String dateString;
    if (messageDate == today) {
      dateString = "Aujourd'hui";
    } else if (messageDate == today.subtract(Duration(days: 1))) {
      dateString = 'Hier';
    } else {
      dateString = '${date.day}/${date.month}/${date.year}';
    }
    
    final timeString = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    
    return '$dateString à $timeString';
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF00d4ff),
          ),
          SizedBox(height: 16),
          Text(
            'Chargement des messages...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: Color(0xFF4a0080),
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Aucun message pour le moment',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Soyez le premier à partager votre avis !',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadMessages,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF9c27b0),
            ),
            child: Text('Réessayer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a0033),
              Color(0xFF2d0052),
              Color(0xFF0a0015),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'VOTRE AVIS COMPTE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'L\'équipe Shikaku vous écoute',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Liste des messages
              Expanded(
                child: StreamBuilder<List<Message>>(
                  
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    
                    
                    
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingIndicator();
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState();
                    }

                    final messages = snapshot.data ?? [];

                    if (messages.isEmpty) {
                      return _buildEmptyState();
                    }

                    // Sort messages by date (oldest first for proper display)
                    final sortedMessages = List<Message>.from(messages)
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: false, // Changed to false since we're sorting manually
                      padding: EdgeInsets.all(16),
                      itemCount: sortedMessages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageItem(sortedMessages[index]);
                      },
                    );
                  },
                ),
              ),

              // Vérification de connexion
              if (currentUser == null) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.orange.withOpacity(0.2),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Connectez-vous pour envoyer des messages',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Zone de saisie (fixe en bas)
              if (currentUser != null)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF1a0033),
                    border: Border(
                      top: BorderSide(color: Color(0xFF6200b3), width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Catégorie sélectionnée au-dessus du champ
                      if (_showCategoryAboveInput && _selectedCategory != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          margin: EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFF9c27b0).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Color(0xFF9c27b0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedCategory!.emoji,
                                style: TextStyle(fontSize: 14),
                              ),
                              SizedBox(width: 6),
                              Text(
                                _selectedCategory!.displayName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = null;
                                    _showCategoryAboveInput = false;
                                  });
                                },
                                child: Icon(Icons.close, color: Colors.white70, size: 14),
                              ),
                            ],
                          ),
                        ),
                      
                      // Champ de saisie
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Color(0xFF2d0052),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(color: Color(0xFF9c27b0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                        controller: _messageController,
                                        focusNode: _messageFocusNode,
                                        maxLines: null,
                                        textInputAction: TextInputAction.newline,
                                        keyboardType: TextInputType.multiline,
                                        style: TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          hintText: _isAdmin 
                                              ? 'Écrivez un message (admin)...' 
                                              : 'Tapez votre message...',
                                          hintStyle: TextStyle(color: Colors.white54),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF9c27b0), Color(0xFF7b1fa2)],
                              ),
                            ),
                            child: _isLoading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(Icons.send, color: Colors.white),
                                    onPressed: _sendMessage,
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// Nouveau Widget StatefulWidget séparé pour le dialogue
class AdminResponseDialog extends StatefulWidget {
  final String messageId;
  final VoidCallback onSuccess;
  final Function(String) onError;

  const AdminResponseDialog({
    Key? key,
    required this.messageId,
    required this.onSuccess,
    required this.onError,
  }) : super(key: key);

  @override
  State<AdminResponseDialog> createState() => _AdminResponseDialogState();
}

class _AdminResponseDialogState extends State<AdminResponseDialog> {
  final TextEditingController _responseController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: Color(0xFF2d0052),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFF9c27b0), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF9c27b0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: Color(0xFF00d4ff), size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Réponse Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        minHeight: 100,
                        maxHeight: 200,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFF1a0033),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFF9c27b0)),
                      ),
                      padding: EdgeInsets.all(12),
                      child: TextField(
                        controller: _responseController,
                        enabled: !_isSending,
                        maxLines: null,
                        autofocus: true,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Tapez votre réponse...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF9c27b0)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSending ? null : () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Annuler',
                      style: TextStyle(
                        color: _isSending ? Colors.white30 : Colors.white70,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSending ? null :() async {
                          if (_responseController.text.trim().isEmpty) {
                            widget.onError('Veuillez écrire une réponse');
                            return;
                          }

                          setState(() {
                            _isSending = true;
                          });

                          try {
                            final currentUser = FirebaseAuth.instance.currentUser;
                            if (currentUser == null) {
                              throw Exception('Utilisateur non connecté');
                            }

                            await FeedbackService.updateMessageAdminResponse(
                              messageId: widget.messageId,
                              adminResponse: _responseController.text.trim(),
                              adminId: currentUser.uid,
                            );

                            if (mounted) {
                              Navigator.of(context).pop();
                              widget.onSuccess();
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                _isSending = false;
                              });
                              widget.onError(e.toString());
                            }
                          }
                      
                      },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00d4ff),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isSending
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Envoyer',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
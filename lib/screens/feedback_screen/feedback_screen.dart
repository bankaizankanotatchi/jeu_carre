import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jeu_carre/models/player.dart';
import 'package:jeu_carre/services/PlayerService.dart';

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

  // Streams pour les données
  Stream<Player>? _playerStream;
  Stream<List<Player>>? _allPlayersStream;

  @override
  void initState() {
    super.initState();
    _loadPlayerData();
    _checkAdminStatus();
    
    // MODIFICATION : Le modal s'affiche quand on clique sur le champ de texte
    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus && _selectedCategory == null && !_isAdmin) {
        _showCategoryModal();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _loadPlayerData() {
    setState(() {
      _playerStream = PlayerService.getCurrentPlayerStream();
      if (_isAdmin) {
        _allPlayersStream = PlayerService.getAllPlayersWithMessages();
      }
    });
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await PlayerService.isUserAdmin();
    setState(() {
      _isAdmin = isAdmin;
      if (_isAdmin) {
        _allPlayersStream = PlayerService.getAllPlayersWithMessages();
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  // MODIFICATION : Modal amélioré avec meilleure gestion
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
                        // Remettre le focus après sélection
                        FocusScope.of(context).requestFocus(_messageFocusNode);
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
    // MODIFICATION : Toujours afficher le modal si pas de catégorie (sauf admin)
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
      await PlayerService.addUserMessage(
        category: _selectedCategory ?? FeedbackCategory.other,
        content: _messageController.text.trim(),
      );

      setState(() {
        _messageController.clear();
        _selectedCategory = null;
        _showCategoryAboveInput = false;
      });

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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // NOUVEAU : Widget pour afficher la réponse admin
  void _showAdminResponseDialog(String playerId, String messageId, String playerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdminResponseDialog(
        playerId: playerId,
        messageId: messageId,
        playerName: playerName,
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Réponse envoyée avec succès'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
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

  // MODIFICATION : Widget message avec photo de profil
  Widget _buildMessageItem(UserMessage message, Player player, {bool isAdminView = false}) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCurrentUser = player.id == currentUser?.uid;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo de profil
          if (!isAdminView || isCurrentUser) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF9c27b0), Color(0xFFe040fb)],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF9c27b0).withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: player.hasAvatarImage
                    ? Image.network(
                        player.avatarUrl!,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        errorBuilder: (context, error, stackTrace) => 
                          Icon(Icons.person, size: 20, color: Colors.white),
                      )
                    : Center(
                        child: Text(
                          player.defaultEmoji,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
              ),
            ),
            SizedBox(width: 12),
          ],
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec nom d'utilisateur
                if (isAdminView && !isCurrentUser) ...[
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF9c27b0), Color(0xFFe040fb)],
                          ),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: ClipOval(
                          child: player.hasAvatarImage
                              ? Image.network(
                                  player.avatarUrl!,
                                  fit: BoxFit.cover,
                                  width: 32,
                                  height: 32,
                                  errorBuilder: (context, error, stackTrace) => 
                                    Icon(Icons.person, size: 16, color: Colors.white),
                                )
                              : Center(
                                  child: Text(
                                    player.defaultEmoji,
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        player.username,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                ],
                
                // Message de l'utilisateur
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
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
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              message.category.emoji,
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            message.category.displayName,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
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
                
                // Bouton réponse admin (uniquement en vue admin pour les autres utilisateurs)
                if (_isAdmin && isAdminView && !isCurrentUser && !message.hasResponse) ...[
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showAdminResponseDialog(player.id, message.id, player.username),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF00d4ff).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NOUVELLE MÉTHODE : Construire la vue admin
  Widget _buildAdminView(List<Player> allPlayers) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    // Filtrer pour enlever l'admin actuel et ne garder que ceux avec des messages
    final playersWithMessages = allPlayers
        .where((player) => player.id != currentUserId && player.messages.isNotEmpty)
        .toList();

    if (playersWithMessages.isEmpty) {
      return _buildEmptyAdminState();
    }

    // Créer une liste de tous les messages avec référence au joueur
    final allMessages = <Map<String, dynamic>>[];
    for (final player in playersWithMessages) {
      for (final message in player.messages) {
        allMessages.add({
          'player': player,
          'message': message,
        });
      }
    }

    // Trier par date (plus récent en premier)
    allMessages.sort((a, b) => b['message'].createdAt.compareTo(a['message'].createdAt));

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: allMessages.length,
      itemBuilder: (context, index) {
        final player = allMessages[index]['player'] as Player;
        final message = allMessages[index]['message'] as UserMessage;
        return _buildMessageItem(message, player, isAdminView: true);
      },
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
            'Chargement...',
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
            'Envoyez votre premier message à l\'équipe !',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAdminState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            color: Color(0xFF4a0080),
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Aucun message utilisateur',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Les utilisateurs n\'ont pas encore envoyé de messages',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitReachedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            color: Color(0xFF9c27b0),
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Limite de messages atteinte',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Vous avez déjà envoyé 3 messages.\nL\'équipe vous répondra bientôt.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
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
                      _isAdmin ? 'MESSAGES UTILISATEURS' : 'VOS MESSAGES',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _isAdmin 
                          ? 'Répondez aux messages des utilisateurs'
                          : 'Communiquez avec l\'équipe Shikaku',
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
                child: _isAdmin
                    ? StreamBuilder<List<Player>>(
                        stream: _allPlayersStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return _buildLoadingIndicator();
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Erreur de chargement',
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                          }
                          final allPlayers = snapshot.data ?? [];
                          return _buildAdminView(allPlayers);
                        },
                      )
                    : StreamBuilder<Player>(
                        stream: _playerStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return _buildLoadingIndicator();
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Erreur de chargement',
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                          }
                          final player = snapshot.data;
                          final messages = player?.messages ?? [];

                          if (messages.isEmpty) {
                            return _buildEmptyState();
                          }

                          final sortedMessages = List<UserMessage>.from(messages)
                            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                          return ListView.builder(
                            controller: _scrollController,
                            reverse: false,
                            padding: EdgeInsets.all(16),
                            itemCount: sortedMessages.length,
                            itemBuilder: (context, index) {
                              return _buildMessageItem(sortedMessages[index], player!);
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

              // Zone de saisie (uniquement pour les non-admins qui peuvent encore envoyer)
              if (currentUser != null && !_isAdmin)
                StreamBuilder<Player>(
                  stream: _playerStream,
                  builder: (context, snapshot) {
                    final player = snapshot.data;
                    final canSendMessage = player?.canSendMessage ?? true;
                    final remainingMessages = player?.remainingMessages ?? 3;

                    if (!canSendMessage) {
                      return _buildLimitReachedState();
                    }

                    return Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFF1a0033),
                        border: Border(
                          top: BorderSide(color: Color(0xFF6200b3), width: 1),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Indicateur de messages restants
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            margin: EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Color(0xFF9c27b0).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.message, color: Color(0xFF9c27b0), size: 14),
                                SizedBox(width: 6),
                                Text(
                                  '$remainingMessages message${remainingMessages > 1 ? 's' : ''} restant${remainingMessages > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    color: Color(0xFF9c27b0),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Catégorie sélectionnée
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
                          
                          // Champ de saisie avec bouton pour ouvrir le modal
                          Row(
                            children: [
                              // Bouton pour ouvrir le modal de catégorie
                              GestureDetector(
                                onTap: _showCategoryModal,
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF4a0080), Color(0xFF2d0052)],
                                    ),
                                    border: Border.all(color: Color(0xFF9c27b0)),
                                  ),
                                  child: Icon(
                                    _selectedCategory != null 
                                        ? Icons.check
                                        : Icons.category,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
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
                                            hintText: 'Tapez votre message...',
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
                    );
                  },
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

// NOUVEAU : Dialog pour la réponse admin
class AdminResponseDialog extends StatefulWidget {
  final String playerId;
  final String messageId;
  final String playerName;
  final VoidCallback onSuccess;
  final Function(String) onError;

  const AdminResponseDialog({
    Key? key,
    required this.playerId,
    required this.messageId,
    required this.playerName,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Réponse à ${widget.playerName}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Votre réponse sera visible par l\'utilisateur',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
                    onPressed: _isSending ? null : () async {
                      if (_responseController.text.trim().isEmpty) {
                        widget.onError('Veuillez écrire une réponse');
                        return;
                      }

                      setState(() {
                        _isSending = true;
                      });

                      try {
                        await PlayerService.respondToMessage(
                          playerId: widget.playerId,
                          messageId: widget.messageId,
                          adminResponse: _responseController.text.trim(),
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
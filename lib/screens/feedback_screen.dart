import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:jeu_carre/models/feedback.dart';
import 'package:flutter/foundation.dart' as foundation;

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  FeedbackCategory? _selectedCategory;
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _showCategoryAboveInput = false;
  bool _emojiVisible = false; // 👈 visibilité du clavier emoji

  @override
  void initState() {
    super.initState();
    _loadSampleMessages();
    
    // Écouter le focus pour afficher le modal de catégorie
    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus && _selectedCategory == null) {
        _showCategoryModal();
      }
    });
  }

void _toggleEmojiKeyboard() {
  setState(() {
    _emojiVisible = !_emojiVisible;
    if (_emojiVisible) {
      _messageFocusNode.unfocus(); // cache le clavier normal
    } else {
      _messageFocusNode.requestFocus(); // réaffiche le clavier
    }
  });
}



  void _loadSampleMessages() {
    // Données simulées pour la démonstration
    setState(() {
      _messages.addAll([
        Message(
          id: '1',
          userId: 'user1',
          username: 'AlexPro',
          userDefaultEmoji: '🎮',
          category: FeedbackCategory.suggestion,
          content: 'Super jeu ! J\'adorerais avoir plus de niveaux de difficulté pour l\'IA.',
          createdAt: DateTime.now().subtract(Duration(hours: 2)),
          likesCount: 12,
          dislikesCount: 1,
          isPublic: true,
          adminResponse: 'Merci pour votre suggestion ! Nous travaillons sur de nouveaux niveaux de difficulté pour la prochaine mise à jour.',
          respondedAt: DateTime.now().subtract(Duration(hours: 1)),
        ),
        Message(
          id: '2',
          userId: 'user2',
          username: 'SarahShik',
          userDefaultEmoji: '👑',
          category: FeedbackCategory.bug,
          content: 'J\'ai remarqué un bug sur l\'écran de classement quand on tourne l\'appareil.',
          createdAt: DateTime.now().subtract(Duration(days: 1)),
          likesCount: 8,
          dislikesCount: 0,
          isPublic: true,
        ),
        Message(
          id: '3',
          userId: 'user3',
          username: 'MikeStrategy',
          userDefaultEmoji: '⚡',
          category: FeedbackCategory.compliment,
          content: 'Les animations sont magnifiques et le gameplay très addictif ! Merci pour ce jeu génial ! 🚀',
          createdAt: DateTime.now().subtract(Duration(days: 2)),
          likesCount: 25,
          dislikesCount: 2,
          isPublic: true,
          adminResponse: 'Nous sommes ravis que l\'expérience vous plaise ! 🎉',
          respondedAt: DateTime.now().subtract(Duration(days: 1)),
        ),
      ]);
    });
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

  void _sendMessage() {
    if (_selectedCategory == null) {
      _showCategoryModal();
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      return;
    }

    final newMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'current_user',
      username: 'Moi',
      userDefaultEmoji: '😊',
      category: _selectedCategory!,
      content: _messageController.text,
      createdAt: DateTime.now(),
      isPublic: true,
    );

    setState(() {
      _messages.insert(0, newMessage);
      _messageController.clear();
      _selectedCategory = null;
      _showCategoryAboveInput = false;
    });

    // Scroll vers le haut pour voir le nouveau message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _likeMessage(int index) {
    setState(() {
      final message = _messages[index];
      _messages[index] = message.copyWith(
        likesCount: message.likesCount + 1,
      );
    });
  }

  void _dislikeMessage(int index) {
    setState(() {
      final message = _messages[index];
      _messages[index] = message.copyWith(
        dislikesCount: message.dislikesCount + 1,
      );
    });
  }

  Widget _buildMessageItem(Message message, int index) {
    final isCurrentUser = message.username == 'Moi';
    
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
                  colors: [
                    Color(0xFF00d4ff),
                    Color(0xFF0099cc),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  message.userDefaultEmoji,
                  style: TextStyle(fontSize: 16),
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
                
                // Interactions
                SizedBox(height: 6),
                Row(
                  mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _likeMessage(index),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.thumb_up, color: Color(0xFF00d4ff), size: 14),
                            SizedBox(width: 4),
                            Text(
                              message.likesCount.toString(),
                              style: TextStyle(
                                color: Color(0xFF00d4ff),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _dislikeMessage(index),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.thumb_down, color: Color(0xFFff006e), size: 14),
                            SizedBox(width: 4),
                            Text(
                              message.dislikesCount.toString(),
                              style: TextStyle(
                                color: Color(0xFFff006e),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
                  colors: [
                    Color(0xFFe040fb),
                    Color(0xFF9c27b0),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  message.userDefaultEmoji,
                  style: TextStyle(fontSize: 16),
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

  @override
  Widget build(BuildContext context) {
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
                child: ListView(
                  controller: _scrollController,
                  reverse: false,
                  padding: EdgeInsets.all(16),
                  children: [
                    SizedBox(height: 16),
                    ..._messages.asMap().entries.map((entry) {
                      return _buildMessageItem(entry.value, entry.key);
                    }).toList(),
                  ],
                ),
              ),

              // Zone de saisie (fixe en bas)
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
                                    onTap: () {
                                        if (_emojiVisible) {
                                          setState(() => _emojiVisible = false);
                                        }
                                      },
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
                                IconButton(
                                  icon: Icon(Icons.emoji_emotions, color: Color(0xFFe040fb)),
                                  onPressed: _toggleEmojiKeyboard,
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
                          child: IconButton(
                            icon: Icon(Icons.send, color: Colors.white),
                            onPressed: _sendMessage,
                          ),
                        ),
                      ],
                    ),
                     SizedBox(width: 8),
                    // Sélecteur d’emoji
                    if (_emojiVisible)
                      Container(
                        height: 256,
                        color: Color(0xFF1a0033),
                        margin: EdgeInsets.only(top:15),
                        child: EmojiPicker(
                          textEditingController: _messageController,
                          onEmojiSelected: (category, emoji) {
                            _messageController.text += emoji.emoji;
                            _messageController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _messageController.text.length),
                            );
                          },
                          onBackspacePressed: () {
                            final text = _messageController.text;
                            if (text.isNotEmpty) {
                              _messageController.text =
                                  text.characters.skipLast(1).toString(); // supprime dernier emoji ou caractère
                              _messageController.selection = TextSelection.fromPosition(
                                TextPosition(offset: _messageController.text.length),
                              );
                            }
                          },
                          config: Config(
                            height: 256,
                            checkPlatformCompatibility: true,
                            emojiViewConfig: EmojiViewConfig(
                              emojiSizeMax: 28 *
                                  (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0),
                            ),
                            viewOrderConfig: const ViewOrderConfig(
                              top: EmojiPickerItem.categoryBar,
                              middle: EmojiPickerItem.emojiView,
                              bottom: EmojiPickerItem.searchBar,
                            ),
                          ),
                        ),
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

// Modèle Message pour remplacer Feedback
class Message {
  final String id;
  final String userId;
  final String username;
  final String? userAvatarUrl;
  final String userDefaultEmoji;
  final FeedbackCategory category;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  final int dislikesCount;
  final List<String> likedBy;
  final List<String> dislikedBy;
  final String? adminResponseId;
  final String? adminResponse;
  final DateTime? respondedAt;
  final bool isPublic;

  Message({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
    this.userDefaultEmoji = '🎮',
    required this.category,
    required this.content,
    required this.createdAt,
    this.likesCount = 0,
    this.dislikesCount = 0,
    List<String>? likedBy,
    List<String>? dislikedBy,
    this.adminResponseId,
    this.adminResponse,
    this.respondedAt,
    this.isPublic = false,
  }) : likedBy = likedBy ?? [],
       dislikedBy = dislikedBy ?? [];

  bool get hasResponse => adminResponse != null && adminResponse!.isNotEmpty;

  Message copyWith({
    int? likesCount,
    int? dislikesCount,
    List<String>? likedBy,
    List<String>? dislikedBy,
    String? adminResponseId,
    String? adminResponse,
    DateTime? respondedAt,
    bool? isPublic,
  }) {
    return Message(
      id: this.id,
      userId: this.userId,
      username: this.username,
      userAvatarUrl: this.userAvatarUrl,
      userDefaultEmoji: this.userDefaultEmoji,
      category: this.category,
      content: this.content,
      createdAt: this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      dislikesCount: dislikesCount ?? this.dislikesCount,
      likedBy: likedBy ?? this.likedBy,
      dislikedBy: dislikedBy ?? this.dislikedBy,
      adminResponseId: adminResponseId ?? this.adminResponseId,
      adminResponse: adminResponse ?? this.adminResponse,
      respondedAt: respondedAt ?? this.respondedAt,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}
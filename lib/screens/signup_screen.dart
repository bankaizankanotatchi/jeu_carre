// screens/signup_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jeu_carre/screens/login_screen.dart';
import 'package:jeu_carre/services/minio_storage_service.dart';
import 'package:jeu_carre/services/preferences_service.dart';
import 'package:jeu_carre/models/player.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MinioStorageService _minioStorage = MinioStorageService();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;



  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    await _googleSignIn.initialize();
    _googleSignIn.attemptLightweightAuthentication();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de l\'image: $e');
    }
  }

  // NOUVELLE MÉTHODE : Upload vers MinIO
  Future<String?> _uploadImageToMinio(File image, String userId) async {
    try {
      
      // Uploader l'image vers MinIO
      final String imageUrl = await _minioStorage.uploadUserAvatar(image, userId);
      print('✅ Avatar uploadé avec succès vers MinIO: $imageUrl');
      return imageUrl;
    } catch (e) {
      print('❌ Erreur upload avatar MinIO: $e');
      // Si MinIO échoue, on peut utiliser une image par défaut ou null
      return null;
    }
  }

  Future<void> _createPlayerProfile(User user, String username, String? avatarUrl) async {
    final player = Player(
      id: user.uid,
      username: username,
      email: user.email ?? '',
      avatarUrl: avatarUrl, // URL MinIO maintenant
      defaultEmoji: 'https://minio.f2mb.xyz/shikaku/user_avatars/profil_par_defaut.jpg',
      role: UserRole.player,
      totalPoints: 0,
      gamesPlayed: 0,
      gamesWon: 0,
      gamesLost: 0,
      gamesDraw: 0,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
      stats: UserStats(
        dailyPoints: 0,
        weeklyPoints: 0,
        monthlyPoints: 0,
        bestGamePoints: 0,
        winStreak: 0,
        bestWinStreak: 0,
        vsAIRecord: {'beginner': 0, 'intermediate': 0, 'expert': 0},
        feedbacksSent: 0,
        feedbacksLiked: 0,
      ),
      isOnline: true,
      inGame: false,
      achievements: [],
      statusMessage: 'Nouveau joueur !',
    );

    await _firestore.collection('users').doc(user.uid).set(player.toMap());
  }
  
  Future<void> _handleGoogleUser(GoogleSignInAccount googleUser, String username) async {
    try {
      final GoogleSignInAuthentication? googleAuth = await googleUser.authentication;
      
      if (googleAuth == null || googleAuth.idToken == null) {
        throw Exception('Authentication Google échouée - tokens manquants');
      }
      
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final playerDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (!playerDoc.exists) {
          // NOUVEAU : Upload vers MinIO si image sélectionnée
          String? avatarUrl;
          if (_selectedImage != null) {
            avatarUrl = await _uploadImageToMinio(_selectedImage!, user.uid);
          } else {
            // Optionnel : utiliser la photo Google si pas de photo sélectionnée
            final photoUrl = googleUser.photoUrl;
            if (photoUrl != null) {
              avatarUrl = photoUrl;
            }
          }

          await _createPlayerProfile(user, username, avatarUrl);
        } else {
          // Joueur existant - mettre à jour le statut
          await _firestore.collection('users').doc(user.uid).update({
            'isOnline': true,
            'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
          });
        }

        _completeSignup();
      }
    } catch (e) {
      throw Exception('Erreur traitement utilisateur Google: $e');
    }
  }

  Future<void> _signUpWithGoogle() async {
    final username = _usernameController.text.trim();
    
    if (username.isEmpty) {
      _showError('Veuillez entrer un nom de joueur');
      return;
    }
    
    if (username.length < 3) {
      _showError('Le nom d\'utilisateur doit contenir au moins 3 caractères');
      return;
    }

    setState(() => _isLoading = true);
    final bool isUnique = await _isUsernameUnique(username);
    
    if (!isUnique) {
      _showError('Ce nom de joueur est déjà utilisé');
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      await _handleGoogleUser(googleUser, username);
      
    } catch (e) {
      _showError('Erreur Google Sign-In: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _isUsernameUnique(String username) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      print('Erreur vérification nom: $e');
      return false;
    }
  }

  // MODIFIÉ : Utiliser MinIO pour l'upload d'image
  Future<void> _signUpWithEmail() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    if (username.isEmpty) {
      _showError('Veuillez entrer un nom d\'utilisateur');
      return;
    }
    
    if (username.length < 3) {
      _showError('Le nom d\'utilisateur doit contenir au moins 3 caractères');
      return;
    }

    setState(() => _isLoading = true);
    final bool isUnique = await _isUsernameUnique(username);
    setState(() => _isLoading = false);

    if (!isUnique) {
      _showError('Ce nom de joueur est déjà utilisé');
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      _showError('Veuillez entrer un email valide');
      return;
    }

    if (password.length < 6) {
      _showError('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final User? user = userCredential.user;
      
      if (user != null) {
        // MODIFIÉ : Upload vers MinIO au lieu de Firebase Storage
        String? avatarUrl;
        if (_selectedImage != null) {
          avatarUrl = await _uploadImageToMinio(_selectedImage!, user.uid);
          print('✅ Avatar uploadé vers MinIO: $avatarUrl');
        } else {
          print('ℹ️ Aucune image sélectionnée, utilisation avatar par défaut');
        }

        await _createPlayerProfile(user, username, avatarUrl);
        _completeSignup();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Erreur d\'inscription';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Cet email est déjà utilisé';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Le mot de passe est trop faible';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Email invalide';
      }
      _showError('$errorMessage: ${e.message}');
    } catch (e) {
      _showError('Erreur inattendue: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _completeSignup() {
    PreferencesService.setFirstLaunchCompleted();
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFff006e),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildAnimatedParticle(int index) {
    final random = (index * 123) % 100;
    final left = (random % 100).toDouble();
    final top = ((random * 7) % 100).toDouble();
    final size = 2.0 + (random % 4);
    final duration = 3 + (random % 5);
    
    return Positioned(
      left: left.clamp(0, 100) * MediaQuery.of(context).size.width / 100,
      top: top.clamp(0, 100) * 200 / 100,
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
                color: const Color(0xFFe040fb).withOpacity(0.6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFe040fb).withOpacity(0.4),
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

  Widget _buildProfilePicture() {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFF2d0052),
                  Color(0xFF1a0033),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF00d4ff),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00d4ff).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _selectedImage != null
                ? ClipOval(
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                    ),
                  )
                : Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white.withOpacity(0.7),
                  ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00d4ff),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameField() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2d0052),
            Color(0xFF1a0033),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF00d4ff),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00d4ff).withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: _usernameController,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Entrez votre nom de joueur',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.person_outline,
            color: Colors.white.withOpacity(0.7),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
        textCapitalization: TextCapitalization.words,
        maxLength: 20,
      ),
    );
  }

  Widget _buildEmailField() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2d0052),
            Color(0xFF1a0033),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF9c27b0),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9c27b0).withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Entrez votre email',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.email_outlined,
            color: Colors.white.withOpacity(0.7),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2d0052),
            Color(0xFF1a0033),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF9c27b0),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9c27b0).withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Entrez votre mot de passe',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.lock_outline,
            color: Colors.white.withOpacity(0.7),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
              color: Colors.white.withOpacity(0.7),
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4285F4),
            Color(0xFF34A853),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4285F4).withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _isLoading ? null : _signUpWithGoogle,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    'assets/images/google.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Continuer avec Google',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF00d4ff),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _isLoading ? null : _navigateToLogin,
          child: Center(
            child: Text(
              'Déjà un compte ? Se connecter',
              style: TextStyle(
                color: const Color(0xFF00d4ff),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  Widget _buildEmailSignInButton() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFe040fb),
            Color(0xFF9c27b0),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFe040fb).withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _isLoading ? null : _signUpWithEmail,
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Commencer à jouer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0015),
      body: Stack(
        children: [
          ...List.generate(8, (index) => _buildAnimatedParticle(index)),
          
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 30),
                
                // Titre
                Column(
                  children: [
                    Text(
                      'CRÉER VOTRE PROFIL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Personnalisez votre expérience de jeu',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                
                const SizedBox(height: 50),
                
                // Photo de profil
                Column(
                  children: [
                    _buildProfilePicture(),
                    const SizedBox(height: 16),
                    Text(
                      'Photo de profil (optionnelle)',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Champ nom d'utilisateur
                _buildUsernameField(),
                
                // Champs email et mot de passe
                _buildEmailField(),
                _buildPasswordField(),
                
                const SizedBox(height: 30),
                
                // Séparateur
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Shikaku',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Bouton inscription email
                _buildEmailSignInButton(),

                const SizedBox(height: 20),
                
                // Bouton "Se connecter"
                _buildLoginButton(),
                
                const SizedBox(height: 30),
                
                // Note
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Vous pourrez modifier votre photo et votre nom plus tard dans les paramètres.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
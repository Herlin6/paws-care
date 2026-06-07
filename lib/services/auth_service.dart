import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:paws_care/models/user_model.dart';
import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/services/fcm_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Register with email and password
  /// Checks username availability before creating account
  Future<User?> register({
    required String email,
    required String password,
    required String username,
    String role = 'Pengguna',
  }) async {
    // Check username availability first
    final isAvailable = await _firestoreService.isUsernameAvailable(username);
    if (!isAvailable) {
      throw Exception('Username sudah digunakan, silakan gunakan username lain.');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        final userModel = UserModel(
          uid: credential.user!.uid,
          username: username,
          email: email,
          password: password,
          phone: '',
          photoBase64: '',
          role: role,
          createdAt: DateTime.now(),
        );
        await _firestoreService.saveUser(userModel);
      }
      return credential.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Login
  Future<User?> login({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return credential.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Login with Google
  Future<User?> loginWithGoogle() async {
    try {
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _auth.signInWithCredential(credential);

      final user = userCredential.user;

      if (user != null) {
        final existing = await _firestoreService.getUser(user.uid);

        if (existing == null) {
          final userModel = UserModel(
            uid: user.uid,
            username:
                user.displayName ??
                user.email?.split('@').first ??
                'User',
            email: user.email ?? '',
            password: '',
            phone: '',
            photoBase64: '',
            role: 'Pengguna',
            createdAt: DateTime.now(),
          );

          await _firestoreService.saveUser(userModel);
        }
      }

      return user;
    } catch (e) {
      rethrow;
    }
  }

  /// Logout — clears FCM token and signs out from all providers
  Future<void> logout() async {
    final user = _auth.currentUser;

    if (user != null) {
      await FcmService().clearTokenForUser(user.uid);
    }

    await _auth.signOut();
  }

  /// Get current user model
  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await _firestoreService.getUser(user.uid);
  }

  /// Update password in Firebase Auth and Firestore
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
      await _firestoreService.updateUser(user.uid, {'password': newPassword});
    }
  }

  /// Ensure admin account exists.
  /// IMPORTANT: Preserves the currently logged-in user's session.
  Future<void> ensureAdminExists() async {
    // Save reference to the currently logged-in user
    final currentLoggedInUser = _auth.currentUser;

    try {
      // Try to create admin account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: 'admin@gmail.com',
        password: 'admin123',
      );
      if (credential.user != null) {
        final adminUser = UserModel(
          uid: credential.user!.uid,
          username: 'Admin',
          email: 'admin@gmail.com',
          password: 'admin123',
          phone: '',
          photoBase64: '',
          role: 'Admin',
          createdAt: DateTime.now(),
        );
        await _firestoreService.saveUser(adminUser);
      }
      // Sign out the admin account we just created/signed-in
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Admin already exists — only verify Firestore doc if no user is logged in.
        // If a user is already logged in, skip signing in as admin to preserve
        // their session (Firebase Auth replaces the current user on signIn).
        if (currentLoggedInUser == null) {
          try {
            final cred = await _auth.signInWithEmailAndPassword(
              email: 'admin@gmail.com',
              password: 'admin123',
            );
            if (cred.user != null) {
              final existing = await _firestoreService.getUser(cred.user!.uid);
              if (existing == null) {
                final adminUser = UserModel(
                  uid: cred.user!.uid,
                  username: 'Admin',
                  email: 'admin@gmail.com',
                  password: 'admin123',
                  phone: '',
                  photoBase64: '',
                  role: 'Admin',
                  createdAt: DateTime.now(),
                );
                await _firestoreService.saveUser(adminUser);
              }
              await _auth.signOut();
            }
          } catch (_) {
            // Ignore errors
          }
        }
      }
    }
  }
}

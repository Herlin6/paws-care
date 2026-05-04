import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/models/user_model.dart';
import 'package:paws_care/services/firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Register with email and password
  Future<User?> register({
    required String email,
    required String password,
    required String username,
    String role = 'Pengguna',
  }) async {
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

  /// Logout
  Future<void> logout() async {
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

  /// Ensure admin account exists
  Future<void> ensureAdminExists() async {
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
      // Sign out admin so user can login normally
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      // If email-already-in-use, admin already exists - check if Firestore doc exists
      if (e.code == 'email-already-in-use') {
        // Admin already exists, make sure Firestore has the data
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

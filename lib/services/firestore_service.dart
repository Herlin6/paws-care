import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/models/comment_model.dart';
import 'package:paws_care/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================
  // POSTS
  // ============================================================

  Stream<List<PostModel>> streamPosts() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<String> addPost(PostModel post) async {
    final docRef = _db.collection('posts').doc();
    final postWithId = post.copyWith(postId: docRef.id);
    await docRef.set(postWithId.toMap());
    return docRef.id;
  }

  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      data['updatedByUid'] = uid;
    }
    await _db.collection('posts').doc(postId).update(data);
  }

  /// Update post with authorization check.
  /// Admin can only edit their own posts. Admin can delete anyone's post.
  /// Throws exception if admin tries to edit another user's post.
  Future<void> updatePostWithAuth(
    String postId,
    Map<String, dynamic> data,
    String currentUserId,
    String currentUserRole,
  ) async {
    // Fetch the post to check ownership
    final doc = await _db.collection('posts').doc(postId).get();
    if (!doc.exists) {
      throw Exception('Post tidak ditemukan');
    }

    final postUserId = doc.data()?['userId'] ?? '';

    // If admin and NOT the owner, forbid editing
    if (currentUserRole == 'Admin' && postUserId != currentUserId) {
      throw Exception(
          'Forbidden: Admin tidak boleh mengedit postingan milik user lain');
    }

    // If not admin and not the owner, forbid editing
    if (currentUserRole != 'Admin' && postUserId != currentUserId) {
      throw Exception(
          'Forbidden: Anda tidak memiliki izin untuk mengedit postingan ini');
    }

    data['updatedByUid'] = currentUserId;
    await _db.collection('posts').doc(postId).update(data);
  }

  Future<void> deletePost(String postId) async {
    final commentsSnapshot = await _db
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .get();
    for (var doc in commentsSnapshot.docs) {
      await doc.reference.delete();
    }
    await _db.collection('posts').doc(postId).delete();
  }

  Future<PostModel?> getPost(String postId) async {
    final doc = await _db.collection('posts').doc(postId).get();
    if (doc.exists) return PostModel.fromMap(doc.data()!, doc.id);
    return null;
  }

  Stream<PostModel?> streamPost(String postId) {
    return _db.collection('posts').doc(postId).snapshots().map((doc) {
      if (doc.exists) return PostModel.fromMap(doc.data()!, doc.id);
      return null;
    });
  }

  // ============================================================
  // FAVORITES
  // ============================================================

  Future<void> toggleFavorite(String postId, String uid) async {
    final docRef = _db.collection('posts').doc(postId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final favoriteBy = List<String>.from(doc.data()?['favoriteBy'] ?? []);
    if (favoriteBy.contains(uid)) {
      await docRef.update({'favoriteBy': FieldValue.arrayRemove([uid])});
    } else {
      await docRef.update({'favoriteBy': FieldValue.arrayUnion([uid])});
    }
  }

  /// Stream favorite posts - tanpa orderBy untuk menghindari composite index
  Stream<List<PostModel>> streamFavoritePosts(String uid) {
    return _db
        .collection('posts')
        .where('favoriteBy', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ============================================================
  // VOLUNTEER / HANDLED BY
  // ============================================================

  Future<bool> joinVolunteer(String postId, String uid) async {
    final docRef = _db.collection('posts').doc(postId);
    final doc = await docRef.get();
    if (!doc.exists) return false;

    final handledBy = List<String>.from(doc.data()?['handledBy'] ?? []);
    if (handledBy.length >= 3) return false;
    if (handledBy.contains(uid)) return false;

    await docRef.update({
      'handledBy': FieldValue.arrayUnion([uid]),
      'status': 'Sedang Ditangani',
    });
    return true;
  }

  Future<void> cancelVolunteer(String postId, String uid) async {
    final docRef = _db.collection('posts').doc(postId);
    await docRef.update({'handledBy': FieldValue.arrayRemove([uid])});

    final doc = await docRef.get();
    final handledBy = List<String>.from(doc.data()?['handledBy'] ?? []);
    if (handledBy.isEmpty) {
      await docRef.update({'status': 'Butuh Bantuan'});
    }
  }

  Future<void> markCompleted({
    required String postId,
    required String uid,
    required String proofBase64,
    String note = '',
  }) async {
    await _db.collection('posts').doc(postId).update({
      'status': 'Berhasil Ditangani',
      'completionProofBase64': proofBase64,
      'completionNote': note,
      'completedByUid': uid,
    });
  }

  Future<void> submitCompletionRequest({
    required String postId,
    required String uid,
    required String proofBase64,
    String note = '',
  }) async {
    await _db.collection('posts').doc(postId).update({
      'status': 'Menunggu Konfirmasi Penyelesaian',
      'completionProofBase64': proofBase64,
      'completionNote': note,
      'completedByUid': uid,
      'completionRequestedAt': FieldValue.serverTimestamp(),
      'rejectionReason': '',
    });
  }

  Future<void> approveCompletion(String postId) async {
    await _db.collection('posts').doc(postId).update({
      'status': 'Berhasil Ditangani',
    });
  }

  Future<void> rejectCompletion({
    required String postId,
    String reason = '',
  }) async {
    await _db.collection('posts').doc(postId).update({
      'status': 'Sedang Ditangani',
      'rejectionReason': reason,
      // Hapus data pengajuan agar bisa mengajukan ulang
      'completionProofBase64': FieldValue.delete(),
      'completionNote': FieldValue.delete(),
      'completedByUid': FieldValue.delete(),
      'completionRequestedAt': FieldValue.delete(),
    });
  }

  // ============================================================
  // COMMENTS
  // ============================================================

  /// Stream komentar - tanpa orderBy untuk menghindari composite index
  Stream<List<CommentModel>> streamComments(String postId) {
    return _db
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => CommentModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  Future<void> addComment(CommentModel comment) async {
    final docRef = _db.collection('comments').doc();
    final commentWithId = CommentModel(
      commentId: docRef.id,
      postId: comment.postId,
      userId: comment.userId,
      username: comment.username,
      text: comment.text,
      createdAt: comment.createdAt,
    );
    await docRef.set(commentWithId.toMap());
  }

  /// Hapus komentar
  Future<void> deleteComment(String commentId) async {
    await _db.collection('comments').doc(commentId).delete();
  }

  // ============================================================
  // USERS
  // ============================================================

  Future<void> saveUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) return UserModel.fromMap(doc.data()!);
    return null;
  }

  Stream<UserModel?> streamUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) return UserModel.fromMap(doc.data()!);
      return null;
    });
  }

  Future<String> getUsername(String uid) async {
    final user = await getUser(uid);
    return user?.username ?? 'Unknown';
  }

  Future<int> countUserPosts(String uid) async {
    final snapshot = await _db.collection('posts').where('userId', isEqualTo: uid).get();
    return snapshot.docs.length;
  }

  Future<int> countUserHelps(String uid) async {
    final snapshot = await _db.collection('posts').where('handledBy', arrayContains: uid).get();
    return snapshot.docs.length;
  }

  /// Check if a username is available (not already used by another user)
  Future<bool> isUsernameAvailable(String username) async {
    final snapshot = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty;
  }
}

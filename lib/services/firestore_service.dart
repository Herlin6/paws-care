import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/models/comment_model.dart';
import 'package:paws_care/models/user_model.dart';

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

  Future<void> addPost(PostModel post) async {
    final docRef = _db.collection('posts').doc();
    final postWithId = post.copyWith(postId: docRef.id);
    await docRef.set(postWithId.toMap());
  }

  /// Update a post with backend validation:
  /// - Only the post owner can edit their own post.
  /// - Admin CANNOT edit posts belonging to other users.
  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    // Fetch the post to check ownership
    final postDoc = await _db.collection('posts').doc(postId).get();
    if (!postDoc.exists) {
      throw Exception('Postingan tidak ditemukan.');
    }

    final postOwnerId = postDoc.data()?['userId'] ?? '';

    // Only allow edit if the current user is the post owner
    if (currentUid != postOwnerId) {
      throw Exception('Forbidden: Anda tidak boleh mengedit postingan milik user lain.');
    }

    await _db.collection('posts').doc(postId).update(data);
  }

  /// Delete a post with backend validation:
  /// - Post owner can delete their own post.
  /// - Admin can delete any post.
  Future<void> deletePost(String postId) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    // Fetch the post to check ownership
    final postDoc = await _db.collection('posts').doc(postId).get();
    if (!postDoc.exists) {
      throw Exception('Postingan tidak ditemukan.');
    }

    final postOwnerId = postDoc.data()?['userId'] ?? '';

    // If not the owner, check if user is admin
    if (currentUid != postOwnerId) {
      final userDoc = await _db.collection('users').doc(currentUid).get();
      final userRole = userDoc.data()?['role'] ?? 'Pengguna';
      if (userRole != 'Admin') {
        throw Exception('Forbidden: Anda tidak memiliki izin untuk menghapus postingan ini.');
      }
    }

    // Delete associated comments
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
}

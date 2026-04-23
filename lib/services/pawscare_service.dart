import "package:firebase_database/firebase_database.dart";

class PawsCareService {
  final DatabaseReference _postsRef = FirebaseDatabase.instance.ref('posts');
  final DatabaseReference _commentsRef =
      FirebaseDatabase.instance.ref('comments');
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');

  Stream<DatabaseEvent> getPosts() {
    return _postsRef.onValue;
  }

  Future<void> addPost(Map<String, dynamic> data) async {
    await _postsRef.push().set(data);
  }

  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    await _postsRef.child(postId).update(data);
  }

  Future<void> deletePost(String postId) async {
    await _postsRef.child(postId).remove();
  }

  Future<void> toggleFavorite(
      String postId, String uid, bool isFavorite) async {
    if (isFavorite) {
      await _postsRef.child(postId).child('favorites').child(uid).set(true);
    } else {
      await _postsRef.child(postId).child('favorites').child(uid).remove();
    }
  }

  Future<void> handlePost(String postId, String uid) async {
    await _postsRef.child(postId).child('handledBy').child(uid).set(true);
  }

  Future<void> unhandlePost(String postId, String uid) async {
    await _postsRef.child(postId).child('handledBy').child(uid).remove();
  }

  Stream<DatabaseEvent> getComments(String postId) {
    return _commentsRef.orderByChild('postId').equalTo(postId).onValue;
  }

  Future<void> addComment(Map<String, dynamic> data) async {
    await _commentsRef.push().set(data);
  }

  Future<void> saveUser(String uid, Map<String, dynamic> data) async {
    await _usersRef.child(uid).set(data);
  }

  Future<DataSnapshot> getUser(String uid) async {
    return await _usersRef.child(uid).get();
  }
}

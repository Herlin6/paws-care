import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/widgets/post_card.dart';
import 'package:paws_care/screens/detail_screen.dart';

class FavoriteScreen extends StatelessWidget {
  const FavoriteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = FirestoreService();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFFF8E7),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.favorite_rounded, color: Colors.red[400], size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Favorit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<List<PostModel>>(
        stream: service.streamFavoritePosts(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF2994A)));
          }
          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.favorite_border_rounded, size: 48, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 20),
                  Text('Belum ada favorit', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  const SizedBox(height: 6),
                  Text('Tekan ❤️ pada laporan untuk menyimpan', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(
                post: post,
                currentUserId: currentUserId,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(postId: post.postId))),
                onFavorite: () => service.toggleFavorite(post.postId, currentUserId),
              );
            },
          );
        },
      ),
    );
  }
}

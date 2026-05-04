import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/widgets/post_card.dart';
import 'package:paws_care/screens/detail_screen.dart';
import 'package:paws_care/screens/edit_post_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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
            Icon(Icons.history, color: const Color(0xFFF2994A), size: 22),
            const SizedBox(width: 8),
            const Text('Riwayat', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
      ),
      body: StreamBuilder<List<PostModel>>(
        stream: service.streamPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF2994A)));
          }
          final allPosts = snapshot.data ?? [];
          final myPosts = allPosts.where((p) => p.userId == currentUserId).toList();

          if (myPosts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Belum ada riwayat posting', style: TextStyle(fontSize: 16, color: Colors.grey[400])),
                  const SizedBox(height: 8),
                  Text('Buat laporan pertamamu!', style: TextStyle(fontSize: 13, color: Colors.grey[350])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            itemCount: myPosts.length,
            itemBuilder: (context, index) {
              final post = myPosts[index];
              return Dismissible(
                key: Key(post.postId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red[400],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white, size: 28),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Hapus Laporan?'),
                      content: const Text('Apakah Anda yakin ingin menghapus laporan ini?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Hapus', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) {
                  service.deletePost(post.postId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Laporan dihapus'), backgroundColor: Colors.red),
                  );
                },
                child: PostCard(
                  post: post,
                  currentUserId: currentUserId,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(postId: post.postId))),
                  onFavorite: () => service.toggleFavorite(post.postId, currentUserId),
                  onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditPostScreen(post: post))),
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Hapus Laporan?'),
                        content: const Text('Apakah Anda yakin?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) service.deletePost(post.postId);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

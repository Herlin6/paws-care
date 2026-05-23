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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFFF2994A).withAlpha(25), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.history_rounded, color: Color(0xFFF2994A), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Riwayat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.history_rounded, size: 48, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 20),
                  Text('Belum ada riwayat', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  const SizedBox(height: 6),
                  Text('Buat laporan pertamamu!', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
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
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFE53935)]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_rounded, color: Colors.white, size: 28),
                      SizedBox(height: 4),
                      Text('Hapus', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
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
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          child: const Text('Hapus', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) {
                  service.deletePost(post.postId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Laporan dihapus'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
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
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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

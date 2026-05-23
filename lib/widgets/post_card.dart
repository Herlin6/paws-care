import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:paws_care/models/post_model.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onTap,
    required this.onFavorite,
    this.onEdit,
    this.onDelete,
  });

  Color _statusColor() {
    switch (post.status) {
      case 'Butuh Bantuan': return const Color(0xFFE53935);
      case 'Sedang Ditangani': return const Color(0xFFF2994A);
      case 'Berhasil Ditangani': return const Color(0xFF4CAF50);
      default: return Colors.grey;
    }
  }

  String _categoryEmoji() {
    switch (post.category) {
      case 'Sakit': return '🩹';
      case 'Kelaparan': return '🍽️';
      case 'Adopsi': return '🏠';
      case 'Sterilisasi': return '✂️';
      default: return '🐾';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} bulan lalu';
    if (diff.inDays > 0) return '${diff.inDays} hari lalu';
    if (diff.inHours > 0) return '${diff.inHours} jam lalu';
    if (diff.inMinutes > 0) return '${diff.inMinutes} menit lalu';
    return 'Baru saja';
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = post.favoriteBy.contains(currentUserId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slotCount = post.handledBy.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(isDark ? 50 : 18), blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: post.imageBase64.isNotEmpty
                      ? Image.memory(
                          base64Decode(post.imageBase64),
                          height: 200, width: double.infinity, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder())
                      : _buildPlaceholder(),
                ),
                // Gradient overlay at bottom of image for readability
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withAlpha(80)],
                      ),
                    ),
                  ),
                ),
                // Category badge
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black87 : Colors.white.withAlpha(235),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_categoryEmoji(), style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(post.category, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                ),
                // Favorite button
                Positioned(
                  top: 12, right: 12,
                  child: GestureDetector(
                    onTap: onFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 4)],
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 20,
                        color: isFavorite ? const Color(0xFFE53935) : Colors.grey[500],
                      ),
                    ),
                  ),
                ),
                // Volunteer count badge at bottom right of image
                if (slotCount > 0)
                  Positioned(
                    bottom: 10, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(150),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('$slotCount/3', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Content section
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(post.title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor().withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: _statusColor(), shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(post.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor())),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(post.description,
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          post.locationText.isNotEmpty ? post.locationText : 'Lokasi tidak tersedia',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time_rounded, size: 12, color: isDark ? Colors.grey[600] : Colors.grey[350]),
                      const SizedBox(width: 3),
                      Text(_timeAgo(post.createdAt), style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[600] : Colors.grey[350])),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 200, width: double.infinity,
      color: const Color(0xFFFFF3E0),
      child: const Center(child: Icon(Icons.pets_rounded, size: 60, color: Color(0xFFF2994A))),
    );
  }
}

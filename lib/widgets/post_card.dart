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
      case 'Butuh Bantuan':
        return const Color(0xFFE53935);
      case 'Sedang Ditangani':
        return const Color(0xFFF2994A);
      case 'Berhasil Ditangani':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }

  String _categoryEmoji() {
    switch (post.category) {
      case 'Sakit':
        return '🩹';
      case 'Kelaparan':
        return '🍽️';
      case 'Adopsi':
        return '🏠';
      case 'Sterilisasi':
        return '✂️';
      default:
        return '🐾';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = post.favoriteBy.contains(currentUserId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + Category Badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: post.imageBase64.isNotEmpty
                      ? Image.memory(
                          base64Decode(post.imageBase64),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            color: const Color(0xFFFFF3E0),
                            child: const Center(
                              child: Icon(Icons.pets,
                                  size: 60, color: Color(0xFFF2994A)),
                            ),
                          ),
                        )
                      : Container(
                          height: 200,
                          width: double.infinity,
                          color: const Color(0xFFFFF3E0),
                          child: const Center(
                            child: Icon(Icons.pets,
                                size: 60, color: Color(0xFFF2994A)),
                          ),
                        ),
                ),
                // Category badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black87
                          : Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_categoryEmoji(),
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          post.category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Favorite button
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: onFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: isFavorite
                            ? const Color(0xFFE53935)
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.locationText.isNotEmpty
                              ? post.locationText
                              : 'Lokasi tidak tersedia',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor().withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _statusColor(),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              post.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}

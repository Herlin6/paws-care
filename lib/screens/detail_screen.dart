import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/models/comment_model.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/screens/edit_post_screen.dart';

class DetailScreen extends StatefulWidget {
  final String postId;
  const DetailScreen({super.key, required this.postId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final FirestoreService _service = FirestoreService();
  final TextEditingController _commentController = TextEditingController();
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String _currentUsername = '';
  String _currentUserRole = 'Pengguna';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await _service.getUser(_currentUserId);
    if (user != null && mounted) {
      setState(() {
        _currentUsername = user.username;
        _currentUserRole = user.role;
      });
    }
  }

  bool get _isAdmin => _currentUserRole == 'Admin';

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays} hari lalu';
    if (diff.inHours > 0) return '${diff.inHours} jam lalu';
    if (diff.inMinutes > 0) return '${diff.inMinutes} menit lalu';
    return 'Baru saja';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Butuh Bantuan': return const Color(0xFFE53935);
      case 'Sedang Ditangani': return const Color(0xFFF2994A);
      case 'Berhasil Ditangani': return const Color(0xFF4CAF50);
      default: return Colors.grey;
    }
  }

  void _showVolunteerDialog(PostModel post) {
    final isJoined = post.handledBy.contains(_currentUserId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isJoined ? 'Batal Menangani?' : 'Konfirmasi Relawan'),
        content: Text(isJoined
            ? 'Apakah Anda yakin ingin membatalkan penanganan?'
            : 'Apakah Anda yakin ingin menjadi relawan untuk menangani hewan ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tidak')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isJoined ? Colors.red : const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (isJoined) {
                await _service.cancelVolunteer(widget.postId, _currentUserId);
              } else {
                final success = await _service.joinVolunteer(widget.postId, _currentUserId);
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Slot relawan sudah penuh!')),
                  );
                }
              }
            },
            child: Text(isJoined ? 'Ya, Batalkan' : 'Ya, Saya Bersedia', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    Uint8List? proofBytes;
    String proofBase64 = '';
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Upload Bukti Penyelesaian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Upload foto sebagai bukti bahwa kasus ini sudah selesai ditangani.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600, maxHeight: 450, imageQuality: 35);
                        if (picked != null) {
                          final bytes = await picked.readAsBytes();
                          setModalState(() {
                            proofBytes = bytes;
                            proofBase64 = base64Encode(bytes);
                          });
                        }
                      },
                      child: Container(
                        height: 180, width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9F6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD5D5C8), width: 1.5),
                        ),
                        child: proofBytes != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(14),
                                child: Image.memory(proofBytes!, fit: BoxFit.cover, width: double.infinity))
                            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text('Tap untuk upload foto bukti', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                              ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        hintText: 'Tambahkan keterangan (opsional)...',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4CAF50))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (proofBase64.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload foto bukti terlebih dahulu!')));
                            return;
                          }
                          await _service.markCompleted(postId: widget.postId, uid: _currentUserId, proofBase64: proofBase64, note: noteController.text.trim());
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kasus ditandai selesai! ✅'), backgroundColor: Color(0xFF4CAF50)));
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: const Text('Tandai Selesai', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteComment(CommentModel comment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Komentar?'),
        content: const Text('Apakah Anda yakin ingin menghapus komentar ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.deleteComment(comment.commentId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Komentar dihapus'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deletePost(PostModel post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Laporan?'),
        content: const Text('Apakah Anda yakin ingin menghapus laporan ini? Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.deletePost(post.postId);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Laporan dihapus'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    await _service.addComment(CommentModel(
      commentId: '', postId: widget.postId, userId: _currentUserId,
      username: _currentUsername, text: text, createdAt: DateTime.now(),
    ));
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFFF8E7),
      body: StreamBuilder<PostModel?>(
        stream: _service.streamPost(widget.postId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFF2994A)));
          final post = snapshot.data;
          if (post == null) return const Center(child: Text('Post tidak ditemukan'));
          return Stack(
            children: [
              _buildContent(post, isDark),
              // Floating fixed back button
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(PostModel post, bool isDark) {
    final isFav = post.favoriteBy.contains(_currentUserId);
    final isJoined = post.handledBy.contains(_currentUserId);
    final slotCount = post.handledBy.length;
    final isFull = slotCount >= 3;
    final isCompleted = post.status == 'Berhasil Ditangani';
    final isOwner = post.userId == _currentUserId;
    final canEditDelete = isOwner || _isAdmin;

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Stack(children: [
          post.imageBase64.isNotEmpty
              ? Image.memory(base64Decode(post.imageBase64), height: 280, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 280, color: const Color(0xFFFFF3E0), child: const Center(child: Icon(Icons.pets, size: 80, color: Color(0xFFF2994A)))))
              : Container(height: 280, width: double.infinity, color: const Color(0xFFFFF3E0), child: const Center(child: Icon(Icons.pets, size: 80, color: Color(0xFFF2994A)))),
          Positioned(top: MediaQuery.of(context).padding.top + 8, right: 16,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _statusColor(post.status), borderRadius: BorderRadius.circular(16)),
              child: Text(post.status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
        ]),
      ),
      // Title row with edit/delete buttons on the right
      SliverToBoxAdapter(
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 6),
              Text('oleh ${post.username}  •  ${_timeAgo(post.createdAt)}', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            ])),
            if (canEditDelete) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditPostScreen(post: post))),
                child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF2994A).withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.edit, color: Color(0xFFF2994A), size: 18))),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _deletePost(post),
                child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.delete, color: Colors.red, size: 18))),
            ],
          ],
        )),
      ),
      SliverToBoxAdapter(
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(post.description, style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.grey[300] : Colors.grey[700])),
          const SizedBox(height: 16),
          // Location (Clickable - opens Google Maps)
          _buildLocationCard(post, isDark),
          const SizedBox(height: 16),
          // Volunteer slots
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.people_outline, color: Color(0xFFF2994A), size: 20), const SizedBox(width: 8),
                const Text('Slot Relawan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), const Spacer(),
                Text('$slotCount/3', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: slotCount / 3, backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
                  color: isFull ? const Color(0xFF4CAF50) : const Color(0xFFF2994A), minHeight: 6)),
              const SizedBox(height: 8),
              Text(slotCount == 0 ? 'Belum ada relawan' : '$slotCount relawan bergabung', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ])),
          const SizedBox(height: 16),
          // Action buttons
          if (!isCompleted) ...[
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _service.toggleFavorite(widget.postId, _currentUserId),
                icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey, size: 18),
                label: Text('Favorit', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)))),
              const SizedBox(width: 12),
              if (isJoined)
                Expanded(flex: 2, child: ElevatedButton.icon(
                  onPressed: _showCompletionDialog,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Selesai', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))))
              else
                Expanded(flex: 2, child: ElevatedButton.icon(
                  onPressed: isFull ? null : () => _showVolunteerDialog(post),
                  icon: Icon(isFull ? Icons.block : Icons.volunteer_activism, size: 18),
                  label: Text(isFull ? 'Slot Penuh' : 'Saya Ingin Menangani', style: const TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400], disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
            ]),
            if (isJoined) ...[
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton(
                onPressed: () => _showVolunteerDialog(post),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Batal Menangani'))),
            ],
          ] else ...[
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF4CAF50).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20), SizedBox(width: 8),
                  Text('Berhasil Ditangani', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF4CAF50)))]),
                if (post.completionNote.isNotEmpty) ...[const SizedBox(height: 8), Text(post.completionNote, style: TextStyle(fontSize: 13, color: Colors.grey[700]))],
                if (post.completionProofBase64.isNotEmpty) ...[const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(post.completionProofBase64), height: 150, width: double.infinity, fit: BoxFit.cover))],
              ])),
          ],
          const SizedBox(height: 20),
          _buildCommentsSection(isDark),
          const SizedBox(height: 16),
        ])),
      ),
    ]);
  }

  Widget _buildLocationCard(PostModel post, bool isDark) {
    final hasCoords = post.latitude != 0 && post.longitude != 0;
    final hasText = post.locationText.isNotEmpty;
    final canOpenMaps = hasCoords || hasText;

    Future<void> openMaps() async {
      Uri url;
      if (hasCoords) {
        url = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${post.latitude},${post.longitude}');
      } else {
        url = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(post.locationText)}');
      }
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }

    return GestureDetector(
      onTap: canOpenMaps ? openMaps : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: canOpenMaps
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                  : isDark
                      ? Colors.grey[800]!
                      : Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on,
                      color: Color(0xFF4CAF50), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasText ? post.locationText : (hasCoords ? 'Lokasi GPS tersedia' : 'Lokasi belum tersedia'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (post.locationDetail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.subdirectory_arrow_right, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                post.locationDetail,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (hasCoords) ...[
                        const SizedBox(height: 4),
                        Text(
                          '📍 ${post.latitude.toStringAsFixed(6)}, ${post.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canOpenMaps)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.open_in_new,
                        color: Color(0xFF4CAF50), size: 16),
                  ),
              ],
            ),
            if (canOpenMaps) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map, size: 16, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 6),
                    Text(
                      hasCoords
                          ? 'Buka di Google Maps (GPS)'
                          : 'Buka di Google Maps (Alamat)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection(bool isDark) {
    return StreamBuilder<List<CommentModel>>(
      stream: _service.streamComments(widget.postId),
      builder: (context, snapshot) {
        final comments = snapshot.data ?? [];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[500]), const SizedBox(width: 6),
            Text('Komentar (${comments.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))]),
          const SizedBox(height: 12),
          if (comments.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('Belum ada komentar', style: TextStyle(color: Colors.grey[400], fontSize: 13))))
          else
            ...comments.map((c) {
              final canDelete = _isAdmin || c.userId == _currentUserId;
              return Container(
                margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.white, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[100]!)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(c.username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    Text(_timeAgo(c.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    if (canDelete) ...[
                      const SizedBox(width: 8),
                      GestureDetector(onTap: () => _deleteComment(c),
                        child: Icon(Icons.delete_outline, size: 16, color: Colors.red[300])),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(c.text, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                ]),
              );
            }),
          const SizedBox(height: 12),
          // Comment input inline in section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              Expanded(child: TextField(controller: _commentController,
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(hintText: 'Tulis komentar...', hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFFF2994A))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), isDense: true))),
              const SizedBox(width: 8),
              GestureDetector(onTap: _sendComment,
                child: Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFFF2994A), shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 20))),
            ]),
          ),
        ]);
      },
    );
  }
}

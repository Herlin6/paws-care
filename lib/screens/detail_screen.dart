import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/models/comment_model.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/services/notification_api_service.dart';
import 'package:paws_care/screens/edit_post_screen.dart';
import 'package:paws_care/widgets/image_source_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class DetailScreen extends StatefulWidget {
  final String postId;
  const DetailScreen({super.key, required this.postId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final FirestoreService _service = FirestoreService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String _currentUsername = '';
  String _currentUserRole = 'Pengguna';

  late Stream<PostModel?> _postStream;
  late Stream<List<CommentModel>> _commentsStream;

  String? _cachedPostBase64;
  Uint8List? _cachedPostBytes;

  Uint8List? _getPostImageBytes(String base64) {
    if (base64.isEmpty) return null;
    if (_cachedPostBase64 != base64) {
      _cachedPostBase64 = base64;
      _cachedPostBytes = base64Decode(base64);
    }
    return _cachedPostBytes;
  }

  String? _cachedProofBase64;
  Uint8List? _cachedProofBytes;

  Uint8List? _getProofImageBytes(String base64) {
    if (base64.isEmpty) return null;
    if (_cachedProofBase64 != base64) {
      _cachedProofBase64 = base64;
      _cachedProofBytes = base64Decode(base64);
    }
    return _cachedProofBytes;
  }

  @override
  void initState() {
    super.initState();
    _postStream = _service.streamPost(widget.postId);
    _commentsStream = _service.streamComments(widget.postId);
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
    _commentFocusNode.dispose();
    super.dispose();
  }

  Widget _buildApprovalPanel(PostModel post, bool isDark) {
    if (post.status != 'Menunggu Konfirmasi Penyelesaian' || post.userId != _currentUserId) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blueAccent),
              SizedBox(width: 8),
              Expanded(child: Text('Menunggu Konfirmasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent))),
            ],
          ),
          const SizedBox(height: 12),
          Text('Seorang relawan telah mengajukan penyelesaian laporan ini.', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700])),
          const SizedBox(height: 12),
          if (post.completionProofBase64.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(_getProofImageBytes(post.completionProofBase64)!, height: 120, width: double.infinity, fit: BoxFit.cover, gaplessPlayback: true),
            ),
            const SizedBox(height: 8),
          ],
          if (post.completionNote.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Text('Catatan:\n${post.completionNote}', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: isDark ? Colors.grey[300] : Colors.grey[700])),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rejectCompletion(post),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  child: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approveCompletion(post),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white),
                  child: const Text('Setujui'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approveCompletion(PostModel post) async {
    await _service.approveCompletion(widget.postId);
    _sendApprovalNotification(post);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Penyelesaian disetujui! ✅'), backgroundColor: Color(0xFF4CAF50)));
  }

  void _rejectCompletion(PostModel post) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak Penyelesaian'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'Alasan penolakan (opsional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.rejectCompletion(postId: widget.postId, reason: reasonController.text.trim());
              _sendRejectionNotification(post);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Penyelesaian ditolak.'), backgroundColor: Colors.red));
            },
            child: const Text('Tolak', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
      case 'Menunggu Konfirmasi Penyelesaian': return Colors.blueAccent;
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
                _sendVolunteerCancelNotification(post);
              } else {
                final success = await _service.joinVolunteer(widget.postId, _currentUserId);
                if (success) {
                  // Kirim notifikasi ke pemilik post
                  _sendVolunteerJoinNotification(post);
                } else if (mounted) {
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

  void _showCompletionDialog(PostModel post) {
    String proofBase64 = '';
    Uint8List? proofBytes;
    final noteController = TextEditingController();
    final bool isOwner = post.userId == _currentUserId;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Upload Bukti Penyelesaian',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black)),
                        GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Icon(Icons.close, color: isDarkMode ? Colors.grey[400] : Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          'Upload foto sebagai bukti bahwa kasus ini sudah selesai ditangani.',
                          style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? Colors.grey[300] : Colors.black87)),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final picked = await ImageSourcePicker.pickImage(
                          context,
                          maxWidth: 800,
                          maxHeight: 800,
                          imageQuality: 85,
                        );
                        if (picked != null) {
                          final croppedFile = await ImageCropper().cropImage(
                            sourcePath: picked.path,
                            uiSettings: [
                              AndroidUiSettings(
                                toolbarTitle: 'Crop Bukti Penyelesaian',
                                toolbarColor: Colors.black,
                                toolbarWidgetColor: Colors.white,
                                initAspectRatio: CropAspectRatioPreset.original,
                                lockAspectRatio: false,
                              ),
                              IOSUiSettings(
                                title: 'Crop Bukti',
                              ),
                              WebUiSettings(
                                context: context,
                                presentStyle: WebPresentStyle.dialog,
                              ),
                            ],
                          );
                          if (croppedFile != null) {
                            final bytes = await croppedFile.readAsBytes();
                            setModalState(() {
                              proofBytes = bytes;
                              proofBase64 = base64Encode(bytes);
                            });
                          }
                        }
                      },
                      child: Container(
                        height: 180, width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF9F9F6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDarkMode ? Colors.grey[700]! : const Color(0xFFD5D5C8), width: 1.5),
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
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Tambahkan keterangan (opsional)...',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        filled: true,
                        fillColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!)),
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
                          if (isOwner) {
                            await _service.markCompleted(postId: widget.postId, uid: _currentUserId, proofBase64: proofBase64, note: noteController.text.trim());
                            _sendCompletionNotification();
                          } else {
                            await _service.submitCompletionRequest(postId: widget.postId, uid: _currentUserId, proofBase64: proofBase64, note: noteController.text.trim());
                            _sendCompletionRequestNotification(post);
                          }
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(isOwner ? 'Kasus ditandai selesai! ✅' : 'Permintaan penyelesaian dikirim! ⏳'),
                              backgroundColor: const Color(0xFF4CAF50),
                            ));
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: Text(isOwner ? 'Tandai Selesai' : 'Ajukan Penyelesaian', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

    // Kirim notifikasi komentar baru ke pemilik post & relawan
    _sendCommentNotification();
  }

  Future<void> _updateLocation(PostModel post) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFFF2994A))),
    );

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Layanan lokasi tidak aktif')));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) Navigator.pop(context);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak')));
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak permanen')));
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      
      String newAddress = '';
      String newDetail = '';
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          newAddress = '${place.street}, ${place.subLocality}, ${place.locality}';
          newDetail = '${place.administrativeArea}, ${place.country}';
        }
      } catch (_) {}

      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Pembaruan Lokasi GPS'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lokasi Lama:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(post.locationText.isNotEmpty ? post.locationText : 'Belum tersedia', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                if (post.latitude != 0 && post.longitude != 0)
                  Text('${post.latitude.toStringAsFixed(6)}, ${post.longitude.toStringAsFixed(6)}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 12),
                const Text('Lokasi Baru:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(newAddress.isNotEmpty ? newAddress : 'Lokasi GPS tersedia', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                Text('${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 16),
                const Text('Gunakan lokasi ini?'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF2994A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Konfirmasi', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _service.updatePost(post.postId, {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'locationText': newAddress,
          'locationDetail': newDetail,
        });

        if (post.handledBy.isNotEmpty) {
          final notifApi = NotificationApiService();
          final db = FirebaseFirestore.instance;
          for (final volUid in post.handledBy) {
            if (volUid != _currentUserId) {
              try {
                final userDoc = await db.collection('users').doc(volUid).get();
                final token = userDoc.data()?['fcmToken'] as String?;
                if (token != null && token.isNotEmpty) {
                  notifApi.sendNotification(
                    token: token,
                    title: '📍 Lokasi Diperbarui',
                    body: 'Lokasi laporan "${post.title}" telah diperbarui oleh pemilik.',
                    data: {'postId': post.postId},
                  );
                }
              } catch (_) {}
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lokasi berhasil diperbarui'), backgroundColor: Color(0xFF4CAF50)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading if error
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memperbarui: $e')));
      }
    }
  }

  Future<void> _removeLocation(PostModel post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Lokasi GPS?'),
        content: const Text('Apakah Anda yakin ingin menghapus data koordinat GPS dari laporan ini? (Teks alamat akan tetap dipertahankan)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.updatePost(post.postId, {
          'latitude': 0.0,
          'longitude': 0.0,
        });

        if (post.handledBy.isNotEmpty) {
          final notifApi = NotificationApiService();
          final db = FirebaseFirestore.instance;
          for (final volUid in post.handledBy) {
            if (volUid != _currentUserId) {
              try {
                final userDoc = await db.collection('users').doc(volUid).get();
                final token = userDoc.data()?['fcmToken'] as String?;
                if (token != null && token.isNotEmpty) {
                  notifApi.sendNotification(
                    token: token,
                    title: '📍 Lokasi Diperbarui',
                    body: 'Lokasi GPS laporan "${post.title}" telah dihapus oleh pemilik.',
                    data: {'postId': post.postId},
                  );
                }
              } catch (_) {}
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lokasi GPS berhasil dihapus'), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
        }
      }
    }
  }

  // ============================================================
  // NOTIFICATION HELPERS
  // ============================================================

  /// Kirim notifikasi komentar baru ke pemilik post, relawan, dan pengguna yang memfavoritkan
  Future<void> _sendCommentNotification() async {
    try {
      final post = await _service.getPost(widget.postId);
      if (post == null) return;

      final notifApi = NotificationApiService();
      final db = FirebaseFirestore.instance;

      // Kumpulkan semua UID penerima, kecuali pengirim
      final recipientUids = <String>{};
      if (post.userId != _currentUserId) {
        recipientUids.add(post.userId);
      }
      for (final volUid in post.handledBy) {
        if (volUid != _currentUserId) {
          recipientUids.add(volUid);
        }
      }
      for (final favUid in post.favoriteBy) {
        if (favUid != _currentUserId) {
          recipientUids.add(favUid);
        }
      }

      // Ambil preferensi dan kirim notifikasi
      for (final uid in recipientUids) {
        final userDoc = await db.collection('users').doc(uid).get();
        final userData = userDoc.data();
        if (userData == null) continue;

        final token = userData['fcmToken'] as String?;
        if (token == null || token.isEmpty) continue;

        final prefs = userData['notificationPrefs'] as Map<String, dynamic>? ?? {};
        final bool enabled = prefs['enabled'] ?? true;
        if (!enabled) continue; // Skip jika master notifikasi dimatikan

        final bool commentOnOwnPost = prefs['commentOnOwnPost'] ?? true;
        final bool commentOnVolunteerPost = prefs['commentOnVolunteerPost'] ?? true;
        final bool commentOnFavoritePost = prefs['commentOnFavoritePost'] ?? true;

        bool shouldSend = false;
        
        // Cek izin berdasarkan peran user tersebut pada postingan
        if (uid == post.userId && commentOnOwnPost) {
          shouldSend = true;
        }
        if (post.handledBy.contains(uid) && commentOnVolunteerPost) {
          shouldSend = true;
        }
        if (post.favoriteBy.contains(uid) && commentOnFavoritePost) {
          shouldSend = true;
        }

        if (shouldSend) {
          notifApi.sendNotification(
            token: token,
            title: '💬 Komentar Baru',
            body: '$_currentUsername mengomentari: ${post.title}',
            data: {'postId': widget.postId, 'senderUid': _currentUserId},
          );
        }
      }
    } catch (_) {}
  }

  /// Kirim notifikasi relawan bergabung ke pemilik post
  Future<void> _sendVolunteerJoinNotification(PostModel post) async {
    try {
      if (post.userId == _currentUserId) return;

      final db = FirebaseFirestore.instance;
      final ownerDoc = await db.collection('users').doc(post.userId).get();
      final ownerToken = ownerDoc.data()?['fcmToken'] as String?;
      if (ownerToken != null && ownerToken.isNotEmpty) {
        NotificationApiService().sendNotification(
          token: ownerToken,
          title: '🤝 Relawan Bergabung',
          body: '$_currentUsername bergabung menangani: ${post.title}',
          data: {'postId': widget.postId},
        );
      }
    } catch (_) {}
  }

  /// Kirim notifikasi relawan membatalkan bantuan ke pemilik post
  Future<void> _sendVolunteerCancelNotification(PostModel post) async {
    try {
      if (post.userId == _currentUserId) return;

      final db = FirebaseFirestore.instance;
      final ownerDoc = await db.collection('users').doc(post.userId).get();
      final ownerToken = ownerDoc.data()?['fcmToken'] as String?;
      if (ownerToken != null && ownerToken.isNotEmpty) {
        NotificationApiService().sendNotification(
          token: ownerToken,
          title: 'Relawan Membatalkan Bantuan',
          body: '$_currentUsername membatalkan bantuan pada laporan Anda.',
          data: {'postId': widget.postId},
        );
      }
    } catch (_) {}
  }

  /// Kirim notifikasi relawan mengajukan penyelesaian
  Future<void> _sendCompletionRequestNotification(PostModel post) async {
    try {
      if (post.userId == _currentUserId) return;

      final db = FirebaseFirestore.instance;
      final ownerDoc = await db.collection('users').doc(post.userId).get();
      final ownerToken = ownerDoc.data()?['fcmToken'] as String?;
      if (ownerToken != null && ownerToken.isNotEmpty) {
        NotificationApiService().sendNotification(
          token: ownerToken,
          title: 'Permintaan Penyelesaian Laporan',
          body: '$_currentUsername telah mengajukan penyelesaian laporan dan menunggu konfirmasi Anda.',
          data: {'postId': widget.postId},
        );
      }
    } catch (_) {}
  }

  /// Kirim notifikasi penyelesaian disetujui
  Future<void> _sendApprovalNotification(PostModel post) async {
    try {
      if (post.completedByUid.isEmpty || post.completedByUid == _currentUserId) return;

      final db = FirebaseFirestore.instance;
      final volDoc = await db.collection('users').doc(post.completedByUid).get();
      final volToken = volDoc.data()?['fcmToken'] as String?;
      if (volToken != null && volToken.isNotEmpty) {
        NotificationApiService().sendNotification(
          token: volToken,
          title: 'Penyelesaian Disetujui',
          body: 'Pemilik laporan menyetujui pengajuan penyelesaian Anda pada: ${post.title}',
          data: {'postId': widget.postId},
        );
      }
    } catch (_) {}
  }

  /// Kirim notifikasi penyelesaian ditolak
  Future<void> _sendRejectionNotification(PostModel post) async {
    try {
      if (post.completedByUid.isEmpty || post.completedByUid == _currentUserId) return;

      final db = FirebaseFirestore.instance;
      final volDoc = await db.collection('users').doc(post.completedByUid).get();
      final volToken = volDoc.data()?['fcmToken'] as String?;
      if (volToken != null && volToken.isNotEmpty) {
        NotificationApiService().sendNotification(
          token: volToken,
          title: 'Penyelesaian Ditolak',
          body: 'Pemilik laporan menolak pengajuan penyelesaian Anda pada: ${post.title}',
          data: {'postId': widget.postId},
        );
      }
    } catch (_) {}
  }

  /// Kirim notifikasi laporan selesai ke pemilik post
  Future<void> _sendCompletionNotification() async {
    try {
      final post = await _service.getPost(widget.postId);
      if (post == null || post.userId == _currentUserId) return;

      final db = FirebaseFirestore.instance;
      final ownerDoc = await db.collection('users').doc(post.userId).get();
      final ownerToken = ownerDoc.data()?['fcmToken'] as String?;
      if (ownerToken != null && ownerToken.isNotEmpty) {
        NotificationApiService().sendNotification(
          token: ownerToken,
          title: '✅ Laporan Selesai',
          body: '${post.title} berhasil ditangani!',
          data: {'postId': widget.postId},
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFFF8E7),
      body: StreamBuilder<PostModel?>(
        stream: _postStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFF2994A)));
          final post = snapshot.data;
          if (post == null) return const Center(child: Text('Post tidak ditemukan'));
          return Stack(
            children: [
              _buildContent(post, isDark),
              // Floating fixed back button
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
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

    // Admin access control:
    // - Admin can DELETE any post
    // - Admin can only EDIT their own posts
    final canDelete = isOwner || _isAdmin;
    final canEdit = isOwner; // Admin can only edit own posts

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Stack(children: [
          post.imageBase64.isNotEmpty
              ? Image.memory(_getPostImageBytes(post.imageBase64)!, height: 280, width: double.infinity, fit: BoxFit.cover, gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Container(height: 280, color: const Color(0xFFFFF3E0), child: const Center(child: Icon(Icons.pets, size: 80, color: Color(0xFFF2994A)))))
              : Container(height: 280, width: double.infinity, color: const Color(0xFFFFF3E0), child: const Center(child: Icon(Icons.pets, size: 80, color: Color(0xFFF2994A)))),
          Positioned(top: MediaQuery.paddingOf(context).top + 8, right: 16,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _statusColor(post.status), borderRadius: BorderRadius.circular(16)),
              child: Text(post.status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
        ]),
      ),
      SliverToBoxAdapter(
        child: _buildApprovalPanel(post, isDark),
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
            if (canEdit) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditPostScreen(post: post))),
                child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF2994A).withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.edit, color: Color(0xFFF2994A), size: 18))),
            ],
            if (canDelete) ...[
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
          // Categories & Animal Type chips
          _buildCategoryAnimalChips(post, isDark),
          const SizedBox(height: 14),
          Text(post.description, style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.grey[300] : Colors.grey[700])),
          const SizedBox(height: 16),
          // Location (Clickable - opens Google Maps)
          _buildLocationCard(post, isDark),
          if (isOwner && !isCompleted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _updateLocation(post),
                icon: const Icon(Icons.gps_fixed, size: 18),
                label: Text((post.latitude != 0 && post.longitude != 0) ? 'Perbarui Lokasi GPS' : 'Gunakan Lokasi GPS Saat Ini', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2994A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
            if (post.latitude != 0 && post.longitude != 0) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _removeLocation(post),
                  icon: const Icon(Icons.location_off, size: 18),
                  label: const Text('Hapus Lokasi GPS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
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
              if (isOwner)
                Expanded(flex: 2, child: ElevatedButton.icon(
                  onPressed: () => _showCompletionDialog(post),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Tandai Selesai', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))))
              else if (isJoined)
                Expanded(flex: 2, child: ElevatedButton.icon(
                  onPressed: post.status == 'Menunggu Konfirmasi Penyelesaian' ? null : () => _showCompletionDialog(post),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(post.status == 'Menunggu Konfirmasi Penyelesaian' ? 'Menunggu Konfirmasi' : 'Selesai', style: const TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400], disabledForegroundColor: Colors.white70,
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
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_getProofImageBytes(post.completionProofBase64)!, height: 150, width: double.infinity, fit: BoxFit.cover, gaplessPlayback: true))],
              ])),
          ],
          const SizedBox(height: 20),
          _buildCommentsSection(isDark),
          const SizedBox(height: 16),
        ])),
      ),
    ]);
  }

  /// Build category and animal type chips row
  Widget _buildCategoryAnimalChips(PostModel post, bool isDark) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        // Animal type chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(PostModel.animalTypeEmoji(post.animalType), style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(post.animalType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50))),
            ],
          ),
        ),
        // Category chips
        ...post.categories.map((cat) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF2994A).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(PostModel.categoryEmoji(cat), style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(cat, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF2994A))),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildLocationCard(PostModel post, bool isDark) {
    final hasCoords = post.latitude != 0 && post.longitude != 0;
    final hasText = post.locationText.isNotEmpty;

    Future<void> openMaps() async {
      // Hanya buka Google Maps jika ada koordinat GPS valid
      if (!hasCoords) return;
      final url = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${post.latitude},${post.longitude}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }

    return GestureDetector(
      onTap: hasCoords ? openMaps : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: hasCoords
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
                        hasText
                            ? post.locationText
                            : (hasCoords
                                ? 'Lokasi GPS tersedia'
                                : 'Lokasi belum tersedia'),
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
                      // Koordinat GPS hanya ditampilkan jika ada lat/lng valid
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
                // Ikon buka maps hanya muncul jika ada koordinat GPS
                if (hasCoords)
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
            // Tombol "Buka di Google Maps" hanya muncul jika ada koordinat GPS
            if (hasCoords) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 16, color: Color(0xFF4CAF50)),
                    SizedBox(width: 6),
                    Text(
                      'Buka di Google Maps',
                      style: TextStyle(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<List<CommentModel>>(
          stream: _commentsStream,
          builder: (context, snapshot) {
            final comments = snapshot.data ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text('Komentar (${comments.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 12),
                if (comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('Belum ada komentar', style: TextStyle(color: Colors.grey[400], fontSize: 13))),
                  )
                else
                  ...comments.map((c) {
                    final canDelete = _isAdmin || c.userId == _currentUserId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(c.username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              Text(_timeAgo(c.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              if (canDelete) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _deleteComment(c),
                                  child: Icon(Icons.delete_outline, size: 16, color: Colors.red[300]),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(c.text, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        // Comment input inline in section
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Tulis komentar...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: Colors.grey[300]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFFF2994A))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendComment,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Color(0xFFF2994A), shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

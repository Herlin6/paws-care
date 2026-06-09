import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:paws_care/widgets/image_source_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paws_care/widgets/main_scaffold.dart';
import 'package:paws_care/services/notification_api_service.dart';
import 'package:image_cropper/image_cropper.dart';

class EditPostScreen extends StatefulWidget {
  final PostModel post;
  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final FirestoreService _service = FirestoreService();
  final AuthService _authService = AuthService();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _locationController;
  late TextEditingController _locationDetailController;
  late List<String> _selectedCategories;
  late String _selectedAnimalType;
  String _imageBase64 = '';
  Uint8List? _imageBytes;
  String? _originalImagePath;
  bool _isLoading = false;
  String _currentUserRole = 'Pengguna';
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _descController = TextEditingController(text: widget.post.description);
    _locationController = TextEditingController(text: widget.post.locationText);
    _locationDetailController = TextEditingController(text: widget.post.locationDetail);
    _selectedCategories = List<String>.from(widget.post.categories);
    _selectedAnimalType = widget.post.animalType;
    _imageBase64 = widget.post.imageBase64;
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (_imageBase64.isNotEmpty) {
      try {
        _imageBytes = base64Decode(_imageBase64);
        // Can't set original path for existing base64, so recrop from network isn't supported without path
      } catch (_) {}
    }
    _loadCurrentUserRole();
  }

  Future<void> _loadCurrentUserRole() async {
    final user = await _authService.getCurrentUserModel();
    if (user != null && mounted) {
      setState(() {
        _currentUserRole = user.role;
        _currentUserId = user.uid;
      });
      // Check: if admin and not owner, block editing immediately
      if (user.role == 'Admin' && widget.post.userId != user.uid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Forbidden: Admin tidak boleh mengedit postingan milik user lain'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _locationDetailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImageSourcePicker.pickImage(
      context,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 50,
    );
    if (picked != null && mounted) {
      _originalImagePath = picked.path;
      _cropImage(picked.path);
    }
  }

  Future<void> _reCropImage() async {
    if (_originalImagePath != null) {
      _cropImage(_originalImagePath!);
    } else {
      // Jika gambar berasal dari network/base64 yang lama, kita harus suruh user pilih ulang
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih ulang foto untuk melakukan crop!')));
    }
  }

  Future<void> _cropImage(String path) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop Foto',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false),
        IOSUiSettings(
          title: 'Crop Foto',
        ),
      ],
    );

    if (croppedFile != null && mounted) {
      final bytes = await croppedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageBase64 = base64Encode(bytes);
      });
    }
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        if (_selectedCategories.length > 1) {
          _selectedCategories.remove(category);
        }
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul dan deskripsi wajib diisi!')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Use updatePostWithAuth for admin access control validation
      await _service.updatePostWithAuth(
        widget.post.postId,
        {
          'title': title,
          'description': desc,
          'categories': _selectedCategories,
          'animalType': _selectedAnimalType,
          'locationText': _locationController.text.trim(),
          'locationDetail': _locationDetailController.text.trim(),
          'imageBase64': _imageBase64,
        },
        _currentUserId,
        _currentUserRole,
      );

      // Kirim notifikasi ke relawan bahwa laporan telah diperbarui
      if (widget.post.handledBy.isNotEmpty) {
        final notifApi = NotificationApiService();
        final db = FirebaseFirestore.instance;
        for (final volUid in widget.post.handledBy) {
          if (volUid != _currentUserId) {
            try {
              final userDoc = await db.collection('users').doc(volUid).get();
              final token = userDoc.data()?['fcmToken'] as String?;
              if (token != null && token.isNotEmpty) {
                notifApi.sendNotification(
                  token: token,
                  title: '✏️ Laporan Diperbarui',
                  body: 'Laporan "${widget.post.title}" telah diperbarui oleh pemilik.',
                  data: {'postId': widget.post.postId},
                );
              }
            } catch (_) {}
          }
        }
      }

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 56),
                ),
                const SizedBox(height: 16),
                const Text('Berhasil! ✅', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Laporan berhasil diperbarui.', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.pop(context);
          MainScaffold.switchTab(0);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: errorMsg.contains('Forbidden') ? Colors.red : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFFF8E7),
      appBar: AppBar(
        title: const Text('Edit Laporan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Foto Hewan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _imageBytes != null ? _reCropImage : _pickImage,
              child: Container(
                height: 200, width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFF8E7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF6D58A), width: 1.5),
                ),
                child: _imageBytes != null
                    ? Stack(
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(14),
                              child: Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
                          Positioned(
                            bottom: 8, left: 8,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.photo_library, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('Ganti foto', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ]),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.crop, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Crop ulang', style: TextStyle(color: Colors.white, fontSize: 11)),
                              ]),
                            ),
                          ),
                        ],
                      )
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('Tap untuk upload foto', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      ]),
              ),
            ),
            const SizedBox(height: 20),
            Text('Judul', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            TextField(controller: _titleController, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _inputDeco('Judul singkat...', isDark)),
            const SizedBox(height: 20),
            Text('Deskripsi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            TextField(controller: _descController, maxLines: 4, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _inputDeco('Jelaskan kondisi hewan...', isDark)),
            const SizedBox(height: 20),
            // ===== JENIS HEWAN =====
            _buildAnimalTypeSection(isDark),
            const SizedBox(height: 20),
            // ===== KATEGORI (MULTI-SELECT) =====
            _buildCategorySection(isDark),
            const SizedBox(height: 20),
            Text('Lokasi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            TextField(controller: _locationController, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _inputDeco('Alamat manual...', isDark)),
            const SizedBox(height: 20),
            Text('Detail Lokasi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            TextField(controller: _locationDetailController, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _inputDeco('Patokan, RT/RW, dll (Opsional)...', isDark)),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2994A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimalTypeSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.pets, size: 18, color: isDark ? Colors.white : Colors.black87),
            const SizedBox(width: 6),
            Text('Jenis Hewan',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PostModel.availableAnimalTypes.map((type) {
            final isSelected = _selectedAnimalType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedAnimalType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF4CAF50) : isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!),
                ),
                child: Text('${PostModel.animalTypeEmoji(type)} $type',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : isDark ? Colors.grey[300] : Colors.black87)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategorySection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.category, size: 18, color: isDark ? Colors.white : Colors.black87),
            const SizedBox(width: 6),
            Text('Kategori',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(width: 6),
            Text('(bisa pilih lebih dari satu)', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PostModel.availableCategories.map((cat) {
            final isSelected = _selectedCategories.contains(cat);
            return GestureDetector(
              onTap: () => _toggleCategory(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF2994A) : isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? const Color(0xFFF2994A) : Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.check, size: 14, color: Colors.white),
                      ),
                    Text('${PostModel.categoryEmoji(cat)} $cat',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : isDark ? Colors.grey[300] : Colors.black87)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      filled: true, fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF2994A), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

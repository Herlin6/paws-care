import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/services/auth_service.dart';
import 'package:paws_care/widgets/main_scaffold.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final FirestoreService _service = FirestoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  String _selectedCategory = 'Sakit';
  String _imageBase64 = '';
  Uint8List? _imageBytes;
  bool _isLoading = false;
  String _currentUsername = '';

  final List<Map<String, String>> _categories = [
    {'label': 'Sakit', 'emoji': '🩹'},
    {'label': 'Kelaparan', 'emoji': '🍽️'},
    {'label': 'Adopsi', 'emoji': '🏠'},
    {'label': 'Sterilisasi', 'emoji': '✂️'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final user = await _authService.getCurrentUserModel();
    if (user != null && mounted) {
      setState(() => _currentUsername = user.username);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 450,
      imageQuality: 35,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final loc = _locationController.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan deskripsi wajib diisi!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final post = PostModel(
      postId: '',
      userId: _currentUserId,
      username: _currentUsername,
      title: title,
      description: desc,
      imageBase64: _imageBase64,
      category: _selectedCategory,
      locationText: loc,
      status: 'Butuh Bantuan',
      createdAt: DateTime.now(),
      favoriteBy: [],
      handledBy: [],
    );

    try {
      await _service.addPost(post);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan berhasil dikirim! 🐾'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        _titleController.clear();
        _descController.clear();
        _locationController.clear();
        setState(() {
          _imageBase64 = '';
          _imageBytes = null;
          _selectedCategory = 'Sakit';
        });
        // Pindah ke halaman Home
        MainScaffold.switchTab(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim: $e')),
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
        title: const Text('Laporan Baru', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Foto Hewan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFF8E7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF6D58A), width: 1.5),
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('Tap untuk upload foto', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Judul', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            TextField(controller: _titleController, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _inputDecoration('Judul singkat laporan...', isDark)),
            const SizedBox(height: 20),
            Text('Deskripsi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            TextField(controller: _descController, maxLines: 4, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _inputDecoration('Jelaskan kondisi hewan yang ditemukan...', isDark)),
            const SizedBox(height: 20),
            Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['label'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat['label']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF2994A) : isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? const Color(0xFFF2994A) : Colors.grey[300]!),
                    ),
                    child: Text('${cat['emoji']} ${cat['label']}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : isDark ? Colors.grey[300] : Colors.black87)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Lokasi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            TextField(controller: _locationController, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _inputDecoration('Masukkan alamat lokasi...', isDark)),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2994A), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 2),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Kirim Laporan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
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

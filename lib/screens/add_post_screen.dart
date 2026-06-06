import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/services/auth_service.dart';
import 'package:paws_care/widgets/main_scaffold.dart';
import 'package:paws_care/screens/image_crop_screen.dart';

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
  double _latitude = 0.0;
  double _longitude = 0.0;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Multi-select categories
  final List<String> _selectedCategories = [];
  // Single-select animal type
  String _selectedAnimalType = '';
  String _imageBase64 = '';
  Uint8List? _imageBytes;
  Uint8List? _originalImageBytes;
  bool _isLoading = false;
  String _currentUsername = '';

  static const List<Map<String, String>> _categories = [
    {'label': 'Hilang', 'emoji': '🔍'},
    {'label': 'Ditemukan', 'emoji': '📦'},
    {'label': 'Kecelakaan', 'emoji': '🚗'},
    {'label': 'Mati', 'emoji': '💀'},
    {'label': 'Terjebak', 'emoji': '🪤'},
    {'label': 'Sakit', 'emoji': '🩹'},
    {'label': 'Lainnya', 'emoji': '🐾'},
  ];

  static const List<Map<String, String>> _animalTypes = [
    {'label': 'Kucing', 'emoji': '🐱'},
    {'label': 'Anjing', 'emoji': '🐶'},
    {'label': 'Burung', 'emoji': '🐦'},
    {'label': 'Kelinci', 'emoji': '🐰'},
    {'label': 'Reptil', 'emoji': '🦎'},
    {'label': 'Lainnya', 'emoji': '🐾'},
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
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 50,
    );
    if (picked != null && mounted) {
      final bytes = await picked.readAsBytes();
      _originalImageBytes = bytes;
      if (!mounted) return;
      // Navigate to crop screen
      final croppedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (_) => ImageCropScreen(imageBytes: bytes)),
      );
      if (croppedBytes != null && mounted) {
        setState(() {
          _imageBytes = croppedBytes;
          _imageBase64 = base64Encode(croppedBytes);
        });
      }
    }
  }

  Future<void> _reCropImage() async {
    if (_originalImageBytes == null) return;
    if (!mounted) return;
    final croppedBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (_) => ImageCropScreen(imageBytes: _originalImageBytes!)),
    );
    if (croppedBytes != null && mounted) {
      setState(() {
        _imageBytes = croppedBytes;
        _imageBase64 = base64Encode(croppedBytes);
      });
    }
  }

  Future<void> _fetchCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktifkan layanan lokasi untuk memilih lokasi otomatis.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin lokasi ditolak. Silakan aktifkan izin lokasi.')),
        );
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationController.text = 'GPS: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil lokasi: $e')),
        );
      }
    }
  }

  void _toggleCategory(String label) {
    setState(() {
      if (_selectedCategories.contains(label)) {
        _selectedCategories.remove(label);
      } else {
        _selectedCategories.add(label);
      }
    });
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

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu kategori!')),
      );
      return;
    }

    if (_selectedAnimalType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih jenis hewan!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final locationText = loc;

    final latitude = _latitude;
    final longitude = _longitude;

    final post = PostModel(
      postId: '',
      userId: _currentUserId,
      username: _currentUsername,
      title: title,
      description: desc,
      imageBase64: _imageBase64,
      categories: List<String>.from(_selectedCategories),
      animalType: _selectedAnimalType,
      locationText: locationText,
      latitude: latitude,
      longitude: longitude,
      status: 'Butuh Bantuan',
      createdAt: DateTime.now(),
      favoriteBy: [],
      handledBy: [],
    );

    try {
      await _service.addPost(post);
      if (mounted) {
        _titleController.clear();
        _descController.clear();
        _locationController.clear();
        setState(() {
          _imageBase64 = '';
          _imageBytes = null;
          _originalImageBytes = null;
          _selectedCategories.clear();
          _selectedAnimalType = '';
        });
        // Show success popup then go to Home
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
                const Text('Berhasil! 🐾', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Laporan berhasil dikirim.', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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
        if (mounted) MainScaffold.switchTab(0);
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
              onTap: _imageBytes != null ? _reCropImage : _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFF8E7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF6D58A), width: 1.5),
                ),
                child: _imageBytes != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                          ),
                          Positioned(
                            bottom: 8, left: 8,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.photo_library, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Ganti foto', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.crop, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('Crop ulang', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ],
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
            // === KATEGORI (Multi-select) ===
            Row(
              children: [
                Text('Kategori',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(width: 8),
                Text('(pilih satu atau lebih)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategories.contains(cat['label']);
                return GestureDetector(
                  onTap: () => _toggleCategory(cat['label']!),
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
                        if (isSelected) ...[
                          const Icon(Icons.check, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                        ],
                        Text('${cat['emoji']} ${cat['label']}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : isDark
                                        ? Colors.grey[300]
                                        : Colors.black87)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // === JENIS HEWAN (Single-select, wajib) ===
            Row(
              children: [
                Text('Jenis Hewan',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(width: 4),
                Text('*', style: TextStyle(color: Colors.red[400], fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _animalTypes.map((animal) {
                final isSelected = _selectedAnimalType == animal['label'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedAnimalType = animal['label']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4CAF50)
                          : isDark
                              ? const Color(0xFF2C2C2C)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isSelected
                              ? const Color(0xFF4CAF50)
                              : Colors.grey[300]!),
                    ),
                    child: Text('${animal['emoji']} ${animal['label']}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : isDark
                                    ? Colors.grey[300]
                                    : Colors.black87)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            Text('Lokasi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            TextField(controller: _locationController, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _inputDecoration('Masukkan alamat lokasi...', isDark)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _fetchCurrentLocation,
                icon: const Icon(Icons.my_location, color: Color(0xFFF2994A)),
                label: const Text('Gunakan lokasi sekarang'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF2994A),
                  side: const BorderSide(color: Color(0xFFF2994A)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
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

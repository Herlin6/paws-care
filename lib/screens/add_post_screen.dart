import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:paws_care/widgets/image_source_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/services/notification_api_service.dart';
import 'package:paws_care/services/auth_service.dart';
import 'package:paws_care/widgets/main_scaffold.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

enum _GpsStatus { loading, success, failed, disabled }

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
  final TextEditingController _locationDetailController =
      TextEditingController();

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  List<String> _selectedCategories = ['Hilang'];
  String _selectedAnimalType = 'Kucing';
  String _imageBase64 = '';
  double? _latitude;
  double? _longitude;
  Uint8List? _imageBytes;
  String? _originalImagePath;
  bool _isLoading = false;
  String _currentUsername = '';
  bool _useGps = true; // true = GPS otomatis, false = manual
  _GpsStatus _gpsStatus = _GpsStatus.loading;
  String _gpsErrorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _gpsStatus = _GpsStatus.loading;
      _gpsErrorMessage = '';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _gpsStatus = _GpsStatus.disabled;
            _gpsErrorMessage = 'Layanan lokasi tidak aktif';
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _gpsStatus = _GpsStatus.failed;
            _gpsErrorMessage = 'Izin lokasi ditolak';
          });
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _gpsStatus = _GpsStatus.failed;
            _gpsErrorMessage = 'Izin lokasi ditolak permanen';
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition();

      String address = '';
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          address = '${place.street}, ${place.subLocality}, ${place.locality}'
              .replaceAll(', ,', ',');
          if (address.startsWith(', ')) address = address.substring(2);
        }
      } catch (e) {
        debugPrint("Geocoding failed: $e");
      }

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _gpsStatus = _GpsStatus.success;
          if (address.isNotEmpty && _locationController.text.isEmpty) {
            _locationController.text = address;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsStatus = _GpsStatus.failed;
          _gpsErrorMessage = 'Gagal mendapatkan lokasi';
        });
      }
    }
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
    _locationDetailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImageSourcePicker.pickImage(
      context,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      _originalImagePath = picked.path;
      _cropImage(picked.path);
    }
  }

  Future<void> _reCropImage() async {
    if (_originalImagePath != null) {
      _cropImage(_originalImagePath!);
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
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Foto'),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
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
    final loc = _locationController.text.trim();
    final locDetail = _locationDetailController.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan deskripsi wajib diisi!')),
      );
      return;
    }

    // Validate location: at least one method should have data
    final hasGps = _useGps && _latitude != null && _longitude != null;
    final hasManualLoc = !_useGps && loc.isNotEmpty;
    if (!hasGps && !hasManualLoc) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _useGps
                ? 'Lokasi GPS belum tersedia. Coba lagi atau gunakan lokasi manual.'
                : 'Masukkan alamat lokasi manual terlebih dahulu.',
          ),
        ),
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
      categories: List<String>.from(_selectedCategories),
      animalType: _selectedAnimalType,
      locationText: loc,
      locationDetail: locDetail,
      latitude: _useGps ? (_latitude ?? 0.0) : 0.0,
      longitude: _useGps ? (_longitude ?? 0.0) : 0.0,
      status: 'Butuh Bantuan',
      createdAt: DateTime.now(),
      favoriteBy: [],
      handledBy: [],
    );

    try {
      final newPostId = await _service.addPost(post);

      // Kirim notifikasi ke topic berdasarkan kombinasi kategori & jenis hewan (AND logic)
      final notifApi = NotificationApiService();
      String sanitize(String s) => s
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9\-_.~%]'), '');

      for (final cat in post.categories) {
        notifApi.sendToTopic(
          topic: 'c_${sanitize(cat)}_a_${sanitize(post.animalType)}',
          title: '📢 Laporan Baru: ${post.title}',
          body: '${post.username} melaporkan ${post.animalType} — $cat',
          data: {'postId': newPostId, 'senderUid': _currentUserId},
        );
      }

      if (mounted) {
        _titleController.clear();
        _descController.clear();
        _locationController.clear();
        _locationDetailController.clear();
        setState(() {
          _imageBase64 = '';
          _imageBytes = null;
          _originalImagePath = null;
          _selectedCategories = ['Hilang'];
          _selectedAnimalType = 'Kucing';
          _latitude = null;
          _longitude = null;
          _useGps = true;
          _gpsStatus = _GpsStatus.loading;
        });
        // Re-fetch GPS for next report
        _getCurrentLocation();
        // Show success popup then go to Home
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF4CAF50),
                    size: 56,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Berhasil! 🐾',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Laporan berhasil dikirim.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengirim: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFFFF8E7),
      appBar: AppBar(
        title: const Text(
          'Laporan Baru',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
            Text(
              'Foto Hewan',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _imageBytes != null ? _reCropImage : _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFFFF8E7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFF6D58A),
                    width: 1.5,
                  ),
                ),
                child: _imageBytes != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.photo_library,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Ganti foto',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.crop,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Crop ulang',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap untuk upload foto',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Judul',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: _inputDecoration('Judul singkat laporan...', isDark),
            ),
            const SizedBox(height: 20),
            Text(
              'Deskripsi',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: _inputDecoration(
                'Jelaskan kondisi hewan yang ditemukan...',
                isDark,
              ),
            ),
            const SizedBox(height: 20),
            // ===== JENIS HEWAN =====
            _buildAnimalTypeSection(isDark),
            const SizedBox(height: 20),
            // ===== KATEGORI (MULTI-SELECT) =====
            _buildCategorySection(isDark),
            const SizedBox(height: 20),
            // ===== LOCATION SECTION =====
            _buildLocationSection(isDark),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2994A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Kirim Laporan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
            Icon(
              Icons.pets,
              size: 18,
              color: isDark ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 6),
            Text(
              'Jenis Hewan',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Text(' *', style: TextStyle(color: Colors.red, fontSize: 14)),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
                        : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  '${PostModel.animalTypeEmoji(type)} $type',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : isDark
                        ? Colors.grey[300]
                        : Colors.black87,
                  ),
                ),
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
            Icon(
              Icons.category,
              size: 18,
              color: isDark ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 6),
            Text(
              'Kategori',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(bisa pilih lebih dari satu)',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFF2994A)
                      : isDark
                      ? const Color(0xFF2C2C2C)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFF2994A)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.check, size: 14, color: Colors.white),
                      ),
                    Text(
                      '${PostModel.categoryEmoji(cat)} $cat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : isDark
                            ? Colors.grey[300]
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on,
              size: 18,
              color: isDark ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 6),
            Text(
              'Lokasi',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Location method toggle
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _useGps = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _useGps
                          ? const Color(0xFF4CAF50)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.gps_fixed,
                          size: 16,
                          color: _useGps
                              ? Colors.white
                              : isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'GPS Otomatis',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _useGps
                                ? Colors.white
                                : isDark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _useGps = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_useGps
                          ? const Color(0xFFF2994A)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_location_alt,
                          size: 16,
                          color: !_useGps
                              ? Colors.white
                              : isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Lokasi Manual',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: !_useGps
                                ? Colors.white
                                : isDark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // GPS status or Manual input
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _useGps ? _buildGpsStatus(isDark) : _buildManualInput(isDark),
        ),
      ],
    );
  }

  Widget _buildGpsStatus(bool isDark) {
    IconData icon;
    Color iconColor;
    String statusText;
    String? subtitleText;
    Widget? trailing;

    switch (_gpsStatus) {
      case _GpsStatus.loading:
        icon = Icons.gps_fixed;
        iconColor = const Color(0xFFF2994A);
        statusText = 'Mencari lokasi GPS...';
        subtitleText = 'Pastikan GPS perangkat Anda aktif';
        trailing = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFF2994A),
          ),
        );
        break;
      case _GpsStatus.success:
        icon = Icons.check_circle;
        iconColor = const Color(0xFF4CAF50);
        statusText = 'Lokasi GPS berhasil ditemukan';
        subtitleText =
            '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}';
        trailing = null;
        break;
      case _GpsStatus.failed:
        icon = Icons.error_outline;
        iconColor = const Color(0xFFE53935);
        statusText = _gpsErrorMessage;
        subtitleText = 'Tap untuk coba lagi atau gunakan lokasi manual';
        trailing = GestureDetector(
          onTap: _getCurrentLocation,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF2994A).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.refresh,
              size: 18,
              color: Color(0xFFF2994A),
            ),
          ),
        );
        break;
      case _GpsStatus.disabled:
        icon = Icons.location_disabled;
        iconColor = Colors.grey;
        statusText = _gpsErrorMessage;
        subtitleText = 'Aktifkan GPS di pengaturan perangkat';
        trailing = GestureDetector(
          onTap: _getCurrentLocation,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF2994A).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.refresh,
              size: 18,
              color: Color(0xFFF2994A),
            ),
          ),
        );
        break;
    }

    final statusCard = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _gpsStatus == _GpsStatus.success
              ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
              : _gpsStatus == _GpsStatus.failed
              ? const Color(0xFFE53935).withValues(alpha: 0.3)
              : isDark
              ? Colors.grey[700]!
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleText,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );

    // Wrap in a Column to add editable location text field
    return Column(
      key: const ValueKey('gps'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        statusCard,
        if (_gpsStatus == _GpsStatus.success) ...[
          const SizedBox(height: 10),
          // Alamat utama - editable by user (tidak mengubah koordinat GPS)
          TextField(
            controller: _locationController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Alamat lokasi (editable, mis: "Jl. Merdeka No. 10")',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
              prefixIcon: Icon(
                Icons.location_on,
                color: Colors.grey[400],
                size: 20,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFF2994A),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.info_outline, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Alamat bisa diedit tanpa mengubah koordinat GPS.',
                  style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _locationDetailController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Detail lokasi (opsional, mis: "Depan Indomaret")',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
              prefixIcon: Icon(
                Icons.edit_note,
                color: Colors.grey[400],
                size: 20,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFF2994A),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildManualInput(bool isDark) {
    return Column(
      key: const ValueKey('manual'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _locationController,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Ketik alamat lokasi utama...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
            filled: true,
            fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFF2994A),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _locationDetailController,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Detail Lokasi (opsional, mis: Depan Indomaret)',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(
              Icons.edit_note,
              color: Colors.grey[400],
              size: 20,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFF2994A),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey[400]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Masukkan alamat lengkap agar relawan mudah menemukan lokasi.',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      filled: true,
      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF2994A), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

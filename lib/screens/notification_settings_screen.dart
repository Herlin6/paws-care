import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/services/fcm_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final FcmService _fcmService = FcmService();
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isLoading = true;
  bool _isSaving = false;

  // Preferences
  bool _enabled = true;
  List<String> _selectedCategories = [];
  List<String> _selectedAnimalTypes = [];
  bool _commentOnOwnPost = true;
  bool _commentOnVolunteerPost = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      final prefs =
          await _fcmService.getNotificationPreferences(_currentUserId);
      if (mounted) {
        setState(() {
          _enabled = prefs['enabled'] ?? true;
          
          final receiveAll = prefs['receiveAll'] == true;
          final cats = List<String>.from(prefs['categories'] ?? []);
          if (cats.contains('Semua') || receiveAll) {
            _selectedCategories = List<String>.from(PostModel.availableCategories);
          } else {
            _selectedCategories = cats;
          }

          final types = List<String>.from(prefs['animalTypes'] ?? []);
          if (types.contains('Semua') || receiveAll) {
            _selectedAnimalTypes = List<String>.from(PostModel.availableAnimalTypes);
          } else {
            _selectedAnimalTypes = types;
          }

          _commentOnOwnPost = prefs['commentOnOwnPost'] ?? true;
          _commentOnVolunteerPost = prefs['commentOnVolunteerPost'] ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    try {
      final prefs = {
        'enabled': _enabled,
        'receiveAll': false,
        'categories': _selectedCategories,
        'animalTypes': _selectedAnimalTypes,
        'commentOnOwnPost': _commentOnOwnPost,
        'commentOnVolunteerPost': _commentOnVolunteerPost,
      };

      await _fcmService.saveNotificationPreferences(
        uid: _currentUserId,
        prefs: prefs,
      );

      // Sync FCM topic subscriptions
      await _fcmService.syncTopicSubscriptions(prefs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan notifikasi tersimpan! ✅'),
            backgroundColor: Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool get _isAllCategoriesSelected =>
      _selectedCategories.length == PostModel.availableCategories.length;

  bool get _isAllAnimalTypesSelected =>
      _selectedAnimalTypes.length == PostModel.availableAnimalTypes.length;

  void _toggleAllCategories(bool value) {
    setState(() {
      if (value) {
        _selectedCategories = List<String>.from(PostModel.availableCategories);
      } else {
        _selectedCategories.clear();
      }
    });
  }

  void _toggleAllAnimalTypes(bool value) {
    setState(() {
      if (value) {
        _selectedAnimalTypes = List<String>.from(PostModel.availableAnimalTypes);
      } else {
        _selectedAnimalTypes.clear();
      }
    });
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  void _toggleAnimalType(String type) {
    setState(() {
      if (_selectedAnimalTypes.contains(type)) {
        _selectedAnimalTypes.remove(type);
      } else {
        _selectedAnimalTypes.add(type);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFFF8E7),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.notifications_outlined, color: Color(0xFFF2994A), size: 22),
            SizedBox(width: 8),
            Text('Pengaturan Notifikasi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF2994A)))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Master toggle
                        _buildMasterToggle(isDark),
                        const SizedBox(height: 16),

                        if (_enabled) ...[
                          // Category selection
                          _buildCategorySection(isDark),
                          const SizedBox(height: 16),

                          // Animal type selection
                          _buildAnimalTypeSection(isDark),
                          const SizedBox(height: 16),
                          
                          // Comment notifications
                          _buildCommentSection(isDark),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                // Save button
                _buildSaveButton(isDark),
              ],
            ),
    );
  }

  Widget _buildMasterToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _enabled
              ? const Color(0xFFF2994A).withValues(alpha: 0.3)
              : isDark
                  ? Colors.grey[800]!
                  : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _enabled
                  ? const Color(0xFFF2994A).withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _enabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: _enabled ? const Color(0xFFF2994A) : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifikasi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _enabled
                      ? 'Notifikasi aktif'
                      : 'Semua notifikasi dinonaktifkan',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: (val) => setState(() => _enabled = val),
            activeTrackColor: const Color(0xFFF2994A),
          ),
        ],
      ),
    );
  }



  Widget _buildCategorySection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📋', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Semua Kategori',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '${_selectedCategories.length} dipilih',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isAllCategoriesSelected,
                onChanged: _toggleAllCategories,
                activeTrackColor: const Color(0xFFF2994A),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pilih kategori laporan yang ingin diterima notifikasinya',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PostModel.availableCategories.map((cat) {
              final isSelected = _selectedCategories.contains(cat);
              final icon = PostModel.categoryEmoji(cat);
              return GestureDetector(
                onTap: () => _toggleCategory(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF2994A).withValues(alpha: 0.15)
                        : isDark
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFF2994A)
                          : isDark
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$icon $cat',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFFF2994A)
                              : isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalTypeSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🐾', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Semua Jenis Hewan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '${_selectedAnimalTypes.length} dipilih',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isAllAnimalTypesSelected,
                onChanged: _toggleAllAnimalTypes,
                activeTrackColor: const Color(0xFF4CAF50),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pilih jenis hewan yang ingin diterima notifikasinya',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PostModel.availableAnimalTypes.map((type) {
              final isSelected = _selectedAnimalTypes.contains(type);
              final icon = PostModel.animalTypeEmoji(type);
              return GestureDetector(
                onTap: () => _toggleAnimalType(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                        : isDark
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4CAF50)
                          : isDark
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$icon $type',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFF4CAF50)
                              : isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  color: Color(0xFFF2994A), size: 20),
              const SizedBox(width: 8),
              Text(
                'Notifikasi Komentar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Dapatkan notifikasi saat ada komentar baru',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 14),
          _buildCommentToggle(
            icon: Icons.article_outlined,
            title: 'Postingan milik sendiri',
            subtitle: 'Komentar pada laporan yang Anda buat',
            value: _commentOnOwnPost,
            onChanged: (val) =>
                setState(() => _commentOnOwnPost = val),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildCommentToggle(
            icon: Icons.volunteer_activism_outlined,
            title: 'Postingan yang diikuti',
            subtitle: 'Komentar pada laporan yang Anda tangani sebagai relawan',
            value: _commentOnVolunteerPost,
            onChanged: (val) =>
                setState(() => _commentOnVolunteerPost = val),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value
            ? const Color(0xFFF2994A).withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value
              ? const Color(0xFFF2994A).withValues(alpha: 0.2)
              : isDark
                  ? Colors.grey[700]!
                  : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    )),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFFF2994A),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _savePreferences,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_rounded, size: 20),
          label: Text(
            _isSaving ? 'Menyimpan...' : 'Simpan Pengaturan',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF2994A),
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                const Color(0xFFF2994A).withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}

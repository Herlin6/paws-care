import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/widgets/image_source_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paws_care/main.dart';
import 'package:paws_care/models/user_model.dart';
import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/services/auth_service.dart';
import 'package:paws_care/screens/login_screen.dart';
import 'package:paws_care/screens/notification_settings_screen.dart';
import 'package:image_cropper/image_cropper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _service = FirestoreService();
  final AuthService _authService = AuthService();
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  UserModel? _user;
  int _postCount = 0;
  int _helpCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = await _service.getUser(_currentUserId);
    final posts = await _service.countUserPosts(_currentUserId);
    final helps = await _service.countUserHelps(_currentUserId);
    if (mounted) {
      setState(() {
        _user = user;
        _postCount = posts;
        _helpCount = helps;
        _isLoading = false;
      });
    }
  }

  void _showProfilePhotoOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPhoto = _user?.photoBase64.isNotEmpty == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Foto Profil',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2994A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_outlined, color: Color(0xFFF2994A)),
              ),
              title: Text('Ubah Foto Profil',
                style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
              subtitle: Text('Ambil dari kamera atau galeri',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndConfirmProfilePhoto();
              },
            ),
            if (hasPhoto) ...[
              const SizedBox(height: 4),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                title: const Text('Hapus Foto Profil',
                  style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
                subtitle: Text('Kembali ke foto default',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeletePhoto();
                },
              ),
            ],
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePhoto() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Foto Profil?'),
        content: const Text('Foto profil akan dihapus dan kembali ke foto default.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.updateUser(_currentUserId, {'photoBase64': ''});
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Foto profil dihapus'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndConfirmProfilePhoto() async {
    final picked = await ImageSourcePicker.pickImage(
      context,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Foto Profil',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Foto Profil',
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        final croppedBytes = await croppedFile.readAsBytes();
        final base64Str = base64Encode(croppedBytes);
        _showPhotoConfirmation(croppedBytes, base64Str);
      }
    }
  }

  void _showPhotoConfirmation(Uint8List imageBytes, String base64Str) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Foto Profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(60),
              child: Image.memory(imageBytes, width: 120, height: 120, fit: BoxFit.cover),
            ),
            const SizedBox(height: 14),
            Text('Gunakan foto ini sebagai foto profil?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.updateUser(_currentUserId, {'photoBase64': base64Str});
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Foto profil diperbarui! ✅'), backgroundColor: Color(0xFF4CAF50)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF2994A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    if (_user == null) return;
    final nameCtrl = TextEditingController(text: _user!.username);
    final phoneCtrl = TextEditingController(text: _user!.phone);
    bool isPhoneValid = _user!.phone.isEmpty || (_user!.phone.length >= 12 && _user!.phone.length <= 13);
    String phoneError = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          void validatePhone() {
            final phone = phoneCtrl.text.trim();
            if (phone.isEmpty) {
              setDialogState(() {
                isPhoneValid = true;
                phoneError = '';
              });
            } else if (phone.length < 12 || phone.length > 13) {
              setDialogState(() {
                isPhoneValid = false;
                phoneError = 'Nomor telepon harus terdiri dari 12–13 digit angka.';
              });
            } else {
              setDialogState(() {
                isPhoneValid = true;
                phoneError = '';
              });
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Edit Profil'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: _editDeco('Username')),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                  ],
                  decoration: _editDeco('Nomor Telepon').copyWith(
                    errorText: phoneError.isNotEmpty ? phoneError : null,
                    errorMaxLines: 2,
                    counterText: '${phoneCtrl.text.length}/13',
                  ),
                  onChanged: (_) => validatePhone(),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: isPhoneValid
                    ? () async {
                        Navigator.pop(ctx);
                        await _service.updateUser(_currentUserId, {
                          'username': nameCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                        });
                        _loadData();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profil diperbarui! ✅'), backgroundColor: Color(0xFF4CAF50)),
                          );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2994A),
                  disabledBackgroundColor: Colors.grey[400],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Simpan', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog() {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscure1 = true;
    bool obscure2 = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ubah Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPassCtrl,
                obscureText: obscure1,
                decoration: _editDeco('Password Baru').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(obscure1 ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.grey),
                    onPressed: () => setDialogState(() => obscure1 = !obscure1),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassCtrl,
                obscureText: obscure2,
                decoration: _editDeco('Konfirmasi Password').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(obscure2 ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.grey),
                    onPressed: () => setDialogState(() => obscure2 = !obscure2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final newPass = newPassCtrl.text.trim();
                final confirmPass = confirmPassCtrl.text.trim();
                if (newPass.isEmpty || confirmPass.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua field harus diisi!')));
                  return;
                }
                if (newPass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password minimal 6 karakter!')));
                  return;
                }
                if (newPass != confirmPass) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password tidak cocok!')));
                  return;
                }
                try {
                  Navigator.pop(ctx);
                  await _authService.updatePassword(newPass);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password berhasil diubah! ✅'), backgroundColor: Color(0xFF4CAF50)),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal ubah password: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2994A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _editDeco(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF2994A))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFFF8E7),
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.person, color: Color(0xFFF2994A), size: 22),
          SizedBox(width: 8),
          Text('Profil', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF2994A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const SizedBox(height: 10),
                // Avatar with photo
                GestureDetector(
                  onTap: _showProfilePhotoOptions,
                  child: Stack(children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xFFF6D58A).withValues(alpha: 0.5),
                      backgroundImage: _user?.photoBase64.isNotEmpty == true
                          ? MemoryImage(base64Decode(_user!.photoBase64))
                          : null,
                      child: _user?.photoBase64.isNotEmpty != true
                          ? Text(
                              (_user?.username.isNotEmpty == true) ? _user!.username[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF6D4C00)),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Color(0xFFF2994A), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                Text(_user?.username ?? '', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _user?.isAdmin == true ? const Color(0xFFE53935).withValues(alpha: 0.1) : const Color(0xFFF2994A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _user?.role ?? 'Pengguna',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: _user?.isAdmin == true ? const Color(0xFFE53935) : const Color(0xFFF2994A)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(_user?.email ?? '', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                if (_user?.phone.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(_user!.phone, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
                const SizedBox(height: 24),
                // Stats
                Row(children: [
                  Expanded(child: _buildStatCard(Icons.article_outlined, Colors.orange, _postCount.toString(), 'Posting', isDark)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildStatCard(Icons.volunteer_activism, const Color(0xFF4CAF50), _helpCount.toString(), 'Bantuan', isDark)),
                ]),
                const SizedBox(height: 24),
                // Menu
                _buildMenuItem(Icons.edit_outlined, 'Edit Profil', isDark, _showEditProfileDialog),
                const SizedBox(height: 10),
                _buildMenuItem(Icons.lock_outline, 'Ubah Password', isDark, _showChangePasswordDialog),
                const SizedBox(height: 10),
                _buildMenuItem(Icons.notifications_outlined, 'Notifikasi', isDark, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()));
                }),
                const SizedBox(height: 10),
                _buildDarkModeItem(isDark),
                const SizedBox(height: 10),
                _buildMenuItem(Icons.logout, 'Logout', isDark, _logout, isLogout: true),
              ]),
            ),
    );
  }

  Widget _buildStatCard(IconData icon, Color color, String value, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(children: [
        Icon(icon, color: color, size: 28), const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ]),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, bool isDark, VoidCallback onTap, {bool isLogout = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
        child: Row(children: [
          Icon(icon, color: isLogout ? Colors.red : Colors.grey[600], size: 22), const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isLogout ? Colors.red : isDark ? Colors.white : Colors.black87))),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
        ]),
      ),
    );
  }

  Widget _buildDarkModeItem(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(children: [
        Icon(Icons.dark_mode_outlined, color: Colors.grey[600], size: 22), const SizedBox(width: 14),
        Expanded(child: Text('Dark Mode', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
        Switch(value: isDark, onChanged: (val) async {
          themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isDarkMode', val);
        }, activeTrackColor: const Color(0xFFF2994A)),
      ]),
    );
  }
}

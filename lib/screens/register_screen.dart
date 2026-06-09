import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/services/auth_service.dart';
import 'package:paws_care/services/fcm_service.dart';
import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/widgets/main_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Username validation state
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String _usernameError = '';
  Timer? _usernameDebounce;

  // Password validation state
  bool _hasMinLength = false;
  bool _hasUpperFirst = false;
  bool _hasLowerCase = false;
  bool _hasDigit = false;
  bool _hasSpecialChar = false;

  bool get _isPasswordValid =>
      _hasMinLength && _hasUpperFirst && _hasLowerCase && _hasDigit && _hasSpecialChar;

  bool get _canRegister =>
      _nameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _isUsernameAvailable == true &&
      _isPasswordValid &&
      !_isLoading;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onUsernameChanged);
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final username = _nameController.text.trim();
    setState(() {
      _isUsernameAvailable = null;
      _usernameError = '';
    });

    if (username.isEmpty) return;

    _usernameDebounce?.cancel();
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _isCheckingUsername = true);
      try {
        final available = await _firestoreService.isUsernameAvailable(username);
        if (mounted && _nameController.text.trim() == username) {
          setState(() {
            _isCheckingUsername = false;
            _isUsernameAvailable = available;
            _usernameError = available
                ? ''
                : 'Username sudah digunakan, silakan gunakan username lain.';
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isCheckingUsername = false);
        }
      }
    });
  }

  void _onPasswordChanged() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUpperFirst = password.isNotEmpty && password[0] == password[0].toUpperCase() && password[0] != password[0].toLowerCase();
      _hasLowerCase = password.contains(RegExp(r'[a-z]'));
      _hasDigit = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]'));
    });
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnack('Semua field harus diisi!');
      return;
    }
    if (!_isPasswordValid) {
      _showSnack('Password belum memenuhi semua syarat!');
      return;
    }
    if (_isUsernameAvailable != true) {
      _showSnack('Username sudah digunakan, silakan gunakan username lain.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await _authService.register(email: email, password: password, username: name);
      if (user != null && mounted) {
        // Save FCM token for the new user
        FcmService().saveTokenForUser(user.uid);
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainScaffold()), (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = 'Registrasi gagal';
        if (e.code == 'email-already-in-use') {
          msg = 'Email sudah terdaftar';
        } else if (e.code == 'weak-password') {
          msg = 'Password terlalu lemah';
        } else if (e.code == 'invalid-email') {
          msg = 'Format email tidak valid';
        }
        _showSnack(msg);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        _showSnack(msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red[400]));
  }

  InputDecoration _deco(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: Colors.grey[400]),
      filled: true, fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF2994A))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildPasswordRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? const Color(0xFF4CAF50) : Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isMet ? const Color(0xFF4CAF50) : Colors.grey[500],
                fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: isDark
              ? [const Color(0xFF3A3020), const Color(0xFF1E1E1E), const Color(0xFF121212)]
              : [const Color(0xFFF6D58A), const Color(0xFFFFF8E7), const Color(0xFFFFFFFF)],
            stops: const [0.0, 0.4, 1.0]),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const SizedBox(height: 60),
              Image.asset(
                'assets/images/logo.png',
                height: 140,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              Text('Selamatkan & rawat hewan di sekitarmu 🐾', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : const Color(0xFF666666))),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.white, borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06), blurRadius: 20, offset: const Offset(0, 4))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Username field with availability check
                  Text('Username', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: _deco('Username unik', isDark).copyWith(
                      suffixIcon: _nameController.text.trim().isEmpty
                          ? null
                          : _isCheckingUsername
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF2994A))),
                                )
                              : _isUsernameAvailable == true
                                  ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 22)
                                  : _isUsernameAvailable == false
                                      ? const Icon(Icons.cancel, color: Colors.red, size: 22)
                                      : null,
                    ),
                  ),
                  if (_usernameError.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(_usernameError, style: const TextStyle(fontSize: 12, color: Colors.red)),
                  ],
                  const SizedBox(height: 18),
                  // Email field
                  Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: _deco('email@contoh.com', isDark),
                    onChanged: (_) => setState(() {})),
                  const SizedBox(height: 18),
                  // Password field with validation
                  Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  TextField(controller: _passwordController, obscureText: _obscurePassword, style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: _deco('••••••••', isDark).copyWith(suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey[400], size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword)))),
                  // Password requirements guide
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFF8E7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Syarat Password:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                        const SizedBox(height: 8),
                        _buildPasswordRequirement('Minimal 8 karakter', _hasMinLength),
                        _buildPasswordRequirement('Huruf pertama harus kapital', _hasUpperFirst),
                        _buildPasswordRequirement('Mengandung minimal 1 huruf kecil', _hasLowerCase),
                        _buildPasswordRequirement('Mengandung minimal 1 angka', _hasDigit),
                        _buildPasswordRequirement('Mengandung minimal 1 karakter khusus (!@#\$%^&*)', _hasSpecialChar),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: _canRegister ? _register : null,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2994A), foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFF2994A).withValues(alpha: 0.4),
                        disabledForegroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Daftar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Sudah punya akun? ', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : const Color(0xFF666666))),
                    GestureDetector(onTap: () => Navigator.pop(context),
                      child: const Text('Masuk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFF2994A)))),
                  ]),
                ]),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ),
    );
  }
}

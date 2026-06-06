import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/services/auth_service.dart';
import 'package:paws_care/widgets/main_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Username check state
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  Timer? _usernameDebounce;

  // Password validation state
  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUpperFirst =>
      _passwordController.text.isNotEmpty &&
      _passwordController.text[0].toUpperCase() ==
          _passwordController.text[0] &&
      RegExp(r'[A-Z]').hasMatch(_passwordController.text[0]);
  bool get _hasLowerCase => RegExp(r'[a-z]').hasMatch(_passwordController.text);
  bool get _hasDigit => RegExp(r'[0-9]').hasMatch(_passwordController.text);
  bool get _hasSpecialChar => RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]')
      .hasMatch(_passwordController.text);
  bool get _isPasswordValid =>
      _hasMinLength &&
      _hasUpperFirst &&
      _hasLowerCase &&
      _hasDigit &&
      _hasSpecialChar;

  bool get _canRegister =>
      _nameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _isPasswordValid &&
      _isUsernameAvailable == true &&
      !_isCheckingUsername;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onUsernameChanged);
    _passwordController.addListener(() => setState(() {}));
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
    _usernameDebounce?.cancel();

    if (username.isEmpty) {
      setState(() {
        _isUsernameAvailable = null;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _isUsernameAvailable = null;
    });

    _usernameDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (username.isEmpty) return;
      try {
        final available = await _authService.isUsernameAvailable(username);
        if (mounted && _nameController.text.trim() == username) {
          setState(() {
            _isUsernameAvailable = available;
            _isCheckingUsername = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isCheckingUsername = false);
        }
      }
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
      _showSnack('Password belum memenuhi seluruh syarat!');
      return;
    }
    if (_isUsernameAvailable != true) {
      _showSnack('Username sudah digunakan, silakan gunakan username lain.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await _authService.register(
          email: email, password: password, username: name);
      if (user != null && mounted) {
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainScaffold()),
            (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = 'Registrasi gagal';
        if (e.code == 'email-already-in-use') {
          msg = 'Email sudah terdaftar';
        } else if (e.code == 'username-already-in-use') {
          msg = 'Username sudah digunakan, silakan gunakan username lain.';
        } else if (e.code == 'weak-password') {
          msg = 'Password terlalu lemah';
        } else if (e.code == 'invalid-email') {
          msg = 'Format email tidak valid';
        }
        _showSnack(msg);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red[400]));
  }

  InputDecoration _deco(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF2994A))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildPasswordRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: isMet ? const Color(0xFF4CAF50) : Colors.grey[400],
          ),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                fontSize: 11,
                color: isMet ? const Color(0xFF4CAF50) : Colors.grey[500],
                fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xFF3A3020),
                      const Color(0xFF1E1E1E),
                      const Color(0xFF121212)
                    ]
                  : [
                      const Color(0xFFF6D58A),
                      const Color(0xFFFFF8E7),
                      const Color(0xFFFFFFFF)
                    ],
              stops: const [0.0, 0.4, 1.0]),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const SizedBox(height: 40),
              const Icon(Icons.pets, size: 56, color: Color(0xFFF2994A)),
              const SizedBox(height: 16),
              RichText(
                  text: TextSpan(
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold),
                      children: [
                    TextSpan(
                        text: 'Paws ',
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF333333))),
                    const TextSpan(
                        text: '& ', style: TextStyle(color: Color(0xFFF2994A))),
                    TextSpan(
                        text: 'Care',
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF333333))),
                  ])),
              const SizedBox(height: 8),
              Text('Selamatkan & rawat hewan di sekitarmu 🐾',
                  style: TextStyle(
                      fontSize: 13,
                      color:
                          isDark ? Colors.grey[400] : const Color(0xFF666666))),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.3 : 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 4))
                    ]),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // === USERNAME ===
                      Text('Username',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87),
                        decoration: _deco('Username unik', isDark).copyWith(
                          suffixIcon: _nameController.text.trim().isEmpty
                              ? null
                              : _isCheckingUsername
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFFF2994A))),
                                    )
                                  : _isUsernameAvailable == true
                                      ? const Icon(Icons.check_circle,
                                          color: Color(0xFF4CAF50), size: 20)
                                      : _isUsernameAvailable == false
                                          ? const Icon(Icons.cancel,
                                              color: Colors.red, size: 20)
                                          : null,
                        ),
                      ),
                      if (_isUsernameAvailable == false)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                              'Username sudah digunakan, silakan gunakan username lain.',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.red[400])),
                        ),
                      if (_isUsernameAvailable == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('✓ Username tersedia',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.green[600])),
                        ),
                      const SizedBox(height: 18),

                      // === EMAIL ===
                      Text('Email',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 8),
                      TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87),
                          decoration: _deco('email@contoh.com', isDark),
                          onChanged: (_) => setState(() {})),
                      const SizedBox(height: 18),

                      // === PASSWORD ===
                      Text('Password',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 8),
                      TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87),
                          decoration: _deco('••••••••', isDark).copyWith(
                              suffixIcon: IconButton(
                                  icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.grey[400],
                                      size: 20),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword)))),

                      // Password requirements checklist
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Syarat password:',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[500])),
                              const SizedBox(height: 4),
                              _buildPasswordRequirement(
                                  'Minimal 8 karakter', _hasMinLength),
                              _buildPasswordRequirement(
                                  'Huruf pertama harus kapital',
                                  _hasUpperFirst),
                              _buildPasswordRequirement(
                                  'Mengandung huruf kecil', _hasLowerCase),
                              _buildPasswordRequirement(
                                  'Mengandung angka', _hasDigit),
                              _buildPasswordRequirement(
                                  'Mengandung karakter khusus (!@#\$%^&* dll)',
                                  _hasSpecialChar),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),

                      // === REGISTER BUTTON ===
                      SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                              onPressed: (_isLoading || !_canRegister)
                                  ? null
                                  : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF2994A),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFFF2994A)
                                    .withValues(alpha: 0.4),
                                disabledForegroundColor: Colors.white70,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text('Daftar',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)))),
                      const SizedBox(height: 16),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Sudah punya akun? ',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : const Color(0xFF666666))),
                            GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text('Masuk',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF2994A)))),
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

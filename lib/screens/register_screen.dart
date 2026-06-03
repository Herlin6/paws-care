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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnack('Semua field harus diisi!');
      return;
    }
    if (password.length < 6) {
      _showSnack('Password minimal 6 karakter!');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await _authService.register(email: email, password: password, username: name);
      if (user != null && mounted) {
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
      if (mounted) _showSnack('Error: $e');
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
              const Icon(Icons.pets, size: 56, color: Color(0xFFF2994A)),
              const SizedBox(height: 16),
              RichText(text: TextSpan(style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold), children: [
                TextSpan(text: 'Paws ', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF333333))),
                const TextSpan(text: '& ', style: TextStyle(color: Color(0xFFF2994A))),
                TextSpan(text: 'Care', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF333333))),
              ])),
              const SizedBox(height: 8),
              Text('Selamatkan & rawat hewan di sekitarmu 🐾', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : const Color(0xFF666666))),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.white, borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06), blurRadius: 20, offset: const Offset(0, 4))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Nama', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  TextField(controller: _nameController, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _deco('Nama lengkap', isDark)),
                  const SizedBox(height: 18),
                  Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _deco('email@contoh.com', isDark)),
                  const SizedBox(height: 18),
                  Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  TextField(controller: _passwordController, obscureText: _obscurePassword, style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: _deco('••••••••', isDark).copyWith(suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey[400], size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword)))),
                  const SizedBox(height: 28),
                  SizedBox(width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2994A), foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFF2994A).withValues(alpha: 0.6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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

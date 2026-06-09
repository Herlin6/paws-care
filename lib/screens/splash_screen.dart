import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/main.dart';
import 'package:paws_care/widgets/main_scaffold.dart';
import 'package:paws_care/screens/login_screen.dart';
import 'package:paws_care/services/fcm_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _slideAnim = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: const Interval(0.3, 0.8, curve: Curves.easeOut)),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _pulseController.repeat(reverse: true);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _navigateBasedOnAuth();
    });
  }

  void _navigateBasedOnAuth() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Save/update FCM token and sync notification preferences for auto-login
      final fcmService = FcmService();
      fcmService.saveTokenForUser(user.uid);
      fcmService.syncPreferencesForUser(user.uid);
    }
    final destination = user != null ? const MainScaffold() : const LoginScreen();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn), child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF3A3020), const Color(0xFF1E1E1E), const Color(0xFF121212)]
                : [const Color(0xFFF6D58A), const Color(0xFFFFF8E7), Colors.white],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_fadeController, _pulseController]),
          builder: (context, _) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated logo
                FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF2994A).withValues(alpha: isDark ? 0.2 : 0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 180,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Subtitle
                Transform.translate(
                  offset: Offset(0, _slideAnim.value * 1.2),
                  child: Opacity(
                    opacity: _fadeAnim.value,
                    child: Text(
                      'Selamatkan & rawat hewan di sekitarmu 🐾',
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : const Color(0xFF666666)),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                // Loading dots
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: const Color(0xFFF2994A).withAlpha(isDark ? 200 : 255)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

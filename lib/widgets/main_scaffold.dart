import 'package:flutter/material.dart';
import 'package:paws_care/screens/home_screen.dart';
import 'package:paws_care/screens/favorite_screen.dart';
import 'package:paws_care/screens/add_post_screen.dart';
import 'package:paws_care/screens/history_screen.dart';
import 'package:paws_care/screens/profile_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  static _MainScaffoldState? _instance;

  static void switchTab(int index) {
    _instance?.switchToTab(index);
  }

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final AnimationController _navAnimController;

  final List<Widget> _screens = [
    const HomeScreen(),
    const FavoriteScreen(),
    const AddPostScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    MainScaffold._instance = this;
    _navAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _navAnimController.forward();
  }

  @override
  void dispose() {
    if (MainScaffold._instance == this) MainScaffold._instance = null;
    _navAnimController.dispose();
    super.dispose();
  }

  void switchToTab(int index) {
    setState(() => _currentIndex = index);
    _navAnimController.reset();
    _navAnimController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(isDark ? 40 : 15), blurRadius: 12, offset: const Offset(0, -3)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                _buildNavItem(1, Icons.favorite_border_rounded, Icons.favorite_rounded, 'Favorit'),
                _buildCenterButton(),
                _buildNavItem(3, Icons.history_rounded, Icons.history_rounded, 'Riwayat'),
                _buildNavItem(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isActive ? const Color(0xFFF2994A) : (isDark ? Colors.grey[600]! : Colors.grey[400]!);

    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) switchToTab(index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFF2994A).withAlpha(30) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(isActive ? activeIcon : icon, size: 24, color: color),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton() {
    return GestureDetector(
      onTap: () {
        if (_currentIndex != 2) switchToTab(2);
      },
      child: Container(
        width: 54, height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFF6D58A), Color(0xFFF2994A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: const Color(0xFFF2994A).withAlpha(100), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 24),
            Text('Post', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

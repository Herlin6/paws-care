import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/services/auth_service.dart';
import 'package:paws_care/widgets/post_card.dart';
import 'package:paws_care/widgets/category_chip.dart';
import 'package:paws_care/screens/detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _service = FirestoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Multi-select category filter
  final Set<String> _selectedCategories = {};
  // Single-select animal type filter
  String? _selectedAnimalType;

  String _searchQuery = '';
  String _userName = '';
  bool _showFilters = false;

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
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = await _authService.getCurrentUserModel();
    if (user != null && mounted) {
      setState(() => _userName = user.username);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategories.isNotEmpty) count++;
    if (_selectedAnimalType != null) count++;
    return count;
  }

  List<PostModel> _filterPosts(List<PostModel> posts) {
    var filtered = posts;

    if (_selectedCategories.isNotEmpty) {
      filtered = filtered
          .where((p) =>
              p.categories.any((cat) => _selectedCategories.contains(cat)))
          .toList();
    }

    if (_selectedAnimalType != null) {
      filtered =
          filtered.where((p) => p.animalType == _selectedAnimalType).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q) ||
              p.username.toLowerCase().contains(q))
          .toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFFFF8E7),
      body: Column(
        children: [
          _buildHeader(isDark),
          _buildFilterBar(isDark),
          if (_showFilters) _buildExpandedFilters(isDark),
          Expanded(child: _buildPostList(isDark)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          right: 16,
          bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF3A3020), const Color(0xFF1E1E1E)]
              : [const Color(0xFFF6D58A), const Color(0xFFFFF8E7)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getGreeting()} 👋',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : const Color(0xFF8B7355),
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                _userName.isNotEmpty ? _userName : 'Paws & Care',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF333333)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 31 : 13),
                    blurRadius: 10,
                    offset: const Offset(0, 2))
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(
                  fontSize: 14, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Cari laporan hewan...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.grey[400], size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(Icons.close_rounded,
                            color: Colors.grey[400], size: 18),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showFilters = !_showFilters),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _showFilters || _activeFilterCount > 0
                    ? const Color(0xFFF2994A)
                    : isDark
                        ? const Color(0xFF2C2C2C)
                        : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _showFilters || _activeFilterCount > 0
                      ? const Color(0xFFF2994A)
                      : isDark
                          ? Colors.grey[700]!
                          : Colors.grey[300]!,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded,
                      size: 16,
                      color: _showFilters || _activeFilterCount > 0
                          ? Colors.white
                          : isDark
                              ? Colors.grey[400]
                              : Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text('Filter',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _showFilters || _activeFilterCount > 0
                              ? Colors.white
                              : isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600])),
                  if (_activeFilterCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x4DFFFFFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$_activeFilterCount',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_activeFilterCount > 0) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() {
                _selectedCategories.clear();
                _selectedAnimalType = null;
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x1AFF0000),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, size: 14, color: Colors.red[400]),
                    const SizedBox(width: 4),
                    Text('Reset',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[400])),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandedFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kategori',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500])),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _categories.map((cat) {
              final isSelected = _selectedCategories.contains(cat['label']);
              return CategoryChip(
                label: cat['label']!,
                emoji: cat['emoji']!,
                isSelected: isSelected,
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedCategories.remove(cat['label']);
                  } else {
                    _selectedCategories.add(cat['label']!);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text('Jenis Hewan',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500])),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              CategoryChip(
                label: 'Semua',
                emoji: '🐾',
                isSelected: _selectedAnimalType == null,
                onTap: () => setState(() => _selectedAnimalType = null),
              ),
              ..._animalTypes.map((animal) {
                final isSelected = _selectedAnimalType == animal['label'];
                return CategoryChip(
                  label: animal['label']!,
                  emoji: animal['emoji']!,
                  isSelected: isSelected,
                  onTap: () =>
                      setState(() => _selectedAnimalType = animal['label']),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostList(bool isDark) {
    return StreamBuilder<List<PostModel>>(
      stream: _service.streamPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingShimmer(isDark);
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final posts = _filterPosts(snapshot.data ?? []);
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.pets_rounded,
                      size: 48, color: Colors.grey[400]),
                ),
                const SizedBox(height: 20),
                Text(
                  _searchQuery.isNotEmpty || _activeFilterCount > 0
                      ? 'Tidak ada hasil'
                      : 'Belum ada laporan',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Coba kata kunci lain'
                      : _activeFilterCount > 0
                          ? 'Coba ubah filter'
                          : 'Jadilah yang pertama melapor!',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(
              post: post,
              currentUserId: _currentUserId,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DetailScreen(postId: post.postId))),
              onFavorite: () =>
                  _service.toggleFavorite(post.postId, _currentUserId),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingShimmer(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 280,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3A3A3A) : Colors.grey[200],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 14,
                        width: 160,
                        decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF3A3A3A)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(
                        height: 10,
                        width: 220,
                        decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF3A3A3A)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(
                        height: 10,
                        width: 140,
                        decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF3A3A3A)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/services/auth_service.dart';
import 'package:paws_care/widgets/post_card.dart';
import 'package:paws_care/widgets/category_chip.dart';
import 'package:paws_care/screens/detail_screen.dart';
import 'package:paws_care/screens/map_screen.dart';

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
  final Set<String> _selectedCategories = {};
  String _selectedAnimalType = 'Semua';
  String _selectedStatus = 'Semua';
  bool _showFilters = false;
  String _searchQuery = '';
  String _userName = '';

  final List<Map<String, String>> _categoryFilters = [
    {'label': 'Semua', 'emoji': '🐾'},
    {'label': 'Hilang', 'emoji': '🔍'},
    {'label': 'Ditemukan', 'emoji': '📦'},
    {'label': 'Kecelakaan', 'emoji': '🚨'},
    {'label': 'Mati', 'emoji': '💀'},
    {'label': 'Terjebak', 'emoji': '🪤'},
    {'label': 'Sakit', 'emoji': '🩹'},
    {'label': 'Lainnya', 'emoji': '📋'},
  ];

  final List<Map<String, String>> _animalTypeFilters = [
    {'label': 'Semua', 'emoji': '🐾'},
    {'label': 'Kucing', 'emoji': '🐱'},
    {'label': 'Anjing', 'emoji': '🐶'},
    {'label': 'Burung', 'emoji': '🐦'},
    {'label': 'Kelinci', 'emoji': '🐰'},
    {'label': 'Reptil', 'emoji': '🦎'},
    {'label': 'Lainnya', 'emoji': '🐾'},
  ];

  final List<Map<String, String>> _statusFilters = [
    {'label': 'Semua', 'emoji': '📋'},
    {'label': 'Butuh Bantuan', 'emoji': '🆘'},
    {'label': 'Sedang Ditangani', 'emoji': '🤝'},
    {'label': 'Menunggu Konfirmasi Penyelesaian', 'emoji': '⏳'},
    {'label': 'Berhasil Ditangani', 'emoji': '✅'},
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

  void _toggleCategoryFilter(String category) {
    setState(() {
      if (category == 'Semua') {
        _selectedCategories.clear();
      } else {
        if (_selectedCategories.contains(category)) {
          _selectedCategories.remove(category);
        } else {
          _selectedCategories.add(category);
        }
      }
    });
  }

  List<PostModel> _filterPosts(List<PostModel> posts) {
    var filtered = posts;

    // Filter by categories (multi-select): post must have at least one matching category
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered.where((p) =>
          p.categories.any((cat) => _selectedCategories.contains(cat))).toList();
    }

    // Filter by animal type
    if (_selectedAnimalType != 'Semua') {
      filtered = filtered.where((p) => p.animalType == _selectedAnimalType).toList();
    }

    // Filter by status
    if (_selectedStatus != 'Semua') {
      filtered = filtered.where((p) => p.status == _selectedStatus).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) =>
          p.title.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.username.toLowerCase().contains(q)).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFFF8E7),
      body: Column(
        children: [
          _buildHeader(isDark),
          if (_showFilters) ...[
            _buildCategoryChips(isDark),
            _buildAnimalTypeChips(isDark),
            _buildStatusChips(isDark),
          ],
          Expanded(child: _buildPostList(isDark)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 16, right: 16, bottom: 14),
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreeting()} 👋',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : const Color(0xFF8B7355), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userName.isNotEmpty ? _userName : 'Paws & Care',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF333333)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: const Icon(Icons.map_rounded, color: Color(0xFFF2994A), size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 30 : 12), blurRadius: 10, offset: const Offset(0, 2))],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Cari laporan hewan...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                              child: Icon(Icons.close_rounded, color: Colors.grey[400], size: 18),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                child: Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: _showFilters ? const Color(0xFFF2994A) : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 30 : 12), blurRadius: 10, offset: const Offset(0, 2))],
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: _showFilters ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(bool isDark) {
    final bool isAllSelected = _selectedCategories.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: Text('Kategori', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        ),
        SizedBox(
          height: 46,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
            scrollDirection: Axis.horizontal,
            itemCount: _categoryFilters.length,
            itemBuilder: (context, index) {
              final cat = _categoryFilters[index];
              final label = cat['label']!;
              final isSelected = label == 'Semua' ? isAllSelected : _selectedCategories.contains(label);
              return CategoryChip(
                label: label,
                emoji: cat['emoji']!,
                isSelected: isSelected,
                onTap: () => _toggleCategoryFilter(label),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnimalTypeChips(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 2),
          child: Text('Jenis Hewan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        ),
        SizedBox(
          height: 46,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
            scrollDirection: Axis.horizontal,
            itemCount: _animalTypeFilters.length,
            itemBuilder: (context, index) {
              final type = _animalTypeFilters[index];
              return CategoryChip(
                label: type['label']!,
                emoji: type['emoji']!,
                isSelected: _selectedAnimalType == type['label'],
                onTap: () => setState(() => _selectedAnimalType = type['label']!),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChips(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 2),
          child: Text('Status Postingan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        ),
        SizedBox(
          height: 46,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
            scrollDirection: Axis.horizontal,
            itemCount: _statusFilters.length,
            itemBuilder: (context, index) {
              final type = _statusFilters[index];
              return CategoryChip(
                label: type['label']!,
                emoji: type['emoji']!,
                isSelected: _selectedStatus == type['label'],
                onTap: () => setState(() => _selectedStatus = type['label']!),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
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
                    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.pets_rounded, size: 48, color: Colors.grey[400]),
                ),
                const SizedBox(height: 20),
                Text(
                  _searchQuery.isNotEmpty ? 'Tidak ada hasil' : 'Belum ada laporan',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Text(
                  _searchQuery.isNotEmpty ? 'Coba kata kunci lain' : 'Jadilah yang pertama melapor!',
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
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(postId: post.postId))),
              onFavorite: () => _service.toggleFavorite(post.postId, _currentUserId),
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                    Container(height: 14, width: 160, decoration: BoxDecoration(color: isDark ? const Color(0xFF3A3A3A) : Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 220, decoration: BoxDecoration(color: isDark ? const Color(0xFF3A3A3A) : Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(height: 10, width: 140, decoration: BoxDecoration(color: isDark ? const Color(0xFF3A3A3A) : Colors.grey[200], borderRadius: BorderRadius.circular(4))),
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

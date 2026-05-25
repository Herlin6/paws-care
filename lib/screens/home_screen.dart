import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/services/auth_service.dart';
import 'package:paws_care/widgets/post_card.dart';
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
  String _searchQuery = '';
  String _userName = '';

  // Filter state
  List<String> _filterCategories = [];
  String _filterAnimalType = '';

  final List<Map<String, String>> _categories = [
    {'label': 'Hilang', 'emoji': '🔍'},
    {'label': 'Ditemukan', 'emoji': '🤝'},
    {'label': 'Kecelakaan', 'emoji': '🚨'},
    {'label': 'Mati', 'emoji': '🪦'},
    {'label': 'Terjebak', 'emoji': '🕸️'},
    {'label': 'Lainnya', 'emoji': '🐾'},
  ];

  final List<Map<String, String>> _animalTypes = [
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

  bool get _hasActiveFilters => _filterCategories.isNotEmpty || _filterAnimalType.isNotEmpty;

  List<PostModel> _filterPosts(List<PostModel> posts) {
    var filtered = posts;
    // Filter by categories (show posts that contain ANY of the selected categories)
    if (_filterCategories.isNotEmpty) {
      filtered = filtered.where((p) =>
        p.categories.any((cat) => _filterCategories.contains(cat))
      ).toList();
    }
    // Filter by animal type
    if (_filterAnimalType.isNotEmpty) {
      filtered = filtered.where((p) => p.animalType == _filterAnimalType).toList();
    }
    // Search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) =>
          p.title.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.username.toLowerCase().contains(q)).toList();
    }
    return filtered;
  }

  void _showFilterSheet() {
    // Temp state for the bottom sheet
    List<String> tempCategories = List.from(_filterCategories);
    String tempAnimalType = _filterAnimalType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.filter_list_rounded, color: isDark ? Colors.white : Colors.black87),
                        const SizedBox(width: 8),
                        Text('Filter Postingan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Categories section
                    Text('Kategori', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text('Pilih satu atau lebih', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _categories.map((cat) {
                        final sel = tempCategories.contains(cat['label']);
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              if (sel) { tempCategories.remove(cat['label']); }
                              else { tempCategories.add(cat['label']!); }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? const Color(0xFFF2994A) : isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9F9F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? const Color(0xFFF2994A) : Colors.grey[300]!),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (sel) ...[const Icon(Icons.check, color: Colors.white, size: 14), const SizedBox(width: 4)],
                              Text('${cat['emoji']} ${cat['label']}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : isDark ? Colors.grey[300] : Colors.black87)),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Animal type section
                    Text('Jenis Hewan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text('Pilih satu jenis', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        // "Semua" option
                        GestureDetector(
                          onTap: () => setModalState(() => tempAnimalType = ''),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: tempAnimalType.isEmpty ? const Color(0xFF4CAF50) : isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9F9F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: tempAnimalType.isEmpty ? const Color(0xFF4CAF50) : Colors.grey[300]!),
                            ),
                            child: Text('🐾 Semua', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tempAnimalType.isEmpty ? Colors.white : isDark ? Colors.grey[300] : Colors.black87)),
                          ),
                        ),
                        ..._animalTypes.map((animal) {
                          final sel = tempAnimalType == animal['label'];
                          return GestureDetector(
                            onTap: () => setModalState(() => tempAnimalType = animal['label']!),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel ? const Color(0xFF4CAF50) : isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9F9F9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: sel ? const Color(0xFF4CAF50) : Colors.grey[300]!),
                              ),
                              child: Text('${animal['emoji']} ${animal['label']}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : isDark ? Colors.grey[300] : Colors.black87)),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Action buttons
                    Row(children: [
                      Expanded(child: OutlinedButton(
                        onPressed: () {
                          setModalState(() { tempCategories.clear(); tempAnimalType = ''; });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                        child: Text('Reset', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _filterCategories = List.from(tempCategories);
                            _filterAnimalType = tempAnimalType;
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF2994A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Terapkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      )),
                    ]),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFFF8E7),
      body: Column(
        children: [
          _buildHeader(isDark),
          // Active filter chips
          if (_hasActiveFilters) _buildActiveFilters(isDark),
          Expanded(child: _buildPostList(isDark)),
        ],
      ),
    );
  }

  Widget _buildActiveFilters(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 6, runSpacing: 6,
        children: [
          ..._filterCategories.map((cat) => Chip(
            label: Text(cat, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFFF2994A).withOpacity(0.15),
            labelStyle: const TextStyle(color: Color(0xFFF2994A)),
            deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFFF2994A)),
            onDeleted: () => setState(() => _filterCategories.remove(cat)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )),
          if (_filterAnimalType.isNotEmpty)
            Chip(
              label: Text(_filterAnimalType, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              backgroundColor: const Color(0xFF4CAF50).withOpacity(0.15),
              labelStyle: const TextStyle(color: Color(0xFF4CAF50)),
              deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF4CAF50)),
              onDeleted: () => setState(() => _filterAnimalType = ''),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          GestureDetector(
            onTap: () => setState(() { _filterCategories.clear(); _filterAnimalType = ''; }),
            child: Chip(
              label: const Text('Hapus semua', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              backgroundColor: Colors.grey.withOpacity(0.15),
              labelStyle: TextStyle(color: Colors.grey[600]),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: const Icon(Icons.pets_rounded, color: Color(0xFFF2994A), size: 22),
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
              const SizedBox(width: 10),
              // Filter button
              GestureDetector(
                onTap: _showFilterSheet,
                child: Container(
                  height: 46, width: 46,
                  decoration: BoxDecoration(
                    color: _hasActiveFilters ? const Color(0xFFF2994A) : isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 30 : 12), blurRadius: 10, offset: const Offset(0, 2))],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.tune_rounded, color: _hasActiveFilters ? Colors.white : Colors.grey[500], size: 22),
                      if (_hasActiveFilters)
                        Positioned(top: 8, right: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
                    ],
                  ),
                ),
              ),
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
                    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.pets_rounded, size: 48, color: Colors.grey[400]),
                ),
                const SizedBox(height: 20),
                Text(
                  _searchQuery.isNotEmpty || _hasActiveFilters ? 'Tidak ada hasil' : 'Belum ada laporan',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Text(
                  _searchQuery.isNotEmpty || _hasActiveFilters ? 'Coba ubah filter atau kata kunci' : 'Jadilah yang pertama melapor!',
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

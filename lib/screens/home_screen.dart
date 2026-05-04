import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/services/firestore_service.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String _selectedCategory = 'Semua';
  String _searchQuery = '';

  final List<Map<String, String>> _categories = [
    {'label': 'Semua', 'emoji': '🐾'},
    {'label': 'Sakit', 'emoji': '🩹'},
    {'label': 'Kelaparan', 'emoji': '🍽️'},
    {'label': 'Adopsi', 'emoji': '🏠'},
    {'label': 'Sterilisasi', 'emoji': '✂️'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PostModel> _filterPosts(List<PostModel> posts) {
    var filtered = posts;
    if (_selectedCategory != 'Semua') {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }
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
          _buildCategoryChips(),
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
              const Icon(Icons.pets, color: Color(0xFFF2994A), size: 24),
              const SizedBox(width: 8),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(text: 'Paws ', style: TextStyle(color: Color(0xFFF2994A))),
                    TextSpan(text: '& ', style: TextStyle(color: Color(0xFFF2994A))),
                    TextSpan(text: 'Care', style: TextStyle(color: Color(0xFFF2994A))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Cari laporan...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                        child: Icon(Icons.clear, color: Colors.grey[400], size: 18),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return CategoryChip(
            label: cat['label']!,
            emoji: cat['emoji']!,
            isSelected: _selectedCategory == cat['label'],
            onTap: () => setState(() => _selectedCategory = cat['label']!),
          );
        },
      ),
    );
  }

  Widget _buildPostList(bool isDark) {
    return StreamBuilder<List<PostModel>>(
      stream: _service.streamPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFF2994A)));
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
                Icon(Icons.pets, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty ? 'Tidak ada hasil untuk "$_searchQuery"' : 'Belum ada laporan',
                  style: TextStyle(fontSize: 16, color: Colors.grey[400]),
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
}

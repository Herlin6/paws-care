import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/screens/detail_screen.dart';
import 'package:paws_care/utils/marker_generator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final FirestoreService _service = FirestoreService();
  
  // State for map
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  final LatLng _defaultCenter = const LatLng(-0.7893, 113.9213);
  
  // State for data
  List<PostModel> _allPosts = [];
  bool _isLoading = true;
  Position? _userPosition;

  // Filter state
  String _selectedCategory = 'Semua';
  String _selectedAnimal = 'Semua';
  String _selectedStatus = 'Semua'; // Default not showing completed
  
  // Lists for filters
  final List<String> _filterCategories = ['Semua', ...PostModel.availableCategories];
  final List<String> _filterAnimals = ['Semua', ...PostModel.availableAnimalTypes];
  final List<String> _filterStatuses = [
    'Semua',
    'Menunggu Relawan',
    'Sedang Ditangani',
    'Menunggu Konfirmasi'
  ];

  @override
  void initState() {
    super.initState();
    _initMapData();
  }

  Future<void> _initMapData() async {
    await _getUserLocation();
    _setupPostsStream();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userPosition = position;
        });
        
        // Move camera to user if map is ready
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude),
              13.0,
            ),
          );
        }
      }
    } catch (_) {}
  }

  void _setupPostsStream() {
    _service.streamPosts().listen((posts) {
      if (!mounted) return;
      
      setState(() {
        _allPosts = posts;
        _isLoading = false;
      });
      
      _applyFiltersAndDrawMarkers();
    });
  }

  Future<void> _applyFiltersAndDrawMarkers() async {
    final filteredPosts = _allPosts.where((post) {
      // 1. Must have GPS
      if (post.latitude == 0 || post.longitude == 0) return false;
      
      // 2. Hide completed/finished by default (Req 2)
      if (post.status == 'Berhasil Ditangani' || post.status == 'Selesai') {
        return false;
      }

      // 3. Category Filter
      if (_selectedCategory != 'Semua' && !post.categories.contains(_selectedCategory)) {
        return false;
      }

      // 4. Animal Type Filter
      if (_selectedAnimal != 'Semua' && post.animalType != _selectedAnimal) {
        return false;
      }

      // 5. Status Filter
      if (_selectedStatus != 'Semua') {
        if (_selectedStatus == 'Menunggu Relawan' && post.status != 'Butuh Bantuan') return false;
        if (_selectedStatus == 'Sedang Ditangani' && post.status != 'Sedang Ditangani') return false;
        if (_selectedStatus == 'Menunggu Konfirmasi' && post.status != 'Menunggu Konfirmasi Penyelesaian') return false;
      }

      return true;
    }).toList();

    final newMarkers = <Marker>{};

    for (final post in filteredPosts) {
      Color markerColor;
      if (post.status == 'Butuh Bantuan') {
        markerColor = const Color(0xFFE53935); // Merah
      } else if (post.status == 'Sedang Ditangani') {
        markerColor = const Color(0xFFF2994A); // Oranye
      } else if (post.status == 'Menunggu Konfirmasi Penyelesaian') {
        markerColor = const Color(0xFFFFCA28); // Kuning
      } else {
        markerColor = const Color(0xFF4CAF50); // Hijau (fallback)
      }

      final icon = await MarkerGenerator.createCustomMarker(
        color: markerColor,
        emoji: PostModel.animalTypeEmoji(post.animalType),
      );

      newMarkers.add(
        Marker(
          markerId: MarkerId(post.postId),
          position: LatLng(post.latitude, post.longitude),
          icon: icon,
          onTap: () => _showPostBottomSheet(post),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
      });
    }
  }

  void _onFilterChanged() {
    _applyFiltersAndDrawMarkers();
  }

  void _showPostBottomSheet(PostModel post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Hitung jarak jika lokasi user tersedia
    String distanceStr = 'Jarak tidak diketahui';
    if (_userPosition != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        _userPosition!.latitude,
        _userPosition!.longitude,
        post.latitude,
        post.longitude,
      );
      if (distanceInMeters < 1000) {
        distanceStr = '${distanceInMeters.toStringAsFixed(0)} meter dari Anda';
      } else {
        distanceStr = '${(distanceInMeters / 1000).toStringAsFixed(1)} km dari Anda';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 80, height: 80,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: post.imageBase64.isNotEmpty
                          ? Image.memory(base64Decode(post.imageBase64), fit: BoxFit.cover)
                          : const Icon(Icons.pets, color: Colors.grey, size: 30),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Jarak
                        Row(
                          children: [
                            Icon(Icons.directions_walk, size: 14, color: const Color(0xFFF2994A)),
                            const SizedBox(width: 4),
                            Text(
                              distanceStr,
                              style: const TextStyle(fontSize: 12, color: Color(0xFFF2994A), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Animal type & Status badges
                        Wrap(
                          spacing: 6, runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${PostModel.animalTypeEmoji(post.animalType)} ${post.animalType}',
                                style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: post.status == 'Sedang Ditangani'
                                    ? Colors.orange.withValues(alpha: 0.15)
                                    : post.status == 'Menunggu Konfirmasi Penyelesaian'
                                        ? Colors.blue.withValues(alpha: 0.15)
                                        : Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                post.status,
                                style: TextStyle(
                                  color: post.status == 'Sedang Ditangani'
                                      ? Colors.orange
                                      : post.status == 'Menunggu Konfirmasi Penyelesaian'
                                          ? Colors.blue
                                          : Colors.red,
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Categories chips
              Wrap(
                spacing: 6, runSpacing: 4,
                children: post.categories
                    .map((cat) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2994A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${PostModel.categoryEmoji(cat)} $cat',
                            style: const TextStyle(color: Color(0xFFF2994A), fontSize: 11, fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),

              // Action Button
              SizedBox(
                width: double.infinity, height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DetailScreen(postId: post.postId)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2994A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Lihat Detail Lengkap', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _moveToUserLocation() async {
    if (_userPosition == null) {
      await _getUserLocation();
    }
    if (_userPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_userPosition!.latitude, _userPosition!.longitude),
          14.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Peta Utama
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              // Set initial map position to user location if already available
              if (_userPosition != null) {
                controller.animateCamera(CameraUpdate.newLatLngZoom(
                  LatLng(_userPosition!.latitude, _userPosition!.longitude), 13.0));
              }
            },
            initialCameraPosition: CameraPosition(
              target: _userPosition != null 
                  ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                  : _defaultCenter,
              zoom: 5.0,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Kita buat tombol custom
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: isDark ? Colors.black54 : Colors.white54,
              child: const Center(child: CircularProgressIndicator(color: Color(0xFFF2994A))),
            ),

          // Empty state message
          if (!_isLoading && _markers.isEmpty)
            Positioned(
              top: 140, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tidak ada marker yang sesuai filter.',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Filter UI (Floating Top)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10, right: 10,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Back button
                  _buildFloatingBtn(
                    icon: Icons.arrow_back,
                    isDark: isDark,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  
                  // Filter Kategori
                  _buildFilterDropdown(
                    value: _selectedCategory,
                    items: _filterCategories,
                    isDark: isDark,
                    icon: Icons.category_outlined,
                    onChanged: (val) {
                      if (val != null) setState(() { _selectedCategory = val; });
                      _onFilterChanged();
                    },
                  ),
                  const SizedBox(width: 8),

                  // Filter Hewan
                  _buildFilterDropdown(
                    value: _selectedAnimal,
                    items: _filterAnimals,
                    isDark: isDark,
                    icon: Icons.pets_outlined,
                    onChanged: (val) {
                      if (val != null) setState(() { _selectedAnimal = val; });
                      _onFilterChanged();
                    },
                  ),
                  const SizedBox(width: 8),

                  // Filter Status
                  _buildFilterDropdown(
                    value: _selectedStatus,
                    items: _filterStatuses,
                    isDark: isDark,
                    icon: Icons.assignment_outlined,
                    onChanged: (val) {
                      if (val != null) setState(() { _selectedStatus = val; });
                      _onFilterChanged();
                    },
                  ),
                ],
              ),
            ),
          ),

          // 3. Tombol Aksi Kanan (Lokasi Saya & Refresh)
          Positioned(
            right: 16,
            bottom: 120, // Di atas legenda
            child: Column(
              children: [
                _buildFloatingBtn(
                  icon: Icons.my_location,
                  isDark: isDark,
                  onTap: _moveToUserLocation,
                  color: const Color(0xFFF2994A),
                  iconColor: Colors.white,
                ),
                const SizedBox(height: 12),
                _buildFloatingBtn(
                  icon: Icons.refresh,
                  isDark: isDark,
                  onTap: _applyFiltersAndDrawMarkers,
                ),
              ],
            ),
          ),

          // 4. Legenda (Floating Bottom)
          Positioned(
            left: 16, bottom: 20, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Legenda Status', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, 
                    color: isDark ? Colors.grey[300] : Colors.grey[700]
                  )),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12, runSpacing: 6,
                    children: [
                      _buildLegendItem(const Color(0xFFE53935), 'Butuh Relawan', isDark),
                      _buildLegendItem(const Color(0xFFF2994A), 'Ditangani', isDark),
                      _buildLegendItem(const Color(0xFFFFCA28), 'Konfirmasi', isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white : Colors.black87)),
      ],
    );
  }

  Widget _buildFloatingBtn({
    required IconData icon, 
    required bool isDark, 
    required VoidCallback onTap,
    Color? color,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color ?? (isDark ? const Color(0xFF2C2C2C) : Colors.white),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        child: Icon(icon, size: 22, color: iconColor ?? (isDark ? Colors.white : Colors.black87)),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required bool isDark,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFF2994A)),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: value,
            items: items.map((e) => DropdownMenuItem(
              value: e, 
              child: Text(e, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
            )).toList(),
            onChanged: onChanged,
            underline: const SizedBox(),
            isDense: true,
            icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
            dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:paws_care/models/post_model.dart';
import 'package:paws_care/services/firestore_service.dart';
import 'package:paws_care/screens/detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final FirestoreService _service = FirestoreService();
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  GoogleMapController? _mapController;

  // Default coordinate (Center of Indonesia) if not determined
  final LatLng _defaultCenter = const LatLng(-0.7893, 113.9213);

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  // Marker color by status
  double _markerHue(String status) {
    switch (status) {
      case 'Butuh Bantuan':
        return BitmapDescriptor.hueRed;
      case 'Sedang Ditangani':
        return BitmapDescriptor.hueBlue;
      case 'Berhasil Ditangani':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueOrange;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Butuh Bantuan': return const Color(0xFFE53935);
      case 'Sedang Ditangani': return const Color(0xFF2196F3);
      case 'Berhasil Ditangani': return const Color(0xFF4CAF50);
      default: return Colors.grey;
    }
  }

  String _animalEmoji(String type) {
    switch (type) {
      case 'Kucing': return '🐱';
      case 'Anjing': return '🐶';
      case 'Burung': return '🐦';
      case 'Kelinci': return '🐰';
      case 'Reptil': return '🦎';
      default: return '🐾';
    }
  }

  void _loadMarkers() {
    _service.streamPosts().listen((posts) {
      if (!mounted) return;
      final newMarkers = <Marker>{};
      
      for (final post in posts) {
        if (post.latitude != 0 && post.longitude != 0) {
          newMarkers.add(
            Marker(
              markerId: MarkerId(post.postId),
              position: LatLng(post.latitude, post.longitude),
              onTap: () => _showPostBottomSheet(post),
              icon: BitmapDescriptor.defaultMarkerWithHue(_markerHue(post.status)),
            ),
          );
        }
      }
      
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
        _isLoading = false;
      });
      
      if (newMarkers.isNotEmpty && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(newMarkers.first.position, 12.0),
        );
      }
    });
  }

  void _showPostBottomSheet(PostModel post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormatted = DateFormat('dd MMM yyyy, HH:mm').format(post.createdAt);
    
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
              // Handle for bottom sheet
              Center(
                child: Container(
                  width: 40,
                  height: 4,
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
                      width: 80,
                      height: 80,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: post.imageBase64.isNotEmpty
                          ? Image.memory(
                              base64Decode(post.imageBase64),
                              fit: BoxFit.cover,
                            )
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(post.status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            post.status,
                            style: TextStyle(
                              color: _statusColor(post.status),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Info rows
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    // Nama Pelapor
                    _infoRow(Icons.person_outline, 'Pelapor', post.username, isDark),
                    const Divider(height: 16),
                    // Jenis Hewan
                    _infoRow(Icons.pets, 'Jenis Hewan',
                        post.animalType.isNotEmpty
                            ? '${_animalEmoji(post.animalType)} ${post.animalType}'
                            : '-',
                        isDark),
                    const Divider(height: 16),
                    // Kategori
                    _infoRow(Icons.category_outlined, 'Kategori',
                        post.categories.isNotEmpty ? post.categories.join(', ') : '-',
                        isDark),
                    const Divider(height: 16),
                    // Tanggal
                    _infoRow(Icons.calendar_today_outlined, 'Tanggal', dateFormatted, isDark),
                    const Divider(height: 16),
                    // Lokasi
                    _infoRow(Icons.location_on_outlined, 'Lokasi',
                        post.locationText.isNotEmpty ? post.locationText : 'Lokasi GPS',
                        isDark),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailScreen(postId: post.postId),
                      ),
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

  Widget _infoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFF2994A)),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.map, color: Color(0xFFF2994A), size: 22),
          SizedBox(width: 8),
          Text('Peta Laporan', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF2994A)))
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: _defaultCenter,
                    zoom: 5.0,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                // Legend
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Keterangan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 6),
                        _legendItem('🔴', 'Butuh Bantuan', isDark),
                        const SizedBox(height: 3),
                        _legendItem('🔵', 'Sedang Ditangani', isDark),
                        const SizedBox(height: 3),
                        _legendItem('🟢', 'Selesai', isDark),
                      ],
                    ),
                  ),
                ),
                if (_markers.isEmpty)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Belum ada laporan dengan koordinat GPS.',
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _legendItem(String emoji, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.grey[700])),
      ],
    );
  }
}

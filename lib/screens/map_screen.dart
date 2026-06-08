import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
              icon: BitmapDescriptor.defaultMarkerWithHue(
                post.status == 'Berhasil Ditangani'
                    ? BitmapDescriptor.hueGreen
                    : post.status == 'Sedang Ditangani'
                        ? BitmapDescriptor.hueOrange
                        : BitmapDescriptor.hueRed,
              ),
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
                          : const Icon(Icons.pets,
                              color: Colors.grey, size: 30),
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
                        const SizedBox(height: 4),
                        // Reporter name
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              post.username,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Animal type + Status
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // Animal type badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${PostModel.animalTypeEmoji(post.animalType)} ${post.animalType}',
                                style: const TextStyle(
                                  color: Color(0xFF4CAF50),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: post.status == 'Berhasil Ditangani'
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : post.status == 'Sedang Ditangani'
                                        ? Colors.orange.withValues(alpha: 0.15)
                                        : Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                post.status,
                                style: TextStyle(
                                  color: post.status == 'Berhasil Ditangani'
                                      ? Colors.green
                                      : post.status == 'Sedang Ditangani'
                                          ? Colors.orange
                                          : Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
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
                spacing: 6,
                runSpacing: 4,
                children: post.categories
                    .map((cat) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF2994A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${PostModel.categoryEmoji(cat)} $cat',
                            style: const TextStyle(
                              color: Color(0xFFF2994A),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),

              // Date info
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    '${post.createdAt.day}/${post.createdAt.month}/${post.createdAt.year}  ${post.createdAt.hour.toString().padLeft(2, '0')}:${post.createdAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Location Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on,
                        size: 18, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.locationText.isNotEmpty
                                ? post.locationText
                                : 'Lokasi GPS tersedia',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  isDark ? Colors.grey[300] : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (post.locationDetail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              post.locationDetail,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Lihat Detail Lengkap',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.map, color: Color(0xFFF2994A), size: 22),
          SizedBox(width: 8),
          Text('Peta Laporan', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF2994A)))
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
                if (_markers.isEmpty)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6)
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Belum ada laporan dengan koordinat GPS.',
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600),
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
}

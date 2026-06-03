import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
              infoWindow: InfoWindow(
                title: post.title,
                snippet: '${post.category} - ${post.status}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailScreen(postId: post.postId),
                    ),
                  );
                },
              ),
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
    });
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF2994A)))
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _defaultCenter,
                zoom: 5.0,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
    );
  }
}

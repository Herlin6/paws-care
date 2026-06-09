import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerGenerator {
  /// Cache untuk menghemat memori jika marker yang sama digambar berulang kali
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Membuat custom marker dinamis berisi pin dengan warna sesuai status,
  /// dan teks/emoji di tengahnya.
  static Future<BitmapDescriptor> createCustomMarker({
    required Color color,
    required String emoji,
  }) async {
    final cacheKey = '${color.value}_$emoji';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    const double size = 120.0;
    
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // 1. Gambar drop shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 5), size / 2.5, shadowPaint);

    // 2. Gambar lingkaran background utama
    final Paint paint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.2, paint);

    // 3. Gambar lingkaran dalam (putih)
    final Paint innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 3.0, innerPaint);

    // 4. Gambar emoji / text di tengah
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: emoji,
      style: const TextStyle(
        fontSize: size / 2.5,
      ),
    );
    textPainter.layout();
    
    final xCenter = (size - textPainter.width) / 2;
    final yCenter = (size - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(xCenter, yCenter));

    // Convert ke BitmapDescriptor
    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    
    final bitmap = BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
    
    // Simpan ke cache
    _cache[cacheKey] = bitmap;
    return bitmap;
  }
}

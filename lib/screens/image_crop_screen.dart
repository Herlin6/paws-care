
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ImageCropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  /// Aspect ratio for crop area (width / height). Default 16:9 landscape to match post card display.
  final double aspectRatio;
  const ImageCropScreen({super.key, required this.imageBytes, this.aspectRatio = 16 / 9});

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final TransformationController _controller = TransformationController();
  double _imgW = 0;
  double _imgH = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _imgW = frame.image.width.toDouble();
        _imgH = frame.image.height.toDouble();
        _loaded = true;
      });
    }
    frame.image.dispose();
    codec.dispose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Compute the crop rect in the available area
  Rect _cropRect(Size area) {
    final ar = widget.aspectRatio;
    double cw, ch;
    if (area.width / area.height > ar) {
      ch = area.height * 0.75;
      cw = ch * ar;
    } else {
      cw = area.width * 0.85;
      ch = cw / ar;
    }
    final cx = (area.width - cw) / 2;
    final cy = (area.height - ch) / 2;
    return Rect.fromLTWH(cx, cy, cw, ch);
  }

  Future<Uint8List?> _doCrop(Size area) async {
    try {
      final crop = _cropRect(area);
      final matrix = _controller.value;
      final scale = matrix.getMaxScaleOnAxis();
      final tx = matrix[12];
      final ty = matrix[13];

      // Image displayed size (fit contain inside area)
      double dispW, dispH;
      final imgAr = _imgW / _imgH;
      final areaAr = area.width / area.height;
      if (imgAr > areaAr) {
        dispW = area.width;
        dispH = area.width / imgAr;
      } else {
        dispH = area.height;
        dispW = area.height * imgAr;
      }

      // Image top-left on screen before transform
      final baseX = (area.width - dispW) / 2;
      final baseY = (area.height - dispH) / 2;

      // After transform: displayed position
      final imgLeft = baseX * scale + tx;
      final imgTop = baseY * scale + ty;
      final scaledW = dispW * scale;
      // scaledH not needed for crop calculation

      // Pixel-per-screen ratio
      final pxPerScreen = _imgW / scaledW;

      // Crop in image pixel coords
      double srcX = (crop.left - imgLeft) * pxPerScreen;
      double srcY = (crop.top - imgTop) * pxPerScreen;
      double srcW = crop.width * pxPerScreen;
      double srcH = crop.height * pxPerScreen;

      srcX = srcX.clamp(0, _imgW);
      srcY = srcY.clamp(0, _imgH);
      srcW = srcW.clamp(1, _imgW - srcX);
      srcH = srcH.clamp(1, _imgH - srcY);

      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final outW = srcW.toInt().clamp(1, 2000);
      final outH = srcH.toInt().clamp(1, 2000);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(srcX, srcY, srcW, srcH),
        Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(outW, outH);
      final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);

      image.dispose();
      codec.dispose();
      cropped.dispose();

      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Crop Foto', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
            onPressed: () async {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              // area = full body minus appbar
              final appBarH = AppBar().preferredSize.height + MediaQuery.of(context).padding.top;
              const bottomH = 52.0; // hint bar height
              final area = Size(box.size.width, box.size.height - appBarH - bottomH);
              final result = await _doCrop(area);
              if (result != null && context.mounted) {
                Navigator.pop(context, result);
              } else if (context.mounted) {
                Navigator.pop(context, widget.imageBytes);
              }
            },
            child: const Text('Selesai', style: TextStyle(color: Color(0xFFF2994A), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF2994A)))
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final area = Size(constraints.maxWidth, constraints.maxHeight);
                    final crop = _cropRect(area);
                    return Stack(
                      children: [
                        // Interactive image
                        Positioned.fill(
                          child: InteractiveViewer(
                            transformationController: _controller,
                            minScale: 0.5,
                            maxScale: 5.0,
                            child: Image.memory(widget.imageBytes, fit: BoxFit.contain),
                          ),
                        ),
                        // Dim overlay outside crop
                        IgnorePointer(child: CustomPaint(
                          size: area,
                          painter: _CropOverlayPainter(cropRect: crop),
                        )),
                      ],
                    );
                  }),
                ),
                Container(
                  height: 52,
                  color: Colors.black,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.pinch, color: Colors.grey[500], size: 20),
                    const SizedBox(width: 8),
                    Text('Geser dan zoom untuk memilih area', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ]),
                ),
              ],
            ),
    );
  }
}

/// Paints a dimmed overlay outside the crop rect, with grid lines and corner handles.
class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  _CropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    // Dim outside
    final dimPaint = Paint()..color = Colors.black.withAlpha(160);
    // Top
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, cropRect.top), dimPaint);
    // Bottom
    canvas.drawRect(Rect.fromLTWH(0, cropRect.bottom, size.width, size.height - cropRect.bottom), dimPaint);
    // Left
    canvas.drawRect(Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height), dimPaint);
    // Right
    canvas.drawRect(Rect.fromLTWH(cropRect.right, cropRect.top, size.width - cropRect.right, cropRect.height), dimPaint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(cropRect, borderPaint);

    // Grid lines (rule of thirds)
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final thirdW = cropRect.width / 3;
    final thirdH = cropRect.height / 3;
    for (int i = 1; i < 3; i++) {
      // Vertical
      final x = cropRect.left + thirdW * i;
      canvas.drawLine(Offset(x, cropRect.top), Offset(x, cropRect.bottom), gridPaint);
      // Horizontal
      final y = cropRect.top + thirdH * i;
      canvas.drawLine(Offset(cropRect.left, y), Offset(cropRect.right, y), gridPaint);
    }

    // Corner handles
    const handleLen = 22.0;
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(Offset(cropRect.left, cropRect.top), Offset(cropRect.left + handleLen, cropRect.top), handlePaint);
    canvas.drawLine(Offset(cropRect.left, cropRect.top), Offset(cropRect.left, cropRect.top + handleLen), handlePaint);
    // Top-right
    canvas.drawLine(Offset(cropRect.right, cropRect.top), Offset(cropRect.right - handleLen, cropRect.top), handlePaint);
    canvas.drawLine(Offset(cropRect.right, cropRect.top), Offset(cropRect.right, cropRect.top + handleLen), handlePaint);
    // Bottom-left
    canvas.drawLine(Offset(cropRect.left, cropRect.bottom), Offset(cropRect.left + handleLen, cropRect.bottom), handlePaint);
    canvas.drawLine(Offset(cropRect.left, cropRect.bottom), Offset(cropRect.left, cropRect.bottom - handleLen), handlePaint);
    // Bottom-right
    canvas.drawLine(Offset(cropRect.right, cropRect.bottom), Offset(cropRect.right - handleLen, cropRect.bottom), handlePaint);
    canvas.drawLine(Offset(cropRect.right, cropRect.bottom), Offset(cropRect.right, cropRect.bottom - handleLen), handlePaint);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) => old.cropRect != cropRect;
}

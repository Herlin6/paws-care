import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Reusable bottom sheet dialog for choosing image source (Camera / Gallery).
/// Returns the picked [XFile] or null if cancelled.
class ImageSourcePicker {
  /// Shows a bottom sheet with Camera and Gallery options.
  /// Returns the [XFile] picked by the user, or null if cancelled/error.
  static Future<XFile?> pickImage(
    BuildContext context, {
    double maxWidth = 800,
    double maxHeight = 800,
    int imageQuality = 85,
  }) async {
    final source = await _showSourceDialog(context);
    if (source == null) return null;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      return picked;
    } catch (e) {
      if (context.mounted) {
        final message = e.toString().contains('camera_access_denied') ||
                e.toString().contains('photo_access_denied')
            ? 'Izin akses ditolak. Silakan buka Pengaturan untuk mengizinkan akses.'
            : 'Gagal mengambil gambar. Silakan coba lagi.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return null;
    }
  }

  /// Shows the bottom sheet dialog and returns the selected [ImageSource].
  static Future<ImageSource?> _showSourceDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Pilih Sumber Foto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            // Camera option
            _buildOption(
              context: ctx,
              icon: Icons.camera_alt_rounded,
              iconColor: const Color(0xFF4CAF50),
              title: 'Ambil dari Kamera',
              subtitle: 'Ambil foto langsung menggunakan kamera',
              isDark: isDark,
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
            // Gallery option
            _buildOption(
              context: ctx,
              icon: Icons.photo_library_rounded,
              iconColor: const Color(0xFFF2994A),
              title: 'Pilih dari Galeri',
              subtitle: 'Pilih foto dari galeri perangkat',
              isDark: isDark,
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  static Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

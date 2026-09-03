import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AttachedFileData {
  final String name;
  final Uint8List bytes;
  final bool isImage;
  final String base64DataUri;

  AttachedFileData({
    required this.name,
    required this.bytes,
    required this.isImage,
    required this.base64DataUri,
  });
}

class AttachmentSheet extends StatelessWidget {
  const AttachmentSheet({super.key});

  static final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 65,
      );

      if (photo != null) {
        final Uint8List bytes = await photo.readAsBytes();
        final String base64Str = base64Encode(bytes);
        final String mime = photo.mimeType ?? 'image/jpeg';
        final dataUri = 'data:$mime;base64,$base64Str';

        if (context.mounted) {
          Navigator.pop(
            context,
            AttachedFileData(
              name: photo.name,
              bytes: bytes,
              isImage: true,
              base64DataUri: dataUri,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickMediaOrFile(BuildContext context) async {
    try {
      final XFile? file = await _picker.pickMedia(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 65,
      );

      if (file != null) {
        final Uint8List bytes = await file.readAsBytes();
        final String base64Str = base64Encode(bytes);
        final String mime = file.mimeType ?? 'application/octet-stream';
        final dataUri = 'data:$mime;base64,$base64Str';

        if (context.mounted) {
          Navigator.pop(
            context,
            AttachedFileData(
              name: file.name,
              bytes: bytes,
              isImage: mime.startsWith('image/'),
              base64DataUri: dataUri,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildOption(
              context,
              icon: Icons.camera_alt_outlined,
              label: 'Camera',
              onTap: () => _pickImage(context, ImageSource.camera),
            ),
            _buildOption(
              context,
              icon: Icons.image_outlined,
              label: 'Photos',
              onTap: () => _pickImage(context, ImageSource.gallery),
            ),
            _buildOption(
              context,
              icon: Icons.folder_outlined,
              label: 'Files',
              onTap: () => _pickMediaOrFile(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: Colors.black87),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

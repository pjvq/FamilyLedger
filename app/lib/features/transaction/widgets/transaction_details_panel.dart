import 'dart:io';
import 'package:go_router/go_router.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/utils/input_sanitizer.dart' show maxNoteLength;

/// Handles image picking and local storage for transaction attachments.
class TransactionImageService {
  final _imagePicker = ImagePicker();

  /// Pick an image from camera or gallery, copy to app documents, return path.
  Future<String?> pickAndSave(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('拍照'),
              onTap: () => ctx.pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('从相册选择'),
              onTap: () => ctx.pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (picked == null) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${appDir.path}/transaction_images');
    if (!imgDir.existsSync()) imgDir.createSync(recursive: true);
    final ext = p.extension(picked.path).isNotEmpty
        ? p.extension(picked.path)
        : '.jpg';
    final destPath =
        '${imgDir.path}/${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999).toString().padLeft(5, '0')}$ext';
    await File(picked.path).copy(destPath);
    return destPath;
  }
}

/// The details panel (note + tags + images) for AddTransactionPage.
class TransactionDetailsPanel extends StatelessWidget {
  final TextEditingController noteController;
  final TextEditingController tagController;
  final List<String> tags;
  final List<String> imagePaths;
  final VoidCallback onTagAdded;
  final void Function(String) onTagRemoved;
  final void Function(String) onImageRemoved;
  final VoidCallback onPickImage;

  const TransactionDetailsPanel({
    super.key,
    required this.noteController,
    required this.tagController,
    required this.tags,
    required this.imagePaths,
    required this.onTagAdded,
    required this.onTagRemoved,
    required this.onImageRemoved,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: noteController,
              maxLength: maxNoteLength,
              decoration: const InputDecoration(
                hintText: '备注',
                prefixIcon: Icon(Icons.note_outlined, size: 18),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ...tags.map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => onTagRemoved(tag),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )),
                SizedBox(
                  width: 100,
                  height: 32,
                  child: TextField(
                    controller: tagController,
                    decoration: const InputDecoration(
                      hintText: '+标签',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 12),
                    onSubmitted: (_) => onTagAdded(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...imagePaths.map((path) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(path),
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 56,
                                  height: 56,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image,
                                      size: 24, color: Colors.grey),
                                ),
                              ),
                            ),
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () => onImageRemoved(path),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  GestureDetector(
                    onTap: onPickImage,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

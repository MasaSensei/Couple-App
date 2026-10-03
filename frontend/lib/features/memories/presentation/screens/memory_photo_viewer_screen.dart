import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/memories/data/models/memory_photo_model.dart';
import 'package:frontend/features/memories/data/repositories/memory_photo_repository.dart';
import 'package:frontend/features/memories/providers/memory_photo_provider.dart';

class MemoryPhotoViewerScreen extends ConsumerStatefulWidget {
  const MemoryPhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  final List<MemoryPhotoModel> photos;
  final int initialIndex;

  @override
  ConsumerState<MemoryPhotoViewerScreen> createState() =>
      _MemoryPhotoViewerScreenState();
}

class _MemoryPhotoViewerScreenState
    extends ConsumerState<MemoryPhotoViewerScreen> {
  late final PageController _pageController;

  late int _currentIndex;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;

    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return _PhotoViewerItem(
                  photo: widget.photos[index],
                  repository: ref.read(memoryPhotoRepositoryProvider),
                );
              },
            ),

            Positioned(
              top: 12,
              left: 12,
              child: _ViewerButton(
                icon: Icons.close,
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),

            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    '${_currentIndex + 1} / ${widget.photos.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoViewerItem extends StatefulWidget {
  const _PhotoViewerItem({required this.photo, required this.repository});

  final MemoryPhotoModel photo;
  final MemoryPhotoRepository repository;

  @override
  State<_PhotoViewerItem> createState() => _PhotoViewerItemState();
}

class _PhotoViewerItemState extends State<_PhotoViewerItem> {
  late Future<List<int>> _photoFuture;

  @override
  void initState() {
    super.initState();

    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant _PhotoViewerItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.photo.id != widget.photo.id) {
      _loadPhoto();
    }
  }

  void _loadPhoto() {
    _photoFuture = widget.repository.getPhotoBytes(photoId: widget.photo.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: _photoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white,
                  size: 48,
                ),
                SizedBox(height: 12),
                Text(
                  'Foto tidak dapat dimuat.',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          );
        }

        final bytes = snapshot.data;

        if (bytes == null || bytes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.white,
                  size: 48,
                ),
                SizedBox(height: 12),
                Text(
                  'Foto tidak tersedia.',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(24),
          clipBehavior: Clip.none,
          panEnabled: true,
          scaleEnabled: true,
          child: Center(
            child: Image.memory(Uint8List.fromList(bytes), fit: BoxFit.contain),
          ),
        );
      },
    );
  }
}

class _ViewerButton extends StatelessWidget {
  const _ViewerButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

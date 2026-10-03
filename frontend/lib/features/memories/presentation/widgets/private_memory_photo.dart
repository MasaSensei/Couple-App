import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/memories/data/models/memory_photo_model.dart';
import 'package:frontend/features/memories/providers/memory_photo_provider.dart';

class PrivateMemoryPhoto extends ConsumerStatefulWidget {
  const PrivateMemoryPhoto({super.key, required this.photo});

  final MemoryPhotoModel photo;

  @override
  ConsumerState<PrivateMemoryPhoto> createState() => _PrivateMemoryPhotoState();
}

class _PrivateMemoryPhotoState extends ConsumerState<PrivateMemoryPhoto> {
  late Future<List<int>> _photoFuture;

  @override
  void initState() {
    super.initState();

    _photoFuture = _loadPhoto();
  }

  Future<List<int>> _loadPhoto() {
    return ref
        .read(memoryPhotoRepositoryProvider)
        .getPhotoBytes(photoId: widget.photo.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: _photoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Icon(Icons.broken_image_outlined, size: 40),
          );
        }

        final bytes = snapshot.data;

        if (bytes == null || bytes.isEmpty) {
          return const Center(
            child: Icon(Icons.image_not_supported_outlined, size: 40),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            Uint8List.fromList(bytes),
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        );
      },
    );
  }
}

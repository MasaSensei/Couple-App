import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/security/encryption_errors.dart';
import 'package:frontend/features/privacy/presentation/restore_access_screen.dart';
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
        .read(memoryPhotoNotifierProvider.notifier)
        .getDecryptedPhotoBytes(photo: widget.photo);
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
          return PhotoErrorView(error: snapshot.error!);
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

/// Never shows unverified bytes; explains the failure without crypto jargon.
class PhotoErrorView extends StatelessWidget {
  const PhotoErrorView({super.key, required this.error, this.color});

  final Object error;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final keyMissing = error is CoupleKeyUnavailableException;

    final content = Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            keyMissing ? Icons.lock_outline_rounded : Icons.broken_image_outlined,
            size: 36,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            keyMissing
                ? EncryptionMessages.keyUnavailable
                : EncryptionMessages.decryptionFailed,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );

    if (!keyMissing) return Center(child: content);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const RestoreAccessScreen()),
      ),
      child: Center(child: content),
    );
  }
}

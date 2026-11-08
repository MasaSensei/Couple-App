import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/security/encryption_errors.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/features/privacy/presentation/restore_access_screen.dart';
import 'package:frontend/features/memories/data/models/memory_photo_model.dart';
import 'package:frontend/features/memories/providers/memory_photo_provider.dart';

class PrivateMemoryPhoto extends ConsumerStatefulWidget {
  const PrivateMemoryPhoto({super.key, required this.photo, this.bare = false});

  final MemoryPhotoModel photo;

  /// Just the decrypted image, filling its box: for callers that frame it
  /// themselves (e.g. `PolaroidFrame`), so the Memory style is not applied twice.
  final bool bare;

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
          return widget.bare
              ? ColoredBox(color: context.tokens.surfaceMuted)
              : const Center(child: AppLoading());
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

        final t = context.tokens;

        // Decode at display size, not the full 2048 px upload: a grid of
        // full-size bitmaps is what exhausts memory on low-end phones.
        final image = LayoutBuilder(
          builder: (context, constraints) {
            final dpr = MediaQuery.devicePixelRatioOf(context);
            final width = constraints.maxWidth.isFinite
                ? (constraints.maxWidth * dpr).round()
                : null;

            return Image.memory(
              Uint8List.fromList(bytes),
              fit: BoxFit.cover,
              width: double.infinity,
              cacheWidth: width,
              gaplessPlayback: true,
            );
          },
        );

        if (widget.bare) {
          return Semantics(image: true, label: 'Photo', child: image);
        }

        return switch (t.memoryStyle) {
          MemoryStyle.soft => ClipRRect(
            borderRadius: BorderRadius.circular(t.photoRadius + 10),
            child: image,
          ),
          MemoryStyle.minimal => image,
          MemoryStyle.polaroid => Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 18),
            decoration: BoxDecoration(
              color: t.paper,
              borderRadius: BorderRadius.circular(3),
              boxShadow: t.elevation(2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(t.photoRadius),
              child: image,
            ),
          ),
        };
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
            keyMissing
                ? Icons.lock_outline_rounded
                : Icons.broken_image_outlined,
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
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const RestoreAccessScreen())),
      child: Center(child: content),
    );
  }
}

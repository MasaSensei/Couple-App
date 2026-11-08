import 'package:flutter/material.dart';

import '../../../../core/widgets/app_widgets.dart';
import '../../data/models/memory_model.dart';
import 'private_memory_photo.dart';

/// The memory's cover photo (decrypted on device), or a quiet paper
/// placeholder for memories that are words only.
class MemoryCover extends StatelessWidget {
  const MemoryCover({required this.memory, super.key});

  final MemoryModel memory;

  @override
  Widget build(BuildContext context) {
    final cover = memory.coverPhoto;
    if (cover != null) {
      return PrivateMemoryPhoto(
        key: ValueKey('cover-${cover.id}'),
        photo: cover,
        bare: true,
      );
    }

    final t = context.tokens;
    return ExcludeSemantics(
      child: ColoredBox(
        color: t.secondary.withValues(alpha: t.isDark ? 0.5 : 0.55),
        child: Center(
          child: Icon(
            Icons.auto_stories_outlined,
            size: 32,
            color: t.textPrimary.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

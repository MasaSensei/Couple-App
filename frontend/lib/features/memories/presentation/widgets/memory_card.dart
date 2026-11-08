import 'package:flutter/material.dart';

import '../../../../core/theme/theme_customization.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/models/memory_model.dart';
import 'memory_cover.dart';

/// One memory on the timeline, photo first. The couple's Memory style picks
/// the frame: soft card, polaroid print, or a compact minimal row.
class MemoryCard extends StatelessWidget {
  const MemoryCard({required this.memory, this.onTap, super.key});

  final MemoryModel memory;
  final VoidCallback? onTap;

  String get _semantics {
    final photos = memory.photosCount ?? 0;
    return [
      memory.title,
      AppFormatters.dayMonthYear(memory.memoryDate),
      ?memory.locationName,
      if (photos > 0) '$photos photo${photos == 1 ? '' : 's'}',
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return switch (context.tokens.memoryStyle) {
      MemoryStyle.polaroid => _polaroid(context),
      MemoryStyle.minimal => _minimal(context),
      MemoryStyle.soft => _soft(context),
    };
  }

  Widget _countBadge(BuildContext context) {
    final count = memory.photosCount ?? 0;
    if (count < 2) return const SizedBox.shrink();
    return Positioned(
      right: AppSpacing.sm,
      bottom: AppSpacing.sm,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 13,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: context.tokens.label.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _soft(BuildContext context) {
    final t = context.tokens;
    final hasCover = memory.coverPhoto != null;

    return JournalCard(
      onTap: onTap,
      ornament: true,
      ornamentSeed: memory.id,
      semanticLabel: _semantics,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasCover)
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(t.cardRadius),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MemoryCover(memory: memory),
                    _countBadge(context),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _TextBlock(memory: memory, showDescription: true),
          ),
        ],
      ),
    );
  }

  Widget _polaroid(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: _semantics,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: PolaroidFrame(
            seed: memory.id,
            aspectRatio: 4 / 3,
            caption: memory.title,
            trailing:
                '${memory.memoryDate.day} ${AppFormatters.monthShort(memory.memoryDate).toUpperCase()}',
            photo: Stack(
              fit: StackFit.expand,
              children: [
                MemoryCover(memory: memory),
                _countBadge(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _minimal(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: onTap != null,
      label: _semantics,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(t.photoRadius + 6),
                child: SizedBox.square(
                  dimension: 72,
                  child: MemoryCover(memory: memory),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _TextBlock(memory: memory, showDescription: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.memory, required this.showDescription});

  final MemoryModel memory;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final photos = memory.photosCount ?? 0;
    final meta = [
      AppFormatters.dayMonthYear(memory.memoryDate),
      ?memory.locationName,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          meta,
          style: t.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          memory.title,
          style: t.title.copyWith(fontSize: 20),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (showDescription &&
            memory.description != null &&
            memory.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            memory.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.body.copyWith(color: t.textSecondary),
          ),
        ],
        if (!showDescription && photos > 0) ...[
          const SizedBox(height: 2),
          Text('$photos photo${photos == 1 ? '' : 's'}', style: t.caption),
        ],
      ],
    );
  }
}

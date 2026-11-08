import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/memories/data/models/memory_photo_model.dart';
import 'package:frontend/features/memories/presentation/widgets/private_memory_photo.dart';
import 'package:frontend/features/memories/providers/memory_photo_provider.dart';

import '../../../../core/widgets/app_widgets.dart';
import '../../data/models/memory_model.dart';
import 'memory_photo_viewer_screen.dart';
import '../widgets/memory_comment_section.dart';

class MemoryDetailScreen extends ConsumerStatefulWidget {
  const MemoryDetailScreen({required this.memory, super.key});

  final MemoryModel memory;

  @override
  ConsumerState<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref
          .read(memoryPhotoNotifierProvider.notifier)
          .loadPhotos(memoryId: widget.memory.id);
    });
  }

  Future<void> _addPhoto() async {
    final file = await ref
        .read(memoryPhotoNotifierProvider.notifier)
        .pickPhoto();
    if (file != null) await _upload(file);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final memory = widget.memory;

    return AppScaffold(
      decorated: true,
      padded: false,
      appBar: AppBar(
        title: Text(AppFormatters.dayMonthYear(memory.memoryDate)),
        actions: [
          IconButton(
            tooltip: 'Recently deleted photos',
            icon: const Icon(Icons.restore_from_trash_outlined),
            onPressed: _showRecentlyDeleted,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Consumer(
          builder: (context, ref, _) {
            final photoState = ref.watch(memoryPhotoNotifierProvider);
            final photos = (photoState.value ?? const <MemoryPhotoModel>[])
                .where((p) => p.status == 'verified')
                .toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              children: [
                if (photos.isNotEmpty) ...[
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: GestureDetector(
                        onTap: () =>
                            _openPhotoViewer(initialIndex: 0, photos: photos),
                        child: PolaroidFrame(
                          seed: memory.id,
                          aspectRatio: 4 / 3,
                          caption: memory.locationName ?? memory.title,
                          trailing: AppFormatters.monthShort(memory.memoryDate)
                              .toUpperCase(),
                          photo: PrivateMemoryPhoto(
                            photo: photos.first,
                            bare: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(
                  AppFormatters.full(memory.memoryDate)
                      .split(' · ')
                      .first
                      .toUpperCase(),
                  style: t.overline,
                ),
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  header: true,
                  child: Text(
                    memory.title,
                    style: t.display.copyWith(fontSize: 30),
                  ),
                ),
                if (memory.locationName != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildLocation(),
                ],
                if (memory.description != null &&
                    memory.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    memory.description!,
                    style: t.body.copyWith(height: 1.6),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: photos.isEmpty
                      ? 'Photos'
                      : 'Photos · ${photos.length}',
                  actionLabel: 'Add photo',
                  onAction: _addPhoto,
                ),
                const SizedBox(height: AppSpacing.sm),
                photoState.when(
                  loading: () => GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    children: List.generate(
                      3,
                      (_) => const SkeletonBox(height: 100),
                    ),
                  ),
                  error: (_, _) => JournalCard(
                    child: Text(
                      'We could not load the photos. Pull back and open this memory again.',
                      style: t.body.copyWith(
                        color: t.onToneContainer(StatusTone.error),
                      ),
                    ),
                  ),
                  data: (_) => photos.isEmpty
                      ? JournalCard(
                          onTap: _addPhoto,
                          child: Row(
                            children: [
                              const SpotIllustration(
                                kind: SpotKind.camera,
                                size: 64,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('No photos yet', style: t.heading),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Add photos to keep this moment. They are encrypted on your phone first.',
                                      style: t.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildGrid(photos),
                ),
                const SizedBox(height: AppSpacing.xl),
                MemoryCommentSection(memoryId: memory.id),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGrid(List<MemoryPhotoModel> photos) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 480 ? 4 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photos.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemBuilder: (context, index) {
            final photo = photos[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(t.photoRadius + 6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Semantics(
                    button: true,
                    label: 'Photo ${index + 1} of ${photos.length}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () =>
                          _openPhotoViewer(initialIndex: index, photos: photos),
                      child: PrivateMemoryPhoto(photo: photo, bare: true),
                    ),
                  ),
                  if (_protectionBadge(photo) case final badge?)
                    Positioned(left: 6, bottom: 6, child: badge),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton(
                      tooltip: 'Move photo to recently deleted',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                      iconSize: 18,
                      onPressed: () => _confirmDeletePhoto(photoId: photo.id),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Small hint on photos the server has not finished protecting.
  /// Protected photos show nothing: that is the normal state.
  Widget? _protectionBadge(MemoryPhotoModel photo) {
    final (icon, label) = switch (photo.protectionStatus) {
      'backing_up' ||
      'uploading' => (Icons.cloud_upload_outlined, 'Backing up'),
      'restoring' => (Icons.autorenew, 'Restoring'),
      'needs_attention' => (Icons.error_outline, 'Needs attention'),
      _ => (null, null),
    };

    if (icon == null) return null;

    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16, semanticLabel: label),
      ),
    );
  }

  Future<void> _confirmDeletePhoto({required int photoId}) async {
    final shouldDelete = await showConfirmSheet(
      context,
      title: 'Delete this photo?',
      message:
          'It moves to "Recently deleted" and can be restored for 30 days.',
      confirmLabel: 'Delete photo',
      destructive: true,
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    final deleted = await ref
        .read(memoryPhotoNotifierProvider.notifier)
        .deletePhoto(memoryId: widget.memory.id, photoId: photoId);

    if (!deleted || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Photo moved to Recently deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _restorePhoto(photoId),
        ),
      ),
    );
  }

  Future<void> _restorePhoto(int photoId) async {
    final restored = await ref
        .read(memoryPhotoNotifierProvider.notifier)
        .restorePhoto(memoryId: widget.memory.id, photoId: photoId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restored
              ? 'Photo restored.'
              : 'This photo can no longer be restored.',
        ),
      ),
    );
  }

  /// Trashed photos can't be opened (the server no longer serves them), so the
  /// list shows dates only, with a restore button for each.
  Future<void> _showRecentlyDeleted() async {
    final notifier = ref.read(memoryPhotoNotifierProvider.notifier);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => FutureBuilder<List<MemoryPhotoModel>>(
        future: notifier.loadTrash(memoryId: widget.memory.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(height: 160, child: AppStateView.loading());
          }

          final photos = snapshot.data ?? const <MemoryPhotoModel>[];

          if (snapshot.hasError || photos.isEmpty) {
            return SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  snapshot.hasError
                      ? 'We could not load deleted photos.'
                      : 'No recently deleted photos.',
                  style: context.tokens.body.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ),
            );
          }

          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              for (final photo in photos)
                ListTile(
                  leading: const Icon(Icons.photo_outlined),
                  title: const Text('Photo'),
                  subtitle: Text(
                    photo.restorableUntil == null
                        ? 'Can be restored'
                        : 'Can be restored until '
                              '${AppFormatters.dayMonthYear(photo.restorableUntil!)}',
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _restorePhoto(photo.id);
                    },
                    child: const Text('Restore'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _upload(File file) async {
    try {
      await ref
          .read(memoryPhotoNotifierProvider.notifier)
          .uploadPhoto(memoryId: widget.memory.id, file: file);
    } on PhotoUploadException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _upload(file),
          ),
        ),
      );
    }
  }

  Widget _buildLocation() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 20,
          color: context.tokens.textSecondary,
        ),

        const SizedBox(width: AppSpacing.xs),

        Expanded(
          child: Text(
            widget.memory.locationName!,
            style: context.tokens.body.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  void _openPhotoViewer({
    required int initialIndex,
    required List<MemoryPhotoModel> photos,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) {
          return MemoryPhotoViewerScreen(
            photos: photos,
            initialIndex: initialIndex,
          );
        },
      ),
    );
  }
}

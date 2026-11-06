import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/memories/data/models/memory_photo_model.dart';
import 'package:frontend/features/memories/presentation/widgets/private_memory_photo.dart';
import 'package:frontend/features/memories/providers/memory_photo_provider.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/models/memory_model.dart';
import 'memory_photo_viewer_screen.dart';
import '../widgets/memory_comment_section.dart';

import 'package:frontend/core/theme/app_theme_tokens.dart';
import 'package:frontend/core/theme/theme_decorations.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory'),
        actions: [
          IconButton(
            tooltip: 'Recently deleted',
            icon: const Icon(Icons.restore_from_trash_outlined),
            onPressed: _showRecentlyDeleted,
          ),
        ],
      ),
      body: ThemedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDate(),

                const SizedBox(height: AppSpacing.md),

                Text(
                  widget.memory.title,
                  style: context.tokens.display.copyWith(fontSize: 28),
                ),

                if (widget.memory.locationName != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildLocation(),
                ],

                if (widget.memory.description != null &&
                    widget.memory.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    widget.memory.description!,
                    style: context.tokens.body.copyWith(
                      color: context.tokens.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                Text(
                  'Photos',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await ref
                        .read(memoryPhotoNotifierProvider.notifier)
                        .pickPhoto();

                    if (file != null) await _upload(file);
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Tambah Foto'),
                ),

                const SizedBox(height: 12),

                Consumer(
                  builder: (context, ref, child) {
                    final photoState = ref.watch(memoryPhotoNotifierProvider);

                    return photoState.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: CircularProgressIndicator(),
                        ),
                      ),

                      error: (error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: context.tokens.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: context.tokens.border),
                          ),
                          child: Text(
                            'Gagal memuat foto.',
                            style: context.tokens.body.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        );
                      },

                      data: (photos) {
                        final verifiedPhotos = photos
                            .where((photo) => photo.status == 'verified')
                            .toList();

                        if (verifiedPhotos.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: context.tokens.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: context.tokens.border),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  color: context.tokens.primary,
                                  size: 36,
                                ),

                                const SizedBox(height: AppSpacing.sm),

                                Text(
                                  'Belum ada foto',
                                  style: context.tokens.subtitle.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                const SizedBox(height: AppSpacing.xs),

                                Text(
                                  'Tambahkan foto untuk '
                                  'mengabadikan memory ini.',
                                  textAlign: TextAlign.center,
                                  style: context.tokens.body.copyWith(
                                    color: context.tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: verifiedPhotos.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: AppSpacing.sm,
                                mainAxisSpacing: AppSpacing.sm,
                                childAspectRatio: 1,
                              ),
                          itemBuilder: (context, index) {
                            final photo = verifiedPhotos[index];

                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: GestureDetector(
                                    onTap: () {
                                      _openPhotoViewer(
                                        initialIndex: index,
                                        photos: verifiedPhotos,
                                      );
                                    },
                                    child: PrivateMemoryPhoto(photo: photo),
                                  ),
                                ),

                                if (_protectionBadge(photo) case final badge?)
                                  Positioned(left: 8, bottom: 8, child: badge),

                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Material(
                                    color: Colors.black54,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => _confirmDeletePhoto(
                                        photoId: photo.id,
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.delete_outline,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),

                MemoryCommentSection(memoryId: widget.memory.id),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDate() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.tokens.secondary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _formatDate(widget.memory.memoryDate),
        style: context.tokens.body.copyWith(
          color: context.tokens.primaryDark,
          fontWeight: FontWeight.w600,
        ),
      ),
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
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus foto?'),
          content: const Text(
            'Foto ini dipindahkan ke "Baru dihapus" dan masih bisa '
            'dipulihkan selama 30 hari.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
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
        content: const Text('Foto dipindahkan ke Baru dihapus.'),
        action: SnackBarAction(
          label: 'Urungkan',
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
              ? 'Foto dipulihkan.'
              : 'Foto ini sudah tidak bisa dipulihkan.',
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
            return const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final photos = snapshot.data ?? const <MemoryPhotoModel>[];

          if (snapshot.hasError || photos.isEmpty) {
            return SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  snapshot.hasError
                      ? 'Tidak bisa memuat foto yang dihapus.'
                      : 'Tidak ada foto yang baru dihapus.',
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
                  title: const Text('Foto'),
                  subtitle: Text(
                    photo.restorableUntil == null
                        ? 'Bisa dipulihkan'
                        : 'Bisa dipulihkan sampai '
                              '${_formatDate(photo.restorableUntil!.toLocal())}',
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _restorePhoto(photo.id);
                    },
                    child: const Text('Pulihkan'),
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
    Navigator.of(context).push(
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

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }
}

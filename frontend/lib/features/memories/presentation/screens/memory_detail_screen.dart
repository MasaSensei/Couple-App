import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/memories/data/models/memory_photo_model.dart';
import 'package:frontend/features/memories/presentation/widgets/private_memory_photo.dart';
import 'package:frontend/features/memories/providers/memory_photo_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memory')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDate(),

              const SizedBox(height: AppSpacing.md),

              Text(
                widget.memory.title,
                style: AppTextStyles.display.copyWith(fontSize: 28),
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
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
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
                  await ref
                      .read(memoryPhotoNotifierProvider.notifier)
                      .pickAndUpload(memoryId: widget.memory.id);
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

                    error: (error, stackTrace) => Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'Gagal memuat foto.',
                        style: AppTextStyles.body.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),

                    data: (photos) {
                      final verifiedPhotos = photos
                          .where((photo) => photo.status == 'verified')
                          .toList();

                      if (verifiedPhotos.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.photo_library_outlined,
                                color: AppColors.primary,
                                size: 36,
                              ),

                              const SizedBox(height: AppSpacing.sm),

                              Text(
                                'Belum ada foto',
                                style: AppTextStyles.subtitle.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: AppSpacing.xs),

                              Text(
                                'Tambahkan foto untuk '
                                'mengabadikan memory ini.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
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

                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () =>
                                        _confirmDeletePhoto(photoId: photo.id),
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
    );
  }

  Widget _buildDate() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _formatDate(widget.memory.memoryDate),
        style: AppTextStyles.body.copyWith(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w600,
        ),
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
            'Foto ini akan dihapus dari memory. '
            'Tindakan ini tidak dapat dibatalkan.',
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

    await ref
        .read(memoryPhotoNotifierProvider.notifier)
        .deletePhoto(memoryId: widget.memory.id, photoId: photoId);
  }

  Widget _buildLocation() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 20,
          color: AppColors.textSecondary,
        ),

        const SizedBox(width: AppSpacing.xs),

        Expanded(
          child: Text(
            widget.memory.locationName!,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
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

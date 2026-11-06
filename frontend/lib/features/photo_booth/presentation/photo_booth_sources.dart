import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/security/encryption_errors.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';
import 'package:frontend/features/memories/data/models/memory_model.dart';
import 'package:frontend/features/memories/data/models/memory_photo_model.dart';
import 'package:frontend/features/memories/presentation/widgets/private_memory_photo.dart';
import 'package:frontend/features/memories/providers/memory_photo_provider.dart';
import 'package:frontend/features/memories/providers/memory_providers.dart';
import 'package:image_picker/image_picker.dart';

/// Picks photos from the device gallery. The picker's cached copy is deleted
/// once read: the bytes live only in memory from then on.
Future<List<Uint8List>> pickFromGallery({required int limit}) async {
  if (limit <= 0) return const [];

  final files = await ImagePicker().pickMultiImage(
    limit: limit > 1 ? limit : null,
  );
  final photos = <Uint8List>[];

  for (final file in files.take(limit)) {
    photos.add(await file.readAsBytes());
    try {
      await File(file.path).delete();
    } catch (_) {
      // Best effort: the OS clears the picker cache eventually.
    }
  }

  return photos;
}

/// Lets the user pick photos from a Memory. Ciphertext is downloaded and
/// decrypted on this device (the normal Memory path); nothing is re-uploaded.
Future<List<Uint8List>?> pickFromMemories(
  BuildContext context, {
  required int limit,
}) {
  return showModalBottomSheet<List<Uint8List>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _MemoryPhotoPicker(limit: limit),
    ),
  );
}

/// Chooses the Memory a finished print is saved to.
Future<MemoryModel?> pickTargetMemory(BuildContext context) {
  return showModalBottomSheet<MemoryModel>(
    context: context,
    showDragHandle: true,
    builder: (_) => Consumer(
      builder: (context, ref, _) => FutureBuilder<List<MemoryModel>>(
        future: ref.read(memoryRepositoryProvider).getMemories(),
        builder: (context, snapshot) => _MemoryList(
          snapshot: snapshot,
          title: 'Save to which memory?',
          onTap: (memory) => Navigator.pop(context, memory),
        ),
      ),
    ),
  );
}

class _MemoryList extends StatelessWidget {
  const _MemoryList({
    required this.snapshot,
    required this.title,
    required this.onTap,
  });

  final AsyncSnapshot<List<MemoryModel>> snapshot;
  final String title;
  final ValueChanged<MemoryModel> onTap;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final memories = snapshot.data ?? const <MemoryModel>[];
    if (snapshot.hasError || memories.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            snapshot.hasError
                ? "We couldn't load your memories."
                : 'Create a memory first, then save your print to it.',
            style: context.tokens.subtitle,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            title,
            style: context.tokens.title.copyWith(fontSize: 18),
          ),
        ),
        for (final memory in memories)
          ListTile(
            leading: const Icon(Icons.photo_album_outlined),
            title: Text(memory.title),
            onTap: () => onTap(memory),
          ),
      ],
    );
  }
}

class _MemoryPhotoPicker extends ConsumerStatefulWidget {
  const _MemoryPhotoPicker({required this.limit});

  final int limit;

  @override
  ConsumerState<_MemoryPhotoPicker> createState() => _MemoryPhotoPickerState();
}

class _MemoryPhotoPickerState extends ConsumerState<_MemoryPhotoPicker> {
  MemoryModel? _memory;
  final _selected = <MemoryPhotoModel>[];
  bool _decrypting = false;
  String? _error;

  Future<void> _add() async {
    setState(() {
      _decrypting = true;
      _error = null;
    });

    final notifier = ref.read(memoryPhotoNotifierProvider.notifier);
    final photos = <Uint8List>[];

    for (final photo in _selected) {
      try {
        photos.add(
          Uint8List.fromList(
            await notifier.getDecryptedPhotoBytes(photo: photo),
          ),
        );
      } on CoupleKeyUnavailableException {
        _error = EncryptionMessages.keyUnavailable;
      } catch (_) {
        // Unverifiable photos are never used (Phase 5 rule).
        _error = EncryptionMessages.decryptionFailed;
      }
    }

    if (!mounted) return;
    if (photos.isEmpty) {
      setState(() => _decrypting = false);
      return;
    }

    Navigator.pop(context, photos);
  }

  @override
  Widget build(BuildContext context) {
    final memory = _memory;

    if (memory == null) {
      return FutureBuilder<List<MemoryModel>>(
        future: ref.read(memoryRepositoryProvider).getMemories(),
        builder: (context, snapshot) => _MemoryList(
          snapshot: snapshot,
          title: 'Choose a memory',
          onTap: (m) => setState(() => _memory = m),
        ),
      );
    }

    return Column(
      children: [
        ListTile(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() {
              _memory = null;
              _selected.clear();
            }),
          ),
          title: Text(memory.title),
          subtitle: Text('Pick up to ${widget.limit}'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(_error!, style: TextStyle(color: context.tokens.error)),
          ),
        Expanded(
          child: FutureBuilder<List<MemoryPhotoModel>>(
            future: ref
                .read(memoryPhotoRepositoryProvider)
                .getPhotos(memoryId: memory.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final photos = (snapshot.data ?? const <MemoryPhotoModel>[])
                  .where((p) => p.status == 'verified')
                  .toList();
              if (photos.isEmpty) {
                return Center(
                  child: Text(
                    'This memory has no photos yet.',
                    style: context.tokens.subtitle,
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                ),
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  final selected = _selected.contains(photo);

                  return Semantics(
                    selected: selected,
                    button: true,
                    label: 'Photo ${index + 1}',
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (selected) {
                          _selected.remove(photo);
                        } else if (_selected.length < widget.limit) {
                          _selected.add(photo);
                        }
                      }),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PrivateMemoryPhoto(photo: photo),
                          if (selected)
                            Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: context.tokens.primary,
                                  child: Text(
                                    '${_selected.indexOf(photo) + 1}',
                                    style: TextStyle(
                                      color: context.tokens.onPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FilledButton(
              onPressed: _selected.isEmpty || _decrypting ? null : _add,
              child: _decrypting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Add ${_selected.length} photo${_selected.length == 1 ? '' : 's'}',
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

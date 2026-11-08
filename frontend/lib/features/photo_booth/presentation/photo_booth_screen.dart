import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/app_widgets.dart';
import 'package:frontend/core/theme/theme_registry.dart';

import '../domain/photo_booth_document.dart';
import '../domain/photo_booth_template.dart';
import '../domain/photo_booth_templates.dart';
import '../providers/photo_booth_controller.dart';
import '../render/photo_booth_preview.dart';
import '../render/photo_booth_renderer.dart';
import 'photo_booth_sources.dart';

/// Photo Booth editor. All editing and rendering happens on this device;
/// saving goes through the encrypted Memory upload, sharing through the
/// system share sheet.
class PhotoBoothScreen extends ConsumerWidget {
  const PhotoBoothScreen({super.key, this.availableTemplates});

  /// Template keys the server currently offers; null = all built-in ones.
  final Set<String>? availableTemplates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(photoBoothControllerProvider);
    final controller = ref.read(photoBoothControllerProvider.notifier);
    final document = state.document;
    final t = context.tokens;
    final renderer = PhotoBoothRenderer(accent: t.primary);

    // Templates suggested by the couple's theme come first.
    final suggested = ThemeRegistry.byKey(t.themeKey).photoBoothTemplates;
    final templates =
        PhotoBoothTemplates.all
            .where(
              (tpl) =>
                  availableTemplates == null ||
                  availableTemplates!.contains(tpl.key),
            )
            .toList()
          ..sort(
            (a, b) => (suggested.contains(a.key) ? 0 : 1).compareTo(
              suggested.contains(b.key) ? 0 : 1,
            ),
          );

    final status = document.photos.isEmpty
        ? 'Add photos to start. This layout holds ${document.template.photoCount}.'
        : '${document.slotted.length} of ${document.template.photoCount} spots filled'
              '${document.photos.length > document.template.photoCount ? ' (extra photos are not used)' : ''}. '
              'Drag a photo to move it, pinch to zoom, double-tap to re-centre.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Booth'),
        leading: const CloseButton(),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.smd,
            AppSpacing.gutter,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border(top: BorderSide(color: t.border)),
          ),
          child: _Actions(state: state),
        ),
      ),
      body: AbsorbPointer(
        absorbing: state.busy != PhotoBoothBusy.none,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            // The stage: the strip as it will be exported, on a soft desk.
            Container(
              color: t.surfaceMuted,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 420,
                        maxHeight: 460,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(boxShadow: t.elevation(3)),
                        child: PhotoBoothPreview(
                          document: document,
                          renderer: renderer,
                          onFramingChanged: controller.setFraming,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      status,
                      style: t.caption,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  const _Step(number: 1, title: 'Choose a layout'),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 156,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: templates.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.smd),
                      itemBuilder: (context, i) => _TemplateTile(
                        template: templates[i],
                        selected: templates[i].key == document.template.key,
                        suggested: suggested.contains(templates[i].key),
                        renderer: renderer,
                        onTap: () => controller.setTemplate(templates[i]),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _Step(number: 2, title: 'Add photos'),
                  const SizedBox(height: AppSpacing.sm),
                  _PhotoSection(document: document),
                  const SizedBox(height: AppSpacing.lg),
                  const _Step(number: 3, title: 'Add a finishing touch'),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Short text (optional)',
                      helperText: document.template.captionArea == null
                          ? 'This layout has no room for text.'
                          : null,
                    ),
                    maxLength: PhotoBoothDocument.maxCaptionLength,
                    enabled: document.template.captionArea != null,
                    onChanged: controller.setCaption,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show date'),
                    subtitle: Text(
                      PhotoBoothRenderer.formatDate(document.date),
                    ),
                    value: document.showDate,
                    onChanged: document.template.captionArea == null
                        ? null
                        : controller.setShowDate,
                    secondary: IconButton(
                      tooltip: 'Change date',
                      icon: const Icon(Icons.edit_calendar_outlined),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: document.date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) controller.setDate(picked);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Numbered step heading: the order is real (layout → photos → finish).
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      header: true,
      label: 'Step $number: $title',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.secondary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: t.label.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(title, style: t.heading),
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.selected,
    required this.suggested,
    required this.renderer,
    required this.onTap,
  });

  final PhotoBoothTemplate template;
  final bool selected;
  final bool suggested;
  final PhotoBoothRenderer renderer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      selected: selected,
      label: '${template.name}${suggested ? ', suggested for your theme' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: 100,
          child: Column(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: context.motion.fast,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: t.surface,
                    border: Border.all(
                      color: selected ? t.primary : t.border,
                      width: selected ? 2.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: selected ? t.elevation(2) : null,
                  ),
                  child: ExcludeSemantics(
                    child: PhotoBoothPreview(
                      document: PhotoBoothDocument(
                        template: template,
                        caption: '',
                        showDate: false,
                        date: DateTime(2026),
                      ),
                      renderer: renderer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (suggested) ...[
                    Icon(Icons.favorite_rounded, size: 11, color: t.primary),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      template.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.label.copyWith(
                        fontSize: 12,
                        color: selected ? t.primary : t.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoSection extends ConsumerWidget {
  const _PhotoSection({required this.document});

  final PhotoBoothDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(photoBoothControllerProvider.notifier);
    final room = PhotoBoothController.maxPhotos - document.photos.length;
    final t = context.tokens;

    Future<void> add(
      Future<List<Uint8List>?> pick,
      PhotoSourceKind kind,
    ) async {
      final photos = await pick;
      if (photos != null && photos.isNotEmpty) {
        controller.addPhotos(photos, kind);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: room <= 0
                    ? null
                    : () => add(
                        pickFromGallery(limit: room),
                        PhotoSourceKind.gallery,
                      ),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: room <= 0
                    ? null
                    : () => add(
                        pickFromMemories(context, limit: room),
                        PhotoSourceKind.memory,
                      ),
                icon: const Icon(Icons.photo_album_outlined),
                label: const Text('Memories'),
              ),
            ),
          ],
        ),
        if (document.photos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Long-press and drag to reorder', style: t.caption),
          SizedBox(
            height: 96,
            child: ReorderableListView(
              scrollDirection: Axis.horizontal,
              onReorderItem: controller.reorder,
              children: [
                for (final (i, photo) in document.photos.indexed)
                  Padding(
                    key: ValueKey(photo.id),
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Stack(
                      children: [
                        Opacity(
                          opacity: i < document.template.photoCount ? 1 : 0.4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: Image.memory(
                              photo.bytes,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                              cacheWidth: 200,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            tooltip: 'Remove photo ${i + 1}',
                            icon: const Icon(Icons.close),
                            onPressed: () => controller.removePhoto(photo.id),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.state});

  final PhotoBoothState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(photoBoothControllerProvider.notifier);
    final accent = context.tokens.primary;
    final busy = state.busy;
    final ready =
        state.document.photos.isNotEmpty && busy == PhotoBoothBusy.none;

    void show(String message) =>
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: !ready
                    ? null
                    : () async {
                        final memory = await pickTargetMemory(context);
                        if (memory == null) return;
                        try {
                          await controller.saveToMemory(
                            memoryId: memory.id,
                            accent: accent,
                          );
                          show(
                            'Saved to "${memory.title}". It is encrypted like every memory photo.',
                          );
                        } on PhotoBoothException catch (e) {
                          show(e.message);
                        }
                      },
                icon: busy == PhotoBoothBusy.saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline),
                label: const Text('Save to Memory'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: !ready
                    ? null
                    : () async {
                        try {
                          await controller.share(accent: accent);
                        } on PhotoBoothException catch (e) {
                          show(e.message);
                        }
                      },
                icon: busy == PhotoBoothBusy.sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Sharing sends an unencrypted copy to the app you choose.',
          style: context.tokens.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

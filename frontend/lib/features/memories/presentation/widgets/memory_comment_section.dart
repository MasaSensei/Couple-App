import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_widgets.dart';
import '../../data/models/memory_comment_model.dart';
import '../../providers/memory_comment_provider.dart';
import '../../../auth/providers/auth_providers.dart';

class MemoryCommentSection extends ConsumerStatefulWidget {
  const MemoryCommentSection({super.key, required this.memoryId});

  final int memoryId;

  @override
  ConsumerState<MemoryCommentSection> createState() =>
      _MemoryCommentSectionState();
}

class _MemoryCommentSectionState extends ConsumerState<MemoryCommentSection> {
  final TextEditingController _commentController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref
          .read(memoryCommentNotifierProvider.notifier)
          .loadComments(memoryId: widget.memoryId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_isSubmitting) {
      return;
    }

    final body = _commentController.text.trim();

    if (body.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await ref
        .read(memoryCommentNotifierProvider.notifier)
        .createComment(memoryId: widget.memoryId, body: body);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send the note. Try again.')),
      );

      return;
    }

    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final commentState = ref.watch(memoryCommentNotifierProvider);
    final myId = ref.watch(authNotifierProvider.select((s) => s.user?.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Notes to each other'),
        const SizedBox(height: AppSpacing.smd),
        commentState.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: AppLoading(size: 22)),
          ),
          error: (error, stackTrace) => Row(
            children: [
              Expanded(
                child: Text(
                  'We could not load the notes.',
                  style: t.body.copyWith(
                    color: t.onToneContainer(StatusTone.error),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref
                    .read(memoryCommentNotifierProvider.notifier)
                    .loadComments(memoryId: widget.memoryId),
                child: const Text('Try again'),
              ),
            ],
          ),
          data: (comments) {
            if (comments.isEmpty) {
              return Text(
                'No notes yet. Tell each other what you loved about it.',
                style: t.body.copyWith(color: t.textSecondary),
              );
            }

            // Oldest first reads like a conversation.
            final ordered = [...comments]
              ..sort(
                (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
                  b.createdAt ?? DateTime(0),
                ),
              );
            return Column(
              children: [
                for (final c in ordered)
                  CommentBubble(
                    author: c.userName,
                    body: c.body,
                    createdAt: c.createdAt,
                    isMine: c.userId == myId,
                    edited:
                        c.updatedAt != null &&
                        c.createdAt != null &&
                        c.updatedAt!.difference(c.createdAt!).inSeconds > 1,
                    trailing: c.userId == myId
                        ? _CommentMenu(comment: c, memoryId: widget.memoryId)
                        : null,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _CommentInput(
          controller: _commentController,
          onSubmit: _submitComment,
          isSubmitting: _isSubmitting,
        ),
      ],
    );
  }
}

class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.onSubmit,
    required this.isSubmitting,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isSubmitting,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(labelText: 'Write a note'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: IconButton.filled(
            onPressed: isSubmitting ? null : onSubmit,
            tooltip: 'Send note',
            icon: isSubmitting
                ? const AppLoading(size: 18)
                : const Icon(Icons.send_rounded),
          ),
        ),
      ],
    );
  }
}

class _CommentMenu extends ConsumerWidget {
  const _CommentMenu({required this.comment, required this.memoryId});

  final MemoryCommentModel comment;
  final int memoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final currentUserId = authState.user?.id;

    final isOwner = currentUserId == comment.userId;

    if (!isOwner) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: 'Note options',
      icon: Icon(Icons.more_horiz_rounded, color: context.tokens.textSecondary),
      onSelected: (value) {
        if (value == 'edit') {
          _editComment(context, ref);
        }

        if (value == 'delete') {
          _deleteComment(context, ref);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Future<void> _editComment(BuildContext context, WidgetRef ref) async {
    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _EditCommentDialog(initialBody: comment.body);
      },
    );

    if (body == null || body.isEmpty) {
      return;
    }

    final success = await ref
        .read(memoryCommentNotifierProvider.notifier)
        .updateComment(commentId: comment.id, body: body);

    if (!context.mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the note.')),
      );
    }
  }

  Future<void> _deleteComment(BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showConfirmSheet(
      context,
      title: 'Delete this note?',
      message: 'It will be removed for both of you.',
      confirmLabel: 'Delete note',
      destructive: true,
    );

    if (shouldDelete != true) {
      return;
    }

    final success = await ref
        .read(memoryCommentNotifierProvider.notifier)
        .deleteComment(commentId: comment.id);

    if (!context.mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete the note.')),
      );
    }
  }
}

class _EditCommentDialog extends StatefulWidget {
  const _EditCommentDialog({required this.initialBody});

  final String initialBody;

  @override
  State<_EditCommentDialog> createState() => _EditCommentDialogState();
}

class _EditCommentDialogState extends State<_EditCommentDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialBody);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();

    if (value.isEmpty) {
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit note'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Note'),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

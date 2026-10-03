import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Komentar gagal dikirim.')));

      return;
    }

    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final commentState = ref.watch(memoryCommentNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comments',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        _CommentInput(
          controller: _commentController,
          onSubmit: _submitComment,
          isSubmitting: _isSubmitting,
        ),

        const SizedBox(height: 16),

        commentState.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stackTrace) => _CommentError(
            onRetry: () {
              ref
                  .read(memoryCommentNotifierProvider.notifier)
                  .loadComments(memoryId: widget.memoryId);
            },
          ),
          data: (comments) {
            if (comments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Belum ada komentar.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return Column(
              children: comments
                  .map(
                    (comment) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CommentItem(
                        comment: comment,
                        memoryId: widget.memoryId,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
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
            decoration: InputDecoration(
              hintText: 'Tulis komentar...',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: isSubmitting ? null : onSubmit,
          icon: isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
        ),
      ],
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({required this.comment, required this.memoryId});

  final MemoryCommentModel comment;
  final int memoryId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                child: Text(
                  comment.userName.isNotEmpty
                      ? comment.userName[0].toUpperCase()
                      : '?',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  comment.userName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _CommentMenu(comment: comment, memoryId: memoryId),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.body, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
      ),
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
        PopupMenuItem(value: 'delete', child: Text('Hapus')),
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
        const SnackBar(content: Text('Komentar gagal diperbarui.')),
      );
    }
  }

  Future<void> _deleteComment(BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus komentar?'),
          content: const Text(
            'Komentar ini akan dihapus dan tidak dapat dikembalikan.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Komentar gagal dihapus.')));
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
      title: const Text('Edit komentar'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        decoration: const InputDecoration(hintText: 'Komentar'),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}

class _CommentError extends StatelessWidget {
  const _CommentError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          children: [
            const Text('Komentar gagal dimuat.'),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

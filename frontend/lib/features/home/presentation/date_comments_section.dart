import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/date_comment_state.dart';
import '../providers/date_providers.dart';

class DateCommentsSection extends ConsumerStatefulWidget {
  const DateCommentsSection({super.key, required this.dateId});

  final int dateId;

  @override
  ConsumerState<DateCommentsSection> createState() =>
      _DateCommentsSectionState();
}

class _DateCommentsSectionState extends ConsumerState<DateCommentsSection> {
  late final TextEditingController _commentController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _commentController = TextEditingController();

    Future.microtask(
      () => ref
          .read(dateCommentNotifierProvider.notifier)
          .loadComments(widget.dateId),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();

    if (content.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final comment = await ref
        .read(dateCommentNotifierProvider.notifier)
        .createComment(dateId: widget.dateId, content: content);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (comment != null) {
      _commentController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dateCommentNotifierProvider);
    final myId = ref.watch(authNotifierProvider.select((s) => s.user?.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Notes to each other'),
        const SizedBox(height: AppSpacing.smd),
        switch (state.status) {
          DateCommentStatus.initial ||
          DateCommentStatus.loading => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: AppLoading(size: 22)),
          ),
          DateCommentStatus.empty => Text(
            'No notes yet. Say something sweet.',
            style: context.tokens.body.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          DateCommentStatus.error => Text(
            state.errorMessage ?? 'We could not load the notes.',
            style: context.tokens.body.copyWith(
              color: context.tokens.onToneContainer(StatusTone.error),
            ),
          ),
          DateCommentStatus.loaded => Column(
            children: [
              for (final c in state.comments)
                CommentBubble(
                  author: c.userName ?? 'Your partner',
                  body: c.content,
                  createdAt: c.createdAt,
                  isMine: c.userId == myId,
                ),
            ],
          ),
        },
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AppTextField(
                controller: _commentController,
                label: 'Write a note',
                maxLines: 3,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IconButton.filled(
                onPressed: _isSubmitting ? null : _submitComment,
                tooltip: 'Send note',
                icon: _isSubmitting
                    ? const AppLoading(size: 18)
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

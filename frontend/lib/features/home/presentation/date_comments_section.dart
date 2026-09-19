import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/home/data/models/date_comment_model.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comments', style: AppTextStyles.subtitle),

        const SizedBox(height: AppSpacing.md),

        _buildComments(state),

        const SizedBox(height: AppSpacing.lg),

        AppTextField(
          controller: _commentController,
          label: 'Add a comment',
          hint: 'Write something...',
        ),

        const SizedBox(height: AppSpacing.md),

        AppButton(
          label: 'Add comment',
          onPressed: _isSubmitting ? null : _submitComment,
          isLoading: _isSubmitting,
        ),
      ],
    );
  }

  Widget _buildComments(DateCommentState state) {
    switch (state.status) {
      case DateCommentStatus.initial:
      case DateCommentStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case DateCommentStatus.empty:
        return Text('No comments yet ♡', style: AppTextStyles.body);

      case DateCommentStatus.error:
        return Text(
          state.errorMessage ?? 'Unable to load comments.',
          style: AppTextStyles.body,
        );

      case DateCommentStatus.loaded:
        return Column(children: state.comments.map(_buildComment).toList());
    }
  }

  Widget _buildComment(DateCommentModel comment) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment.userName ?? 'Unknown', style: AppTextStyles.subtitle),

          const SizedBox(height: AppSpacing.xs),

          Text(comment.content, style: AppTextStyles.body),

          if (comment.createdAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_formatDate(comment.createdAt!), style: AppTextStyles.body),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');

    final month = localDate.month.toString().padLeft(2, '0');

    final year = localDate.year;

    final hour = localDate.hour.toString().padLeft(2, '0');

    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }
}

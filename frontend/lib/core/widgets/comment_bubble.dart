import 'package:flutter/material.dart';

import '../format/app_formatters.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_tokens.dart';
import 'journal/couple_avatars.dart';

/// One comment in a thread. Your own comments sit on the right on a soft
/// tint; your partner's on the left on the surface colour.
class CommentBubble extends StatelessWidget {
  const CommentBubble({
    required this.author,
    required this.body,
    super.key,
    this.createdAt,
    this.isMine = false,
    this.edited = false,
    this.trailing,
  });

  final String author;
  final String body;
  final DateTime? createdAt;
  final bool isMine;
  final bool edited;

  /// e.g. a menu button for edit/delete on your own comments.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final meta = [
      if (createdAt != null) AppFormatters.sinceShort(createdAt!),
      if (edited) 'edited',
    ].join(' · ');

    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.smd,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isMine
            ? Color.alphaBlend(
                t.secondary.withValues(alpha: t.isDark ? 0.55 : 0.6),
                t.surface,
              )
            : t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMine ? 18 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMine ? 'You' : author,
                  style: t.label.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(body, style: t.body),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta, style: t.caption),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 14,
                backgroundColor: t.secondary,
                child: Text(
                  CoupleAvatars.initial(author),
                  style: t.label.copyWith(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: bubble,
            ),
          ),
        ],
      ),
    );
  }
}

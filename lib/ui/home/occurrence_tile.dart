import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/agenda.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';
import 'occurrence_sheet.dart';

/// やること1件ぶんの行。丸をタップで完了、行をタップでくわしい操作。
class OccurrenceTile extends StatelessWidget {
  const OccurrenceTile(this.occurrence, {super.key});
  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final o = occurrence;
    final chore = o.chore;
    final genre = store.genreById(chore.genreId);
    final record = o.record;
    final doer = store.memberById(record?.doneById);
    final assignee = store.memberById(chore.assigneeId);
    final muted = scheme.onSurfaceVariant;

    // 2行目に並べる小さな情報
    final details = <InlineSpan>[];
    void addDetail(String text, {Color? color}) {
      if (details.isNotEmpty) {
        details.add(
          TextSpan(
            text: '  ・  ',
            style: TextStyle(color: muted),
          ),
        );
      }
      details.add(
        TextSpan(
          text: text,
          style: TextStyle(color: color),
        ),
      );
    }

    if (o.isDone) {
      addDetail('${doer?.name ?? 'だれか'}がやった');
      if (o.isUnplanned) {
        addDetail(record!.note.isEmpty ? 'ついでに' : record.note);
      } else if (o.date.isBefore(store.today)) {
        addDetail('${formatDate(o.date)}の分');
      }
    } else if (o.isSkipped) {
      addDetail('今回はスキップ');
    } else {
      if (o.overdue) {
        addDetail('${formatDate(o.date)}の予定', color: scheme.error);
      }
      addDetail(genre.name);
      if (chore.dueMinutes != null) {
        addDetail('${formatMinutes(chore.dueMinutes!)}まで');
      }
    }

    final canThank =
        o.isDone &&
        record!.doneById != null &&
        record.doneById != store.currentMemberId;
    final thanks = o.isDone ? store.thanksFor(record!.id) : const <Thanks>[];
    final iThanked = thanks.any((t) => t.fromId == store.currentMemberId);

    return InkWell(
      onTap: () => showOccurrenceSheet(context, o),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
        child: Row(
          children: [
            _CheckButton(occurrence: o, color: Color(genre.color)),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chore.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: o.isResolved ? muted : scheme.onSurface,
                      fontWeight: o.isResolved
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text.rich(
                    TextSpan(children: details),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (canThank || thanks.isNotEmpty)
              _ThanksButton(
                count: thanks.length,
                active: iThanked,
                onPressed: canThank
                    ? () {
                        HapticFeedback.selectionClick();
                        store.toggleThanks(record.id, stampKeys.first);
                      }
                    : null,
              ),
            if (o.isDone)
              MemberAvatar(doer, size: 30)
            else if (!o.isSkipped)
              Opacity(
                opacity: assignee == null ? 0.7 : 1,
                child: MemberAvatar(assignee, size: 30),
              ),
          ],
        ),
      ),
    );
  }
}

/// 完了の丸。まだ → 完了、完了・スキップ → 元に戻す。長押しでやった人を選ぶ。
class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.occurrence, required this.color});
  final Occurrence occurrence;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final o = occurrence;
    final Widget mark;
    final String tooltip;
    if (o.isDone) {
      tooltip = '完了を取り消す';
      mark = Container(
        key: const ValueKey('done'),
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 21),
      );
    } else if (o.isSkipped) {
      tooltip = 'スキップを取り消す';
      mark = Container(
        key: const ValueKey('skipped'),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.redo_rounded,
          color: scheme.onSurfaceVariant,
          size: 18,
        ),
      );
    } else {
      tooltip = '完了にする';
      mark = Container(
        key: const ValueKey('pending'),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: tint(o.overdue ? scheme.error : color, context),
          shape: BoxShape.circle,
          border: Border.all(
            color: o.overdue ? scheme.error : onTint(color, context),
            width: 2.2,
          ),
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: InkResponse(
        radius: 26,
        onTap: () => _toggle(context),
        onLongPress: o.isPending ? () => showOccurrenceSheet(context, o) : null,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: mark,
            ),
          ),
        ),
      ),
    );
  }

  void _toggle(BuildContext context) {
    final store = context.readStore;
    final o = occurrence;
    if (o.isResolved) {
      store.undoRecord(o.record!.id);
      return;
    }
    HapticFeedback.lightImpact();
    final record = store.complete(o);
    showNotice(
      context,
      '「${o.chore.name}」完了！おつかれさま',
      actionLabel: '取り消す',
      onAction: () => store.undoRecord(record.id),
    );
  }
}

class _ThanksButton extends StatelessWidget {
  const _ThanksButton({
    required this.count,
    required this.active,
    required this.onPressed,
  });
  final int count;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = active || (onPressed == null && count > 0)
        ? scheme.tertiary
        : scheme.onSurfaceVariant;
    return Tooltip(
      message: onPressed == null ? 'もらったスタンプ' : 'ありがとうを送る',
      child: InkResponse(
        radius: 22,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                count > 0
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 20,
                color: color,
              ),
              if (count > 0) ...[
                const SizedBox(width: 2),
                Text(
                  '$count',
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

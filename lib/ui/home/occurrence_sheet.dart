import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/agenda.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../chores/chore_editor.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';

/// やること1件のくわしい操作（やった人を選ぶ・スキップ・スタンプ・編集）。
Future<void> showOccurrenceSheet(BuildContext context, Occurrence occurrence) {
  return showAppSheet<void>(
    context,
    builder: (_) => _OccurrenceSheet(occurrence),
  );
}

class _OccurrenceSheet extends StatelessWidget {
  const _OccurrenceSheet(this.occurrence);
  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final o = occurrence;
    // 一覧に出さない家事（予定外の記録用）も含めて、最新の内容を引き直す。
    final chore = store.choreById(o.chore.id) ?? o.chore;
    final genre = store.genreById(chore.genreId);
    final record = o.record == null ? null : store.recordById(o.record!.id);
    final wasResolved = o.record != null;
    if (wasResolved && record == null) {
      // 開いている間に取り消された。
      return const SizedBox(height: 8);
    }

    final info = <String>[
      genre.name,
      if (!chore.archived) chore.repeat.describe(chore.start),
      if (chore.dueMinutes != null) '${formatMinutes(chore.dueMinutes!)}まで',
    ];

    void close() => Navigator.pop(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GenreIcon(genre, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chore.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(info.join('  ・  '), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoLine(
          icon: Icons.event_rounded,
          text: o.isUnplanned
              ? '予定外の記録（${formatDateLong(o.date)}）'
              : o.overdue
              ? '${formatDateLong(o.date)}の予定（やり忘れ）'
              : '${formatDateLong(o.date)}の予定',
          color: o.overdue ? scheme.error : null,
        ),
        if (record != null)
          _InfoLine(
            icon: record.isDone ? Icons.task_alt_rounded : Icons.redo_rounded,
            text: record.isDone
                ? '完了日時: ${formatDateTime(record.at)}'
                : 'スキップした日時: ${formatDateTime(record.at)}',
            color: record.isDone ? scheme.primary : null,
          ),
        if (!chore.archived)
          _InfoLine(
            icon: Icons.person_rounded,
            text: '担当: ${store.memberById(chore.assigneeId)?.name ?? 'だれでも'}',
          ),
        if (chore.memo.isNotEmpty)
          _InfoLine(icon: Icons.notes_rounded, text: chore.memo),
        const SizedBox(height: 8),
        const Divider(),
        if (record == null) ...[
          const SectionLabel(
            'やった人をえらんで完了',
            padding: EdgeInsets.fromLTRB(0, 16, 0, 10),
          ),
          MemberPicker(
            members: store.members,
            onSelected: (m) {
              HapticFeedback.lightImpact();
              store.complete(o, doneById: m.id);
              close();
            },
          ),
        ] else if (record.isDone) ...[
          const SectionLabel(
            'やった人',
            padding: EdgeInsets.fromLTRB(0, 16, 0, 10),
          ),
          MemberPicker(
            members: store.members,
            selectedId: record.doneById,
            onSelected: (m) => store.setDoneBy(record.id, m.id),
          ),
          _StampSection(record: record),
        ] else ...[
          const SectionLabel(
            'スキップしました。やっぱりやった場合は、やった人をえらんでください',
            padding: EdgeInsets.fromLTRB(0, 16, 0, 10),
          ),
          MemberPicker(
            members: store.members,
            onSelected: (m) {
              store.setDoneBy(record.id, m.id);
              close();
            },
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (record == null)
              OutlinedButton.icon(
                onPressed: () {
                  store.skip(o);
                  close();
                },
                icon: const Icon(Icons.redo_rounded, size: 18),
                label: const Text('今回はスキップ'),
              )
            else
              OutlinedButton.icon(
                onPressed: () {
                  store.undoRecord(record.id);
                  close();
                },
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: Text(record.unplanned ? '記録を消す' : '未完了に戻す'),
              ),
            if (!chore.archived)
              OutlinedButton.icon(
                onPressed: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.push(choreEditorRoute(chore: chore));
                },
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('家事を編集'),
              ),
          ],
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: c),
            ),
          ),
        ],
      ),
    );
  }
}

/// スタンプを送る・もらったスタンプを見る。
class _StampSection extends StatelessWidget {
  const _StampSection({required this.record});
  final Record record;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final thanks = store.thanksFor(record.id);
    final mine = thanks
        .where((t) => t.fromId == store.currentMemberId)
        .map((t) => t.stamp)
        .firstOrNull;
    final isOwn = record.doneById == store.currentMemberId;
    final doer = store.memberById(record.doneById);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          isOwn ? 'もらったスタンプ' : '${doer?.name ?? 'やった人'}にスタンプを送る',
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
        ),
        if (!isOwn)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in stampKeys)
                FilterChip(
                  avatar: Icon(
                    stampIcons[key],
                    size: 18,
                    color: mine == key
                        ? scheme.onTertiaryContainer
                        : scheme.tertiary,
                  ),
                  label: Text(stampLabels[key]!),
                  selected: mine == key,
                  selectedColor: scheme.tertiaryContainer,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    store.toggleThanks(record.id, key);
                  },
                ),
            ],
          ),
        if (thanks.isEmpty && isOwn)
          Text('家族がスタンプを送ると、ここに届きます。', style: theme.textTheme.bodySmall),
        if (thanks.isNotEmpty) ...[
          if (!isOwn) const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in thanks)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tint(scheme.tertiary, context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MemberAvatar(store.memberById(t.fromId), size: 20),
                      const SizedBox(width: 6),
                      Icon(
                        stampIcons[t.stamp] ?? Icons.favorite_rounded,
                        size: 16,
                        color: scheme.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        stampLabels[t.stamp] ?? 'ありがとう',
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

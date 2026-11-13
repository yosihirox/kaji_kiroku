import 'package:flutter/material.dart';

import '../../domain/catalog.dart';
import '../../domain/dates.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';
import 'chore_editor.dart';

/// 家事を追加するシート。自分で作るか、よくある家事からえらぶ。
///
/// [genreId] を渡すと、そのジャンルのよくある家事だけを出し、
/// 「自分で作る」もそのジャンルをえらんだ状態で開く。
/// [date] を渡すと、その日を初回の日付にした状態で開く。
Future<void> showAddChoreSheet(
  BuildContext context, {
  String? genreId,
  DateTime? date,
}) {
  return showAppSheet<void>(
    context,
    builder: (_) => _AddChoreSheet(genreId: genreId, date: date),
  );
}

class _AddChoreSheet extends StatelessWidget {
  const _AddChoreSheet({this.genreId, this.date});
  final String? genreId;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final registered = {for (final c in store.chores) c.name};

    void open({ChoreTemplate? template}) {
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(
        choreEditorRoute(
          template: template,
          genreId: template == null ? genreId : null,
          date: date,
        ),
      );
    }

    final only = genreId == null ? null : store.genreById(genreId!);
    final genres = only == null ? store.visibleGenres : [only];
    final hasTemplates = genres.any(
      (g) => choreTemplates.any((t) => t.genreId == g.id),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (only != null) ...[
              GenreIcon(only, size: 32),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                only == null ? '家事を追加' : '「${only.name}」の家事を追加',
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),
        if (date != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.event_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${formatDateLong(date!)}から始める家事として登録します',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: open,
            icon: const Icon(Icons.edit_rounded, size: 20),
            label: const Text('自分で作る'),
          ),
        ),
        if (hasTemplates) ...[
          const SizedBox(height: 20),
          Text('よくある家事からえらぶ', style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            'くり返しの設定まで入った状態で開きます。内容はその場で変えられます。',
            style: theme.textTheme.bodySmall,
          ),
        ],
        for (final g in genres)
          if (choreTemplates.any((t) => t.genreId == g.id)) ...[
            if (only != null)
              const SizedBox(height: 12)
            else
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Row(
                  children: [
                    GenreIcon(g, size: 28),
                    const SizedBox(width: 8),
                    Text(g.name, style: theme.textTheme.titleSmall),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in choreTemplates.where((t) => t.genreId == g.id))
                  if (registered.contains(t.name))
                    Chip(
                      avatar: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      label: Text(t.name),
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      backgroundColor: scheme.surfaceContainer,
                      side: BorderSide.none,
                    )
                  else
                    ActionChip(
                      label: Text(t.name),
                      onPressed: () => open(template: t),
                    ),
              ],
            ),
          ],
      ],
    );
  }
}

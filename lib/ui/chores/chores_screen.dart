import 'package:flutter/material.dart';

import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';
import 'add_chore_sheet.dart';
import 'chore_editor.dart';
import 'genres_screen.dart';

/// 家事: 登録してある家事を、ジャンルごとに並べる。
class ChoresScreen extends StatelessWidget {
  const ChoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final chores = store.chores;
    final byGenre = <String, List<Chore>>{};
    for (final c in chores) {
      (byGenre[store.genreById(c.genreId).id] ??= []).add(c);
    }
    // 非表示にしたジャンルでも、家事が入っていれば最後に出す。
    final genres = [
      ...store.visibleGenres.where((g) => byGenre.containsKey(g.id)),
      ...store.genres.where((g) => g.hidden && byGenre.containsKey(g.id)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const ScreenTitle('家事', icon: Icons.checklist_rounded),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(genresRoute()),
              icon: const Icon(Icons.category_rounded, size: 20),
              label: const Text('ジャンル'),
            ),
          ),
        ],
      ),
      body: chores.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.checklist_rounded,
                  title: 'まだ家事がありません',
                  message: 'よくある家事からえらぶと、くり返しの設定まで入った状態で登録できます。',
                  actions: [
                    FilledButton.icon(
                      onPressed: () => showAddChoreSheet(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('家事を追加'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
              children: [
                for (final g in genres) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 4, 4),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: '「${g.name}」の家事を追加',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              showAddChoreSheet(context, genreId: g.id),
                          icon: const Icon(Icons.add_rounded, size: 20),
                        ),
                        const SizedBox(width: 6),
                        GenreIcon(g, size: 32),
                        const SizedBox(width: 10),
                        Text(
                          g.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${byGenre[g.id]!.length}件',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < byGenre[g.id]!.length; i++) ...[
                          if (i > 0) const Divider(indent: 16),
                          _ChoreTile(byGenre[g.id]![i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
      floatingActionButton: chores.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'chores-add',
              onPressed: () => showAddChoreSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('家事を追加'),
            ),
    );
  }
}

class _ChoreTile extends StatelessWidget {
  const _ChoreTile(this.chore);
  final Chore chore;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final next = store.nextDue(chore);
    final today = store.today;
    final overdue = next != null && next.isBefore(today);

    final String nextLabel;
    if (next == null) {
      nextLabel = '完了';
    } else if (overdue) {
      nextLabel = 'やり忘れ';
    } else {
      nextLabel = '次は${relativeDayLabel(next, today)}';
    }
    final parts = [
      chore.repeat.describe(chore.start),
      if (chore.dueMinutes != null) '${formatMinutes(chore.dueMinutes!)}まで',
    ];

    return InkWell(
      onTap: () => Navigator.of(context).push(choreEditorRoute(chore: chore)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chore.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: parts.join('  ・  ')),
                        const TextSpan(text: '  ・  '),
                        TextSpan(
                          text: nextLabel,
                          style: TextStyle(
                            color: overdue ? scheme.error : null,
                          ),
                        ),
                      ],
                    ),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Opacity(
              opacity: chore.assigneeId == null ? 0.7 : 1,
              child: MemberAvatar(store.memberById(chore.assigneeId), size: 30),
            ),
          ],
        ),
      ),
    );
  }
}

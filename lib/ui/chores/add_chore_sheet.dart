import 'package:flutter/material.dart';

import '../../domain/catalog.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';
import 'chore_editor.dart';

/// 家事を追加するシート。自分で作るか、よくある家事からえらぶ。
Future<void> showAddChoreSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _AddChoreSheet());
}

class _AddChoreSheet extends StatelessWidget {
  const _AddChoreSheet();

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final registered = {for (final c in store.chores) c.name};

    void open({ChoreTemplate? template}) {
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(choreEditorRoute(template: template));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('家事を追加', style: theme.textTheme.titleLarge),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: open,
            icon: const Icon(Icons.edit_rounded, size: 20),
            label: const Text('自分で作る'),
          ),
        ),
        const SizedBox(height: 20),
        Text('よくある家事からえらぶ', style: theme.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          'くり返しの設定まで入った状態で開きます。内容はその場で変えられます。',
          style: theme.textTheme.bodySmall,
        ),
        for (final g in store.visibleGenres)
          if (choreTemplates.any((t) => t.genreId == g.id)) ...[
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

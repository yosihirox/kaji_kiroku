import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../ui_common.dart';
import 'chore_edit_screen.dart';

/// 家事一覧: ジャンルごとに登録済みの家事と繰り返しを並べる。
class ChoresScreen extends StatelessWidget {
  const ChoresScreen({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hidden = store.genres.where((g) => g.hidden).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('家事一覧'),
        actions: [
          TextButton.icon(
            onPressed: () => showGenreEditor(context, store),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('ジャンル追加'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final g in store.visibleGenres) ..._genreSection(context, g),
          if (hidden.isNotEmpty) ...[
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('非表示のジャンル', style: theme.textTheme.titleSmall),
            ),
            for (final g in hidden)
              ListTile(
                leading: GenreBadge(g, size: 32),
                title: Text(g.name),
                trailing: TextButton(
                  onPressed: () => store.updateGenre(g, hidden: false),
                  child: const Text('表示する'),
                ),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'chores-add',
        onPressed: () => openChoreEditor(context, store),
        icon: const Icon(Icons.add),
        label: const Text('家事を追加'),
      ),
    );
  }

  List<Widget> _genreSection(BuildContext context, Genre g) {
    final theme = Theme.of(context);
    final chores = store.activeChores.where((c) => c.genreId == g.id).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
        child: Row(
          children: [
            GenreBadge(g, size: 28),
            const SizedBox(width: 8),
            Text(g.name,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Text('${chores.length}件', style: theme.textTheme.bodySmall),
            const Spacer(),
            IconButton(
              tooltip: '${g.name}に家事を追加',
              icon: const Icon(Icons.add),
              onPressed: () => openChoreEditor(context, store, genreId: g.id),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'edit':
                    await showGenreEditor(context, store, genre: g);
                  case 'hide':
                    await store.updateGenre(g, hidden: true);
                  case 'delete':
                    await store.deleteGenre(g);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('名前・アイコンを変更')),
                const PopupMenuItem(value: 'hide', child: Text('非表示にする')),
                if (!g.builtIn)
                  const PopupMenuItem(
                      value: 'delete', child: Text('削除（家事は「その他」へ）')),
              ],
            ),
          ],
        ),
      ),
      for (final c in chores)
        ListTile(
          contentPadding: const EdgeInsets.only(left: 52, right: 16),
          title: Text(c.name),
          subtitle: Text(c.repeat.describe(c.startDate)),
          trailing: MemberAvatar(store.memberById(c.assigneeId)),
          onTap: () => openChoreEditor(context, store, chore: c),
        ),
      if (chores.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(52, 0, 16, 8),
          child: Text('まだありません',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ),
    ];
  }
}

/// ジャンルの追加・変更ダイアログ。
Future<void> showGenreEditor(BuildContext context, AppStore store,
    {Genre? genre}) async {
  final name = TextEditingController(text: genre?.name ?? '');
  var icon = genre?.iconKey ?? 'star';
  var color = genre?.colorValue ?? paletteColors.first;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(genre == null ? 'ジャンルを追加' : 'ジャンルを変更'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                autofocus: genre == null,
                decoration: const InputDecoration(
                    labelText: 'ジャンル名', hintText: '例: 車・庭仕事'),
              ),
              const SizedBox(height: 16),
              const Text('アイコン'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final e in genreIcons.entries)
                    IconButton(
                      isSelected: icon == e.key,
                      style: IconButton.styleFrom(
                        backgroundColor: icon == e.key
                            ? Color(color).withValues(alpha: 0.2)
                            : null,
                      ),
                      icon: Icon(e.value,
                          color: icon == e.key ? Color(color) : null),
                      onPressed: () => setState(() => icon = e.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('色'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in paletteColors)
                    GestureDetector(
                      onTap: () => setState(() => color = c),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(c),
                        child: color == c
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              final n = name.text.trim();
              if (n.isEmpty) return;
              if (genre == null) {
                await store.addGenre(n, icon, color);
              } else {
                await store.updateGenre(genre,
                    name: n, iconKey: icon, colorValue: color);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

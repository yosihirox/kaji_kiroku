import 'package:flutter/material.dart';

import '../../domain/catalog.dart';
import '../../domain/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';

Route<void> genresRoute() =>
    MaterialPageRoute<void>(builder: (_) => const GenresScreen());

/// ジャンルの管理: 並べ替え、追加、名前・アイコン・色の変更、非表示。
class GenresScreen extends StatelessWidget {
  const GenresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final genres = store.genres;
    final counts = <String, int>{};
    for (final c in store.chores) {
      counts[c.genreId] = (counts[c.genreId] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(title: Text('ジャンル', style: theme.textTheme.titleLarge)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '使わないジャンルは目のボタンで隠せます。右のつまみを押したまま動かすと、並べ替えられます。',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
              buildDefaultDragHandles: false,
              itemCount: genres.length,
              onReorderItem: store.reorderGenres,
              proxyDecorator: (child, _, _) =>
                  Material(color: Colors.transparent, child: child),
              itemBuilder: (context, i) {
                final g = genres[i];
                return Padding(
                  key: ValueKey(g.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => showGenreEditor(context, genre: g),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                        child: Row(
                          children: [
                            Opacity(
                              opacity: g.hidden ? 0.4 : 1,
                              child: GenreIcon(g, size: 40),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    g.name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: g.hidden
                                              ? scheme.onSurfaceVariant
                                              : null,
                                        ),
                                  ),
                                  Text(
                                    [
                                      '家事 ${counts[g.id] ?? 0}件',
                                      if (g.hidden) '非表示',
                                    ].join('  ・  '),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: g.hidden ? '表示する' : '隠す',
                              onPressed: () =>
                                  store.updateGenre(g.id, hidden: !g.hidden),
                              icon: Icon(
                                g.hidden
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.drag_indicator_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'genre-add',
        onPressed: () => showGenreEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('ジャンルを追加'),
      ),
    );
  }
}

/// ジャンルの追加・変更シート。
Future<void> showGenreEditor(BuildContext context, {Genre? genre}) {
  return showAppSheet<void>(context, builder: (_) => _GenreEditor(genre));
}

class _GenreEditor extends StatefulWidget {
  const _GenreEditor(this.genre);
  final Genre? genre;

  @override
  State<_GenreEditor> createState() => _GenreEditorState();
}

class _GenreEditorState extends State<_GenreEditor> {
  late final _name = TextEditingController(text: widget.genre?.name ?? '');
  late String _icon = widget.genre?.icon ?? 'home';
  late int _color = widget.genre?.color ?? genreColors[8];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final store = context.readStore;
    final g = widget.genre;
    if (g == null) {
      store.addGenre(name, _icon, _color);
    } else {
      store.updateGenre(g.id, name: name, icon: _icon, color: _color);
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final g = widget.genre!;
    final ok = await confirm(
      context,
      title: '「${g.name}」を削除しますか？',
      message: 'このジャンルの家事は「その他」に移ります。',
      action: '削除',
      destructive: true,
    );
    if (!ok || !mounted) return;
    context.readStore.deleteGenre(g.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final g = widget.genre;
    final color = Color(_color);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          g == null ? 'ジャンルを追加' : 'ジャンルを変更',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          autofocus: g == null,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'ジャンル名',
            hintText: '例: 車、庭しごと',
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
        ),
        const SectionLabel('アイコン', padding: EdgeInsets.fromLTRB(0, 18, 0, 8)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in genreIcons.entries)
              Semantics(
                button: true,
                selected: _icon == e.key,
                label: 'アイコン',
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _icon = e.key),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _icon == e.key
                          ? tint(color, context)
                          : scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _icon == e.key
                            ? onTint(color, context)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      e.value,
                      size: 22,
                      color: _icon == e.key
                          ? onTint(color, context)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SectionLabel('色', padding: EdgeInsets.fromLTRB(0, 18, 0, 8)),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in genreColors)
              Semantics(
                button: true,
                selected: _color == c,
                label: '色',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                    ),
                    child: _color == c
                        ? const Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            if (g != null && !g.builtIn)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                label: const Text('削除'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: _name.text.trim().isEmpty ? null : _save,
              child: Text(g == null ? '追加' : '保存'),
            ),
          ],
        ),
      ],
    );
  }
}

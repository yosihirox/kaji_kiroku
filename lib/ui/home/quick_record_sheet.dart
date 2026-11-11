import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/catalog.dart';
import '../../domain/models.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';

/// 予定になかった家事を「やったよ」と記録するシート。
Future<void> showQuickRecordSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _QuickRecordSheet());
}

class _QuickRecordSheet extends StatefulWidget {
  const _QuickRecordSheet();

  @override
  State<_QuickRecordSheet> createState() => _QuickRecordSheetState();
}

class _QuickRecordSheetState extends State<_QuickRecordSheet> {
  final _name = TextEditingController();
  String? _doneById;
  String _genreId = otherGenreId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done(String choreName) {
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('「$choreName」を記録しました。おつかれさま')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final doneById = _doneById ?? store.currentMemberId;
    final query = _name.text.trim();
    final matches = store.chores
        .where((c) => query.isEmpty || c.name.contains(query))
        .toList();
    final exact = matches.any((c) => c.name == query);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('やったことを記録', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('予定になかった家事も、がんばりに残せます。', style: theme.textTheme.bodySmall),
        const SectionLabel('やった人', padding: EdgeInsets.fromLTRB(0, 16, 0, 10)),
        MemberPicker(
          members: store.members,
          selectedId: doneById,
          onSelected: (m) => setState(() => _doneById = m.id),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'やった家事の名前（例: 玄関の掃き掃除）',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (query.isNotEmpty && !exact) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in store.visibleGenres)
                ChoiceChip(
                  avatar: Icon(
                    iconForGenre(g),
                    size: 16,
                    color: Color(g.color),
                  ),
                  label: Text(g.name),
                  selected: _genreId == g.id,
                  onSelected: (_) => setState(() => _genreId = g.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                store.recordUnplannedByName(
                  query,
                  _genreId,
                  doneById: doneById,
                );
                _done(query);
              },
              icon: const Icon(Icons.check_rounded),
              label: Text('「$query」を記録'),
            ),
          ),
        ],
        if (matches.isNotEmpty) ...[
          SectionLabel(
            query.isEmpty ? '登録してある家事からえらぶ' : '登録してある家事',
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
          ),
          for (final c in matches)
            _ChoreRow(
              c,
              onTap: () {
                store.recordUnplanned(c, doneById: doneById);
                _done(c.name);
              },
            ),
        ],
      ],
    );
  }
}

class _ChoreRow extends StatelessWidget {
  const _ChoreRow(this.chore, {required this.onTap});
  final Chore chore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            GenreIcon(store.genreById(chore.genreId), size: 36),
            const SizedBox(width: 12),
            Expanded(child: Text(chore.name, style: theme.textTheme.bodyLarge)),
            Icon(
              Icons.add_task_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

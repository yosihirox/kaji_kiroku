import 'package:flutter/material.dart';

import '../models.dart';
import '../recurrence.dart';
import '../store.dart';
import '../ui_common.dart';
import 'chore_edit_screen.dart';

/// ホーム: 期限切れ → 今日 → 明日 … と1週間分の「やること」を並べる。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _onlyMine = false;

  AppStore get store => widget.store;

  bool _visible(AgendaItem i) {
    if (!_onlyMine) return true;
    final c = i.chore;
    if (i.record?.doneById == store.currentMemberId) return true;
    return c.assigneeId == null || c.assigneeId == store.currentMemberId;
  }

  @override
  Widget build(BuildContext context) {
    final overdue = store.overdue().where(_visible).toList();
    final days = store.upcoming();
    final theme = Theme.of(context);

    final children = <Widget>[];
    if (overdue.isNotEmpty) {
      children.add(_SectionHeader(
        title: '期限切れ',
        color: theme.colorScheme.error,
        icon: Icons.warning_amber_rounded,
      ));
      for (final item in overdue) {
        children.add(_tile(item, overdue: true));
      }
    }
    for (final day in days) {
      final items = day.items.where(_visible).toList();
      final diff = daysBetween(store.today, day.date);
      final label = switch (diff) {
        0 => '今日 ${formatDate(day.date)}',
        1 => '明日 ${formatDate(day.date)}',
        _ => formatDate(day.date),
      };
      final remaining = items.where((i) => !i.isResolved).length;
      children.add(_SectionHeader(
        title: label,
        trailing: items.isEmpty
            ? null
            : remaining == 0
                ? 'ぜんぶ完了'
                : 'のこり$remaining件',
        emphasized: diff == 0,
      ));
      if (items.isEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
          child: Text('予定なし',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ));
      }
      for (final item in items) {
        children.add(_tile(item));
      }
    }
    if (store.activeChores.isEmpty) {
      children.insert(
        0,
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'まだ家事が登録されていません。\n右下の「＋」から「洗濯槽の掃除（毎月）」のように登録してみましょう。',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('やること'),
        actions: [
          IconButton(
            tooltip: 'ついでにやった家事を記録',
            icon: const Icon(Icons.bolt),
            onPressed: _recordUnplanned,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('自分の担当だけ'),
                  selected: _onlyMine,
                  onSelected: (v) => setState(() => _onlyMine = v),
                ),
                const Spacer(),
                Text('${store.currentMember?.name ?? ''} として記録中',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: children,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home-add',
        onPressed: () => openChoreEditor(context, store),
        icon: const Icon(Icons.add),
        label: const Text('家事を追加'),
      ),
    );
  }

  Widget _tile(AgendaItem item, {bool overdue = false}) {
    final theme = Theme.of(context);
    final chore = item.chore;
    final genre = store.genreById(chore.genreId);
    final rec = item.record;
    final assignee = store.memberById(chore.assigneeId);

    String subtitle;
    Member? avatarMember = assignee;
    if (rec?.status == RecordStatus.done) {
      final who = store.memberById(rec!.doneById);
      avatarMember = who;
      subtitle = '${who?.name ?? '（退出したメンバー）'}がやった${rec.unplanned ? '（ついでに）' : ''}';
    } else if (rec?.status == RecordStatus.skipped) {
      subtitle = '今回はスキップ';
    } else {
      final parts = [genre.name, '担当: ${assignee?.name ?? 'だれでも'}'];
      if (overdue) parts.insert(0, '${formatDate(item.date)}の分');
      subtitle = parts.join(' · ');
    }

    return ListTile(
      leading: IconButton(
        tooltip: item.isDone ? '完了を取り消す' : '完了にする',
        iconSize: 30,
        onPressed: () => _toggle(item),
        icon: Icon(
          item.isDone
              ? Icons.check_circle
              : rec?.status == RecordStatus.skipped
                  ? Icons.remove_circle_outline
                  : Icons.radio_button_unchecked,
          color: item.isDone
              ? Color(genre.colorValue)
              : overdue
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
        ),
      ),
      title: Row(
        children: [
          Icon(iconFor(genre), size: 16, color: Color(genre.colorValue)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              chore.name,
              style: item.isResolved
                  ? TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: theme.colorScheme.outline)
                  : null,
            ),
          ),
        ],
      ),
      subtitle: Text(subtitle),
      trailing: MemberAvatar(avatarMember),
      onTap: () => _showActions(item),
      onLongPress: () => _showActions(item),
    );
  }

  Future<void> _toggle(AgendaItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    if (item.isResolved) {
      await store.undo(item.chore, item.date);
      return;
    }
    await store.complete(item.chore, item.date);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('「${item.chore.name}」完了！おつかれさま'),
      action: SnackBarAction(
        label: '取り消す',
        onPressed: () => store.undo(item.chore, item.date),
      ),
    ));
  }

  Future<void> _showActions(AgendaItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(item.chore.name,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(
                  '${formatDate(item.date)} · ${item.chore.repeat.describe(item.chore.startDate)}'),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('やった人を選んで完了'),
            ),
            for (final m in store.members)
              ListTile(
                leading: MemberAvatar(m),
                title: Text(m.name),
                trailing: item.record?.doneById == m.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  store.complete(item.chore, item.date, doneById: m.id);
                },
              ),
            const Divider(),
            if (item.record?.status != RecordStatus.skipped &&
                !(item.record?.unplanned ?? false))
              ListTile(
                leading: const Icon(Icons.redo),
                title: const Text('今回はスキップ'),
                onTap: () {
                  Navigator.pop(context);
                  store.skip(item.chore, item.date);
                },
              ),
            if (item.isResolved)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('未完了に戻す'),
                onTap: () {
                  Navigator.pop(context);
                  if (item.record!.unplanned) {
                    store.deleteRecord(item.record!);
                  } else {
                    store.undo(item.chore, item.date);
                  }
                },
              ),
            if (!item.chore.archived)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('この家事を編集'),
                onTap: () {
                  Navigator.pop(context);
                  openChoreEditor(this.context, store, chore: item.chore);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 予定にない家事を「やったよ」と記録する。
  Future<void> _recordUnplanned() async {
    final chores = store.activeChores..sort((a, b) => a.name.compareTo(b.name));
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            const ListTile(
              title: Text('ついでにやった家事を記録'),
              subtitle: Text('予定になかった家事も、がんばりに残せます'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('名前を入力して記録'),
              onTap: () async {
                Navigator.pop(context);
                final name = await askText(this.context,
                    title: 'やった家事', hint: '例: 冷蔵庫の掃除');
                if (name == null || name.isEmpty) return;
                await store.recordUnplannedByName(name, 'other');
              },
            ),
            const Divider(),
            for (final c in chores)
              ListTile(
                leading: GenreBadge(store.genreById(c.genreId), size: 32),
                title: Text(c.name),
                onTap: () {
                  Navigator.pop(context);
                  store.recordUnplanned(c);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.color,
    this.icon,
    this.emphasized = false,
  });

  final String title;
  final String? trailing;
  final Color? color;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? (emphasized ? theme.colorScheme.primary : null);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: c),
            const SizedBox(width: 4),
          ],
          Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: c, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (trailing != null)
            Text(trailing!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

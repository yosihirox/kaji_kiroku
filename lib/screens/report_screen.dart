import 'package:flutter/material.dart';

import '../models.dart';
import '../recurrence.dart';
import '../store.dart';
import '../ui_common.dart';

enum _Period { week, month }

/// がんばり: 誰がどの家事をどれだけやったかを見える化する。
/// 競争ではなく感謝のための画面なので、順位は出さない。
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  _Period _period = _Period.week;

  AppStore get store => widget.store;

  (DateTime, DateTime) get _range {
    final t = store.today;
    if (_period == _Period.week) {
      final monday = addDays(t, -(t.weekday - 1));
      return (monday, addDays(monday, 6));
    }
    return (DateTime(t.year, t.month, 1), DateTime(t.year, t.month + 1, 0));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (from, to) = _range;
    final done = store.doneBetween(from, to);
    final byMember = <String?, List<Record>>{};
    for (final m in store.members) {
      byMember[m.id] = [];
    }
    for (final r in done) {
      final key = store.memberById(r.doneById) == null ? null : r.doneById;
      (byMember[key] ??= []).add(r);
    }
    final maxCount = byMember.values.fold<int>(0, (m, l) => l.length > m ? l.length : m);

    return Scaffold(
      appBar: AppBar(title: const Text('がんばり')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_Period>(
            segments: const [
              ButtonSegment(value: _Period.week, label: Text('今週')),
              ButtonSegment(value: _Period.month, label: Text('今月')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 16),
          Text(
            '${formatDate(from)} 〜 ${formatDate(to)}　家族で ${done.length}件 の家事をしました',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          for (final e in byMember.entries)
            _MemberCard(
              store: store,
              member: store.memberById(e.key),
              records: e.value,
              maxCount: maxCount,
            ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.store,
    required this.member,
    required this.records,
    required this.maxCount,
  });

  final AppStore store;
  final Member? member;
  final List<Record> records;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = member == null ? Colors.grey : Color(member!.colorValue);
    final byGenre = <String, int>{};
    for (final r in records) {
      final c = store.choreById(r.choreId);
      if (c == null) continue;
      byGenre[c.genreId] = (byGenre[c.genreId] ?? 0) + 1;
    }
    final genreEntries = byGenre.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: MemberAvatar(member, radius: 18),
        title: Row(
          children: [
            Text(member?.name ?? '（退出したメンバー）',
                style: theme.textTheme.titleMedium),
            const Spacer(),
            Text('${records.length}件', style: theme.textTheme.titleMedium),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: maxCount == 0 ? 0 : records.length / maxCount,
                  minHeight: 8,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
              ),
              if (genreEntries.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    for (final e in genreEntries)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconFor(store.genreById(e.key)),
                              size: 14,
                              color: Color(store.genreById(e.key).colorValue)),
                          const SizedBox(width: 2),
                          Text('${store.genreById(e.key).name} ${e.value}',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        children: [
          if (records.isEmpty)
            const ListTile(title: Text('この期間の記録はまだありません')),
          for (final r in records)
            ListTile(
              dense: true,
              leading: Icon(
                iconFor(store.genreById(store.choreById(r.choreId)?.genreId ?? 'other')),
                size: 20,
              ),
              title: Text(store.choreById(r.choreId)?.name ?? '（削除された家事）'),
              subtitle: r.unplanned ? const Text('ついでにやった') : null,
              trailing: Text(formatDate(r.at)),
            ),
        ],
      ),
    );
  }
}

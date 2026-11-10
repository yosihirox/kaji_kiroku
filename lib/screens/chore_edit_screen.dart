import 'package:flutter/material.dart';

import '../models.dart';
import '../recurrence.dart';
import '../store.dart';
import '../ui_common.dart';

Future<void> openChoreEditor(BuildContext context, AppStore store,
    {Chore? chore, String? genreId}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => ChoreEditScreen(store: store, chore: chore, genreId: genreId),
  ));
}

/// 家事の登録・編集。
class ChoreEditScreen extends StatefulWidget {
  const ChoreEditScreen({super.key, required this.store, this.chore, this.genreId});
  final AppStore store;
  final Chore? chore;
  final String? genreId;

  @override
  State<ChoreEditScreen> createState() => _ChoreEditScreenState();
}

class _ChoreEditScreenState extends State<ChoreEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _memo;
  late String _genreId;
  String? _assigneeId;
  late DateTime _start;

  late RepeatType _type;
  late int _interval;
  late Set<int> _weekdays;
  late int _monthDay;
  late Set<int> _nths;
  late int _weekday;

  AppStore get store => widget.store;
  bool get _isNew => widget.chore == null;

  @override
  void initState() {
    super.initState();
    final c = widget.chore;
    _name = TextEditingController(text: c?.name ?? '');
    _memo = TextEditingController(text: c?.memo ?? '');
    _genreId = c?.genreId ?? widget.genreId ?? store.visibleGenres.first.id;
    _assigneeId = c?.assigneeId;
    _start = c?.startDate ?? store.today;
    final r = c?.repeat ?? const Repeat.none();
    _type = r.type;
    _interval = r.interval;
    _weekdays = {...r.weekdays};
    if (_weekdays.isEmpty) _weekdays = {_start.weekday};
    _monthDay = r.type == RepeatType.monthlyDay ? r.monthDay : _start.day;
    _nths = {...r.nths};
    if (_nths.isEmpty) _nths = {(_start.day - 1) ~/ 7 + 1 > 4 ? 5 : (_start.day - 1) ~/ 7 + 1};
    _weekday = r.type == RepeatType.monthlyNthWeekday ? r.weekday : _start.weekday;
  }

  @override
  void dispose() {
    _name.dispose();
    _memo.dispose();
    super.dispose();
  }

  Repeat get _repeat => Repeat(
        type: _type,
        interval: _interval,
        weekdays: _type == RepeatType.weekly ? _weekdays : const {},
        monthDay: _monthDay,
        nths: _type == RepeatType.monthlyNthWeekday ? _nths : const {},
        weekday: _weekday,
      );

  String? get _problem {
    if (_name.text.trim().isEmpty) return '家事の名前を入れてください';
    if (_type == RepeatType.weekly && _weekdays.isEmpty) return '曜日を選んでください';
    if (_type == RepeatType.monthlyNthWeekday && _nths.isEmpty) {
      return '第何週かを選んでください';
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _problem;
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final chore = Chore(
      id: widget.chore?.id ?? store.newId(),
      name: _name.text.trim(),
      genreId: _genreId,
      startDate: _start,
      repeat: _repeat,
      assigneeId: _assigneeId,
      memo: _memo.text.trim(),
    );
    await store.saveChore(chore);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この家事を削除しますか？'),
        content: const Text('これまでの完了記録も消えます。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除')),
        ],
      ),
    );
    if (ok != true) return;
    await store.deleteChore(widget.chore!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repeatValid = !(_type == RepeatType.weekly && _weekdays.isEmpty) &&
        !(_type == RepeatType.monthlyNthWeekday && _nths.isEmpty);
    final preview = repeatValid
        ? _repeat.occurrencesBetween(
            store.today, addDays(store.today, 400), _start,
            lastDone: widget.chore == null ? null : store.lastDoneDate(widget.chore!.id))
        : <DateTime>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '家事を追加' : '家事を編集'),
        actions: [
          if (!_isNew)
            IconButton(
                tooltip: '削除',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline)),
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            autofocus: _isNew,
            decoration: const InputDecoration(
              labelText: '家事の名前',
              hintText: '例: 洗濯槽の掃除',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Text('ジャンル', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in store.visibleGenres)
                ChoiceChip(
                  showCheckmark: false,
                  avatar: Icon(iconFor(g), size: 18, color: Color(g.colorValue)),
                  label: Text(g.name),
                  selected: _genreId == g.id,
                  onSelected: (_) => setState(() => _genreId = g.id),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('担当予定', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('だれでも'),
                selected: _assigneeId == null,
                onSelected: (_) => setState(() => _assigneeId = null),
              ),
              for (final m in store.members)
                ChoiceChip(
                  showCheckmark: false,
                  avatar: MemberAvatar(m, radius: 10),
                  label: Text(m.name),
                  selected: _assigneeId == m.id,
                  onSelected: (_) => setState(() => _assigneeId = m.id),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('繰り返し', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<RepeatType>(
            initialValue: _type,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: RepeatType.none, child: Text('1回だけ')),
              DropdownMenuItem(value: RepeatType.daily, child: Text('毎日・N日ごと')),
              DropdownMenuItem(value: RepeatType.weekly, child: Text('毎週（曜日を指定）')),
              DropdownMenuItem(value: RepeatType.monthlyDay, child: Text('毎月（日にちを指定）')),
              DropdownMenuItem(
                  value: RepeatType.monthlyNthWeekday,
                  child: Text('毎月（第2月曜などを指定）')),
              DropdownMenuItem(value: RepeatType.yearly, child: Text('毎年')),
              DropdownMenuItem(
                  value: RepeatType.afterDone, child: Text('やった日からN日後')),
            ],
            onChanged: (v) => setState(() {
              _type = v!;
              if (_type == RepeatType.afterDone && _interval < 2) _interval = 30;
              if (_type != RepeatType.afterDone && _interval == 30) _interval = 1;
            }),
          ),
          const SizedBox(height: 12),
          ..._repeatDetails(theme),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(_type == RepeatType.none ? 'いつまでに' : '開始日'),
            subtitle: Text('${_start.year}年 ${formatDate(_start)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _start,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _start = dateOnly(picked));
            },
          ),
          if (_type != RepeatType.none) ...[
            const SizedBox(height: 4),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_repeat.describe(_start),
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      preview.isEmpty
                          ? '次の予定はありません'
                          : '次の予定: ${preview.take(4).map(formatDate).join('、')}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _memo,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'メモ（任意）',
              hintText: '例: 洗剤は洗面台の下',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _repeatDetails(ThemeData theme) {
    Widget intervalRow(String prefix, String unit) => Row(
          children: [
            Text(prefix),
            IconButton(
              onPressed: _interval > 1 ? () => setState(() => _interval--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$_interval', style: theme.textTheme.titleMedium),
            IconButton(
              onPressed: () => setState(() => _interval++),
              icon: const Icon(Icons.add_circle_outline),
            ),
            Text(unit),
          ],
        );

    Widget weekdayChips(Set<int> selected, void Function(int) onTap) => Wrap(
          spacing: 6,
          children: [
            for (var w = 1; w <= 7; w++)
              FilterChip(
                label: Text(weekdayLabels[w - 1]),
                selected: selected.contains(w),
                showCheckmark: false,
                onSelected: (_) => setState(() => onTap(w)),
              ),
          ],
        );

    switch (_type) {
      case RepeatType.none:
        return [];
      case RepeatType.daily:
        return [intervalRow('', '日ごと')];
      case RepeatType.weekly:
        return [
          intervalRow('', '週ごと'),
          weekdayChips(_weekdays, (w) {
            _weekdays.contains(w) ? _weekdays.remove(w) : _weekdays.add(w);
          }),
        ];
      case RepeatType.monthlyDay:
        return [
          intervalRow('', 'か月ごと'),
          DropdownButtonFormField<int>(
            initialValue: _monthDay,
            decoration: const InputDecoration(
                labelText: '日にち', border: OutlineInputBorder()),
            items: [
              for (var d = 1; d <= 31; d++)
                DropdownMenuItem(value: d, child: Text('$d日')),
              const DropdownMenuItem(value: 0, child: Text('月末')),
            ],
            onChanged: (v) => setState(() => _monthDay = v!),
          ),
        ];
      case RepeatType.monthlyNthWeekday:
        return [
          intervalRow('', 'か月ごと'),
          Wrap(
            spacing: 6,
            children: [
              for (final n in [1, 2, 3, 4, 5])
                FilterChip(
                  label: Text(n == 5 ? '最終' : '第$n'),
                  selected: _nths.contains(n),
                  onSelected: (_) => setState(() {
                    _nths.contains(n) ? _nths.remove(n) : _nths.add(n);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          weekdayChips({_weekday}, (w) => _weekday = w),
        ];
      case RepeatType.yearly:
        return [
          intervalRow('', '年ごと'),
          Text('開始日と同じ月日に繰り返します', style: theme.textTheme.bodySmall),
        ];
      case RepeatType.afterDone:
        return [
          intervalRow('最後にやった日から', '日後'),
          Text('遅れてやっても、次回はやった日から数え直します。掃除系の家事におすすめです。',
              style: theme.textTheme.bodySmall),
        ];
    }
  }
}

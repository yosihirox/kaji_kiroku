import 'package:flutter/material.dart';

import '../../domain/catalog.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/recurrence.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';

/// 家事の登録・編集画面を開くルート。
///
/// [chore] を渡すと編集、[template] を渡すとよくある家事を下書きにした新規登録。
Route<void> choreEditorRoute({
  Chore? chore,
  ChoreTemplate? template,
  String? genreId,
  DateTime? date,
}) {
  return MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => ChoreEditor(
      chore: chore,
      template: template,
      genreId: genreId,
      date: date,
    ),
  );
}

/// くり返しの大きな分け方（画面のえらび方）。
enum _Cycle { once, daily, weekly, monthly, yearly, afterDone }

const _cycleLabels = {
  _Cycle.once: '1回だけ',
  _Cycle.daily: '毎日',
  _Cycle.weekly: '毎週',
  _Cycle.monthly: '毎月',
  _Cycle.yearly: '毎年',
  _Cycle.afterDone: 'やった日から',
};

class ChoreEditor extends StatefulWidget {
  const ChoreEditor({
    super.key,
    this.chore,
    this.template,
    this.genreId,
    this.date,
  });
  final Chore? chore;
  final ChoreTemplate? template;
  final String? genreId;

  /// 新しく登録するときの初回の日付（ホームの日付ごとの「＋」から開いたとき）。
  final DateTime? date;

  @override
  State<ChoreEditor> createState() => _ChoreEditorState();
}

class _ChoreEditorState extends State<ChoreEditor> {
  final _name = TextEditingController();
  final _memo = TextEditingController();
  bool _initialized = false;

  late String _genreId;
  String? _assigneeId;
  late DateTime _start;
  int? _dueMinutes;

  _Cycle _cycle = _Cycle.once;
  int _interval = 1;
  Set<int> _weekdays = {};
  bool _monthlyByWeekday = false;
  int _monthDay = 1;
  Set<int> _nths = {};
  int _weekday = DateTime.monday;

  bool get _isNew => widget.chore == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final store = context.readStore;
    final c = widget.chore;
    final t = widget.template;
    final today = store.today;

    _name.text = c?.name ?? t?.name ?? '';
    _memo.text = c?.memo ?? '';
    final genres = store.visibleGenres;
    _genreId =
        c?.genreId ??
        t?.genreId ??
        widget.genreId ??
        (genres.isNotEmpty ? genres.first.id : otherGenreId);
    _assigneeId = c?.assigneeId;
    final date = widget.date == null ? null : dateOnly(widget.date!);
    _start = c?.start ?? date ?? t?.startFor(today) ?? today;
    _dueMinutes = c?.dueMinutes ?? t?.dueMinutes;

    final r = c?.repeat ?? t?.repeat ?? const Repeat.none();
    _cycle = switch (r.type) {
      RepeatType.none => _Cycle.once,
      RepeatType.daily => _Cycle.daily,
      RepeatType.weekly => _Cycle.weekly,
      RepeatType.monthlyDay || RepeatType.monthlyNthWeekday => _Cycle.monthly,
      RepeatType.yearly => _Cycle.yearly,
      RepeatType.afterDone => _Cycle.afterDone,
    };
    _interval = r.interval < 1 ? 1 : r.interval;
    _monthlyByWeekday = r.type == RepeatType.monthlyNthWeekday;
    // えらんでいない種類の項目にも、開始日に合わせたそれらしい初期値を入れておく。
    _weekdays = r.type == RepeatType.weekly && r.weekdays.isNotEmpty
        ? {...r.weekdays}
        : {_start.weekday};
    _monthDay = r.type == RepeatType.monthlyDay ? r.monthDay : _start.day;
    final nth = (_start.day - 1) ~/ 7 + 1;
    _nths = r.type == RepeatType.monthlyNthWeekday && r.nths.isNotEmpty
        ? {...r.nths}
        : {nth > 4 ? Repeat.lastWeek : nth};
    _weekday = r.type == RepeatType.monthlyNthWeekday
        ? r.weekday
        : _start.weekday;
  }

  @override
  void dispose() {
    _name.dispose();
    _memo.dispose();
    super.dispose();
  }

  Repeat get _repeat => switch (_cycle) {
    _Cycle.once => const Repeat.none(),
    _Cycle.daily => Repeat.daily(_interval),
    _Cycle.weekly => Repeat.weekly({..._weekdays}, interval: _interval),
    _Cycle.monthly =>
      _monthlyByWeekday
          ? Repeat.monthlyNth({..._nths}, _weekday, interval: _interval)
          : Repeat.monthlyDay(_monthDay, interval: _interval),
    _Cycle.yearly => Repeat.yearly(_interval),
    _Cycle.afterDone => Repeat.afterDone(_interval),
  };

  String? get _problem {
    if (_name.text.trim().isEmpty) return '家事の名前を入れてください';
    if (_cycle == _Cycle.weekly && _weekdays.isEmpty) return '曜日をえらんでください';
    if (_cycle == _Cycle.monthly && _monthlyByWeekday && _nths.isEmpty) {
      return '第何週かをえらんでください';
    }
    return null;
  }

  void _setCycle(_Cycle cycle) {
    if (cycle == _cycle) return;
    setState(() {
      _cycle = cycle;
      _interval = cycle == _Cycle.afterDone ? 14 : 1;
    });
  }

  void _save() {
    final problem = _problem;
    if (problem != null) {
      showNotice(context, problem);
      return;
    }
    final store = context.readStore;
    store.saveChore(
      Chore(
        id: widget.chore?.id ?? store.newChoreId(),
        name: _name.text.trim(),
        genreId: _genreId,
        start: _start,
        repeat: _repeat,
        dueMinutes: _dueMinutes,
        assigneeId: _assigneeId,
        memo: _memo.text.trim(),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'この家事を削除しますか？',
      message: 'これからの予定には出なくなります。これまでにやった記録は「がんばり」に残ります。',
      action: '削除',
      destructive: true,
    );
    if (!ok || !mounted) return;
    context.readStore.deleteChore(widget.chore!.id);
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _start = dateOnly(picked));
  }

  Future<void> _pickTime() async {
    final current = _dueMinutes ?? 8 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: '何時までに',
    );
    if (picked != null) {
      setState(() => _dueMinutes = picked.hour * 60 + picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew ? '家事を追加' : '家事を編集',
          style: theme.textTheme.titleLarge,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(76, 40)),
              onPressed: _save,
              child: const Text('保存'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          TextField(
            controller: _name,
            autofocus: _isNew && widget.template == null,
            textInputAction: TextInputAction.done,
            style: theme.textTheme.titleMedium,
            decoration: const InputDecoration(
              labelText: '家事の名前',
              hintText: '例: 洗濯槽の掃除',
            ),
          ),
          const SectionLabel('ジャンル'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in store.visibleGenres)
                ChoiceChip(
                  avatar: Icon(
                    iconForGenre(g),
                    size: 18,
                    color: Color(g.color),
                  ),
                  label: Text(g.name),
                  selected: _genreId == g.id,
                  onSelected: (_) => setState(() => _genreId = g.id),
                ),
            ],
          ),
          const SectionLabel('担当'),
          MemberPicker(
            members: store.members,
            selectedId: _assigneeId,
            allowAnyone: true,
            anyoneSelected: _assigneeId == null,
            onAnyone: () => setState(() => _assigneeId = null),
            onSelected: (m) => setState(() => _assigneeId = m.id),
          ),
          const SectionLabel('くり返し'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _Cycle.values)
                ChoiceChip(
                  label: Text(_cycleLabels[c]!),
                  selected: _cycle == c,
                  onSelected: (_) => _setCycle(c),
                ),
            ],
          ),
          if (_cycle != _Cycle.once) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _cycleDetails(theme),
                ),
              ),
            ),
          ],
          const SectionLabel('いつ'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _ValueRow(
                  icon: Icons.event_rounded,
                  label: switch (_cycle) {
                    _Cycle.once => '期限の日',
                    _Cycle.afterDone => '最初の予定日',
                    _Cycle.yearly => '日付',
                    _ => 'はじめる日',
                  },
                  value: '${_start.year}年 ${formatDateLong(_start)}',
                  onTap: _pickDate,
                ),
                const Divider(indent: 16, endIndent: 16),
                _ValueRow(
                  icon: Icons.schedule_rounded,
                  label: '時刻',
                  value: _dueMinutes == null
                      ? 'きめない'
                      : '${formatMinutes(_dueMinutes!)}まで',
                  muted: _dueMinutes == null,
                  onTap: _pickTime,
                  action: _dueMinutes == null
                      ? null
                      : IconButton(
                          tooltip: '時刻をきめない',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _dueMinutes = null),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Preview(
            repeat: _repeat,
            start: _start,
            lastTouched: _isNew ? null : store.lastTouched(widget.chore!.id),
            today: store.today,
          ),
          const SectionLabel('メモ'),
          TextField(
            controller: _memo,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '例: 洗剤は洗面台の下'),
          ),
          if (!_isNew) ...[
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                label: const Text('この家事を削除'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// えらんだくり返しに合わせた、こまかい設定。
  List<Widget> _cycleDetails(ThemeData theme) {
    Widget every(String unit, {int max = 99}) => NumberStepper(
      value: _interval,
      max: max,
      suffix: unit,
      onChanged: (v) => setState(() => _interval = v),
    );

    Widget weekdayRow(Set<int> selected, void Function(int) onTap) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var w = 1; w <= 7; w++)
          _RoundToggle(
            label: weekdayLabels[w - 1],
            selected: selected.contains(w),
            onTap: () => setState(() => onTap(w)),
          ),
      ],
    );

    Widget hint(String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(text, style: theme.textTheme.bodySmall),
    );

    switch (_cycle) {
      case _Cycle.once:
        return const [];
      case _Cycle.daily:
        return [every('日ごと')];
      case _Cycle.weekly:
        return [
          every('週ごと', max: 52),
          const SizedBox(height: 14),
          weekdayRow(_weekdays, (w) {
            _weekdays.contains(w) ? _weekdays.remove(w) : _weekdays.add(w);
          }),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('平日'),
                onPressed: () =>
                    setState(() => _weekdays = {...Repeat.weekdaysOnly}),
              ),
              ActionChip(
                label: const Text('土日'),
                onPressed: () => setState(() => _weekdays = {6, 7}),
              ),
            ],
          ),
        ];
      case _Cycle.monthly:
        return [
          every('か月ごと', max: 24),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('日にちで')),
              ButtonSegment(value: true, label: Text('第○曜日で')),
            ],
            selected: {_monthlyByWeekday},
            onSelectionChanged: (s) =>
                setState(() => _monthlyByWeekday = s.first),
          ),
          const SizedBox(height: 14),
          if (!_monthlyByWeekday) ...[
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('月末'),
                  selected: _monthDay == 0,
                  onSelected: (_) => setState(
                    () => _monthDay = _monthDay == 0 ? _start.day : 0,
                  ),
                ),
                if (_monthDay != 0)
                  NumberStepper(
                    value: _monthDay,
                    max: 31,
                    suffix: '日',
                    onChanged: (v) => setState(() => _monthDay = v),
                  ),
              ],
            ),
            if (_monthDay > 28) hint('$_monthDay日がない月は、月末の日になります。'),
          ] else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final n in const [1, 2, 3, 4, Repeat.lastWeek])
                  ChoiceChip(
                    label: Text(n == Repeat.lastWeek ? '最終' : '第$n'),
                    selected: _nths.contains(n),
                    onSelected: (_) => setState(() {
                      _nths.contains(n) ? _nths.remove(n) : _nths.add(n);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            weekdayRow({_weekday}, (w) => _weekday = w),
          ],
        ];
      case _Cycle.yearly:
        return [every('年ごと', max: 10), hint('下の「日付」と同じ月日にくり返します。')];
      case _Cycle.afterDone:
        return [
          NumberStepper(
            value: _interval,
            prefix: 'やった日から',
            suffix: '日後',
            onChanged: (v) => setState(() => _interval = v),
          ),
          hint('遅れてやっても、次回はやった日から数え直します。掃除のように「間をあけすぎない」ことが大事な家事に向いています。'),
        ];
    }
  }
}

/// 曜日などの丸い切り替えボタン。
class _RoundToggle extends StatelessWidget {
  const _RoundToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label曜日',
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primary : scheme.surface,
        shape: CircleBorder(
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// この設定だといつ予定に出るかの確認。
class _Preview extends StatelessWidget {
  const _Preview({
    required this.repeat,
    required this.start,
    required this.lastTouched,
    required this.today,
  });

  final Repeat repeat;
  final DateTime start;
  final DateTime? lastTouched;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final upcoming = <DateTime>[];
    if (repeat.isValid) {
      var from = today;
      for (var i = 0; i < 4; i++) {
        final next = repeat.nextOnOrAfter(from, start, lastDone: lastTouched);
        if (next == null) break;
        upcoming.add(next);
        if (repeat.type == RepeatType.afterDone ||
            repeat.type == RepeatType.none) {
          break;
        }
        from = addDays(next, 1);
      }
    }

    final String detail;
    if (!repeat.isValid) {
      detail = '曜日や週をえらぶと、予定日がここに出ます。';
    } else if (repeat.type == RepeatType.none) {
      detail = start.isBefore(today)
          ? '${formatDate(start)}が期限でした。保存すると「やり忘れ」に出ます。'
          : '${formatDate(start)}の予定に出ます。';
    } else if (repeat.type == RepeatType.afterDone) {
      final next = repeat.nextAfterDone(start, lastTouched);
      detail = '次の予定: ${formatDate(next)}。そのあとは、やった日から数えます。';
    } else if (upcoming.isEmpty) {
      detail = '次の予定はありません。';
    } else {
      detail = '次の予定: ${upcoming.map(formatDate).join('、')}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_repeat_rounded,
            size: 20,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repeat.describe(start),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 「ラベル ……… 値」の行。せまい画面では値が折り返す。
class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.muted = false,
    this.action,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool muted;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, action == null ? 16 : 6, 8),
          child: Row(
            children: [
              Icon(icon, color: scheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Text(label, style: theme.textTheme.bodyLarge),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: muted ? scheme.onSurfaceVariant : null,
                  ),
                ),
              ),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}

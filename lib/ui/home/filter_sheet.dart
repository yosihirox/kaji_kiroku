import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/dates.dart';
import '../../domain/home_filter.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';

/// ホームの「絞り込み」シート。「絞り込み検索」で新しい条件を返す。
/// シートの外をタップして閉じたときは null（条件は変えない）。
Future<HomeFilter?> showFilterSheet(BuildContext context, HomeFilter current) {
  return showModalBottomSheet<HomeFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FilterSheet(initial: current),
  );
}

/// 期間のえらび方。
enum _Period { none, today, tomorrow, thisWeek, lastWeek, custom }

const _periodLabels = {
  _Period.none: '指定なし',
  _Period.today: '今日',
  _Period.tomorrow: '明日',
  _Period.thisWeek: '今週',
  _Period.lastWeek: '先週',
  _Period.custom: '日付で指定',
};

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final HomeFilter initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late HomeFilter _f = widget.initial;
  late final _keyword = TextEditingController(text: widget.initial.keyword);
  bool _customPeriod = false;

  /// 「リセットしました」を出している間は true。
  bool _justReset = false;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _customPeriod =
        widget.initial.hasPeriod && _presetOf(widget.initial) == null;
  }

  @override
  void dispose() {
    _keyword.dispose();
    _resetTimer?.cancel();
    super.dispose();
  }

  DateTime get _today => context.readStore.today;

  (DateTime, DateTime)? _rangeOf(_Period p) {
    final t = _today;
    final monday = startOfWeek(t);
    return switch (p) {
      _Period.today => (t, t),
      _Period.tomorrow => (addDays(t, 1), addDays(t, 1)),
      _Period.thisWeek => (monday, addDays(monday, 6)),
      _Period.lastWeek => (addDays(monday, -7), addDays(monday, -1)),
      _Period.none || _Period.custom => null,
    };
  }

  /// いまの期間がどのえらび方に当たるか。どれでもなければ null。
  _Period? _presetOf(HomeFilter f) {
    if (!f.hasPeriod) return _Period.none;
    for (final p in [
      _Period.today,
      _Period.tomorrow,
      _Period.thisWeek,
      _Period.lastWeek,
    ]) {
      final r = _rangeOf(p)!;
      if (isSameDay(r.$1, f.from!) && isSameDay(r.$2, f.to!)) return p;
    }
    return null;
  }

  _Period get _period =>
      _customPeriod ? _Period.custom : (_presetOf(_f) ?? _Period.custom);

  Future<void> _pickRange() async {
    final t = _today;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(t.year - 3, 1, 1),
      lastDate: DateTime(t.year + 1, 12, 31),
      currentDate: t,
      initialDateRange: _f.hasPeriod
          ? DateTimeRange(start: _f.from!, end: _f.to!)
          : DateTimeRange(start: t, end: addDays(t, 6)),
      helpText: '期間をえらぶ',
      saveText: '決定',
    );
    if (picked == null || !mounted) return;
    var end = dateOnly(picked.end);
    final start = dateOnly(picked.start);
    if (daysBetween(start, end) >= maxFilterDays) {
      end = addDays(start, maxFilterDays - 1);
    }
    setState(() {
      _customPeriod = true;
      _f = _f.copyWith(from: start, to: end);
    });
  }

  void _setPeriod(_Period p) {
    if (p == _Period.custom) {
      _pickRange();
      return;
    }
    final r = _rangeOf(p);
    setState(() {
      _customPeriod = false;
      _f = r == null
          ? _f.copyWith(clearPeriod: true)
          : _f.copyWith(from: r.$1, to: r.$2);
    });
  }

  void _reset() {
    FocusScope.of(context).unfocus();
    _resetTimer?.cancel();
    setState(() {
      _f = HomeFilter.none;
      _keyword.clear();
      _customPeriod = false;
      _justReset = true;
    });
    _resetTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _justReset = false);
    });
  }

  void _apply() {
    Navigator.pop(context, _f.copyWith(keyword: _keyword.text.trim()));
  }

  Set<String> _toggle(Set<String> set, String id, bool on) =>
      on ? {...set, id} : ({...set}..remove(id));

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final draft = _f.copyWith(keyword: _keyword.text);
    final count = draft.conditionCount;

    final genres = store.visibleGenres;
    final chores = store.chores
        .where((c) => _f.genreIds.isEmpty || _f.genreIds.contains(c.genreId))
        .toList();

    Widget section(String title, Widget child, {String? hint}) => Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );

    Widget chips(List<Widget> children) =>
        Wrap(spacing: 8, runSpacing: 8, children: children);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('絞り込み', style: theme.textTheme.titleLarge),
                ),
                if (count > 0)
                  Text(
                    '$count件の条件',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                IconButton(
                  tooltip: 'とじる',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              children: [
                section(
                  'キーワード',
                  TextField(
                    controller: _keyword,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      hintText: '家事の名前・メモ・ジャンルから探す',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _keyword.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'キーワードを消す',
                              onPressed: () => setState(() => _keyword.clear()),
                              icon: const Icon(Icons.close_rounded, size: 20),
                            ),
                    ),
                  ),
                ),
                section(
                  '完了・未完了',
                  chips([
                    for (final s in StatusFilter.values)
                      ChoiceChip(
                        label: Text(statusFilterLabels[s]!),
                        selected: _f.status == s,
                        onSelected: (_) =>
                            setState(() => _f = _f.copyWith(status: s)),
                      ),
                  ]),
                ),
                section(
                  '日付（期間）',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      chips([
                        for (final p in _Period.values)
                          ChoiceChip(
                            avatar: p == _Period.custom
                                ? const Icon(Icons.date_range_rounded, size: 18)
                                : null,
                            label: Text(_periodLabels[p]!),
                            selected: _period == p,
                            onSelected: (_) => _setPeriod(p),
                          ),
                      ]),
                      if (_f.hasPeriod) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _pickRange,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event_rounded,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    periodLabel(_f),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  hint: '指定なしのときは、やり忘れと今日から1週間を出します。',
                ),
                section(
                  'ジャンル',
                  chips([
                    for (final g in genres)
                      FilterChip(
                        avatar: Icon(iconForGenre(g), size: 18),
                        label: Text(g.name),
                        selected: _f.genreIds.contains(g.id),
                        onSelected: (on) => setState(() {
                          final ids = _toggle(_f.genreIds, g.id, on);
                          // えらんだジャンルに入らない家事名は外す。
                          final keep = ids.isEmpty
                              ? _f.choreIds
                              : {
                                  for (final id in _f.choreIds)
                                    if (ids.contains(
                                      store.choreById(id)?.genreId,
                                    ))
                                      id,
                                };
                          _f = _f.copyWith(genreIds: ids, choreIds: keep);
                        }),
                      ),
                  ]),
                ),
                section(
                  '家事名',
                  chores.isEmpty
                      ? Text('えらべる家事がありません。', style: theme.textTheme.bodySmall)
                      : chips([
                          for (final c in chores)
                            FilterChip(
                              label: Text(c.name),
                              selected: _f.choreIds.contains(c.id),
                              onSelected: (on) => setState(
                                () => _f = _f.copyWith(
                                  choreIds: _toggle(_f.choreIds, c.id, on),
                                ),
                              ),
                            ),
                        ]),
                  hint: _f.genreIds.isEmpty ? null : 'えらんだジャンルの家事だけを出しています。',
                ),
                section(
                  '担当',
                  chips([
                    FilterChip(
                      avatar: const MemberAvatar(null, size: 24),
                      label: const Text('だれでも'),
                      selected: _f.assigneeIds.contains(anyoneId),
                      onSelected: (on) => setState(
                        () => _f = _f.copyWith(
                          assigneeIds: _toggle(_f.assigneeIds, anyoneId, on),
                        ),
                      ),
                    ),
                    for (final m in store.members)
                      FilterChip(
                        avatar: MemberAvatar(m, size: 24),
                        label: Text(m.name),
                        selected: _f.assigneeIds.contains(m.id),
                        onSelected: (on) => setState(
                          () => _f = _f.copyWith(
                            assigneeIds: _toggle(_f.assigneeIds, m.id, on),
                          ),
                        ),
                      ),
                  ]),
                ),
                section(
                  'やった人',
                  chips([
                    for (final m in store.members)
                      FilterChip(
                        avatar: MemberAvatar(m, size: 24),
                        label: Text(m.name),
                        selected: _f.doneByIds.contains(m.id),
                        onSelected: (on) => setState(
                          () => _f = _f.copyWith(
                            doneByIds: _toggle(_f.doneByIds, m.id, on),
                          ),
                        ),
                      ),
                  ]),
                  hint: 'えらぶと、その人が完了した家事だけになります。',
                ),
                section(
                  '時刻',
                  chips([
                    for (final t in TimeFilter.values)
                      ChoiceChip(
                        label: Text(timeFilterLabels[t]!),
                        selected: _f.time == t,
                        onSelected: (_) =>
                            setState(() => _f = _f.copyWith(time: t)),
                      ),
                  ]),
                  hint: '「何時までに」を決めている家事かどうか。',
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.bottomSheetTheme.backgroundColor ?? scheme.surface,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: _justReset
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '条件をリセットしました',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: scheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.error,
                              side: BorderSide(
                                color: count == 0
                                    ? scheme.outlineVariant
                                    : scheme.error.withValues(alpha: 0.6),
                              ),
                              minimumSize: const Size(0, 52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            onPressed: count == 0 ? null : _reset,
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 20,
                            ),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('検索条件をリセット'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            onPressed: _apply,
                            icon: const Icon(Icons.search_rounded, size: 20),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('絞り込み検索'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「11/10（月）〜11/16（日）」のような期間の書き方。
String periodLabel(HomeFilter f) {
  if (!f.hasPeriod) return '';
  final days = f.periodDays;
  final a = days.first;
  final b = days.last;
  return isSameDay(a, b) ? formatDate(a) : '${formatDate(a)}〜${formatDate(b)}';
}

/// 絞り込み中の条件を短くまとめる（ホームの帯に出す）。
List<String> describeFilter(
  HomeFilter f, {
  required String Function(String genreId) genreName,
  required String? Function(String choreId) choreName,
  required String? Function(String memberId) memberName,
}) {
  String names(Iterable<String?> list) =>
      list.whereType<String>().take(3).join('・') +
      (list.length > 3 ? ' ほか' : '');
  return [
    if (f.keyword.trim().isNotEmpty) '「${f.keyword.trim()}」',
    if (f.status != StatusFilter.all) statusFilterLabels[f.status]!,
    if (f.hasPeriod) periodLabel(f),
    if (f.genreIds.isNotEmpty) names(f.genreIds.map(genreName)),
    if (f.choreIds.isNotEmpty) names(f.choreIds.map(choreName)),
    if (f.assigneeIds.isNotEmpty)
      '担当: ${names(f.assigneeIds.map((id) => id == anyoneId ? 'だれでも' : memberName(id)))}',
    if (f.doneByIds.isNotEmpty) 'やった人: ${names(f.doneByIds.map(memberName))}',
    if (f.time != TimeFilter.all) timeFilterLabels[f.time]!,
  ];
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/agenda.dart';
import '../../domain/dates.dart';
import '../../domain/home_filter.dart';
import '../../domain/report.dart';
import '../chores/add_chore_sheet.dart';
import '../messages/messages.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';
import 'filter_sheet.dart';
import 'occurrence_tile.dart';
import 'quick_record_sheet.dart';

/// ホーム: やり忘れ → 今日 → 明日 … と1週間分の「やること」を並べる。
///
/// 右下の「絞り込み」で条件をえらぶと、合うものだけを出す。条件は保存しないので、
/// アプリを閉じると何も絞り込んでいない状態に戻る。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _onlyMine = false;

  /// カレンダーでえらんだ日。null なら今日からの1週間を出す。
  DateTime? _date;

  /// 絞り込みの条件。
  HomeFilter _filter = HomeFilter.none;

  Future<void> _pickDate(DateTime today) async {
    final picked = await showDayPicker(context, initial: _date ?? today);
    if (picked == null || !mounted) return;
    setState(() {
      _date = isSameDay(picked, today) ? null : picked;
      // カレンダーで日をえらんだら、絞り込みの期間はやめてその日を出す。
      if (_filter.hasPeriod) _filter = _filter.copyWith(clearPeriod: true);
    });
  }

  Future<void> _openFilter() async {
    final result = await showFilterSheet(context, _filter);
    if (result == null || !mounted) return;
    setState(() {
      _filter = result;
      if (result.hasPeriod) _date = null;
    });
  }

  /// その日（やり忘れ）のまだの分を、まとめて完了にする。
  Future<void> _completeAll(String label, List<Occurrence> items) async {
    final pending = items.where((o) => o.isPending).toList();
    if (pending.isEmpty) return;
    final store = context.readStore;
    final ok = await confirm(
      context,
      title: '$labelの${pending.length}件を、まとめて完了にしますか？',
      message:
          '${store.currentMember?.name ?? 'いま使っている人'}さんが'
          '今日（${formatDate(store.today)}）やったことになります。',
      action: '一括完了',
    );
    if (!ok || !mounted) return;
    HapticFeedback.lightImpact();
    final records = store.completeAll(pending);
    showNotice(
      context,
      '${records.length}件を完了にしました。おつかれさま！',
      actionLabel: '取り消す',
      onAction: () => store.undoRecords(records.map((r) => r.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final agenda = store.agenda;
    final me = store.currentMemberId;
    final filter = _filter;
    final filtering = filter.isActive;

    bool visible(Occurrence o) =>
        (!_onlyMine || isMine(o.chore, me) || o.record?.doneById == me) &&
        filter.matches(
          o,
          today: agenda.today,
          genreName: (id) => store.genreById(id).name,
        );
    AgendaDay only(AgendaDay d) =>
        AgendaDay(d.date, d.items.where(visible).toList());

    final overdue = agenda.overdue.where(visible).toList();
    final days = [for (final d in agenda.days) only(d)];
    final today = days.first;
    final hasChores = store.chores.isNotEmpty;
    final picked = filter.hasPeriod ? null : _date;
    final pickedDay = picked == null ? null : only(store.dayItems(picked));

    void addOn(DateTime date) => showAddChoreSheet(context, date: date);

    /// 1日分の見出しとカード。絞り込み中は、合うものがない日は出さない。
    List<Widget> daySection(
      AgendaDay day, {
      required String title,
      String? subtitle,
      bool emphasized = false,
    }) {
      if (filtering && day.items.isEmpty) return const [];
      final pending = day.pendingCount;
      return [
        _DayHeader(
          title: title,
          subtitle: subtitle,
          emphasized: emphasized,
          compact: day.items.isEmpty,
          onAdd: () => addOn(day.date),
          trailing: day.items.isEmpty
              ? '予定なし'
              : pending == 0
              ? 'ぜんぶ完了'
              : 'のこり$pending件',
          onCompleteAll: pending == 0
              ? null
              : () => _completeAll(
                  relativeDayLabel(day.date, agenda.today),
                  day.items,
                ),
        ),
        _ItemsCard(items: day.items, onAdd: () => addOn(day.date)),
      ];
    }

    final List<Widget> lists;
    if (filter.hasPeriod) {
      final sections = [
        for (final d in filter.periodDays)
          ...daySection(
            only(store.dayForFilter(d)),
            title: relativeDayLabel(d, agenda.today),
            subtitle: daysBetween(agenda.today, d).abs() <= 2
                ? formatDate(d)
                : null,
            emphasized: isSameDay(d, agenda.today),
          ),
      ];
      lists = sections.isEmpty ? [const _NoMatchCard()] : sections;
    } else if (pickedDay != null) {
      lists = [
        ...daySection(
          pickedDay,
          title: relativeDayLabel(pickedDay.date, agenda.today),
          subtitle: formatDate(pickedDay.date),
          emphasized: true,
        ),
        if (filtering && pickedDay.items.isEmpty) const _NoMatchCard(),
      ];
    } else if (!filtering &&
        !hasChores &&
        today.items.isEmpty &&
        overdue.isEmpty) {
      lists = [_FirstStepsCard(onAdd: () => showAddChoreSheet(context))];
    } else {
      final sections = [
        if (overdue.isNotEmpty) ...[
          _DayHeader(
            title: 'やり忘れ',
            icon: Icons.notification_important_rounded,
            color: scheme.error,
            trailing: '${overdue.length}件',
            onCompleteAll: () => _completeAll('やり忘れ', overdue),
          ),
          _ItemsCard(
            items: overdue,
            borderColor: scheme.error.withValues(alpha: 0.45),
          ),
        ],
        ...daySection(
          today,
          title: '今日',
          subtitle: formatDate(today.date),
          emphasized: true,
        ),
        for (final day in days.skip(1))
          ...daySection(
            day,
            title: relativeDayLabel(day.date, agenda.today),
            subtitle: daysBetween(agenda.today, day.date) <= 2
                ? formatDate(day.date)
                : null,
          ),
      ];
      lists = sections.isEmpty ? [const _NoMatchCard()] : sections;
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 176),
          children: [
            _Header(
              date: picked ?? agenda.today,
              onPickDate: () => _pickDate(agenda.today),
            ),
            const SizedBox(height: 14),
            if (store.showHomeCheer) ...[
              const _CheerCard(),
              const SizedBox(height: 12),
            ],
            if (filtering)
              _FilterBanner(
                filter: filter,
                onEdit: _openFilter,
                onClear: () => setState(() => _filter = HomeFilter.none),
              ),
            if (pickedDay == null && !filter.hasPeriod) ...[
              if (!filtering) ...[
                _SummaryCard(today: today, overdueCount: overdue.length),
                const SizedBox(height: 12),
              ],
            ] else if (pickedDay != null)
              _PastDayBanner(
                date: pickedDay.date,
                today: agenda.today,
                onBack: () => setState(() => _date = null),
              ),
            // せまい画面や大きい文字では、2段に折り返す。
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChoiceChip(
                      label: const Text('みんな'),
                      selected: !_onlyMine,
                      onSelected: (_) => setState(() => _onlyMine = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('自分の担当'),
                      selected: _onlyMine,
                      onSelected: (_) => setState(() => _onlyMine = true),
                    ),
                  ],
                ),
                Wrap(
                  children: [
                    TextButton.icon(
                      onPressed: () => showQuickRecordSheet(context),
                      icon: const Icon(Icons.bolt_rounded, size: 20),
                      label: const Text('やったことを記録'),
                    ),
                    TextButton.icon(
                      onPressed: () => showAddChoreSheet(context),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('家事を追加'),
                    ),
                  ],
                ),
              ],
            ),
            ...lists,
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'home-filter',
            onPressed: _openFilter,
            backgroundColor: filtering
                ? scheme.tertiaryContainer
                : scheme.secondaryContainer,
            foregroundColor: filtering
                ? scheme.onTertiaryContainer
                : scheme.onSecondaryContainer,
            icon: Badge(
              isLabelVisible: filtering,
              label: Text('${filter.conditionCount}'),
              child: const Icon(Icons.search_rounded),
            ),
            label: const Text('絞り込み'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'home-add',
            onPressed: () => showAddChoreSheet(context, date: _date),
            icon: const Icon(Icons.add_rounded),
            label: const Text('家事を追加'),
          ),
        ],
      ),
    );
  }
}

/// 絞り込み中であることと、その条件。
class _FilterBanner extends StatelessWidget {
  const _FilterBanner({
    required this.filter,
    required this.onEdit,
    required this.onClear,
  });
  final HomeFilter filter;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final parts = describeFilter(
      filter,
      genreName: (id) => store.genreById(id).name,
      choreName: (id) => store.choreById(id)?.name,
      memberName: (id) => store.memberById(id)?.name,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          child: Row(
            children: [
              Icon(Icons.filter_alt_rounded, color: scheme.onTertiaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '絞り込み中',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                    Text(
                      parts.join('  ・  '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onTertiaryContainer,
                ),
                onPressed: onClear,
                child: const Text('解除'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 絞り込んだ結果、何もなかったとき。
class _NoMatchCard extends StatelessWidget {
  const _NoMatchCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 16),
      child: Card(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: '条件に合う家事はありません',
          message: '右下の「絞り込み」から条件を変えてみてください。',
        ),
      ),
    );
  }
}

/// 日付と、この端末を使っている人の切り替え。日付をタップするとカレンダーが開く。
class _Header extends StatelessWidget {
  const _Header({required this.date, required this.onPickDate});
  final DateTime date;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final me = store.currentMember;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: 'カレンダーで日付をえらぶ',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onPickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 28,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            formatDateLong(date),
                            style: theme.textTheme.headlineMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Tooltip(
          message: '使う人を切り替える',
          child: Material(
            color: scheme.surface,
            shape: StadiumBorder(
              side: BorderSide(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _switchMember(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 5, 10, 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MemberAvatar(me, size: 30),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Text(
                        me?.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _switchMember(BuildContext context) {
    showAppSheet<void>(
      context,
      builder: (context) {
        final store = context.store;
        final theme = Theme.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('いま使っているのは？', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '丸をタップして完了したとき、この人がやったことになります。',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final m in store.members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: MemberAvatar(m, size: 40),
                title: Text(m.name, style: theme.textTheme.titleMedium),
                trailing: m.id == store.currentMemberId
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: theme.colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  store.setCurrentMember(m.id);
                  Navigator.pop(context);
                },
              ),
          ],
        );
      },
    );
  }
}

/// 今日のすすみ具合。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.today, required this.overdueCount});
  final AgendaDay today;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final planned = today.items.where((o) => !o.isSkipped).toList();
    final total = planned.length;
    final done = planned.where((o) => o.isDone).length;
    final allDone = total > 0 && done == total;

    final background = allDone
        ? colors.celebrateContainer
        : scheme.primaryContainer;
    final foreground = allDone ? colors.onCelebrate : scheme.onPrimaryContainer;
    final accent = allDone ? colors.celebrate : scheme.primary;

    final String title;
    final String subtitle;
    if (total == 0) {
      title = '今日の予定はありません';
      subtitle = overdueCount > 0 ? 'やり忘れを片付けるチャンスです。' : 'ゆっくりすごしましょう。';
    } else if (allDone) {
      title = '今日のぶんは、ぜんぶ完了！';
      subtitle = '$total件おわりました。おつかれさまでした。';
    } else {
      title = 'のこり ${total - done}件';
      subtitle = done == 0 ? '今日は$total件あります。' : '$total件のうち、$done件おわりました。';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: total == 0 ? 0 : done / total),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    color: accent,
                    backgroundColor: foreground.withValues(alpha: 0.12),
                  ),
                ),
                Center(
                  child: allDone
                      ? Icon(Icons.celebration_rounded, color: accent, size: 28)
                      : Text(
                          total == 0 ? '0' : '$done/$total',
                          textScaler: TextScaler.noScaling,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground.withValues(alpha: 0.85),
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

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
    this.color,
    this.emphasized = false,
    this.compact = false,
    this.onAdd,
    this.onCompleteAll,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final IconData? icon;
  final Color? color;
  final bool emphasized;

  /// 予定のない日は、行間を詰めて控えめに出す。
  final bool compact;

  /// 日付の左の「＋」（その日を指定して家事を追加）。
  final VoidCallback? onAdd;

  /// 「のこり○件」の右の「一括完了」。
  final VoidCallback? onCompleteAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleColor =
        color ?? (compact ? scheme.onSurfaceVariant : scheme.onSurface);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        onAdd == null ? 6 : 0,
        compact ? 12 : 18,
        2,
        compact ? 4 : 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onAdd != null) ...[
            IconButton.filledTonal(
              tooltip: 'この日に家事を追加',
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
            ),
            const SizedBox(width: 4),
          ],
          if (icon != null) ...[
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(
                text: title,
                style:
                    (emphasized
                            ? theme.textTheme.titleLarge
                            : theme.textTheme.titleMedium)
                        ?.copyWith(color: titleColor),
                children: [
                  if (subtitle != null)
                    TextSpan(
                      text: '  $subtitle',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color ?? scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (onCompleteAll != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'まだの家事をまとめて完了にする',
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 36),
                  foregroundColor: color ?? scheme.primary,
                  side: BorderSide(
                    color: (color ?? scheme.primary).withValues(alpha: 0.5),
                  ),
                  textStyle: theme.textTheme.labelMedium,
                ),
                onPressed: onCompleteAll,
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text('一括完了'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 1日分のやることをまとめたカード。[onAdd] があれば、いちばん下に「家事を追加」。
class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items, this.borderColor, this.onAdd});
  final List<Occurrence> items;
  final Color? borderColor;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor ?? scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(indent: 96),
            OccurrenceTile(items[i], key: ValueKey(items[i].key)),
          ],
          if (onAdd != null) ...[
            if (items.isNotEmpty) const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                child: TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('家事を追加'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// まだ家事を1つも登録していないときの案内。
class _FirstStepsCard extends StatelessWidget {
  const _FirstStepsCard({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: EmptyState(
          icon: Icons.checklist_rounded,
          title: 'まずは家事を登録しましょう',
          message:
              '「洗濯槽の掃除を毎月」「資源ゴミを第2・第4月曜」のように登録すると、'
              'やる日にここへ出てきます。',
          actions: [
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('家事を追加'),
            ),
          ],
        ),
      ),
    );
  }
}

/// カレンダーで1日えらぶ。「決定」で決まり、外をタップすると何も変えずに閉じる。
Future<DateTime?> showDayPicker(
  BuildContext context, {
  required DateTime initial,
}) {
  final today = context.readStore.today;
  final first = DateTime(today.year - 3, 1, 1);
  final last = DateTime(today.year + 1, 12, 31);
  var selected = initial.isBefore(first) || initial.isAfter(last)
      ? today
      : initial;
  return showDialog<DateTime>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('見たい日をえらぶ', style: theme.textTheme.titleMedium),
                SizedBox(
                  width: 320,
                  child: CalendarDatePicker(
                    initialDate: selected,
                    firstDate: first,
                    lastDate: last,
                    currentDate: today,
                    onDateChanged: (d) => selected = d,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, selected),
                      child: const Text('決定'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 今日以外の日を見ているときの案内と「今日に戻る」。
class _PastDayBanner extends StatelessWidget {
  const _PastDayBanner({
    required this.date,
    required this.today,
    required this.onBack,
  });
  final DateTime date;
  final DateTime today;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${formatDate(date)}の家事を見ています',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
          TextButton(onPressed: onBack, child: const Text('今日に戻る')),
        ],
      ),
    );
  }
}

/// ホームの「がんばり」枠: 今日家事をした人、この1週間で1番がんばった人、メッセージ。
class _CheerCard extends StatelessWidget {
  const _CheerCard();

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final today = store.todayDoneCounts;
    final week = store.weekDoneCounts;
    final top = week.isEmpty
        ? const <MemberCount>[]
        : week.where((c) => c.count == week.first.count).toList();

    Widget countRow(MemberCount c, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          MemberAvatar(c.member, size: strong ? 28 : 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${c.member.name}さん',
              style: strong
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyLarge,
            ),
          ),
          Text(
            '${c.count}件',
            style:
                (strong
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.labelLarge)
                    ?.copyWith(color: strong ? colors.celebrate : null),
          ),
        ],
      ),
    );

    final expanded = store.homeCheerExpanded;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 見出しの行をタップすると、開いたり折りたたんだりできる。
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              onTap: () => store.setHomeCheerExpanded(!expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.volunteer_activism_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('がんばり', style: theme.textTheme.titleMedium),
                    ),
                    if (!expanded && today.isNotEmpty) ...[
                      for (final c in today.take(4))
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: MemberAvatar(c.member, size: 22),
                        ),
                      const SizedBox(width: 6),
                    ],
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '今日',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (today.isEmpty)
                          Text(
                            '今日はまだ記録がありません。',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        else
                          for (final c in today) countRow(c),
                        if (top.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'この1週間で1番家事をがんばった人',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          for (final c in top) countRow(c, strong: true),
                          const SizedBox(height: 4),
                          Text(
                            'がんばりました！おつかれさま！ありがとう！',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.celebrate,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            onPressed: () => showSendMessageSheet(context),
                            icon: const Icon(Icons.mail_rounded, size: 18),
                            label: const Text('メッセージを送る'),
                          ),
                        ),
                        if (store.recentMessages.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const RecentMessages(),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

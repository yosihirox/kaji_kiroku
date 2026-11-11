import 'package:flutter/material.dart';

import '../../domain/agenda.dart';
import '../../domain/dates.dart';
import '../chores/add_chore_sheet.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';
import 'occurrence_tile.dart';
import 'quick_record_sheet.dart';

/// ホーム: やり忘れ → 今日 → 明日 … と1週間分の「やること」を並べる。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _onlyMine = false;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final agenda = store.agenda;
    final me = store.currentMemberId;

    bool visible(Occurrence o) =>
        !_onlyMine || isMine(o.chore, me) || o.record?.doneById == me;

    final overdue = agenda.overdue.where(visible).toList();
    final days = [
      for (final d in agenda.days)
        AgendaDay(d.date, d.items.where(visible).toList()),
    ];
    final today = days.first;
    final hasChores = store.chores.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
          children: [
            _Header(today: agenda.today),
            const SizedBox(height: 14),
            _SummaryCard(today: today, overdueCount: overdue.length),
            const SizedBox(height: 12),
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
                TextButton.icon(
                  onPressed: () => showQuickRecordSheet(context),
                  icon: const Icon(Icons.bolt_rounded, size: 20),
                  label: const Text('やったことを記録'),
                ),
              ],
            ),
            if (!hasChores && today.items.isEmpty && overdue.isEmpty)
              _FirstStepsCard(onAdd: () => showAddChoreSheet(context))
            else ...[
              if (overdue.isNotEmpty) ...[
                _DayHeader(
                  title: 'やり忘れ',
                  icon: Icons.notification_important_rounded,
                  color: scheme.error,
                  trailing: '${overdue.length}件',
                ),
                _ItemsCard(
                  items: overdue,
                  borderColor: scheme.error.withValues(alpha: 0.45),
                ),
              ],
              _DayHeader(
                title: '今日',
                subtitle: formatDate(today.date),
                emphasized: true,
                trailing: today.items.isEmpty
                    ? null
                    : today.pendingCount == 0
                    ? 'ぜんぶ完了'
                    : 'のこり${today.pendingCount}件',
              ),
              if (today.items.isEmpty)
                const _EmptyDayCard()
              else
                _ItemsCard(items: today.items),
              for (final day in days.skip(1)) ...[
                _DayHeader(
                  title: relativeDayLabel(day.date, agenda.today),
                  subtitle: daysBetween(agenda.today, day.date) <= 2
                      ? formatDate(day.date)
                      : null,
                  trailing: day.items.isEmpty ? '予定なし' : null,
                  compact: day.items.isEmpty,
                ),
                if (day.items.isNotEmpty) _ItemsCard(items: day.items),
              ],
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home-add',
        onPressed: () => showAddChoreSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('家事を追加'),
      ),
    );
  }
}

/// 日付と、この端末を使っている人の切り替え。
class _Header extends StatelessWidget {
  const _Header({required this.today});
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final me = store.currentMember;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDateLong(today),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text('今日のやること', style: theme.textTheme.headlineMedium),
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
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final IconData? icon;
  final Color? color;
  final bool emphasized;

  /// 予定のない日は、行間を詰めて控えめに出す。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleColor =
        color ?? (compact ? scheme.onSurfaceVariant : scheme.onSurface);
    return Padding(
      padding: EdgeInsets.fromLTRB(6, compact ? 14 : 22, 6, compact ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
          if (trailing != null) const SizedBox(width: 8),
          if (trailing != null)
            Text(
              trailing!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color ?? scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// 1日分のやることをまとめたカード。
class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items, this.borderColor});
  final List<Occurrence> items;
  final Color? borderColor;

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
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(indent: 56),
            OccurrenceTile(items[i], key: ValueKey(items[i].key)),
          ],
        ],
      ),
    );
  }
}

class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.spa_rounded, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '今日の予定はありません。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
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

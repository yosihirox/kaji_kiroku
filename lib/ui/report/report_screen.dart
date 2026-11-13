import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/report.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../messages/messages.dart';
import '../widgets/store_scope.dart';

/// がんばり: 誰がどの家事をどれだけやったかを見える化する。
///
/// 競争ではなく感謝のための画面なので、順位や勝ち負けは出さない。
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _week = true;

  /// 0 が今週（今月）、-1 がその前。
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final period = _week
        ? ReportPeriod.week(store.today, _offset)
        : ReportPeriod.month(store.today, _offset);
    final report = store.report(period);
    final messages = store.messagesBetween(period.from, period.to);
    final periodName = _offset == 0
        ? (_week ? '今週' : '今月')
        : _offset == -1
        ? (_week ? '先週' : '先月')
        : period.label;

    return Scaffold(
      appBar: AppBar(
        title: const ScreenTitle(
          'がんばり',
          icon: Icons.volunteer_activism_rounded,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
        children: [
          // せまい画面では、期間の切り替えが下の段に折り返す。
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: true, label: Text('週')),
                  ButtonSegment(value: false, label: Text('月')),
                ],
                selected: {_week},
                onSelectionChanged: (s) => setState(() {
                  _week = s.first;
                  _offset = 0;
                }),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _week ? '前の週' : '前の月',
                    onPressed: () => setState(() => _offset--),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 92),
                    child: Column(
                      children: [
                        Text(periodName, style: theme.textTheme.titleSmall),
                        if (_week || _offset >= -1)
                          Text(
                            _week
                                ? period.label
                                : '${period.from.month}/1〜${period.to.month}/${period.to.day}',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _week ? '次の週' : '次の月',
                    onPressed: _offset < 0
                        ? () => setState(() => _offset++)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (report.total == 0)
            Card(
              child: EmptyState(
                icon: Icons.volunteer_activism_rounded,
                title: '$periodNameの記録はまだありません',
                message: 'ホームで家事を完了すると、誰がどんな家事をしたかがここに集まります。',
              ),
            ),
          if (report.total > 0)
            _SummaryCard(report: report, periodName: periodName),
          if (messages.isNotEmpty) ...[
            SectionLabel('$periodNameのメッセージ'),
            MessageList(messages),
          ],
          if (report.total > 0) ...[
            const SizedBox(height: 12),
            for (final m in report.members)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MemberCard(report: m),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Text(
                '件数は、実際にやった人ごとに数えています。家事によって大変さはちがうので、数の多い少ないより「こんなこともやってくれていたんだ」を見つけるのに使ってください。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'report-message',
        onPressed: () => showSendMessageSheet(context),
        icon: const Icon(Icons.mail_rounded),
        label: const Text('メッセージを送る'),
      ),
    );
  }
}

/// 色の見分けに使う、メンバー（外れた人は null）の色。
Color _seriesColor(BuildContext context, Member? member) => member == null
    ? neutralSeriesColor(context)
    : memberColor(member.color, context);

/// 家族全体の件数と、日ごとの内訳。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report, required this.periodName});
  final Report report;
  final String periodName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = report.members.where((m) => m.count > 0).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$periodName、家族でやった家事',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${report.total}', style: theme.textTheme.displaySmall),
                const SizedBox(width: 4),
                Text('件', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            // だれがどれだけ、の割合
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < active.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: active[i].count,
                        child: ColoredBox(
                          color: _seriesColor(context, active[i].member),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final m in report.members)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _seriesColor(context, m.member),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${m.member?.name ?? '外れたメンバー'}  ${m.count}件',
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '日ごと',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _DailyChart(report: report),
          ],
        ),
      ),
    );
  }
}

/// 日ごとの件数を、人ごとに積み上げた棒グラフ。
class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.report});
  final Report report;

  static const _plotHeight = 96.0;
  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final max = report.maxDayTotal;
    final isWeek = report.period.isWeek;
    final order = [for (final m in report.members) m.member];

    return Column(
      children: [
        Row(
          children: [
            Text(
              '$max件',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: Divider(color: scheme.outlineVariant)),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: _plotHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in report.daily)
                Expanded(
                  child: _DayBar(
                    day: day,
                    order: order,
                    unit: max == 0 ? 0 : (_plotHeight - 8) / max,
                    gap: _gap,
                    maxWidth: isWeek ? 22 : 12,
                  ),
                ),
            ],
          ),
        ),
        Divider(color: scheme.outline),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final day in report.daily)
              Expanded(
                child: Text(
                  isWeek
                      ? weekdayLabels[day.date.weekday - 1]
                      : (day.date.day == 1 || day.date.day % 5 == 0)
                      ? '${day.date.day}'
                      : '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  textScaler: TextScaler.noScaling,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isSameDay(day.date, store.today)
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                    fontWeight: isSameDay(day.date, store.today)
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.order,
    required this.unit,
    required this.gap,
    required this.maxWidth,
  });

  final DayCount day;

  /// 積む順番（下から）。凡例と同じ並び。
  final List<Member?> order;

  /// 1件あたりの高さ。
  final double unit;
  final double gap;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final segments = [
      for (final m in order)
        if ((day.byMember[m?.id] ?? 0) > 0) (m, day.byMember[m?.id]!),
    ];
    if (segments.isEmpty) return const SizedBox.expand();
    final detail = segments
        .map((s) => '${s.$1?.name ?? '外れたメンバー'} ${s.$2}件')
        .join('、');

    return Tooltip(
      message: '${formatDate(day.date)}  $detail',
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: '${formatDate(day.date)} $detail',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 上から描くので、凡例の順（下から）を逆にして並べる。
            for (var i = segments.length - 1; i >= 0; i--) ...[
              Container(
                width: maxWidth,
                height: (segments[i].$2 * unit - (i > 0 ? gap : 0)).clamp(
                  2.0,
                  double.infinity,
                ),
                decoration: BoxDecoration(
                  color: _seriesColor(context, segments[i].$1),
                  borderRadius: i == segments.length - 1
                      ? const BorderRadius.vertical(top: Radius.circular(4))
                      : null,
                ),
              ),
              if (i > 0) SizedBox(height: gap),
            ],
          ],
        ),
      ),
    );
  }
}

/// 1人分のカード。件数、ジャンルの内訳、やった家事の一覧。
class _MemberCard extends StatefulWidget {
  const _MemberCard({required this.report});
  final MemberReport report;

  @override
  State<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<_MemberCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = widget.report;
    final name = r.member?.name ?? '外れたメンバー';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MemberAvatar(r.member, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium),
                      if (r.thanksReceived > 0)
                        Row(
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              size: 14,
                              color: scheme.tertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'スタンプ ${r.thanksReceived}こ',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Text('${r.count}', style: theme.textTheme.headlineMedium),
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('件', style: theme.textTheme.labelLarge),
                ),
              ],
            ),
            if (r.count == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                child: Text(
                  'この期間の記録はまだありません。',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in r.byGenre) _GenreCount(e.key, e.value),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'やったこと',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in r.byChore)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: c.name),
                            if (c.count > 1)
                              TextSpan(
                                text: '  ×${c.count}',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                  ),
                  label: Text(_expanded ? 'とじる' : '日ごとの記録を見る'),
                ),
              ),
              if (_expanded) ...[
                const Divider(),
                for (final record in r.records)
                  _RecordRow(record, key: ValueKey(record.id)),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _GenreCount extends StatelessWidget {
  const _GenreCount(this.genreId, this.count);
  final String genreId;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final genre = context.store.genreById(genreId);
    final color = Color(genre.color);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: tint(color, context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconForGenre(genre), size: 16, color: onTint(color, context)),
          const SizedBox(width: 5),
          Text('${genre.name} $count', style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// 記録1件。ほかの人の記録にはスタンプを送れる。
class _RecordRow extends StatelessWidget {
  const _RecordRow(this.record, {super.key});
  final Record record;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chore = store.choreById(record.choreId);
    final thanks = store.thanksFor(record.id);
    final canThank =
        record.doneById != null &&
        record.doneById != store.currentMemberId &&
        store.memberById(record.doneById) != null;
    final iThanked = thanks.any((t) => t.fromId == store.currentMemberId);
    final detail = [
      formatDate(record.at),
      if (record.note.isNotEmpty) record.note else if (record.unplanned) 'ついでに',
    ].join('  ・  ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          GenreIcon(store.genreById(chore?.genreId ?? 'other'), size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chore?.name ?? '（削除した家事）',
                  style: theme.textTheme.bodyLarge,
                ),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (canThank || thanks.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: iThanked || !canThank
                    ? scheme.tertiary
                    : scheme.onSurfaceVariant,
                minimumSize: const Size(44, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: canThank
                  ? () {
                      HapticFeedback.selectionClick();
                      store.toggleThanks(record.id, stampKeys.first);
                    }
                  : null,
              icon: Icon(
                thanks.isEmpty
                    ? Icons.favorite_border_rounded
                    : Icons.favorite_rounded,
                size: 18,
                color: thanks.isEmpty ? null : scheme.tertiary,
              ),
              label: Text(thanks.isEmpty ? 'ありがとう' : '${thanks.length}'),
            ),
        ],
      ),
    );
  }
}

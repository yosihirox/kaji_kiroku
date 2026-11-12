import 'package:flutter/material.dart';

import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/notifications.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';

Route<void> notificationSettingsRoute() =>
    MaterialPageRoute<void>(builder: (_) => const NotificationSettingsScreen());

/// 通知とリマインドのこまかい設定。
///
/// 試作版ではまだ端末に通知は届かないので、「この設定だと今日なにが届くか」を
/// その場で確かめられるようにしている。
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = store.notifications;
    void update(NotificationSettings s) => store.updateNotifications(s);

    Future<void> pickTime(
      int current,
      ValueChanged<int> onPicked, {
      String? help,
    }) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
        helpText: help,
      );
      if (picked != null) onPicked(picked.hour * 60 + picked.minute);
    }

    Widget timeButton(
      int minutes,
      ValueChanged<int> onPicked, {
      required bool enabled,
      String? help,
    }) => OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(72, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      onPressed: enabled ? () => pickTime(minutes, onPicked, help: help) : null,
      child: Text(formatMinutes(minutes)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('通知とリマインド', style: theme.textTheme.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.construction_rounded,
                  color: scheme.onSecondaryContainer,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'スマホに通知が届くのは、アプリ版になってからです。'
                    'いまは設定を変えると、下の「今日届く通知」で届く内容を確かめられます。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SectionLabel('今日届く通知（${store.currentMember?.name ?? ''}さんの場合）'),
          _Preview(notices: store.plannedNotices),
          const SectionLabel('やることのお知らせ'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _SwitchRow(
                  title: '朝のまとめ',
                  subtitle: '今日の件数と、自分の担当の件数',
                  value: n.morningSummary,
                  onChanged: (v) => update(n.copyWith(morningSummary: v)),
                  trailing: timeButton(
                    n.morningMinutes,
                    (m) => update(n.copyWith(morningMinutes: m)),
                    enabled: n.morningSummary,
                    help: '朝のまとめの時刻',
                  ),
                ),
                const Divider(indent: 16),
                _SwitchRow(
                  title: '期限の前',
                  subtitle: '時刻をきめた家事の、少し前に知らせる',
                  value: n.beforeDue,
                  onChanged: (v) => update(n.copyWith(beforeDue: v)),
                  trailing: DropdownButton<int>(
                    value: n.beforeDueMinutes,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(14),
                    style: theme.textTheme.labelLarge,
                    onChanged: n.beforeDue
                        ? (v) => update(n.copyWith(beforeDueMinutes: v))
                        : null,
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10分前')),
                      DropdownMenuItem(value: 30, child: Text('30分前')),
                      DropdownMenuItem(value: 60, child: Text('1時間前')),
                      DropdownMenuItem(value: 120, child: Text('2時間前')),
                    ],
                  ),
                ),
                const Divider(indent: 16),
                _SwitchRow(
                  title: 'やり忘れリマインド',
                  subtitle: 'まだ終わっていない家事があるときに知らせる',
                  value: n.overdueReminder,
                  onChanged: (v) => update(n.copyWith(overdueReminder: v)),
                  trailing: timeButton(
                    n.overdueMinutes,
                    (m) => update(n.copyWith(overdueMinutes: m)),
                    enabled: n.overdueReminder,
                    help: 'やり忘れリマインドの時刻',
                  ),
                ),
              ],
            ),
          ),
          const SectionLabel('家族のうごき'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _SwitchRow(
                  title: '家族が家事を完了したとき',
                  value: n.familyDone,
                  onChanged: (v) => update(n.copyWith(familyDone: v)),
                ),
                const Divider(indent: 16),
                _SwitchRow(
                  title: '買い物リストに追加があったとき',
                  value: n.shopping,
                  onChanged: (v) => update(n.copyWith(shopping: v)),
                ),
                const Divider(indent: 16),
                _SwitchRow(
                  title: 'スタンプをもらったとき',
                  value: n.thanks,
                  onChanged: (v) => update(n.copyWith(thanks: v)),
                ),
                const Divider(indent: 16),
                _SwitchRow(
                  title: 'メッセージが届いたとき',
                  value: n.messages,
                  onChanged: (v) => update(n.copyWith(messages: v)),
                ),
              ],
            ),
          ),
          const SectionLabel('おやすみ時間'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: _SwitchRow(
              title: 'この時間は音を鳴らさない',
              subtitle: '通知は届きますが、音やバイブは鳴りません',
              value: n.quietHours,
              onChanged: (v) => update(n.copyWith(quietHours: v)),
              below: Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  timeButton(
                    n.quietStart,
                    (m) => update(n.copyWith(quietStart: m)),
                    enabled: n.quietHours,
                    help: 'おやすみ時間のはじまり',
                  ),
                  const Text('から'),
                  timeButton(
                    n.quietEnd,
                    (m) => update(n.copyWith(quietEnd: m)),
                    enabled: n.quietHours,
                    help: 'おやすみ時間のおわり',
                  ),
                  const Text('まで'),
                ],
              ),
            ),
          ),
          const SectionLabel('ジャンルごと'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, g) in store.visibleGenres.indexed) ...[
                  if (i > 0) const Divider(indent: 64),
                  SwitchListTile(
                    secondary: GenreIcon(g, size: 36),
                    title: Text(g.name),
                    value: !n.mutedGenreIds.contains(g.id),
                    onChanged: (on) {
                      final muted = {...n.mutedGenreIds};
                      on ? muted.remove(g.id) : muted.add(g.id);
                      update(n.copyWith(mutedGenreIds: muted));
                    },
                  ),
                ],
              ],
            ),
          ),
          const SectionLabel('バッジの件数'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('家族みんなの分')),
                ButtonSegment(value: true, label: Text('自分の担当だけ')),
              ],
              selected: {n.badgeMineOnly},
              onSelectionChanged: (s) =>
                  update(n.copyWith(badgeMineOnly: s.first)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
            child: Text(
              'バッジには「やり忘れ」と「今日のまだの分」を合わせた件数が出ます。',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// スイッチ付きの1行。右に時刻などの部品、下に追加の部品を置ける。
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.trailing,
    this.below,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    if (subtitle != null)
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: title,
                child: Switch(value: value, onChanged: onChanged),
              ),
            ],
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Opacity(opacity: value ? 1 : 0.5, child: trailing),
            ),
          if (below != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Opacity(opacity: value ? 1 : 0.5, child: below),
            ),
        ],
      ),
    );
  }
}

/// いまの設定で今日届く通知の一覧。
class _Preview extends StatelessWidget {
  const _Preview({required this.notices});
  final List<PlannedNotice> notices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (notices.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.notifications_off_rounded,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'この設定だと、今日は通知が届きません。',
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (final (i, notice) in notices.indexed) ...[
              if (i > 0) const Divider(indent: 76),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        formatMinutes(notice.minutes),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 1, right: 10),
                      child: Icon(
                        switch (notice.kind) {
                          NoticeKind.morning => Icons.wb_sunny_rounded,
                          NoticeKind.beforeDue => Icons.schedule_rounded,
                          NoticeKind.overdue =>
                            Icons.notification_important_rounded,
                          NoticeKind.message => Icons.mail_rounded,
                        },
                        size: 18,
                        color: scheme.primary,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notice.title, style: theme.textTheme.titleSmall),
                          Text(notice.body, style: theme.textTheme.bodySmall),
                          if (notice.quiet)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.bedtime_rounded,
                                    size: 14,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'おやすみ時間なので音は鳴りません',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 通知の設定から「今日どんな通知が届くか」を組み立てる。
///
/// 試作版では設定画面のプレビューに使う。スマホアプリ版では、同じ結果を
/// 端末の通知として予約する。
library;

import 'agenda.dart';
import 'dates.dart';
import 'models.dart';

enum NoticeKind { morning, beforeDue, overdue }

/// 届く予定の通知1件。
class PlannedNotice {
  const PlannedNotice({
    required this.minutes,
    required this.kind,
    required this.title,
    required this.body,
    required this.quiet,
  });

  /// 届く時刻（0:00 からの分）。
  final int minutes;
  final NoticeKind kind;
  final String title;
  final String body;

  /// おやすみ時間中なので、音を鳴らさずに届く。
  final bool quiet;
}

/// [memberId] の端末に今日届く通知を、時刻順に返す。
List<PlannedNotice> planNotices({
  required Agenda agenda,
  required NotificationSettings settings,
  required String? memberId,
}) {
  bool audible(Occurrence o) =>
      !settings.mutedGenreIds.contains(o.chore.genreId);

  final today = agenda.todayItems.items
      .where((o) => !o.isUnplanned && !o.isSkipped && audible(o))
      .toList();
  final pendingToday = today.where((o) => o.isPending).toList();
  final overdue = agenda.overdue.where(audible).toList();
  final mineToday = pendingToday
      .where((o) => isMine(o.chore, memberId))
      .toList();
  final mineOverdue = overdue.where((o) => isMine(o.chore, memberId)).toList();

  final notices = <PlannedNotice>[];
  void add(int minutes, NoticeKind kind, String title, String body) {
    final m = minutes.clamp(0, 24 * 60 - 1);
    notices.add(
      PlannedNotice(
        minutes: m,
        kind: kind,
        title: title,
        body: body,
        quiet: settings.isQuiet(m),
      ),
    );
  }

  if (settings.morningSummary && (today.isNotEmpty || overdue.isNotEmpty)) {
    final mine = today.where((o) => isMine(o.chore, memberId)).length;
    final parts = <String>[
      if (today.isNotEmpty) '今日の家事は${today.length}件、うちあなたの担当は$mine件です。',
      if (overdue.isNotEmpty) 'やり忘れが${overdue.length}件あります。',
    ];
    add(settings.morningMinutes, NoticeKind.morning, '今日のやること', parts.join(''));
  }

  if (settings.beforeDue) {
    for (final o in mineToday) {
      final due = o.chore.dueMinutes;
      if (due == null) continue;
      add(
        due - settings.beforeDueMinutes,
        NoticeKind.beforeDue,
        'もうすぐ「${o.chore.name}」',
        '${formatMinutes(due)} までの予定です。',
      );
    }
  }

  if (settings.overdueReminder) {
    final left = [...mineOverdue, ...mineToday];
    if (left.isNotEmpty) {
      final names = left.take(3).map((o) => o.chore.name).join('、');
      final more = left.length > 3 ? ' ほか' : '';
      add(
        settings.overdueMinutes,
        NoticeKind.overdue,
        'まだ終わっていない家事が${left.length}件あります',
        '$names$more',
      );
    }
  }

  notices.sort((a, b) => a.minutes.compareTo(b.minutes));
  return notices;
}

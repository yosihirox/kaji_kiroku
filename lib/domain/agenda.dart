/// ホーム画面に並べる「やること」を、家事と実施記録から組み立てる。
///
/// 画面にも保存先にも依存しない計算だけを置く。
library;

import 'dates.dart';
import 'models.dart';
import 'recurrence.dart';

/// ある家事の、ある予定日の1回分。
class Occurrence {
  const Occurrence({
    required this.chore,
    required this.date,
    this.record,
    this.overdue = false,
  });

  final Chore chore;

  /// 予定日。予定外の記録ではやった日。
  final DateTime date;

  /// 完了・スキップ済みならその記録。
  final Record? record;

  /// 予定日を過ぎても終わっていない。
  final bool overdue;

  bool get isDone => record?.status == RecordStatus.done;
  bool get isSkipped => record?.status == RecordStatus.skipped;
  bool get isResolved => record != null;
  bool get isPending => record == null;
  bool get isUnplanned => record?.unplanned ?? false;

  /// 一覧の中でこの1回分を見分けるキー。
  String get key =>
      isUnplanned ? 'record:${record!.id}' : '${chore.id}@${dateKey(date)}';
}

/// ホーム画面の1日分。
class AgendaDay {
  const AgendaDay(this.date, this.items);
  final DateTime date;
  final List<Occurrence> items;

  int get pendingCount => items.where((i) => i.isPending).length;
  int get doneCount => items.where((i) => i.isDone).length;
}

/// ホーム画面全体。
class Agenda {
  const Agenda({
    required this.today,
    required this.overdue,
    required this.days,
  });

  final DateTime today;

  /// やり忘れ（予定日を過ぎて未完了）。古い順。
  final List<Occurrence> overdue;

  /// 今日から順に1日ずつ。
  final List<AgendaDay> days;

  AgendaDay get todayItems => days.first;

  /// バッジに出す件数（やり忘れ＋今日の未完了）。
  /// [memberId] を渡すと、その人の担当と「だれでも」の分だけ数える。
  int pendingCount({String? memberId}) {
    bool counts(Occurrence o) =>
        o.isPending && (memberId == null || isMine(o.chore, memberId));
    return overdue.where(counts).length + todayItems.items.where(counts).length;
  }
}

/// [memberId] の担当か（「だれでも」も含む）。
bool isMine(Chore chore, String? memberId) =>
    chore.assigneeId == null || chore.assigneeId == memberId;

/// 家事ごとに記録を引けるようにしたもの。
class _RecordIndex {
  _RecordIndex(Iterable<Record> records) {
    for (final r in records) {
      (byChore[r.choreId] ??= []).add(r);
    }
  }

  final byChore = <String, List<Record>>{};

  /// 予定日ごとの記録（予定外の記録は除く）。
  Map<DateTime, Record> planned(String choreId) => {
    for (final r in byChore[choreId] ?? const <Record>[])
      if (!r.unplanned) r.date: r,
  };

  /// 最後に手をつけた日（完了・スキップ・予定外の実施）。
  DateTime? lastTouched(String choreId) {
    DateTime? last;
    for (final r in byChore[choreId] ?? const <Record>[]) {
      final d = dateOnly(r.at);
      if (last == null || d.isAfter(last)) last = d;
    }
    return last;
  }
}

/// 「やった日からN日後」の家事が、最後に手をつけられた日。
DateTime? lastTouchedDate(String choreId, Iterable<Record> records) =>
    _RecordIndex(
      records.where((r) => r.choreId == choreId),
    ).lastTouched(choreId);

/// [today] から [days] 日分のやることを組み立てる。
///
/// 決まり:
/// - 繰り返す家事のやり忘れは、家事ごとに直近の1回分だけ出す。次の予定日が来たら
///   そちらに切り替わる（毎日の家事が何日分もたまって並ぶことはない）。
/// - 1回だけの家事は、終わらせるまでやり忘れに残る。
/// - 過ぎた予定を今日片付けたものと、予定外の「ついでにやった」は今日の欄に出す。
Agenda buildAgenda({
  required Iterable<Chore> chores,
  required Iterable<Record> records,
  required DateTime today,
  int days = 7,
}) {
  final t = dateOnly(today);
  final end = addDays(t, days - 1);
  final index = _RecordIndex(records);
  final byDay = <DateTime, List<Occurrence>>{
    for (var i = 0; i < days; i++) addDays(t, i): [],
  };
  final overdue = <Occurrence>[];
  final choreById = {for (final c in chores) c.id: c};

  for (final chore in chores) {
    if (chore.archived) continue;
    final planned = index.planned(chore.id);
    final repeat = chore.repeat;
    final afterDone = repeat.type == RepeatType.afterDone;
    final lastTouched = afterDone ? index.lastTouched(chore.id) : null;

    // これからの予定
    final dates = repeat.occurrencesBetween(
      t,
      end,
      chore.start,
      lastDone: lastTouched,
    );
    final shown = <DateTime>{};
    for (final d in dates) {
      // 「やった日からN日後」の次回は、いつもまだ終わっていない1回分。
      final record = afterDone ? null : planned[d];
      byDay[d]!.add(Occurrence(chore: chore, date: d, record: record));
      shown.add(d);
    }

    // 上の予定に入らない記録（今日やった分や、ルールを変える前の分）
    for (final r in planned.values) {
      if (shown.contains(r.date)) continue;
      final inWindow = !r.date.isBefore(t) && !r.date.isAfter(end);
      final doneTodayForPast =
          r.isDone && r.date.isBefore(t) && isSameDay(r.at, t);
      if (inWindow) {
        byDay[r.date]!.add(Occurrence(chore: chore, date: r.date, record: r));
      } else if (doneTodayForPast) {
        byDay[t]!.add(Occurrence(chore: chore, date: r.date, record: r));
      }
    }

    // やり忘れ
    final DateTime? missed;
    switch (repeat.type) {
      case RepeatType.none:
        final s = dateOnly(chore.start);
        missed = s.isBefore(t) ? s : null;
      case RepeatType.afterDone:
        final next = repeat.nextAfterDone(chore.start, lastTouched);
        missed = next.isBefore(t) ? next : null;
      default:
        missed = repeat.occursOn(t, chore.start)
            ? null
            : repeat.previousBefore(t, chore.start);
    }
    if (missed != null && (afterDone || !planned.containsKey(missed))) {
      overdue.add(Occurrence(chore: chore, date: missed, overdue: true));
    }
  }

  // 予定外の「ついでにやった」は、やった日の欄に出す。
  for (final r in records) {
    if (!r.unplanned) continue;
    final chore = choreById[r.choreId];
    final list = byDay[r.date];
    if (chore == null || list == null) continue;
    list.add(Occurrence(chore: chore, date: r.date, record: r));
  }

  overdue.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.chore.name.compareTo(b.chore.name);
  });
  for (final list in byDay.values) {
    list.sort(_compareInDay);
  }
  return Agenda(
    today: t,
    overdue: overdue,
    days: [for (final e in byDay.entries) AgendaDay(e.key, e.value)],
  );
}

/// 1日の中の並び順: まだのものを先に（時刻が早い順）、終わったものは後ろへ。
int _compareInDay(Occurrence a, Occurrence b) {
  if (a.isResolved != b.isResolved) return a.isResolved ? 1 : -1;
  if (a.isResolved) return a.record!.at.compareTo(b.record!.at);
  final at = a.chore.dueMinutes ?? 24 * 60;
  final bt = b.chore.dueMinutes ?? 24 * 60;
  if (at != bt) return at.compareTo(bt);
  return a.chore.name.compareTo(b.chore.name);
}

/// 家事の「次の予定日」。やり忘れがあればその日、もう予定がなければ null。
DateTime? nextDueDate(Chore chore, Iterable<Record> records, DateTime today) {
  final t = dateOnly(today);
  final index = _RecordIndex(records.where((r) => r.choreId == chore.id));
  final planned = index.planned(chore.id);
  final repeat = chore.repeat;
  switch (repeat.type) {
    case RepeatType.none:
      final s = dateOnly(chore.start);
      return planned.containsKey(s) ? null : s;
    case RepeatType.afterDone:
      return repeat.nextAfterDone(chore.start, index.lastTouched(chore.id));
    default:
      var d = t;
      // 完了済みの回を飛ばして、次のまだの回を探す。
      for (var i = 0; i < 60; i++) {
        final next = repeat.nextOnOrAfter(d, chore.start);
        if (next == null) return null;
        if (!planned.containsKey(next)) return next;
        d = addDays(next, 1);
      }
      return null;
  }
}

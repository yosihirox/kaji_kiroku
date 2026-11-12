/// 「がんばり」画面の集計。誰が何をどれだけやったかをまとめる。
library;

import 'dates.dart';
import 'models.dart';

/// 集計する期間（両端を含む）。
class ReportPeriod {
  const ReportPeriod(this.from, this.to, {required this.isWeek});

  /// [today] を含む週（月曜はじまり）から [offset] 週ずらした期間。0 が今週、-1 が先週。
  factory ReportPeriod.week(DateTime today, [int offset = 0]) {
    final monday = addDays(startOfWeek(today), offset * 7);
    return ReportPeriod(monday, addDays(monday, 6), isWeek: true);
  }

  /// [today] を含む月から [offset] か月ずらした期間。
  factory ReportPeriod.month(DateTime today, [int offset = 0]) {
    final first = DateTime(today.year, today.month + offset, 1);
    return ReportPeriod(
      first,
      DateTime(first.year, first.month + 1, 0),
      isWeek: false,
    );
  }

  final DateTime from;
  final DateTime to;
  final bool isWeek;

  int get dayCount => daysBetween(from, to) + 1;

  bool contains(DateTime at) {
    final d = dateOnly(at);
    return !d.isBefore(from) && !d.isAfter(to);
  }

  String get label => isWeek
      ? '${from.month}/${from.day}〜${to.month}/${to.day}'
      : '${from.year}年${from.month}月';
}

/// 1つの家事を何回やったか。
class ChoreCount {
  const ChoreCount({
    required this.choreId,
    required this.name,
    required this.genreId,
    required this.count,
  });
  final String choreId;
  final String name;
  final String genreId;
  final int count;
}

/// 1人分の集計。
class MemberReport {
  const MemberReport({
    required this.member,
    required this.records,
    required this.byGenre,
    required this.byChore,
    required this.thanksReceived,
  });

  /// null は、すでに家族から外れた人の記録をまとめたもの。
  final Member? member;

  /// 期間内にやった記録（新しい順）。
  final List<Record> records;

  /// ジャンルごとの件数（多い順）。
  final List<MapEntry<String, int>> byGenre;

  /// 家事ごとの回数（多い順）。
  final List<ChoreCount> byChore;

  /// もらったスタンプの数。
  final int thanksReceived;

  int get count => records.length;
}

/// 1日分の、人ごとの件数。
class DayCount {
  const DayCount(this.date, this.byMember);
  final DateTime date;

  /// メンバーの ID（外れた人は null）ごとの件数。
  final Map<String?, int> byMember;

  int get total => byMember.values.fold(0, (a, b) => a + b);
}

class Report {
  const Report({
    required this.period,
    required this.members,
    required this.daily,
  });

  final ReportPeriod period;

  /// 今の家族は全員（0件でも）含む。外れた人の記録があれば最後にまとめて1つ。
  final List<MemberReport> members;
  final List<DayCount> daily;

  int get total => members.fold(0, (a, m) => a + m.count);
  int get maxMemberCount =>
      members.fold(0, (a, m) => m.count > a ? m.count : a);
  int get maxDayTotal => daily.fold(0, (a, d) => d.total > a ? d.total : a);
}

Report buildReport({
  required List<Member> members,
  required Iterable<Chore> chores,
  required Iterable<Record> records,
  required Iterable<Thanks> thanks,
  required ReportPeriod period,
}) {
  final memberIds = {for (final m in members) m.id};
  final choreById = {for (final c in chores) c.id: c};
  final done = records.where((r) => r.isDone && period.contains(r.at)).toList()
    ..sort((a, b) => b.at.compareTo(a.at));

  String? bucket(Record r) =>
      memberIds.contains(r.doneById) ? r.doneById : null;

  final byMember = <String?, List<Record>>{for (final m in members) m.id: []};
  for (final r in done) {
    (byMember[bucket(r)] ??= []).add(r);
  }

  final thanksByRecord = <String, int>{};
  for (final t in thanks) {
    thanksByRecord[t.recordId] = (thanksByRecord[t.recordId] ?? 0) + 1;
  }

  MemberReport summarize(Member? member, List<Record> list) {
    final genres = <String, int>{};
    final counts = <String, int>{};
    var thanked = 0;
    for (final r in list) {
      final genreId = choreById[r.choreId]?.genreId ?? 'other';
      genres[genreId] = (genres[genreId] ?? 0) + 1;
      counts[r.choreId] = (counts[r.choreId] ?? 0) + 1;
      thanked += thanksByRecord[r.id] ?? 0;
    }
    final byChore =
        [
          for (final e in counts.entries)
            ChoreCount(
              choreId: e.key,
              name: choreById[e.key]?.name ?? '（削除した家事）',
              genreId: choreById[e.key]?.genreId ?? 'other',
              count: e.value,
            ),
        ]..sort((a, b) {
          final c = b.count.compareTo(a.count);
          return c != 0 ? c : a.name.compareTo(b.name);
        });
    return MemberReport(
      member: member,
      records: list,
      byGenre: genres.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
      byChore: byChore,
      thanksReceived: thanked,
    );
  }

  final daily = <DayCount>[];
  for (var i = 0; i < period.dayCount; i++) {
    final day = addDays(period.from, i);
    final counts = <String?, int>{};
    for (final r in done) {
      if (!isSameDay(r.at, day)) continue;
      final key = bucket(r);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    daily.add(DayCount(day, counts));
  }

  return Report(
    period: period,
    members: [
      for (final m in members) summarize(m, byMember[m.id]!),
      if (byMember[null]?.isNotEmpty ?? false) summarize(null, byMember[null]!),
    ],
    daily: daily,
  );
}

/// 1人分の件数。
class MemberCount {
  const MemberCount(this.member, this.count);
  final Member member;
  final int count;
}

/// [from] から [to] の日（両端を含む）にやった家事の件数を、人ごとに多い順で返す。
/// 0件の人は入れない。同じ件数なら家族の並び順。
List<MemberCount> doneCountsBetween({
  required List<Member> members,
  required Iterable<Record> records,
  required DateTime from,
  required DateTime to,
}) {
  final period = ReportPeriod(dateOnly(from), dateOnly(to), isWeek: false);
  final counts = <String, int>{};
  for (final r in records) {
    if (!r.isDone || r.doneById == null || !period.contains(r.at)) continue;
    counts[r.doneById!] = (counts[r.doneById!] ?? 0) + 1;
  }
  final result = [
    for (final m in members)
      if ((counts[m.id] ?? 0) > 0) MemberCount(m, counts[m.id]!),
  ];
  // sort は安定なので、同じ件数なら家族の並び順のまま。
  final order = {for (var i = 0; i < members.length; i++) members[i].id: i};
  result.sort((a, b) {
    final c = b.count.compareTo(a.count);
    return c != 0 ? c : order[a.member.id]!.compareTo(order[b.member.id]!);
  });
  return result;
}

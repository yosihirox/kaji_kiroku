/// 繰り返し予定のルールと、日付の計算。
///
/// 端末のタイムゾーンや時刻に左右されないよう、日付は「年月日だけの DateTime」で扱う。
library;

const weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

/// 年月日だけにした日付。
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 日付を足し引きする（夏時間の影響を受けないよう DateTime のコンストラクタで計算）。
DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// 「11/12（水）」のような表示。
String formatDate(DateTime d) =>
    '${d.month}/${d.day}（${weekdayLabels[d.weekday - 1]}）';

enum RepeatType {
  /// 1回だけ
  none,

  /// N日ごと
  daily,

  /// N週ごと、指定した曜日
  weekly,

  /// Nか月ごと、指定日（0 は月末）
  monthlyDay,

  /// Nか月ごと、第N曜日（第2・第4月曜など。5 は最終）
  monthlyNthWeekday,

  /// N年ごと、初回と同じ月日
  yearly,

  /// 最後にやった日からN日後
  afterDone,
}

/// 繰り返しルール。
class Repeat {
  const Repeat({
    required this.type,
    this.interval = 1,
    this.weekdays = const {},
    this.monthDay = 1,
    this.nths = const {},
    this.weekday = DateTime.monday,
  });

  const Repeat.none() : this(type: RepeatType.none);

  final RepeatType type;

  /// N日・N週・Nか月・N年ごとの N。afterDone では日数。
  final int interval;

  /// weekly で使う曜日（1=月〜7=日）。
  final Set<int> weekdays;

  /// monthlyDay で使う日。0 は月末。月の日数を超える日は月末に寄せる。
  final int monthDay;

  /// monthlyNthWeekday で使う「第何」。1〜4、5 は最終。
  final Set<int> nths;

  /// monthlyNthWeekday で使う曜日。
  final int weekday;

  bool get isRepeating => type != RepeatType.none;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'interval': interval,
        'weekdays': weekdays.toList()..sort(),
        'monthDay': monthDay,
        'nths': nths.toList()..sort(),
        'weekday': weekday,
      };

  factory Repeat.fromJson(Map<String, dynamic> j) => Repeat(
        type: RepeatType.values.byName(j['type'] as String),
        interval: j['interval'] as int? ?? 1,
        weekdays: {...(j['weekdays'] as List? ?? const []).cast<int>()},
        monthDay: j['monthDay'] as int? ?? 1,
        nths: {...(j['nths'] as List? ?? const []).cast<int>()},
        weekday: j['weekday'] as int? ?? DateTime.monday,
      );

  /// 「毎月 第2・第4 月曜日」のような説明文。
  String describe(DateTime start) {
    final n = interval;
    switch (type) {
      case RepeatType.none:
        return '1回だけ（${formatDate(start)}）';
      case RepeatType.daily:
        return n == 1 ? '毎日' : '$n日ごと';
      case RepeatType.weekly:
        final days = (weekdays.toList()..sort())
            .map((w) => weekdayLabels[w - 1])
            .join('・');
        return '${n == 1 ? '毎週' : '$n週ごと'} $days曜日';
      case RepeatType.monthlyDay:
        final day = monthDay == 0 ? '月末' : '$monthDay日';
        return '${n == 1 ? '毎月' : '$nか月ごと'} $day';
      case RepeatType.monthlyNthWeekday:
        final ns = (nths.toList()..sort())
            .map((x) => x == 5 ? '最終' : '第$x')
            .join('・');
        return '${n == 1 ? '毎月' : '$nか月ごと'} $ns ${weekdayLabels[weekday - 1]}曜日';
      case RepeatType.yearly:
        return '${n == 1 ? '毎年' : '$n年ごと'} ${start.month}月${start.day}日';
      case RepeatType.afterDone:
        return 'やった日から$n日後';
    }
  }

  /// [date] が予定日かどうか。afterDone は [lastDone] から決まる。
  bool occursOn(DateTime date, DateTime start, {DateTime? lastDone}) {
    final d = dateOnly(date);
    final s = dateOnly(start);
    if (d.isBefore(s)) return false;
    final n = interval < 1 ? 1 : interval;
    switch (type) {
      case RepeatType.none:
        return d == s;
      case RepeatType.daily:
        return daysBetween(s, d) % n == 0;
      case RepeatType.weekly:
        if (!weekdays.contains(d.weekday)) return false;
        final startMonday = addDays(s, -(s.weekday - 1));
        final weeks = daysBetween(startMonday, d) ~/ 7;
        return weeks % n == 0;
      case RepeatType.monthlyDay:
        if (_monthsBetween(s, d) % n != 0) return false;
        final last = daysInMonth(d.year, d.month);
        final target = (monthDay == 0 || monthDay > last) ? last : monthDay;
        return d.day == target;
      case RepeatType.monthlyNthWeekday:
        if (_monthsBetween(s, d) % n != 0) return false;
        if (d.weekday != weekday) return false;
        final nth = (d.day - 1) ~/ 7 + 1;
        final isLast = d.day + 7 > daysInMonth(d.year, d.month);
        return nths.contains(nth) && nth <= 4 || (nths.contains(5) && isLast);
      case RepeatType.yearly:
        if ((d.year - s.year) % n != 0) return false;
        // 2/29 始まりは平年では 2/28 に寄せる。
        final day = s.day > daysInMonth(d.year, s.month)
            ? daysInMonth(d.year, s.month)
            : s.day;
        return d.month == s.month && d.day == day;
      case RepeatType.afterDone:
        return d == nextAfterDone(s, lastDone);
    }
  }

  /// afterDone の次の予定日。
  DateTime nextAfterDone(DateTime start, DateTime? lastDone) {
    final s = dateOnly(start);
    if (lastDone == null) return s;
    final next = addDays(dateOnly(lastDone), interval < 1 ? 1 : interval);
    return next.isBefore(s) ? s : next;
  }

  /// [from] から [to] まで（両端を含む）の予定日。
  List<DateTime> occurrencesBetween(
    DateTime from,
    DateTime to,
    DateTime start, {
    DateTime? lastDone,
  }) {
    final result = <DateTime>[];
    var d = dateOnly(from);
    final s = dateOnly(start);
    if (d.isBefore(s)) d = s;
    final end = dateOnly(to);
    if (type == RepeatType.afterDone) {
      final next = nextAfterDone(s, lastDone);
      if (!next.isBefore(d) && !next.isAfter(end)) result.add(next);
      return result;
    }
    if (type == RepeatType.none) {
      if (!s.isBefore(d) && !s.isAfter(end)) result.add(s);
      return result;
    }
    while (!d.isAfter(end)) {
      if (occursOn(d, s)) result.add(d);
      d = addDays(d, 1);
    }
    return result;
  }

  static int _monthsBetween(DateTime a, DateTime b) =>
      (b.year - a.year) * 12 + (b.month - a.month);
}

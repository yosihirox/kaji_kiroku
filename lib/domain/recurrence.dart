/// 繰り返し予定のルールと、予定日の計算。
library;

import 'dates.dart';

enum RepeatType {
  /// 1回だけ
  none,

  /// N日ごと
  daily,

  /// N週ごと、指定した曜日
  weekly,

  /// Nか月ごと、指定日（0 は月末）
  monthlyDay,

  /// Nか月ごと、第N曜日（第2・第4月曜など）
  monthlyNthWeekday,

  /// N年ごと、開始日と同じ月日
  yearly,

  /// 最後にやった日からN日後
  afterDone,
}

/// 繰り返しルール。変更できない値として扱う。
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
  const Repeat.daily([int interval = 1])
    : this(type: RepeatType.daily, interval: interval);
  const Repeat.weekly(Set<int> weekdays, {int interval = 1})
    : this(type: RepeatType.weekly, weekdays: weekdays, interval: interval);
  const Repeat.monthlyDay(int day, {int interval = 1})
    : this(type: RepeatType.monthlyDay, monthDay: day, interval: interval);
  const Repeat.monthlyNth(Set<int> nths, int weekday, {int interval = 1})
    : this(
        type: RepeatType.monthlyNthWeekday,
        nths: nths,
        weekday: weekday,
        interval: interval,
      );
  const Repeat.yearly([int interval = 1])
    : this(type: RepeatType.yearly, interval: interval);
  const Repeat.afterDone(int days)
    : this(type: RepeatType.afterDone, interval: days);

  /// 「第N」の選択肢で「最終」を表す値。
  static const lastWeek = 5;

  /// 月〜金。
  static const weekdaysOnly = {1, 2, 3, 4, 5};

  final RepeatType type;

  /// N日・N週・Nか月・N年ごとの N。afterDone では日数。
  final int interval;

  /// weekly で使う曜日（1=月〜7=日）。
  final Set<int> weekdays;

  /// monthlyDay で使う日。0 は月末。月の日数を超える日は月末に寄せる。
  final int monthDay;

  /// monthlyNthWeekday で使う「第何」。1〜4 と [lastWeek]。
  final Set<int> nths;

  /// monthlyNthWeekday で使う曜日。
  final int weekday;

  int get _n => interval < 1 ? 1 : interval;

  bool get isRepeating => type != RepeatType.none;

  /// 予定日が1つも作れない設定になっていないか。
  bool get isValid => switch (type) {
    RepeatType.weekly => weekdays.isNotEmpty,
    RepeatType.monthlyNthWeekday => nths.isNotEmpty,
    _ => true,
  };

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'interval': interval,
    'weekdays': weekdays.toList()..sort(),
    'monthDay': monthDay,
    'nths': nths.toList()..sort(),
    'weekday': weekday,
  };

  factory Repeat.fromJson(Map<String, dynamic> j) => Repeat(
    type: RepeatType.values.asNameMap()[j['type']] ?? RepeatType.none,
    interval: (j['interval'] as num?)?.toInt() ?? 1,
    weekdays: {
      ...(j['weekdays'] as List? ?? const []).map((e) => (e as num).toInt()),
    },
    monthDay: (j['monthDay'] as num?)?.toInt() ?? 1,
    nths: {...(j['nths'] as List? ?? const []).map((e) => (e as num).toInt())},
    weekday: (j['weekday'] as num?)?.toInt() ?? DateTime.monday,
  );

  /// 「毎月 第2・第4 月曜」のような短い説明。
  String describe(DateTime start) {
    final n = _n;
    switch (type) {
      case RepeatType.none:
        return '1回だけ';
      case RepeatType.daily:
        return n == 1 ? '毎日' : '$n日ごと';
      case RepeatType.weekly:
        final sorted = weekdays.toList()..sort();
        final String days;
        if (sorted.length == 7) {
          days = '毎日';
        } else if (sorted.length == 5 && weekdays.containsAll(weekdaysOnly)) {
          days = '平日';
        } else {
          days = sorted.map((w) => weekdayLabels[w - 1]).join('・');
        }
        return '${n == 1 ? '毎週' : '$n週ごと'} $days';
      case RepeatType.monthlyDay:
        final day = monthDay == 0 ? '月末' : '$monthDay日';
        return '${n == 1 ? '毎月' : '$nか月ごと'} $day';
      case RepeatType.monthlyNthWeekday:
        final ns = (nths.toList()..sort())
            .map((x) => x == lastWeek ? '最終' : '第$x')
            .join('・');
        return '${n == 1 ? '毎月' : '$nか月ごと'} $ns ${weekdayLabels[weekday - 1]}曜';
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
    final n = _n;
    switch (type) {
      case RepeatType.none:
        return d == s;
      case RepeatType.daily:
        return daysBetween(s, d) % n == 0;
      case RepeatType.weekly:
        if (!weekdays.contains(d.weekday)) return false;
        final weeks = daysBetween(startOfWeek(s), d) ~/ 7;
        return weeks % n == 0;
      case RepeatType.monthlyDay:
        if (_monthsBetween(s, d) % n != 0) return false;
        final last = daysInMonth(d.year, d.month);
        final target = (monthDay <= 0 || monthDay > last) ? last : monthDay;
        return d.day == target;
      case RepeatType.monthlyNthWeekday:
        if (_monthsBetween(s, d) % n != 0) return false;
        if (d.weekday != weekday) return false;
        final nth = (d.day - 1) ~/ 7 + 1;
        final isLast = d.day + 7 > daysInMonth(d.year, d.month);
        return (nth <= 4 && nths.contains(nth)) ||
            (isLast && nths.contains(lastWeek));
      case RepeatType.yearly:
        if ((d.year - s.year) % n != 0) return false;
        // 2/29 始まりは、うるう年でない年は 2/28 に寄せる。
        final last = daysInMonth(d.year, s.month);
        final day = s.day > last ? last : s.day;
        return d.month == s.month && d.day == day;
      case RepeatType.afterDone:
        return d == nextAfterDone(s, lastDone);
    }
  }

  /// afterDone の次の予定日。まだ一度もやっていなければ開始日。
  DateTime nextAfterDone(DateTime start, DateTime? lastDone) {
    final s = dateOnly(start);
    if (lastDone == null) return s;
    final next = addDays(dateOnly(lastDone), _n);
    return next.isBefore(s) ? s : next;
  }

  /// [from] から [to] まで（両端を含む）の予定日。
  List<DateTime> occurrencesBetween(
    DateTime from,
    DateTime to,
    DateTime start, {
    DateTime? lastDone,
  }) {
    final s = dateOnly(start);
    final end = dateOnly(to);
    var d = dateOnly(from);
    if (d.isBefore(s)) d = s;
    if (!isValid || d.isAfter(end)) return const [];

    bool inRange(DateTime x) => !x.isBefore(d) && !x.isAfter(end);
    if (type == RepeatType.none) return inRange(s) ? [s] : const [];
    if (type == RepeatType.afterDone) {
      final next = nextAfterDone(s, lastDone);
      return inRange(next) ? [next] : const [];
    }
    final result = <DateTime>[];
    while (!d.isAfter(end)) {
      if (occursOn(d, s)) result.add(d);
      d = addDays(d, 1);
    }
    return result;
  }

  /// [from] 以降でいちばん近い予定日。見つからなければ null。
  DateTime? nextOnOrAfter(DateTime from, DateTime start, {DateTime? lastDone}) {
    final s = dateOnly(start);
    var d = dateOnly(from);
    if (d.isBefore(s)) d = s;
    if (!isValid) return null;
    if (type == RepeatType.none) return d == s ? s : null;
    if (type == RepeatType.afterDone) {
      final next = nextAfterDone(s, lastDone);
      return next.isBefore(d) ? null : next;
    }
    for (var i = 0; i <= _searchDays; i++) {
      if (occursOn(d, s)) return d;
      d = addDays(d, 1);
    }
    return null;
  }

  /// [before] より前でいちばん近い予定日。見つからなければ null。
  /// afterDone は「次の予定日」が1つあるだけなので対象外。
  DateTime? previousBefore(DateTime before, DateTime start) {
    final s = dateOnly(start);
    var d = addDays(dateOnly(before), -1);
    if (!isValid || d.isBefore(s)) return null;
    if (type == RepeatType.none) return s;
    if (type == RepeatType.afterDone) return null;
    for (var i = 0; i <= _searchDays && !d.isBefore(s); i++) {
      if (occursOn(d, s)) return d;
      d = addDays(d, -1);
    }
    return null;
  }

  /// 予定日を探すときにさかのぼる・先を見る最大日数。
  int get _searchDays => switch (type) {
    RepeatType.yearly => 366 * _n + 1,
    RepeatType.monthlyDay || RepeatType.monthlyNthWeekday => 31 * (_n + 1) + 7,
    RepeatType.weekly => 7 * (_n + 1),
    _ => _n + 1,
  };

  static int _monthsBetween(DateTime a, DateTime b) =>
      (b.year - a.year) * 12 + (b.month - a.month);

  /// このルールで意味を持つ項目だけを並べたもの。同じルールかどうかの比較に使う。
  String get _signature {
    String sorted(Set<int> s) => (s.toList()..sort()).join(',');
    return switch (type) {
      RepeatType.none => 'none',
      RepeatType.daily ||
      RepeatType.yearly ||
      RepeatType.afterDone => '${type.name}/$_n',
      RepeatType.weekly => 'weekly/$_n/${sorted(weekdays)}',
      RepeatType.monthlyDay => 'monthlyDay/$_n/$monthDay',
      RepeatType.monthlyNthWeekday => 'monthlyNth/$_n/$weekday/${sorted(nths)}',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Repeat && other._signature == _signature;

  @override
  int get hashCode => _signature.hashCode;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kaji_kiroku/recurrence.dart';

void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  test('毎月 第2・第4 月曜日', () {
    const r = Repeat(
      type: RepeatType.monthlyNthWeekday,
      nths: {2, 4},
      weekday: DateTime.monday,
    );
    final dates = r.occurrencesBetween(d(2026, 11, 1), d(2026, 12, 31), d(2026, 11, 1));
    expect(dates, [d(2026, 11, 9), d(2026, 11, 23), d(2026, 12, 14), d(2026, 12, 28)]);
  });

  test('毎月 最終金曜日', () {
    const r = Repeat(
      type: RepeatType.monthlyNthWeekday,
      nths: {5},
      weekday: DateTime.friday,
    );
    final dates = r.occurrencesBetween(d(2026, 11, 1), d(2027, 1, 31), d(2026, 11, 1));
    expect(dates, [d(2026, 11, 27), d(2026, 12, 25), d(2027, 1, 29)]);
  });

  test('毎月31日は短い月では月末になる', () {
    const r = Repeat(type: RepeatType.monthlyDay, monthDay: 31);
    final dates = r.occurrencesBetween(d(2027, 1, 1), d(2027, 4, 30), d(2027, 1, 1));
    expect(dates, [d(2027, 1, 31), d(2027, 2, 28), d(2027, 3, 31), d(2027, 4, 30)]);
  });

  test('3か月ごとの25日', () {
    const r = Repeat(type: RepeatType.monthlyDay, monthDay: 25, interval: 3);
    final dates = r.occurrencesBetween(d(2026, 11, 1), d(2027, 6, 30), d(2026, 11, 10));
    expect(dates, [d(2026, 11, 25), d(2027, 2, 25), d(2027, 5, 25)]);
  });

  test('2週ごと 火・金', () {
    const r = Repeat(
      type: RepeatType.weekly,
      interval: 2,
      weekdays: {DateTime.tuesday, DateTime.friday},
    );
    // 2026-11-10 は火曜日
    final dates = r.occurrencesBetween(d(2026, 11, 10), d(2026, 11, 30), d(2026, 11, 10));
    expect(dates, [d(2026, 11, 10), d(2026, 11, 13), d(2026, 11, 24), d(2026, 11, 27)]);
  });

  test('3日ごと', () {
    const r = Repeat(type: RepeatType.daily, interval: 3);
    final dates = r.occurrencesBetween(d(2026, 11, 12), d(2026, 11, 20), d(2026, 11, 10));
    expect(dates, [d(2026, 11, 13), d(2026, 11, 16), d(2026, 11, 19)]);
  });

  test('毎年（うるう日は平年 2/28）', () {
    const r = Repeat(type: RepeatType.yearly);
    final dates = r.occurrencesBetween(d(2028, 1, 1), d(2029, 12, 31), d(2028, 2, 29));
    expect(dates, [d(2028, 2, 29), d(2029, 2, 28)]);
  });

  test('やった日から30日後', () {
    const r = Repeat(type: RepeatType.afterDone, interval: 30);
    expect(r.nextAfterDone(d(2026, 11, 1), null), d(2026, 11, 1));
    expect(r.nextAfterDone(d(2026, 11, 1), d(2026, 11, 5)), d(2026, 12, 5));
  });

  test('説明文', () {
    const r = Repeat(
      type: RepeatType.monthlyNthWeekday,
      nths: {2, 4},
      weekday: DateTime.monday,
    );
    expect(r.describe(d(2026, 11, 1)), '毎月 第2・第4 月曜日');
    expect(
      const Repeat(type: RepeatType.weekly, weekdays: {2, 5}).describe(d(2026, 11, 1)),
      '毎週 火・金曜日',
    );
  });

  test('JSON で保存して戻せる', () {
    const r = Repeat(
      type: RepeatType.monthlyNthWeekday,
      interval: 2,
      nths: {1, 5},
      weekday: DateTime.sunday,
    );
    final back = Repeat.fromJson(r.toJson());
    expect(back.type, r.type);
    expect(back.interval, 2);
    expect(back.nths, {1, 5});
    expect(back.weekday, DateTime.sunday);
  });
}

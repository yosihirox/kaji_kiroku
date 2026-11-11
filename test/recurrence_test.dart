import 'package:flutter_test/flutter_test.dart';
import 'package:kaji_kiroku/domain/dates.dart';
import 'package:kaji_kiroku/domain/recurrence.dart';

void main() {
  List<String> keys(Iterable<DateTime> dates) => dates.map(dateKey).toList();

  group('予定日の計算', () {
    test('1回だけ', () {
      const r = Repeat.none();
      final start = DateTime(2026, 11, 12);
      expect(r.occursOn(DateTime(2026, 11, 12), start), isTrue);
      expect(r.occursOn(DateTime(2026, 11, 13), start), isFalse);
      expect(r.isRepeating, isFalse);
    });

    test('3日ごと', () {
      const r = Repeat.daily(3);
      final start = DateTime(2026, 11, 1);
      expect(
        keys(
          r.occurrencesBetween(
            DateTime(2026, 11, 1),
            DateTime(2026, 11, 10),
            start,
          ),
        ),
        ['2026-11-01', '2026-11-04', '2026-11-07', '2026-11-10'],
      );
    });

    test('毎週 火・金', () {
      const r = Repeat.weekly({2, 5});
      final start = DateTime(2026, 11, 2); // 月
      expect(
        keys(
          r.occurrencesBetween(
            DateTime(2026, 11, 2),
            DateTime(2026, 11, 15),
            start,
          ),
        ),
        ['2026-11-03', '2026-11-06', '2026-11-10', '2026-11-13'],
      );
    });

    test('2週ごとの土曜は、開始日の週を1週目として数える', () {
      const r = Repeat.weekly({6}, interval: 2);
      final start = DateTime(2026, 11, 4); // 水
      expect(
        keys(
          r.occurrencesBetween(
            DateTime(2026, 11, 1),
            DateTime(2026, 12, 6),
            start,
          ),
        ),
        ['2026-11-07', '2026-11-21', '2026-12-05'],
      );
    });

    test('毎月31日は、31日がない月は月末に寄せる', () {
      const r = Repeat.monthlyDay(31);
      final start = DateTime(2026, 1, 1);
      expect(r.occursOn(DateTime(2026, 2, 28), start), isTrue);
      expect(r.occursOn(DateTime(2026, 4, 30), start), isTrue);
      expect(r.occursOn(DateTime(2026, 3, 30), start), isFalse);
      expect(r.occursOn(DateTime(2026, 3, 31), start), isTrue);
    });

    test('月末', () {
      const r = Repeat.monthlyDay(0);
      final start = DateTime(2028, 1, 1);
      expect(r.occursOn(DateTime(2028, 2, 29), start), isTrue); // うるう年
      expect(r.occursOn(DateTime(2028, 2, 28), start), isFalse);
    });

    test('3か月ごと', () {
      const r = Repeat.monthlyDay(1, interval: 3);
      final start = DateTime(2026, 11, 1);
      expect(
        keys(
          r.occurrencesBetween(
            DateTime(2026, 11, 1),
            DateTime(2027, 6, 1),
            start,
          ),
        ),
        ['2026-11-01', '2027-02-01', '2027-05-01'],
      );
    });

    test('第2・第4月曜', () {
      const r = Repeat.monthlyNth({2, 4}, DateTime.monday);
      final start = DateTime(2026, 11, 1);
      expect(
        keys(
          r.occurrencesBetween(
            DateTime(2026, 11, 1),
            DateTime(2026, 12, 31),
            start,
          ),
        ),
        ['2026-11-09', '2026-11-23', '2026-12-14', '2026-12-28'],
      );
    });

    test('最終金曜は、月によって第4にも第5にもなる', () {
      const r = Repeat.monthlyNth({Repeat.lastWeek}, DateTime.friday);
      final start = DateTime(2026, 10, 1);
      expect(
        keys(
          r.occurrencesBetween(
            DateTime(2026, 10, 1),
            DateTime(2026, 11, 30),
            start,
          ),
        ),
        ['2026-10-30', '2026-11-27'],
      );
    });

    test('毎年。2/29 始まりは平年だと 2/28', () {
      const r = Repeat.yearly();
      final start = DateTime(2028, 2, 29);
      expect(r.occursOn(DateTime(2029, 2, 28), start), isTrue);
      expect(r.occursOn(DateTime(2032, 2, 29), start), isTrue);
      expect(r.occursOn(DateTime(2032, 2, 28), start), isFalse);
    });

    test('やった日から14日後', () {
      const r = Repeat.afterDone(14);
      final start = DateTime(2026, 11, 1);
      expect(r.nextAfterDone(start, null), start);
      expect(
        r.nextAfterDone(start, DateTime(2026, 11, 5)),
        DateTime(2026, 11, 19),
      );
      expect(
        keys(
          r.occurrencesBetween(
            DateTime(2026, 11, 1),
            DateTime(2026, 11, 30),
            start,
            lastDone: DateTime(2026, 11, 5),
          ),
        ),
        ['2026-11-19'],
      );
    });

    test('開始日より前は予定にならない', () {
      const r = Repeat.daily();
      expect(
        r.occursOn(DateTime(2026, 10, 31), DateTime(2026, 11, 1)),
        isFalse,
      );
    });

    test('曜日を選んでいない毎週は、予定を作らない', () {
      const r = Repeat.weekly({});
      expect(r.isValid, isFalse);
      expect(
        r.occurrencesBetween(
          DateTime(2026, 11, 1),
          DateTime(2026, 11, 30),
          DateTime(2026, 11, 1),
        ),
        isEmpty,
      );
    });
  });

  group('前後の予定日を探す', () {
    test('次の予定日', () {
      const r = Repeat.monthlyNth({2, 4}, DateTime.monday);
      final start = DateTime(2026, 11, 1);
      expect(
        r.nextOnOrAfter(DateTime(2026, 11, 10), start),
        DateTime(2026, 11, 23),
      );
      expect(
        r.nextOnOrAfter(DateTime(2026, 11, 23), start),
        DateTime(2026, 11, 23),
      );
    });

    test('毎年の次の予定日は1年先でも見つかる', () {
      const r = Repeat.yearly();
      final start = DateTime(2026, 12, 28);
      expect(
        r.nextOnOrAfter(DateTime(2026, 12, 29), start),
        DateTime(2027, 12, 28),
      );
    });

    test('直前の予定日', () {
      const r = Repeat.weekly({1});
      final start = DateTime(2026, 11, 2);
      expect(
        r.previousBefore(DateTime(2026, 11, 11), start),
        DateTime(2026, 11, 9),
      );
      expect(r.previousBefore(DateTime(2026, 11, 2), start), isNull);
    });

    test('1回だけの家事の直前の予定日は開始日', () {
      const r = Repeat.none();
      final start = DateTime(2026, 11, 5);
      expect(r.previousBefore(DateTime(2026, 11, 11), start), start);
      expect(r.previousBefore(DateTime(2026, 11, 5), start), isNull);
    });
  });

  group('説明文', () {
    final start = DateTime(2026, 11, 11);
    test('よく使う形', () {
      expect(const Repeat.daily().describe(start), '毎日');
      expect(const Repeat.daily(3).describe(start), '3日ごと');
      expect(const Repeat.weekly({2, 5}).describe(start), '毎週 火・金');
      expect(const Repeat.weekly(Repeat.weekdaysOnly).describe(start), '毎週 平日');
      expect(const Repeat.weekly({6}, interval: 2).describe(start), '2週ごと 土');
      expect(const Repeat.monthlyDay(0).describe(start), '毎月 月末');
      expect(const Repeat.monthlyNth({2, 4}, 1).describe(start), '毎月 第2・第4 月曜');
      expect(const Repeat.yearly().describe(start), '毎年 11月11日');
      expect(const Repeat.afterDone(14).describe(start), 'やった日から14日後');
    });
  });

  test('保存して読み戻しても同じルールになる', () {
    const rules = [
      Repeat.none(),
      Repeat.daily(2),
      Repeat.weekly({1, 3, 5}, interval: 2),
      Repeat.monthlyDay(0, interval: 3),
      Repeat.monthlyNth({2, Repeat.lastWeek}, DateTime.sunday),
      Repeat.yearly(),
      Repeat.afterDone(30),
    ];
    for (final r in rules) {
      expect(Repeat.fromJson(r.toJson()), r);
    }
  });
}

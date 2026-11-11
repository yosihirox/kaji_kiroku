/// 日付まわりの小さな道具。
///
/// 端末の時刻やタイムゾーンに左右されないよう、予定日は「年月日だけの DateTime」
/// （ローカル時刻の 0:00）で扱う。
library;

const weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

/// 年月日だけにした日付。
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 日付を足し引きする。夏時間のある地域でもずれないよう、コンストラクタで計算する。
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// [a] から [b] までの日数（b が後なら正）。
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// 月曜はじまりの週の月曜日。
DateTime startOfWeek(DateTime d) => addDays(dateOnly(d), -(d.weekday - 1));

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _pad2(int n) => n.toString().padLeft(2, '0');

/// 保存用の「2026-11-11」形式。
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_pad2(d.month)}-${_pad2(d.day)}';

DateTime parseDateKey(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// 「11/12（水）」
String formatDate(DateTime d) =>
    '${d.month}/${d.day}（${weekdayLabels[d.weekday - 1]}）';

/// 「11月12日（水）」
String formatDateLong(DateTime d) =>
    '${d.month}月${d.day}日（${weekdayLabels[d.weekday - 1]}）';

/// 0:00 からの分を「7:30」にする。
String formatMinutes(int minutes) => '${minutes ~/ 60}:${_pad2(minutes % 60)}';

/// 今日から見た呼び方。「今日」「明日」「あさって」「きのう」、それ以外は日付。
String relativeDayLabel(DateTime day, DateTime today) {
  switch (daysBetween(today, day)) {
    case 0:
      return '今日';
    case 1:
      return '明日';
    case 2:
      return 'あさって';
    case -1:
      return 'きのう';
    default:
      return formatDate(day);
  }
}

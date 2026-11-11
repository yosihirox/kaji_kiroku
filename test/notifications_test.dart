import 'package:flutter_test/flutter_test.dart';
import 'package:kaji_kiroku/domain/agenda.dart';
import 'package:kaji_kiroku/domain/models.dart';
import 'package:kaji_kiroku/domain/notifications.dart';
import 'package:kaji_kiroku/domain/recurrence.dart';

void main() {
  final today = DateTime(2026, 11, 11);

  Chore chore(
    String name, {
    String? assignee,
    int? due,
    String genre = 'cleaning',
    DateTime? start,
    Repeat repeat = const Repeat.daily(),
  }) => Chore(
    id: name,
    name: name,
    genreId: genre,
    start: start ?? today,
    repeat: repeat,
    assigneeId: assignee,
    dueMinutes: due,
  );

  List<PlannedNotice> plan(
    List<Chore> chores, {
    NotificationSettings settings = const NotificationSettings(),
    List<Record> records = const [],
  }) => planNotices(
    agenda: buildAgenda(chores: chores, records: records, today: today),
    settings: settings,
    memberId: 'me',
  );

  test('朝のまとめ、期限前、やり忘れの順に並ぶ', () {
    final notices = plan([
      chore('燃えるゴミ出し', assignee: 'me', due: 8 * 60),
      chore('食器洗い', assignee: 'papa'),
      chore(
        '粗大ゴミの申し込み',
        repeat: const Repeat.none(),
        start: DateTime(2026, 11, 9),
      ),
    ]);
    expect(notices.map((n) => n.kind), [
      NoticeKind.morning,
      NoticeKind.beforeDue,
      NoticeKind.overdue,
    ]);
    expect(notices[0].minutes, 7 * 60);
    expect(notices[0].body, '今日の家事は2件、うちあなたの担当は1件です。やり忘れが1件あります。');
    expect(notices[1].minutes, 7 * 60 + 30);
    expect(notices[1].title, 'もうすぐ「燃えるゴミ出し」');
    expect(notices[2].minutes, 20 * 60);
    expect(notices[2].title, 'まだ終わっていない家事が2件あります');
  });

  test('やることがない日は何も届かない', () {
    expect(plan([]), isEmpty);
  });

  test('種類ごとに止められる', () {
    final chores = [chore('燃えるゴミ出し', assignee: 'me', due: 8 * 60)];
    final notices = plan(
      chores,
      settings: const NotificationSettings(
        morningSummary: false,
        overdueReminder: false,
      ),
    );
    expect(notices.map((n) => n.kind), [NoticeKind.beforeDue]);
  });

  test('止めたジャンルの家事は数えない', () {
    final notices = plan([
      chore('ペットの散歩', genre: 'pet'),
      chore('食器洗い'),
    ], settings: const NotificationSettings(mutedGenreIds: {'pet'}));
    expect(notices.first.body, startsWith('今日の家事は1件'));
  });

  test('ほかの人の担当は、期限前とやり忘れでは知らせない', () {
    final notices = plan([chore('ゴミ出し', assignee: 'papa', due: 8 * 60)]);
    expect(notices.map((n) => n.kind), [NoticeKind.morning]);
  });

  test('おやすみ時間に入る通知は、音なしの印が付く', () {
    final notices = plan(
      [chore('早朝のゴミ出し', assignee: 'me', due: 6 * 60 + 30)],
      settings: const NotificationSettings(
        morningMinutes: 7 * 60,
        quietStart: 22 * 60,
        quietEnd: 7 * 60,
      ),
    );
    final before = notices.firstWhere((n) => n.kind == NoticeKind.beforeDue);
    expect(before.minutes, 6 * 60);
    expect(before.quiet, isTrue);
    expect(
      notices.firstWhere((n) => n.kind == NoticeKind.morning).quiet,
      isFalse,
    );
  });

  test('おやすみ時間は日付をまたげる', () {
    const s = NotificationSettings(quietStart: 22 * 60, quietEnd: 7 * 60);
    expect(s.isQuiet(23 * 60), isTrue);
    expect(s.isQuiet(3 * 60), isTrue);
    expect(s.isQuiet(7 * 60), isFalse);
    expect(s.isQuiet(12 * 60), isFalse);
    expect(
      const NotificationSettings(quietHours: false).isQuiet(23 * 60),
      isFalse,
    );
  });

  test('完了した家事は、やり忘れリマインドに入らない', () {
    final c = chore('食器洗い', assignee: 'me');
    final notices = plan(
      [c],
      records: [
        Record(
          id: 'r',
          choreId: c.id,
          date: today,
          status: RecordStatus.done,
          doneById: 'me',
          at: DateTime(2026, 11, 11, 8),
        ),
      ],
    );
    expect(notices.any((n) => n.kind == NoticeKind.overdue), isFalse);
  });
}

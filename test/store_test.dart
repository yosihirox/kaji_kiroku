import 'package:flutter_test/flutter_test.dart';
import 'package:kaji_kiroku/models.dart';
import 'package:kaji_kiroku/recurrence.dart';
import 'package:kaji_kiroku/store.dart';

void main() {
  // 2026-11-11（水）
  var now = DateTime(2026, 11, 11, 9);
  late AppStore store;
  late MemoryStorage storage;

  setUp(() async {
    now = DateTime(2026, 11, 11, 9);
    storage = MemoryStorage();
    store = AppStore(storage, clock: () => now);
    await store.load();
  });

  Chore addChore(String name, Repeat repeat, DateTime start, {String? assignee}) {
    final c = Chore(
      id: store.newId(),
      name: name,
      genreId: 'cleaning',
      startDate: start,
      repeat: repeat,
      assigneeId: assignee,
    );
    store.saveChore(c);
    return c;
  }

  test('初回起動でメンバー1人と初期ジャンル8つができる', () {
    expect(store.members, hasLength(1));
    expect(store.currentMemberId, store.members.first.id);
    expect(store.genres.map((g) => g.name),
        ['料理', '買い物', '洗濯', '掃除', 'ペット', '子守', '教育', 'その他']);
  });

  test('1週間分の予定が日付順に並ぶ', () {
    addChore('ゴミ出し', const Repeat(type: RepeatType.weekly, weekdays: {1, 4}),
        DateTime(2026, 11, 1));
    final days = store.upcoming();
    expect(days, hasLength(7));
    expect(days.first.date, DateTime(2026, 11, 11));
    final withItems = [
      for (final d in days)
        if (d.items.isNotEmpty) d.date
    ];
    expect(withItems, [DateTime(2026, 11, 12), DateTime(2026, 11, 16)]);
  });

  test('担当予定者と実際にやった人を別々に残せる', () async {
    await store.addMember('パパ');
    final me = store.members[0];
    final papa = store.members[1];
    final c = addChore('風呂掃除', const Repeat(type: RepeatType.daily),
        DateTime(2026, 11, 11), assignee: papa.id);
    await store.complete(c, DateTime(2026, 11, 11));
    final item = store.upcoming().first.items.single;
    expect(item.chore.assigneeId, papa.id);
    expect(item.record!.doneById, me.id);
    expect(item.isDone, isTrue);
  });

  test('期限切れは家事ごとに最新の1回だけ出る', () {
    addChore('食器洗い', const Repeat(type: RepeatType.daily), DateTime(2026, 11, 1));
    final overdue = store.overdue();
    expect(overdue, hasLength(1));
    expect(overdue.single.date, DateTime(2026, 11, 10));
  });

  test('完了すると期限切れから消え、取り消すと戻る', () async {
    final c = addChore('洗濯槽の掃除', const Repeat.none(), DateTime(2026, 11, 5));
    expect(store.overdue(), hasLength(1));
    await store.complete(c, DateTime(2026, 11, 5));
    expect(store.overdue(), isEmpty);
    await store.undo(c, DateTime(2026, 11, 5));
    expect(store.overdue(), hasLength(1));
  });

  test('先の予定を前倒しで完了できる', () async {
    final c = addChore('シーツ交換', const Repeat(type: RepeatType.weekly, weekdays: {6}),
        DateTime(2026, 11, 1));
    await store.complete(c, DateTime(2026, 11, 14));
    final sat = store.upcoming().firstWhere((d) => d.date == DateTime(2026, 11, 14));
    expect(sat.items.single.isDone, isTrue);
  });

  test('やった日からN日後は完了日から次回が決まる', () async {
    final c = addChore('排水口の掃除', const Repeat(type: RepeatType.afterDone, interval: 3),
        DateTime(2026, 11, 11));
    await store.complete(c, DateTime(2026, 11, 11));
    final days = store.upcoming();
    final dated = {
      for (final d in days)
        for (final i in d.items) i.date: i.isDone
    };
    expect(dated, {DateTime(2026, 11, 11): true, DateTime(2026, 11, 14): false});
  });

  test('ついでにやった家事はがんばりに数えられる', () async {
    await store.recordUnplannedByName('冷蔵庫の掃除', 'cleaning');
    final done = store.doneBetween(DateTime(2026, 11, 9), DateTime(2026, 11, 15));
    expect(done, hasLength(1));
    expect(store.activeChores, isEmpty); // 一覧には出ない
    expect(store.upcoming().first.items.single.record!.unplanned, isTrue);
  });

  test('バッジは期限切れ＋今日の未完了', () async {
    addChore('食器洗い', const Repeat(type: RepeatType.daily), DateTime(2026, 11, 1));
    expect(store.badgeCount(), 2);
  });

  test('保存して読み直しても同じ', () async {
    addChore('ゴミ出し', const Repeat(type: RepeatType.monthlyNthWeekday, nths: {2, 4}),
        DateTime(2026, 11, 1));
    await store.addGenre('車', 'car', 0xFF4E79A7);
    final again = AppStore(storage, clock: () => now);
    await again.load();
    expect(again.chores.single.repeat.nths, {2, 4});
    expect(again.genres.last.name, '車');
  });
}

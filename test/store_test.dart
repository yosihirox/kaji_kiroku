import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaji_kiroku/data/storage.dart';
import 'package:kaji_kiroku/domain/agenda.dart';
import 'package:kaji_kiroku/domain/catalog.dart';
import 'package:kaji_kiroku/domain/dates.dart';
import 'package:kaji_kiroku/domain/models.dart';
import 'package:kaji_kiroku/domain/recurrence.dart';
import 'package:kaji_kiroku/domain/report.dart';
import 'package:kaji_kiroku/state/app_store.dart';

void main() {
  // 2026-11-11 は水曜日
  var now = DateTime(2026, 11, 11, 9);
  late MemoryStorage storage;
  late AppStore store;
  late String me;
  late String papa;

  setUp(() async {
    now = DateTime(2026, 11, 11, 9);
    storage = MemoryStorage();
    store = AppStore(storage, clock: () => now);
    await store.load();
    store.completeOnboarding(myName: 'わたし', familyNames: ['パパ']);
    me = store.members[0].id;
    papa = store.members[1].id;
  });

  Chore add(
    String name,
    Repeat repeat,
    DateTime start, {
    String? assignee,
    int? due,
    String genre = 'cleaning',
  }) {
    final c = Chore(
      id: store.newChoreId(),
      name: name,
      genreId: genre,
      start: start,
      repeat: repeat,
      assigneeId: assignee,
      dueMinutes: due,
    );
    store.saveChore(c);
    return c;
  }

  List<String> names(Iterable<Occurrence> items) =>
      items.map((o) => o.chore.name).toList();

  group('はじめての設定', () {
    test('設定前は家族がいない', () async {
      final fresh = AppStore(MemoryStorage(), clock: () => now);
      await fresh.load();
      expect(fresh.onboarded, isFalse);
      expect(fresh.members, isEmpty);
      expect(fresh.genres.map((g) => g.name), [
        '料理',
        '買い物',
        '洗濯',
        '掃除',
        'ペット',
        '子守',
        '教育',
        'その他',
      ]);
    });

    test('名前と家族、選んだ家事が登録される', () async {
      final fresh = AppStore(MemoryStorage(), clock: () => now);
      await fresh.load();
      fresh.completeOnboarding(
        myName: ' なな ',
        familyNames: ['しろくま', ''],
        templates: choreTemplates.where((t) => t.starter).toList(),
      );
      expect(fresh.onboarded, isTrue);
      expect(fresh.members.map((m) => m.name), ['なな', 'しろくま']);
      expect(fresh.currentMember!.name, 'なな');
      expect(fresh.members[0].color, isNot(fresh.members[1].color));
      expect(fresh.chores, isNotEmpty);
      expect(fresh.shoppingLists.map((l) => l.name), ['スーパー', 'ドラッグストア']);
    });
  });

  group('やること', () {
    test('1週間分が日付順に並ぶ', () {
      add('ゴミ出し', const Repeat.weekly({1, 4}), DateTime(2026, 11, 1));
      add('食器洗い', const Repeat.daily(), DateTime(2026, 11, 11));
      final days = store.agenda.days;
      expect(days, hasLength(7));
      expect(days.first.date, DateTime(2026, 11, 11));
      expect(names(days[0].items), ['食器洗い']);
      expect(names(days[1].items), ['ゴミ出し', '食器洗い']); // 11/12（木）
      expect(names(days[5].items), ['ゴミ出し', '食器洗い']); // 11/16（月）
    });

    test('時刻を決めた家事が先に並ぶ', () {
      add('あとで', const Repeat.daily(), now);
      add('朝いち', const Repeat.daily(), now, due: 8 * 60);
      expect(names(store.agenda.todayItems.items), ['朝いち', 'あとで']);
    });

    test('完了は「この端末の人」、やった人を選ぶこともできる', () {
      add('食器洗い', const Repeat.daily(), now, assignee: me);
      var item = store.agenda.todayItems.items.single;
      final record = store.complete(item);
      expect(record.doneById, me);

      store.setDoneBy(record.id, papa);
      item = store.agenda.todayItems.items.single;
      expect(item.isDone, isTrue);
      expect(item.record!.doneById, papa);
      // 担当予定者は変わらない
      expect(item.chore.assigneeId, me);
    });

    test('取り消すと未完了に戻る', () {
      add('食器洗い', const Repeat.daily(), now);
      final record = store.complete(store.agenda.todayItems.items.single);
      store.undoRecord(record.id);
      expect(store.agenda.todayItems.items.single.isPending, isTrue);
    });

    test('先の日の予定も前倒しで完了できる', () {
      add('ゴミ出し', const Repeat.weekly({4}), DateTime(2026, 11, 1));
      final thursday = store.agenda.days[1].items.single;
      store.complete(thursday);
      expect(store.agenda.days[1].items.single.isDone, isTrue);
      // がんばりには、実際にやった今日の分として数える
      final report = store.report(ReportPeriod.week(store.today));
      expect(report.daily[2].total, 1); // 月火水の「水」
    });

    test('スキップした予定は今日の欄にスキップとして残る', () {
      add('食器洗い', const Repeat.daily(), now);
      store.skip(store.agenda.todayItems.items.single);
      final item = store.agenda.todayItems.items.single;
      expect(item.isSkipped, isTrue);
      expect(store.badgeCount, 0);
    });
  });

  group('やり忘れ', () {
    test('1回だけの家事は、終わらせるまで残る', () {
      add('粗大ゴミの申し込み', const Repeat.none(), DateTime(2026, 10, 20));
      expect(names(store.agenda.overdue), ['粗大ゴミの申し込み']);
      store.complete(store.agenda.overdue.single);
      expect(store.agenda.overdue, isEmpty);
    });

    test('繰り返す家事は直近の1回分だけ出る', () {
      add('トイレ掃除', const Repeat.weekly({6}), DateTime(2026, 10, 1));
      final overdue = store.agenda.overdue;
      expect(overdue, hasLength(1));
      expect(overdue.single.date, DateTime(2026, 11, 7));
    });

    test('今日も予定がある家事は、今日の分に切り替わる', () {
      add('食器洗い', const Repeat.daily(), DateTime(2026, 11, 1));
      expect(store.agenda.overdue, isEmpty);
      expect(names(store.agenda.todayItems.items), ['食器洗い']);
    });

    test('やり忘れを今日片付けると、今日の欄に完了として出る', () {
      add('トイレ掃除', const Repeat.weekly({6}), DateTime(2026, 10, 1));
      store.complete(store.agenda.overdue.single, doneById: papa);
      expect(store.agenda.overdue, isEmpty);
      final today = store.agenda.todayItems.items.single;
      expect(today.isDone, isTrue);
      expect(today.date, DateTime(2026, 11, 7));
      expect(today.record!.doneById, papa);
    });

    test('スキップしたやり忘れは消える', () {
      add('トイレ掃除', const Repeat.weekly({6}), DateTime(2026, 10, 1));
      store.skip(store.agenda.overdue.single);
      expect(store.agenda.overdue, isEmpty);
      expect(store.agenda.todayItems.items, isEmpty);
    });

    test('バッジは やり忘れ＋今日の未完了。自分の担当だけにもできる', () {
      add('自分の', const Repeat.daily(), now, assignee: me);
      add('パパの', const Repeat.daily(), now, assignee: papa);
      add('だれでも', const Repeat.none(), DateTime(2026, 11, 9));
      expect(store.badgeCount, 3);
      store.updateNotifications(
        store.notifications.copyWith(badgeMineOnly: true),
      );
      expect(store.badgeCount, 2);
      store.setCurrentMember(papa);
      expect(store.badgeCount, 2);
    });
  });

  group('やった日からN日後', () {
    test('完了すると次回がやった日から数え直される', () {
      final c = add(
        '排水口の掃除',
        const Repeat.afterDone(14),
        DateTime(2026, 11, 1),
      );
      // 11/1 の予定を過ぎているので、やり忘れに出る
      expect(names(store.agenda.overdue), ['排水口の掃除']);

      store.complete(store.agenda.overdue.single);
      expect(store.agenda.overdue, isEmpty);
      // 今日の欄に完了として出て、次回は 14 日後
      expect(store.agenda.todayItems.items.single.isDone, isTrue);
      expect(store.nextDue(c), DateTime(2026, 11, 25));

      now = DateTime(2026, 11, 25, 9);
      store.refreshClock();
      final item = store.agenda.todayItems.items.single;
      expect(item.isPending, isTrue);
      expect(item.date, DateTime(2026, 11, 25));
    });

    test('取り消すと元の予定日に戻る', () {
      final c = add('排水口の掃除', const Repeat.afterDone(14), now);
      final record = store.complete(store.agenda.todayItems.items.single);
      expect(store.nextDue(c), DateTime(2026, 11, 25));
      store.undoRecord(record.id);
      expect(store.nextDue(c), DateTime(2026, 11, 11));
    });

    test('3日後の予定を前倒しでやっても、次の予定が消えない', () {
      final c = add('水やり', const Repeat.afterDone(3), DateTime(2026, 11, 14));
      final ahead = store.agenda.days[3].items.single; // 11/14
      store.complete(ahead);
      expect(store.agenda.todayItems.items.single.isDone, isTrue);
      expect(store.nextDue(c), DateTime(2026, 11, 14));
      expect(store.agenda.days[3].items.single.isPending, isTrue);
    });
  });

  group('予定外の記録', () {
    test('登録済みの家事を「ついでにやった」と記録できる', () {
      final c = add(
        '冷蔵庫の掃除',
        const Repeat.monthlyDay(1),
        DateTime(2026, 11, 1),
      );
      store.recordUnplanned(c, doneById: papa);
      final item = store.agenda.todayItems.items.single;
      expect(item.isUnplanned, isTrue);
      expect(item.record!.doneById, papa);
      // 毎月1日の予定はそのまま
      expect(store.nextDue(c), DateTime(2026, 12, 1));
    });

    test('名前だけで記録すると、一覧には出ない家事として残る', () {
      store.recordUnplannedByName('玄関の掃き掃除', 'cleaning');
      store.recordUnplannedByName('玄関の掃き掃除', 'cleaning');
      expect(store.chores, isEmpty);
      expect(names(store.agenda.todayItems.items), ['玄関の掃き掃除', '玄関の掃き掃除']);
      final report = store.report(ReportPeriod.week(store.today));
      expect(report.members.first.byChore.single.count, 2);
    });
  });

  group('がんばり', () {
    test('実際にやった人ごとに、ジャンルと家事の内訳が出る', () {
      final dish = add('食器洗い', const Repeat.daily(), now, genre: 'cooking');
      final bath = add('お風呂掃除', const Repeat.daily(), now);
      store.complete(
        store.agenda.todayItems.items.firstWhere((o) => o.chore.id == dish.id),
        doneById: papa,
      );
      store.complete(
        store.agenda.todayItems.items.firstWhere((o) => o.chore.id == bath.id),
        doneById: papa,
      );
      store.recordUnplanned(dish, doneById: me);

      final report = store.report(ReportPeriod.week(store.today));
      expect(report.total, 3);
      final mine = report.members.firstWhere((m) => m.member!.id == me);
      final his = report.members.firstWhere((m) => m.member!.id == papa);
      expect(mine.count, 1);
      expect(his.count, 2);
      expect(
        his.byGenre.map((e) => e.key),
        containsAll(['cooking', 'cleaning']),
      );
      expect(report.maxMemberCount, 2);
    });

    test('スキップは数えない。0件の人も載る', () {
      add('食器洗い', const Repeat.daily(), now);
      store.skip(store.agenda.todayItems.items.single);
      final report = store.report(ReportPeriod.week(store.today));
      expect(report.total, 0);
      expect(report.members, hasLength(2));
    });

    test('外れたメンバーの記録はまとめて残る', () {
      add('食器洗い', const Repeat.daily(), now);
      store.complete(store.agenda.todayItems.items.single, doneById: papa);
      store.removeMember(papa);
      final report = store.report(ReportPeriod.week(store.today));
      expect(report.members, hasLength(2));
      expect(report.members.last.member, isNull);
      expect(report.members.last.count, 1);
    });

    test('先週・先月にさかのぼれる', () {
      final lastWeek = ReportPeriod.week(store.today, -1);
      expect(lastWeek.from, DateTime(2026, 11, 2));
      expect(lastWeek.to, DateTime(2026, 11, 8));
      final lastMonth = ReportPeriod.month(store.today, -1);
      expect(lastMonth.from, DateTime(2026, 10, 1));
      expect(lastMonth.to, DateTime(2026, 10, 31));
      expect(lastMonth.label, '2026年10月');
    });

    test('スタンプは1人1つ。同じものをもう一度送ると取り消し', () {
      add('食器洗い', const Repeat.daily(), now);
      final record = store.complete(
        store.agenda.todayItems.items.single,
        doneById: papa,
      );
      store.toggleThanks(record.id, 'thanks');
      store.toggleThanks(record.id, 'great');
      expect(store.thanksFor(record.id).single.stamp, 'great');
      final report = store.report(ReportPeriod.week(store.today));
      expect(
        report.members.firstWhere((m) => m.member!.id == papa).thanksReceived,
        1,
      );
      store.toggleThanks(record.id, 'great');
      expect(store.thanksFor(record.id), isEmpty);
    });
  });

  group('ジャンルと家事', () {
    test('自作ジャンルを消すと、家事は「その他」に移る', () {
      final g = store.addGenre('車', 'car', genreColors.first);
      final c = add('洗車', const Repeat.monthlyDay(1), now, genre: g.id);
      store.deleteGenre(g.id);
      expect(store.choreById(c.id)!.genreId, otherGenreId);
      expect(store.genres.any((x) => x.id == g.id), isFalse);
    });

    test('初期ジャンルは消せないが、非表示にできる', () {
      store.deleteGenre('pet');
      expect(store.genres.any((g) => g.id == 'pet'), isTrue);
      store.updateGenre('pet', hidden: true);
      expect(store.visibleGenres.any((g) => g.id == 'pet'), isFalse);
    });

    test('ジャンルを並べ替えられる', () {
      store.reorderGenres(3, 0); // 掃除を先頭へ
      expect(store.genres.first.name, '掃除');
      expect(store.genres[1].name, '料理');
    });

    test('記録のある家事を消しても、がんばりには残る', () {
      final c = add('食器洗い', const Repeat.daily(), now);
      store.complete(store.agenda.todayItems.items.single);
      store.deleteChore(c.id);
      expect(store.chores, isEmpty);
      final report = store.report(ReportPeriod.week(store.today));
      expect(report.members.first.byChore.single.name, '食器洗い');
    });

    test('メンバーを外すと、担当は「だれでも」に戻る', () {
      final c = add('食器洗い', const Repeat.daily(), now, assignee: papa);
      store.removeMember(papa);
      expect(store.choreById(c.id)!.assigneeId, isNull);
      // 最後の1人は外せない
      store.removeMember(me);
      expect(store.members, hasLength(1));
    });
  });

  group('買い物リスト', () {
    late String list;
    setUp(() => list = store.shoppingLists.first.id);

    test('追加してカゴに入れ、買い物おわりで「買い出し」が記録される', () {
      store.addShoppingItem(list, '牛乳', note: '2本');
      final egg = store.addShoppingItem(list, '卵')!;
      final tofu = store.addShoppingItem(list, '豆腐')!;
      expect(store.shoppingTodoCount, 3);

      store.updateShoppingItem(egg.id, inCart: true);
      store.updateShoppingItem(tofu.id, inCart: true);
      expect(store.shoppingTodoCount, 1);

      final trip = store.finishShopping(list, doneById: papa)!;
      expect(trip.count, 2);
      expect(store.shoppingItems(list).map((i) => i.name), ['牛乳']);

      final item = store.agenda.todayItems.items.single;
      expect(item.chore.name, '買い出し');
      expect(item.record!.note, 'スーパー・2点');
      expect(item.record!.doneById, papa);
      // 買い出し用の家事は一覧には出ない
      expect(store.chores, isEmpty);
    });

    test('カゴが空なら何も記録しない', () {
      store.addShoppingItem(list, '牛乳');
      expect(store.finishShopping(list), isNull);
      expect(store.records, isEmpty);
    });

    test('買い物おわりは取り消せる', () {
      final milk = store.addShoppingItem(list, '牛乳')!;
      store.updateShoppingItem(milk.id, inCart: true);
      final trip = store.finishShopping(list)!;
      store.undoShopping(trip);
      expect(store.shoppingItems(list).single.inCart, isTrue);
      expect(store.records, isEmpty);
    });

    test('同じ名前は二重に入らない', () {
      store.addShoppingItem(list, '牛乳');
      store.addShoppingItem(list, ' 牛乳 ');
      expect(store.shoppingItems(list), hasLength(1));
    });

    test('候補は、よく買うものが先で、いまリストにあるものは出ない', () {
      for (var i = 0; i < 2; i++) {
        final item = store.addShoppingItem(list, 'オートミール')!;
        store.updateShoppingItem(item.id, inCart: true);
        store.finishShopping(list);
      }
      store.addShoppingItem(list, '牛乳');
      final suggestions = store.shoppingSuggestions(list);
      expect(suggestions.first, 'オートミール');
      expect(suggestions, isNot(contains('牛乳')));
      expect(suggestions, contains('卵'));
    });

    test('リストを消すと中の品物も消える。最後の1つは消せない', () {
      final second = store.shoppingLists[1].id;
      store.addShoppingItem(second, '歯みがき粉');
      store.deleteShoppingList(second);
      expect(store.shoppingLists, hasLength(1));
      expect(store.shoppingTodoCount, 0);
      store.deleteShoppingList(list);
      expect(store.shoppingLists, hasLength(1));
    });
  });

  group('保存', () {
    test('保存したデータを読み戻せる', () async {
      final c = add(
        '資源ゴミ',
        const Repeat.monthlyNth({2, 4}, 1),
        now,
        assignee: papa,
        due: 8 * 60,
      );
      add('食器洗い', const Repeat.daily(), now);
      store.complete(store.agenda.todayItems.items.first);
      store.addShoppingItem(store.shoppingLists.first.id, '牛乳');
      store.updateNotifications(
        store.notifications.copyWith(
          morningMinutes: 6 * 60,
          mutedGenreIds: {'pet'},
        ),
      );
      store.setAppearance(Appearance.dark);
      await store.flush();

      final reloaded = AppStore(storage, clock: () => now);
      await reloaded.load();
      expect(reloaded.onboarded, isTrue);
      expect(reloaded.members.map((m) => m.name), ['わたし', 'パパ']);
      expect(reloaded.currentMemberId, me);
      final chore = reloaded.choreById(c.id)!;
      expect(chore.repeat, c.repeat);
      expect(chore.assigneeId, papa);
      expect(chore.dueMinutes, 480);
      expect(reloaded.records, hasLength(1));
      expect(reloaded.shoppingTodoCount, 1);
      expect(reloaded.notifications.morningMinutes, 360);
      expect(reloaded.notifications.mutedGenreIds, {'pet'});
      expect(reloaded.appearance, Appearance.dark);
    });

    test('試作版 0.1 のデータを引き継げる', () async {
      final v1 = jsonEncode({
        'version': 1,
        'members': [
          {'id': 'm1', 'name': 'わたし', 'color': 0xFF4E79A7},
          {'id': 'm2', 'name': 'パパ', 'color': 0xFFE15759},
        ],
        'genres': [
          {
            'id': 'cleaning',
            'name': '掃除',
            'icon': 'cleaning',
            'color': 0xFF76B7B2,
            'builtIn': true,
            'hidden': false,
            'order': 3,
          },
          {
            'id': 'other',
            'name': 'その他',
            'icon': 'other',
            'color': 0xFF8C8C8C,
            'builtIn': true,
            'hidden': false,
            'order': 7,
          },
        ],
        'chores': [
          {
            'id': 'c1',
            'name': '資源ゴミ',
            'genreId': 'cleaning',
            'start': '2026-10-02',
            'repeat': {
              'type': 'monthlyNthWeekday',
              'interval': 1,
              'weekdays': [],
              'monthDay': 2,
              'nths': [2, 4],
              'weekday': 1,
            },
            'assignee': 'm2',
            'memo': '',
            'archived': false,
          },
        ],
        'records': [
          {
            'id': 'r1',
            'choreId': 'c1',
            'date': '2026-11-09',
            'status': 'done',
            'doneBy': 'm2',
            'at': '2026-11-09T08:00:00.000',
            'unplanned': false,
          },
        ],
        'currentMember': 'm1',
      });
      final storage = MemoryStorage({AppStore.legacyStorageKey: v1});
      final old = AppStore(storage, clock: () => now);
      await old.load();
      // 引き継いだら、すぐ新しい形で保存される（前の版のデータも残す）
      await old.flush();
      expect(storage.values[AppStore.storageKey], isNotNull);
      expect(storage.values[AppStore.legacyStorageKey], v1);

      expect(old.onboarded, isTrue);
      expect(old.members.map((m) => m.name), ['わたし', 'パパ']);
      expect(old.members.first.color, memberColors.first);
      expect(old.genreById('cleaning').color, defaultGenres()[3].color);
      expect(old.chores.single.repeat, const Repeat.monthlyNth({2, 4}, 1));
      expect(old.agenda.overdue, isEmpty); // 11/9 の分は完了済み
      expect(old.shoppingLists, isNotEmpty);
      final report = old.report(ReportPeriod.week(old.today));
      expect(report.members[1].count, 1);
    });

    test('壊れたデータは別の場所に残して、空の状態から始める', () async {
      final broken = MemoryStorage({AppStore.storageKey: '{こわれている'});
      final s = AppStore(broken, clock: () => now);
      await s.load();
      expect(s.onboarded, isFalse);
      expect(broken.values[AppStore.brokenBackupKey], '{こわれている');
    });

    test('書き出したデータを読み込める。おかしな文字列は受け付けない', () async {
      add('食器洗い', const Repeat.daily(), now);
      final backup = store.exportData();
      final other = AppStore(MemoryStorage(), clock: () => now);
      await other.load();
      expect(other.importData('こんにちは'), isFalse);
      expect(other.importData('{"version": 99}'), isFalse);
      expect(other.importData(backup), isTrue);
      expect(other.chores.single.name, '食器洗い');
      expect(other.onboarded, isTrue);
    });

    test('すべて消すと、はじめての設定に戻る', () {
      add('食器洗い', const Repeat.daily(), now);
      store.resetAll();
      expect(store.onboarded, isFalse);
      expect(store.chores, isEmpty);
      expect(store.members, isEmpty);
    });
  });

  test('日付が変わると、やることが新しい日に切り替わる', () {
    add('1回だけ', const Repeat.none(), DateTime(2026, 11, 11));
    var notified = 0;
    store.addListener(() => notified++);
    store.refreshClock();
    expect(notified, 0);

    now = DateTime(2026, 11, 12, 0, 1);
    store.refreshClock();
    expect(notified, 1);
    expect(store.agenda.today, DateTime(2026, 11, 12));
    expect(names(store.agenda.overdue), ['1回だけ']);
    expect(dateKey(store.agenda.days.first.date), '2026-11-12');
  });
}

// 画面を実際に操作して確かめるテスト。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaji_kiroku/app.dart';
import 'package:kaji_kiroku/data/storage.dart';
import 'package:kaji_kiroku/domain/catalog.dart';
import 'package:kaji_kiroku/domain/dates.dart';
import 'package:kaji_kiroku/domain/models.dart';
import 'package:kaji_kiroku/domain/recurrence.dart';
import 'package:kaji_kiroku/state/app_store.dart';

/// 2026-11-11（水）の夕方、という設定。
final _now = DateTime(2026, 11, 11, 18, 30);

Future<AppStore> _newStore([MemoryStorage? storage]) async {
  final store = AppStore(storage ?? MemoryStorage(), clock: () => _now);
  await store.load();
  return store;
}

/// はじめての設定を済ませ、最初の家事が入った状態。
Future<AppStore> _readyStore([MemoryStorage? storage]) async {
  final store = await _newStore(storage);
  store.completeOnboarding(
    myName: 'なな',
    familyNames: ['しろくま'],
    templates: choreTemplates.where((t) => t.starter).toList(),
  );
  return store;
}

Future<void> _pumpApp(
  WidgetTester tester,
  AppStore store, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(KajiApp(store: store));
  await tester.pumpAndSettle();
}

/// 下のタブを切り替える。
Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// 出ているお知らせ（スナックバー）が消えるまで待つ。
Future<void> _waitNotice(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('はじめての設定を終えると、ホームが開いて保存される', (tester) async {
    final storage = MemoryStorage();
    final store = await _newStore(storage);
    await _pumpApp(tester, store);

    expect(find.text('家事きろく'), findsOneWidget);
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();

    // 名前を入れるまでは進めない
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'つぎへ'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField).at(0), 'なな');
    await tester.enterText(find.byType(TextField).at(1), 'しろくま');
    await tester.pump();
    await tester.tap(find.text('つぎへ'));
    await tester.pumpAndSettle();

    final starters = choreTemplates.where((t) => t.starter).length;
    await tester.tap(find.text('$starters件の家事ではじめる'));
    await tester.pumpAndSettle();

    expect(find.text('今日のやること'), findsOneWidget);
    expect(store.onboarded, isTrue);
    expect(store.members.map((m) => m.name), ['なな', 'しろくま']);
    expect(store.currentMember?.name, 'なな');
    expect(store.chores, hasLength(starters));

    // 開き直しても残っている
    await store.flush();
    final reopened = await _newStore(storage);
    expect(reopened.onboarded, isTrue);
    expect(reopened.chores, hasLength(starters));
  });

  testWidgets('丸をタップすると完了になり、取り消せる', (tester) async {
    final store = await _readyStore();
    await _pumpApp(tester, store);
    final pending = find.byTooltip('完了にする').evaluate().length;
    expect(pending, greaterThan(0));

    await tester.tap(find.byTooltip('完了にする').first);
    await tester.pumpAndSettle();
    expect(store.records, hasLength(1));
    expect(store.records.single.isDone, isTrue);
    expect(store.records.single.doneById, store.currentMemberId);
    expect(find.byTooltip('完了にする'), findsNWidgets(pending - 1));
    expect(find.byTooltip('完了を取り消す'), findsOneWidget);

    await tester.tap(find.text('取り消す'));
    await tester.pumpAndSettle();
    expect(store.records, isEmpty);
    expect(find.byTooltip('完了にする'), findsNWidgets(pending));
    await _waitNotice(tester);
  });

  testWidgets('家族がやった家事として記録できる', (tester) async {
    final store = await _readyStore();
    final kuma = store.members[1];
    await _pumpApp(tester, store);

    // 家事の行をタップ → やった人をえらぶ
    await tester.tap(find.text('食器洗い').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(kuma.name).last);
    await tester.pumpAndSettle();

    expect(store.records.single.doneById, kuma.id);
    await _waitNotice(tester);
  });

  testWidgets('予定になかった家事を「ついでに」記録できる', (tester) async {
    final store = await _readyStore();
    await _pumpApp(tester, store);

    await tester.tap(find.text('やったことを記録'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '玄関の掃き掃除');
    await tester.pumpAndSettle();
    final button = find.text('「玄関の掃き掃除」を記録');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    final record = store.records.single;
    expect(record.unplanned, isTrue);
    expect(record.isDone, isTrue);
    expect(store.choreById(record.choreId)?.name, '玄関の掃き掃除');
    // 今日のところに、やったこととして出る
    expect(find.text('玄関の掃き掃除'), findsOneWidget);
    await _waitNotice(tester);
  });

  testWidgets('やったことを記録: えらんでから「完了」でまとめて記録する', (tester) async {
    final store = await _readyStore();
    await _pumpApp(tester, store);

    await tester.tap(find.text('やったことを記録'));
    await tester.pumpAndSettle();
    final names = [store.chores[0].name, store.chores[1].name];
    for (final name in names) {
      await tester.ensureVisible(find.text(name).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }
    // えらんだだけでは、まだ記録されない
    expect(store.records, isEmpty);

    await tester.ensureVisible(find.text('完了（2件）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完了（2件）'));
    await tester.pumpAndSettle();
    expect(store.records, hasLength(2));
    expect(store.records.every((r) => r.unplanned && r.isDone), isTrue);
    await _waitNotice(tester);
  });

  testWidgets('完了のお知らせは3秒で消え、タップやタブの切り替えでも消える', (tester) async {
    final store = await _readyStore();
    await _pumpApp(tester, store);

    Future<void> complete() async {
      await tester.tap(find.byTooltip('完了にする').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('取り消す'), findsOneWidget);
    }

    // 何もしなくても3秒ほどで消える
    await complete();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('取り消す'), findsNothing);

    // 画面のどこかをタップすると消える
    await complete();
    await tester.tapAt(const Offset(387, 400));
    await tester.pumpAndSettle();
    expect(find.text('取り消す'), findsNothing);

    // タブを切り替えると消える
    await complete();
    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('取り消す'), findsNothing);
  });

  testWidgets('ホーム: カレンダーで日付をえらぶと、その日の家事が見られる', (tester) async {
    final store = await _readyStore();
    await _pumpApp(tester, store);
    final today = store.today;
    final other = today.day == 15 ? 14 : 15;

    // 欄外タップでは日付は変わらない
    await tester.tap(find.byTooltip('カレンダーで日付をえらぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$other'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('今日のやること'), findsOneWidget);

    // 「決定」でその日に切り替わる
    await tester.tap(find.byTooltip('カレンダーで日付をえらぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$other'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    expect(find.text('この日の家事'), findsOneWidget);
    expect(
      find.text(formatDateLong(DateTime(today.year, today.month, other))),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('今日に戻る'));
    await tester.tap(find.text('今日に戻る'));
    await tester.pumpAndSettle();
    expect(find.text('今日のやること'), findsOneWidget);
  });

  testWidgets('メッセージ: 送るとホームとがんばりに出て、送った本人だけが消せる', (tester) async {
    final store = await _readyStore();
    final kuma = store.members[1];
    // 今日いちばん家事をした人が、最初から宛先になる
    store.complete(store.agenda.todayItems.items.first, doneById: kuma.id);
    await _pumpApp(tester, store);

    await tester.tap(find.text('メッセージを送る'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'いつもありがとう！');
    await tester.pumpAndSettle();
    await tester.tap(find.text('送信'));
    await tester.pumpAndSettle();

    final message = store.recentMessages.single;
    expect(message.toId, kuma.id);
    expect(message.fromId, store.currentMemberId);
    expect(find.textContaining('いつもありがとう！'), findsOneWidget);
    expect(find.byTooltip('メッセージを削除'), findsOneWidget);
    await _waitNotice(tester);

    await _openTab(tester, 'がんばり');
    expect(find.text('この1週間のメッセージ'), findsOneWidget);
    expect(find.textContaining('いつもありがとう！'), findsOneWidget);

    // 受け取った人には × が出ない
    store.setCurrentMember(kuma.id);
    await tester.pumpAndSettle();
    expect(find.byTooltip('メッセージを削除'), findsNothing);

    // 送った本人は、確かめてから消せる
    store.setCurrentMember(message.fromId);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('メッセージを削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('いいえ'));
    await tester.pumpAndSettle();
    expect(store.recentMessages, hasLength(1));
    await tester.tap(find.byTooltip('メッセージを削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('はい'));
    await tester.pumpAndSettle();
    expect(store.recentMessages, isEmpty);
  });

  testWidgets('買い物: 数は左に出て、左スワイプの「削除」で消せる', (tester) async {
    final store = await _readyStore();
    final list = store.shoppingLists.first.id;
    store.addShoppingItem(list, '牛乳');
    await _pumpApp(tester, store);
    await _openTab(tester, '買い物');

    await tester.tap(find.text('牛乳'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('2本'), findsOneWidget);
    expect(
      tester.getCenter(find.text('2本')).dx,
      lessThan(tester.getTopLeft(find.text('牛乳')).dx),
    );

    // 「よく買うもの」をしまう
    expect(find.text('卵'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('卵'), findsNothing);

    expect(find.text('削除'), findsNothing);
    await tester.drag(find.text('牛乳'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(store.shoppingItems(list), isEmpty);
  });

  testWidgets('買い物: 「＋ リスト」はその場で入力できる', (tester) async {
    final store = await _readyStore();
    await _pumpApp(tester, store);
    await _openTab(tester, '買い物');
    final before = store.shoppingLists.length;

    await tester.ensureVisible(find.widgetWithText(TextField, 'リスト'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'リスト'), 'ホームセンター');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(store.shoppingLists, hasLength(before + 1));
    expect(store.shoppingLists.last.name, 'ホームセンター');
  });

  testWidgets('家事を自分で作って登録できる', (tester) async {
    final store = await _readyStore();
    await _pumpApp(tester, store);
    final before = store.chores.length;

    await tester.tap(find.text('家事を追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自分で作る'));
    await tester.pumpAndSettle();

    // 名前がないと保存できない
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.chores, hasLength(before));

    await tester.enterText(find.byType(TextField).first, '窓ふき');
    await tester.tap(find.text('毎週'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final chore = store.chores.singleWhere((c) => c.name == '窓ふき');
    expect(chore.repeat.type, RepeatType.weekly);
    expect(chore.repeat.isValid, isTrue);
    // 今日（水曜）はじまりなので、今日のやることに出る
    expect(find.text('窓ふき'), findsOneWidget);
    await _waitNotice(tester);
  });

  testWidgets('買い物: 追加 → カゴに入れる → 買い物おわりで記録が残る', (tester) async {
    final store = await _readyStore();
    await _pumpApp(tester, store);
    await _openTab(tester, '買い物');

    await tester.enterText(find.widgetWithText(TextField, '買うものを追加'), '牛乳');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('牛乳'), findsOneWidget);
    expect(store.shoppingTodoCount, 1);

    await tester.tap(find.byTooltip('カゴに入れた'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('買い物おわり（1点）'));
    await tester.pumpAndSettle();

    expect(store.shoppingTodoCount, 0);
    expect(store.shoppingItems(store.shoppingLists.first.id), isEmpty);
    expect(store.records.single.choreId, shoppingTripChoreId);

    // 取り消すと、リストに戻る
    await tester.tap(find.text('取り消す'));
    await tester.pumpAndSettle();
    expect(store.records, isEmpty);
    expect(store.shoppingItems(store.shoppingLists.first.id), hasLength(1));
    await _waitNotice(tester);
  });

  testWidgets('がんばり: やった人ごとに件数が出て、ありがとうを送れる', (tester) async {
    final store = await _readyStore();
    final kuma = store.members[1];
    final today = store.agenda.todayItems.items;
    store.complete(today[0], doneById: kuma.id);
    store.complete(today[1], doneById: kuma.id);
    store.complete(today[2]);
    await _pumpApp(tester, store);
    await _openTab(tester, 'がんばり');

    expect(find.text('今週、家族でやった家事'), findsOneWidget);
    expect(find.text('なな  1件'), findsOneWidget);
    expect(find.text('しろくま  2件'), findsOneWidget);

    // 家族がやった記録に、ホームからありがとうを送る
    await _openTab(tester, 'ホーム');
    await tester.tap(find.byTooltip('ありがとうを送る').first);
    await tester.pumpAndSettle();
    expect(
      store.thanksFor(store.records.first.id).length +
          store.thanksFor(store.records[1].id).length,
      1,
    );
  });

  testWidgets('設定: 画面の明るさを切り替えられる', (tester) async {
    final store = await _readyStore();
    await _pumpApp(tester, store);
    await _openTab(tester, '設定');

    await tester.ensureVisible(find.text('ダーク'));
    await tester.tap(find.text('ダーク'));
    await tester.pumpAndSettle();
    expect(store.appearance, Appearance.dark);
    expect(
      Theme.of(tester.element(find.text('ダーク'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('小さい画面・大きい文字でも、はじめての設定がはみ出さない', (tester) async {
    final store = await _newStore();
    await _pumpApp(tester, store, size: const Size(320, 568), textScale: 1.3);
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'なな');
    await tester.pump();
    await tester.tap(find.text('もう1人追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('つぎへ'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('えらばずにはじめる'));
    await tester.pumpAndSettle();
    // 家事がまだないときの案内
    expect(store.chores, isEmpty);
    expect(find.text('今日のやること'), findsOneWidget);
  });

  testWidgets('小さい画面・大きい文字でも、どの画面もはみ出さない', (tester) async {
    final store = await _readyStore();
    final today = store.agenda.todayItems.items;
    store.complete(today[0], doneById: store.members[1].id);
    store.complete(today[1]);
    final list = store.shoppingLists.first.id;
    store.addShoppingItem(list, '牛乳', note: '2本');
    store.updateShoppingItem(
      store.addShoppingItem(list, '豆腐')!.id,
      inCart: true,
    );
    // はみ出しがあると、描画のエラーとしてテストが落ちる。
    await _pumpApp(tester, store, size: const Size(320, 568), textScale: 1.3);

    // 上の「がんばり」枠の分だけ下に送ってから、家事の行をタップする
    for (
      var i = 0;
      i < 10 && find.text(today[2].chore.name).evaluate().isEmpty;
      i++
    ) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text(today[2].chore.name).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(today[2].chore.name).first);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(160, 10));
    await tester.pumpAndSettle();

    for (var i = 0; i < 10 && find.text('やったことを記録').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('やったことを記録'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('やったことを記録'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(160, 10));
    await tester.pumpAndSettle();

    // カレンダー、メッセージを送るシート
    for (
      var i = 0;
      i < 10 && find.byTooltip('カレンダーで日付をえらぶ').evaluate().isEmpty;
      i++
    ) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('カレンダーで日付をえらぶ'));
    await tester.pumpAndSettle();
    expect(find.text('決定'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('決定'), findsNothing);
    await tester.ensureVisible(find.text('メッセージを送る'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('メッセージを送る'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'いつもありがとう！');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('送信'));
    await tester.tap(find.text('送信'));
    await tester.pumpAndSettle();
    expect(find.textContaining('いつもありがとう！'), findsOneWidget);

    await _openTab(tester, '買い物');
    await tester.tap(find.text('牛乳'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('3個'), findsOneWidget);

    await _openTab(tester, '家事');
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('」の家事を追加'), findsOneWidget);
    expect(find.text('自分で作る'), findsOneWidget);
    await tester.tapAt(const Offset(160, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('食器洗い'));
    await tester.pumpAndSettle();
    expect(find.text('家事を編集'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('毎日'),
      find.byType(ListView).last,
      const Offset(0, -120),
    );
    for (final cycle in ['毎日', '毎週', '毎月', '毎年', 'やった日から', '1回だけ']) {
      // 同じ文字が下の「次の予定」にも出るので、先に出てくるチップをえらぶ
      await tester.ensureVisible(find.text(cycle).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(cycle).first);
      await tester.pumpAndSettle();
    }
    // いちばん下（メモ・削除）まで
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ジャンル'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await _openTab(tester, 'がんばり');
    await tester.tap(find.widgetWithText(SegmentedButton<bool>, '月'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await tester.pumpAndSettle();
    }

    await _openTab(tester, '設定');
    await tester.dragUntilVisible(
      find.text('通知とリマインド'),
      find.byType(ListView).last,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('通知とリマインド'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
  });
}

// README に載せる画面の画像を作る。
//
//   flutter test tool/screenshots_test.dart
//
// docs/screenshots/ に PNG が出る。見本のデータを入れた状態でアプリを動かし、
// 実際の画面をそのまま画像にしている。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaji_kiroku/app.dart';
import 'package:kaji_kiroku/data/storage.dart';
import 'package:kaji_kiroku/domain/models.dart';
import 'package:kaji_kiroku/domain/recurrence.dart';
import 'package:kaji_kiroku/state/app_store.dart';

const _size = Size(390, 844);
const _pixelRatio = 2.0;
final _outDir = Directory('docs/screenshots');

Future<void> _loadFonts() async {
  Future<ByteData> read(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());
  final text = FontLoader('ZenMaruGothic')
    ..addFont(read('assets/fonts/ZenMaruGothic-Medium.ttf'))
    ..addFont(read('assets/fonts/ZenMaruGothic-Bold.ttf'));
  await text.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      read(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    );
  await icons.load();
}

/// 見本のデータ。2026-11-11（水）の夕方、という設定。
Future<AppStore> _seed({Appearance appearance = Appearance.light}) async {
  var now = DateTime(2026, 11, 1, 9);
  final store = AppStore(MemoryStorage(), clock: () => now);
  await store.load();
  store.completeOnboarding(myName: 'なな', familyNames: ['しろくま']);
  store.setAppearance(appearance);
  final nana = store.members[0].id;
  final kuma = store.members[1].id;

  Chore add(
    String name,
    String genre,
    Repeat repeat,
    DateTime start, {
    String? who,
    int? due,
    String memo = '',
  }) {
    final c = Chore(
      id: store.newChoreId(),
      name: name,
      genreId: genre,
      start: start,
      repeat: repeat,
      assigneeId: who,
      dueMinutes: due,
      memo: memo,
    );
    store.saveChore(c);
    return c;
  }

  final first = DateTime(2026, 11, 1);
  final dish = add('食器洗い', 'cooking', const Repeat.daily(), first);
  final dinner = add(
    '晩ごはん作り',
    'cooking',
    const Repeat.daily(),
    first,
    who: nana,
  );
  final laundry = add('洗濯', 'laundry', const Repeat.daily(), first, who: kuma);
  final bath = add('お風呂掃除', 'cleaning', const Repeat.daily(), first, who: kuma);
  final burnable = add(
    '燃えるゴミ出し',
    'cleaning',
    const Repeat.weekly({2, 5}),
    first,
    who: kuma,
    due: 8 * 60,
  );
  final recycle = add(
    '資源ゴミ出し',
    'cleaning',
    const Repeat.monthlyNth({2, 4}, 1),
    first,
    who: kuma,
    due: 8 * 60,
    memo: 'びん・かんは青いコンテナへ',
  );
  add('トイレ掃除', 'cleaning', const Repeat.weekly({6}), first, who: nana);
  final washer = add(
    '洗濯槽の掃除',
    'laundry',
    const Repeat.monthlyDay(1),
    first,
    memo: '洗濯槽クリーナーは洗面台の下',
  );
  add('排水口の掃除', 'cleaning', const Repeat.afterDone(14), DateTime(2026, 11, 13));
  final nursery = add(
    '保育園の準備',
    'childcare',
    const Repeat.weekly(Repeat.weekdaysOnly),
    first,
    who: nana,
    due: 7 * 60 + 30,
  );
  add(
    '粗大ゴミの申し込み',
    'other',
    const Repeat.none(),
    DateTime(2026, 11, 13),
    who: nana,
  );
  final fridge = add('冷蔵庫の整理', 'cooking', const Repeat.monthlyDay(0), first);

  // 11/1 から 11/10 まで、それらしく記録を積む。
  void done(Chore c, String who) {
    final o = store.agenda.todayItems.items
        .where((o) => o.chore.id == c.id && o.isPending)
        .firstOrNull;
    if (o != null) store.complete(o, doneById: who);
  }

  for (var day = 1; day <= 10; day++) {
    now = DateTime(2026, 11, day, 20);
    store.refreshClock();
    done(dinner, day % 4 == 0 ? kuma : nana);
    done(dish, day.isEven ? kuma : nana);
    done(laundry, day % 5 == 0 ? nana : kuma);
    if (day % 3 != 0) done(bath, kuma);
    done(burnable, kuma);
    done(recycle, kuma);
    done(nursery, nana);
    if (day == 1) done(washer, nana);
  }

  final supermarket = store.shoppingLists[0].id;
  final drugstore = store.shoppingLists[1].id;
  now = DateTime(2026, 11, 7, 17);
  for (final name in ['牛乳', '卵', '納豆', '鶏むね肉', 'キャベツ']) {
    final item = store.addShoppingItem(supermarket, name)!;
    store.updateShoppingItem(item.id, inCart: true);
  }
  store.finishShopping(supermarket, doneById: kuma);

  // 今日
  now = DateTime(2026, 11, 11, 18, 30);
  store.refreshClock();
  final laundryRecord = store.complete(
    store.agenda.todayItems.items.firstWhere((o) => o.chore.id == laundry.id),
    doneById: kuma,
  );
  done(nursery, nana);
  final fridgeRecord = store.recordUnplanned(fridge, doneById: kuma);
  store.toggleThanks(laundryRecord.id, 'thanks');
  store.toggleThanks(fridgeRecord.id, 'great');

  store.setCurrentMember(kuma);
  store.addShoppingItem(supermarket, '牛乳', note: '2本');
  store.addShoppingItem(supermarket, '食パン');
  store.setCurrentMember(nana);
  final tofu = store.addShoppingItem(supermarket, '豆腐')!;
  store.addShoppingItem(supermarket, 'バナナ');
  store.updateShoppingItem(tofu.id, inCart: true);
  store.addShoppingItem(drugstore, '洗濯洗剤', note: 'つめかえ用');
  return store;
}

void main() {
  final boundaryKey = GlobalKey();

  Future<void> pumpApp(WidgetTester tester, AppStore store) async {
    tester.view.physicalSize = _size * _pixelRatio;
    tester.view.devicePixelRatio = _pixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: KajiApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: _pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      _outDir.createSync(recursive: true);
      File(
        '${_outDir.path}/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  setUpAll(_loadFonts);

  /// 影つきの本番と同じ見た目で動かす（テストはふつう影を描かない）。
  void screenshotTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugDisableShadows = false;
      try {
        await body(tester);
      } finally {
        debugDisableShadows = true;
      }
    });
  }

  screenshotTest('はじめての設定', (tester) async {
    final store = AppStore(
      MemoryStorage(),
      clock: () => DateTime(2026, 11, 11, 18, 30),
    );
    await store.load();
    await pumpApp(tester, store);
    // 画像はテストの中では自動で読み込まれないので、先に読んでおく。
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/app_icon.png'),
        tester.element(find.byType(KajiApp)),
      ),
    );
    await shot(tester, '01_welcome');

    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'なな');
    await tester.enterText(find.byType(TextField).at(1), 'しろくま');
    await tester.pump();
    await shot(tester, '02_family');

    await tester.tap(find.text('つぎへ'));
    await shot(tester, '03_starter_chores');
  });

  screenshotTest('おもな画面', (tester) async {
    final store = await _seed();
    await pumpApp(tester, store);
    await shot(tester, '10_home');

    await tester.tap(find.text('お風呂掃除'));
    await shot(tester, '11_home_sheet');
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -520));
    await shot(tester, '12_home_week');

    await tester.tap(find.text('買い物').last);
    await shot(tester, '20_shopping');

    await tester.tap(find.text('家事').last);
    await shot(tester, '30_chores');

    await tester.ensureVisible(find.text('資源ゴミ出し'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('資源ゴミ出し'));
    await shot(tester, '31_chore_editor');
    await tester.drag(find.byType(ListView).last, const Offset(0, -420));
    await shot(tester, '32_chore_editor_repeat');
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('家事を追加').last);
    await shot(tester, '33_add_chore');
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();

    await tester.tap(find.text('がんばり').last);
    await shot(tester, '40_report');
    await tester.drag(find.byType(ListView).last, const Offset(0, -430));
    await shot(tester, '41_report_members');

    await tester.tap(find.text('設定').last);
    await shot(tester, '50_settings');
    await tester.tap(find.text('通知とリマインド'));
    await shot(tester, '51_notifications');
    await tester.drag(find.byType(ListView).last, const Offset(0, -560));
    await shot(tester, '52_notifications_more');
  });

  screenshotTest('ダークモード', (tester) async {
    final store = await _seed(appearance: Appearance.dark);
    await pumpApp(tester, store);
    await shot(tester, '60_home_dark');
    await tester.tap(find.text('がんばり').last);
    await shot(tester, '61_report_dark');
    await tester.tap(find.text('買い物').last);
    await shot(tester, '62_shopping_dark');
  });
}

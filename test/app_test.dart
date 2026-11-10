import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaji_kiroku/main.dart';
import 'package:kaji_kiroku/store.dart';

void main() {
  testWidgets('家事を登録するとホームに出て、全タブを行き来できる', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = AppStore(MemoryStorage(), clock: () => DateTime(2026, 11, 11, 9));
    await store.load();
    await tester.pumpWidget(KajiApp(store: store));
    await tester.pumpAndSettle();

    // ホームの「家事を追加」から毎日の家事を登録する
    await tester.tap(find.text('家事を追加').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '食器洗い');
    await tester.tap(find.text('1回だけ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('毎日・N日ごと').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(store.chores.single.name, '食器洗い');
    expect(find.text('食器洗い'), findsWidgets);

    // 丸をタップして完了
    await tester.tap(find.byTooltip('完了にする').first);
    await tester.pumpAndSettle();
    expect(store.records, hasLength(1));
    expect(find.text('わたしがやった'), findsOneWidget);

    for (final tab in ['家事一覧', 'がんばり', '設定', 'ホーム']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}

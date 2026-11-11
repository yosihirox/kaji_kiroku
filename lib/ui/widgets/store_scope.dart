import 'package:flutter/widgets.dart';

import '../../state/app_store.dart';

/// 画面のどこからでも [AppStore] を取り出せるようにする。
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);

  /// 変更があったら作り直される形で取り出す。
  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// 作り直しを伴わずに取り出す（ボタンを押したときの処理など）。
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

extension StoreContext on BuildContext {
  AppStore get store => StoreScope.of(this);
  AppStore get readStore => StoreScope.read(this);
}

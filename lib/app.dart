import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'domain/models.dart';
import 'state/app_store.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';
import 'ui/widgets/common.dart';
import 'ui/widgets/store_scope.dart';

/// パソコンの広い画面でも、スマホくらいの幅で表示する。
const _maxAppWidth = 560.0;

class KajiApp extends StatefulWidget {
  const KajiApp({super.key, required this.store});
  final AppStore store;

  @override
  State<KajiApp> createState() => _KajiAppState();
}

class _KajiAppState extends State<KajiApp> {
  late Appearance _appearance = widget.store.appearance;
  late bool _onboarded = widget.store.onboarded;
  final _noticeObserver = NoticeNavigatorObserver();

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  /// アプリ全体を作り直すのは、外観か「はじめての設定が済んだか」が変わったときだけ。
  void _onStoreChanged() {
    final store = widget.store;
    if (store.appearance == _appearance && store.onboarded == _onboarded) {
      return;
    }
    setState(() {
      _appearance = store.appearance;
      _onboarded = store.onboarded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: widget.store,
      child: MaterialApp(
        title: '家事きろく',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: switch (_appearance) {
          Appearance.system => ThemeMode.system,
          Appearance.light => ThemeMode.light,
          Appearance.dark => ThemeMode.dark,
        },
        navigatorObservers: [_noticeObserver],
        builder: (context, child) =>
            NoticeDismisser(child: _PhoneFrame(child: child!)),
        home: _onboarded
            ? const Shell(key: ValueKey('shell'))
            : const OnboardingScreen(key: ValueKey('onboarding')),
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.sizeOf(context);
    if (size.width <= _maxAppWidth) return child;
    // 中の画面には、枠の幅を画面の幅として伝える。
    return ColoredBox(
      color: colors.backdrop,
      child: Center(
        child: SizedBox(
          width: _maxAppWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 40,
                ),
              ],
            ),
            child: ClipRect(
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(size: Size(_maxAppWidth, size.height)),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

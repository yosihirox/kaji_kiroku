import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/chores_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'screens/settings_screen.dart';
import 'store.dart';

/// 端末内（SharedPreferences）に保存する。
class PrefsStorage implements StateStorage {
  static const _key = 'state_v1';
  @override
  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(_key);
  @override
  Future<void> save(String json) async =>
      (await SharedPreferences.getInstance()).setString(_key, json);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore(PrefsStorage());
  await store.load();
  runApp(KajiApp(store: store));
}

class KajiApp extends StatelessWidget {
  const KajiApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '家事きろく',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4E79A7),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF4E79A7),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: HomeShell(store: store),
    );
  }
}

/// 画面下のタブ。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final AppStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final badge = store.badgeCount();
        final pages = [
          HomeScreen(store: store),
          ChoresScreen(store: store),
          ReportScreen(store: store),
          SettingsScreen(store: store),
        ];
        return Scaffold(
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge'),
                  child: const Icon(Icons.today_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge'),
                  child: const Icon(Icons.today),
                ),
                label: 'ホーム',
              ),
              const NavigationDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: '家事一覧',
              ),
              const NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: 'がんばり',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '設定',
              ),
            ],
          ),
        );
      },
    );
  }
}

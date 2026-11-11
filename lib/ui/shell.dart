import 'dart:async';

import 'package:flutter/material.dart';

import 'chores/chores_screen.dart';
import 'home/home_screen.dart';
import 'report/report_screen.dart';
import 'settings/settings_screen.dart';
import 'shopping/shopping_screen.dart';
import 'widgets/store_scope.dart';

/// 画面下の5つのタブ。
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 開いたまま日付が変わっても、今日のやることに切り替わるようにする。
    _clock = Timer.periodic(
      const Duration(minutes: 1),
      (_) => context.readStore.refreshClock(),
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.readStore.refreshClock();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final badge = store.badgeCount;
    final toBuy = store.shoppingTodoCount;

    Widget withBadge(int count, IconData icon) => Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(icon),
    );

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          ShoppingScreen(),
          ChoresScreen(),
          ReportScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: withBadge(badge, Icons.wb_sunny_outlined),
              selectedIcon: withBadge(badge, Icons.wb_sunny_rounded),
              label: 'ホーム',
            ),
            NavigationDestination(
              icon: withBadge(toBuy, Icons.shopping_basket_outlined),
              selectedIcon: withBadge(toBuy, Icons.shopping_basket_rounded),
              label: '買い物',
            ),
            const NavigationDestination(
              icon: Icon(Icons.checklist_rounded),
              selectedIcon: Icon(Icons.checklist_rounded),
              label: '家事',
            ),
            const NavigationDestination(
              icon: Icon(Icons.volunteer_activism_outlined),
              selectedIcon: Icon(Icons.volunteer_activism_rounded),
              label: 'がんばり',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: '設定',
            ),
          ],
        ),
      ),
    );
  }
}

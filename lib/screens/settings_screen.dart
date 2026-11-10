import 'package:flutter/material.dart';

import '../store.dart';
import '../ui_common.dart';

/// 設定: 家族メンバー、この端末を使う人、招待（次の段階）。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          _header(theme, '家族メンバー'),
          for (final m in store.members)
            ListTile(
              leading: MemberAvatar(m, radius: 18),
              title: Text(m.name),
              subtitle: m.id == store.currentMemberId
                  ? const Text('この端末を使っている人')
                  : null,
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'me':
                      await store.setCurrentMember(m.id);
                    case 'rename':
                      final name = await askText(context,
                          title: '名前を変更', initial: m.name);
                      if (name != null && name.isNotEmpty) {
                        await store.renameMember(m.id, name);
                      }
                    case 'remove':
                      await store.removeMember(m.id);
                  }
                },
                itemBuilder: (context) => [
                  if (m.id != store.currentMemberId)
                    const PopupMenuItem(value: 'me', child: Text('この端末の利用者にする')),
                  const PopupMenuItem(value: 'rename', child: Text('名前を変更')),
                  if (store.members.length > 1)
                    const PopupMenuItem(value: 'remove', child: Text('メンバーから外す')),
                ],
              ),
            ),
          ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: const Text('メンバーを追加'),
            onTap: () async {
              final name = await askText(context,
                  title: 'メンバーを追加', hint: '例: パパ、ママ、ななちゃん');
              if (name != null && name.isNotEmpty) await store.addMember(name);
            },
          ),
          Card(
            margin: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceContainerHighest,
            child: const ListTile(
              leading: Icon(Icons.link),
              title: Text('家族を招待（準備中）'),
              subtitle: Text(
                  '試作版では、この端末の中だけで家族全員分を記録します。招待リンクで家族のスマホとつながる機能は、次の段階で追加します。'),
            ),
          ),
          _header(theme, '通知'),
          const ListTile(
            leading: Icon(Icons.notifications_none),
            title: Text('通知・リマインド（準備中）'),
            subtitle: Text('朝のまとめ、期限前、やり忘れのお知らせは次の段階で追加します。'),
          ),
          _header(theme, 'このアプリについて'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('家事きろく（試作版 0.1）'),
          ),
        ],
      ),
    );
  }

  Widget _header(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text,
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.primary)),
      );
}

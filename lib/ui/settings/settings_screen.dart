import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../chores/genres_screen.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';
import 'notification_settings_screen.dart';

/// アプリの版。pubspec.yaml の version と合わせる。
const appVersionLabel = '試作版 0.4';

/// 設定: 家族、通知、表示、データ。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = store.notifications;

    final notificationSummary = [
      if (n.morningSummary) '朝のまとめ ${formatMinutes(n.morningMinutes)}',
      if (n.overdueReminder) 'やり忘れ ${formatMinutes(n.overdueMinutes)}',
      if (!n.morningSummary && !n.overdueReminder) 'まとめとリマインドはオフ',
    ].join('  ・  ');

    return Scaffold(
      appBar: AppBar(
        title: const ScreenTitle('設定', icon: Icons.settings_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          const SectionLabel('家族'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final m in store.members) ...[
                  ListTile(
                    leading: MemberAvatar(m, size: 40),
                    title: Text(m.name, style: theme.textTheme.titleMedium),
                    subtitle: m.id == store.currentMemberId
                        ? const Text('いまこの端末を使っている人')
                        : null,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showAppSheet<void>(
                      context,
                      builder: (_) => _MemberEditor(memberId: m.id),
                    ),
                  ),
                  const Divider(indent: 72),
                ],
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 20,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    '家族を追加',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                  onTap: () async {
                    final name = await askText(
                      context,
                      title: '家族を追加',
                      hint: '名前（ニックネームでOK）',
                      confirm: '追加',
                    );
                    if (name != null) store.addMember(name);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.phonelink_rounded,
                  color: scheme.onSecondaryContainer,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '家族それぞれのスマホとつなぐ機能（招待リンク）は準備中です。'
                    'いまは、この端末の中に家族みんなの分を記録します。'
                    'ホーム右上の名前をタップすると、使う人を切り替えられます。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SectionLabel('通知'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.notifications_rounded),
              title: const Text('通知とリマインド'),
              subtitle: Text(notificationSummary),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () =>
                  Navigator.of(context).push(notificationSettingsRoute()),
            ),
          ),
          const SectionLabel('家事'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.category_rounded),
              title: const Text('ジャンルの管理'),
              subtitle: const Text('追加、並べ替え、使わないジャンルを隠す'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(genresRoute()),
            ),
          ),
          const SectionLabel('表示'),
          const _SubLabel('ホーム画面'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.volunteer_activism_rounded),
                  title: const Text('「がんばり」の表示'),
                  subtitle: Text(
                    store.showHomeCheer ? 'ホームにがんばり枠を出す' : 'ホームにがんばり枠を出さない',
                  ),
                  value: store.showHomeCheer,
                  onChanged: store.setShowHomeCheer,
                ),
                const Divider(indent: 56),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.low_priority_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '完了家事の表示位置',
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: false, label: Text('位置維持')),
                          ButtonSegment(value: true, label: Text('最下部')),
                        ],
                        selected: {store.doneMovesToBottom},
                        onSelectionChanged: (s) =>
                            store.setDoneMovesToBottom(s.first),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        store.doneMovesToBottom
                            ? '完了にした家事は、その日のいちばん下に移ります。'
                            : '完了にしても、家事はその場所のままチェックだけ入ります。',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SubLabel('画面の明るさ'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<Appearance>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Appearance.system, label: Text('自動')),
                ButtonSegment(value: Appearance.light, label: Text('ライト')),
                ButtonSegment(value: Appearance.dark, label: Text('ダーク')),
              ],
              selected: {store.appearance},
              onSelectionChanged: (s) => store.setAppearance(s.first),
            ),
          ),
          const SectionLabel('データ'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_rounded),
                  title: const Text('バックアップを書き出す'),
                  subtitle: const Text('データを文字としてコピーします'),
                  onTap: () => _export(context),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('バックアップを読み込む'),
                  subtitle: const Text('コピーしておいたデータで置き換えます'),
                  onTap: () => _import(context),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: Icon(Icons.restart_alt_rounded, color: scheme.error),
                  title: Text(
                    'すべて消してはじめから',
                    style: TextStyle(color: scheme.error),
                  ),
                  onTap: () => _reset(context),
                ),
              ],
            ),
          ),
          const SectionLabel('このアプリについて'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_rounded),
                  title: Text('家事きろく'),
                  trailing: Text(appVersionLabel),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.description_rounded),
                  title: const Text('ライセンス'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: '家事きろく',
                    applicationVersion: appVersionLabel,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Text(
              '試作版のデータは、この端末（ブラウザ版はこのブラウザ）の中だけに保存されます。',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final data = context.readStore.exportData();
    await Clipboard.setData(ClipboardData(text: data));
    if (!context.mounted) return;
    showNotice(context, 'バックアップをコピーしました。メモやメールに貼り付けて保管してください');
  }

  Future<void> _import(BuildContext context) async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('バックアップを読み込む'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('書き出したデータを貼り付けてください。いまのデータは、読み込んだ内容に置き換わります。'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(hintText: 'ここに貼り付け'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('読み込む'),
          ),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty || !context.mounted) return;
    final ok = context.readStore.importData(raw);
    showNotice(context, ok ? 'バックアップを読み込みました' : '読み込めませんでした。貼り付けた内容を確かめてください');
  }

  Future<void> _reset(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'すべて消してはじめからにしますか？',
      message: '家族、家事、記録、買い物リストがすべて消えます。元には戻せません。',
      action: 'すべて消す',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    context.readStore.resetAll();
  }
}

/// 大項目の中の小見出し。
class _SubLabel extends StatelessWidget {
  const _SubLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// メンバーの名前・色の変更、使う人の切り替え、家族から外す。
class _MemberEditor extends StatefulWidget {
  const _MemberEditor({required this.memberId});
  final String memberId;

  @override
  State<_MemberEditor> createState() => _MemberEditorState();
}

class _MemberEditorState extends State<_MemberEditor> {
  final _name = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _name.text = context.readStore.memberById(widget.memberId)?.name ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _saveName() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    context.readStore.updateMember(widget.memberId, name: name);
  }

  Future<void> _remove(Member member) async {
    final ok = await confirm(
      context,
      title: '${member.name}さんを家族から外しますか？',
      message: 'これまでの記録は「がんばり」に残ります。担当になっている家事は「だれでも」に戻ります。',
      action: '外す',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final store = context.readStore;
    Navigator.pop(context);
    store.removeMember(member.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final member = store.memberById(widget.memberId);
    if (member == null) return const SizedBox(height: 8);
    final isCurrent = member.id == store.currentMemberId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MemberAvatar(member, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: _name,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: '名前'),
                onChanged: (_) => _saveName(),
              ),
            ),
          ],
        ),
        const SectionLabel('色', padding: EdgeInsets.fromLTRB(0, 18, 0, 8)),
        MemberColorPicker(
          selected: member.color,
          onSelected: (c) => store.updateMember(member.id, color: c),
        ),
        const SizedBox(height: 20),
        if (isCurrent)
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('いまこの端末を使っている人です', style: theme.textTheme.bodyMedium),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => store.setCurrentMember(member.id),
              icon: const Icon(Icons.swap_horiz_rounded, size: 20),
              label: Text('${member.name}さんとして使う'),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (store.members.length > 1)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                onPressed: () => _remove(member),
                icon: const Icon(Icons.person_remove_rounded, size: 20),
                label: const Text('家族から外す'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('とじる'),
            ),
          ],
        ),
      ],
    );
  }
}

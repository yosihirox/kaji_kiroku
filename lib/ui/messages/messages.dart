/// 家族へのひとことメッセージ（送るシートと、一覧の1行）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';

/// 「2026/11/12 22:31」
String formatMessageTime(DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${at.year}/${two(at.month)}/${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
}

/// メッセージを送るシート。シートの外をタップすると、送らずに閉じる。
Future<void> showSendMessageSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _SendMessageSheet());
}

class _SendMessageSheet extends StatefulWidget {
  const _SendMessageSheet();

  @override
  State<_SendMessageSheet> createState() => _SendMessageSheetState();
}

class _SendMessageSheetState extends State<_SendMessageSheet> {
  final _text = TextEditingController();
  String? _toId;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// 最初にえらんでおく宛先: 今日いちばん家事をした人。
  /// 今日まだだれもしていなければ、自分以外の最初の人。
  String? _defaultTo() {
    final store = context.readStore;
    final today = store.todayDoneCounts;
    if (today.isNotEmpty) return today.first.member.id;
    final others = store.members.where((m) => m.id != store.currentMemberId);
    return (others.isNotEmpty ? others.first : store.members.firstOrNull)?.id;
  }

  void _send() {
    final to = _toId ?? _defaultTo();
    if (to == null || _text.text.trim().isEmpty) return;
    final store = context.readStore;
    if (store.sendMessage(to, _text.text) == null) return;
    HapticFeedback.lightImpact();
    final navigator = Navigator.of(context);
    showNotice(context, '${store.memberById(to)?.name ?? ''}さんにメッセージを送りました');
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final toId = _toId ?? _defaultTo();
    final canSend = toId != null && _text.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('メッセージを送る', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('ホームと「がんばり」に1週間表示されます。', style: theme.textTheme.bodySmall),
        const SectionLabel('だれに？', padding: EdgeInsets.fromLTRB(0, 16, 0, 10)),
        MemberPicker(
          members: store.members,
          selectedId: toId,
          onSelected: (m) => setState(() => _toId = m.id),
        ),
        const SectionLabel('メッセージ', padding: EdgeInsets.fromLTRB(0, 18, 0, 10)),
        TextField(
          controller: _text,
          minLines: 2,
          maxLines: 5,
          maxLength: 200,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: '例: 今週はたくさん家事をしてくれてありがとう！',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canSend ? _send : null,
            icon: const Icon(Icons.send_rounded, size: 20),
            label: const Text('送信'),
          ),
        ),
      ],
    );
  }
}

/// メッセージ1件。「だれ → だれ」と本文、送った日時。送った本人には × を出す。
class MessageTile extends StatelessWidget {
  const MessageTile(this.message, {super.key});
  final FamilyMessage message;

  Future<void> _delete(BuildContext context) async {
    final store = context.readStore;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('このメッセージを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('いいえ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('はい'),
          ),
        ],
      ),
    );
    if (ok ?? false) store.deleteMessage(message.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final from = store.memberById(message.fromId);
    final to = store.memberById(message.toId);
    final mine = message.fromId == store.currentMemberId;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    MemberAvatar(from, size: 22),
                    Text(
                      '${from?.name ?? '家族'}さん',
                      style: theme.textTheme.labelLarge,
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    MemberAvatar(to, size: 22),
                    Text(
                      '${to?.name ?? '家族'}さん',
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: message.text,
                    children: [
                      TextSpan(
                        text: '（${formatMessageTime(message.at)}）',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (mine)
            IconButton(
              tooltip: 'メッセージを削除',
              visualDensity: VisualDensity.compact,
              onPressed: () => _delete(context),
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// 直近1週間のメッセージを並べる。なければ何も出さない。
class RecentMessages extends StatelessWidget {
  const RecentMessages({super.key, this.spacing = 8});
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final messages = context.store.recentMessages;
    if (messages.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < messages.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          MessageTile(messages[i], key: ValueKey(messages[i].id)),
        ],
      ],
    );
  }
}

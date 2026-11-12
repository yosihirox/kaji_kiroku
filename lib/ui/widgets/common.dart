/// いくつもの画面で使う小さな部品。
library;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../theme.dart';

/// ジャンルに選べるアイコン。キーで保存する。
const genreIcons = <String, IconData>{
  'cooking': Icons.restaurant_rounded,
  'shopping': Icons.shopping_basket_rounded,
  'laundry': Icons.local_laundry_service_rounded,
  'cleaning': Icons.cleaning_services_rounded,
  'pet': Icons.pets_rounded,
  'childcare': Icons.child_friendly_rounded,
  'education': Icons.school_rounded,
  'other': Icons.more_horiz_rounded,
  'home': Icons.home_rounded,
  'car': Icons.directions_car_rounded,
  'garden': Icons.yard_rounded,
  'money': Icons.savings_rounded,
  'health': Icons.medical_services_rounded,
  'trash': Icons.delete_rounded,
  'event': Icons.event_rounded,
  'star': Icons.star_rounded,
  'bath': Icons.bathtub_rounded,
  'bed': Icons.bed_rounded,
  'tools': Icons.handyman_rounded,
  'mail': Icons.mail_rounded,
};

/// スタンプのアイコン。
const stampIcons = <String, IconData>{
  'thanks': Icons.favorite_rounded,
  'great': Icons.auto_awesome_rounded,
  'helped': Icons.volunteer_activism_rounded,
  'otsukare': Icons.emoji_food_beverage_rounded,
};

IconData iconForGenre(Genre g) => genreIcons[g.icon] ?? Icons.label_rounded;

/// ジャンルの角丸アイコン。
class GenreIcon extends StatelessWidget {
  const GenreIcon(this.genre, {super.key, this.size = 40});
  final Genre genre;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Color(genre.color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint(color, context),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        iconForGenre(genre),
        color: onTint(color, context),
        size: size * 0.56,
      ),
    );
  }
}

/// メンバーの頭文字アイコン。null は「だれでも」。
class MemberAvatar extends StatelessWidget {
  const MemberAvatar(this.member, {super.key, this.size = 28, this.ring});
  final Member? member;
  final double size;

  /// まわりに付ける輪の色（選択中の表示など）。
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = member;
    final Widget face;
    if (m == null) {
      face = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.groups_rounded,
          size: size * 0.6,
          color: scheme.onSurfaceVariant,
        ),
      );
    } else {
      final color = memberColor(m.color, context);
      // 黄色のような明るい色の上では、白い文字が読みにくいので濃い文字にする。
      final onColor = color.computeLuminance() > 0.3
          ? const Color(0xFF3B2A00)
          : Colors.white;
      face = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          m.name.isEmpty ? '?' : m.name.characters.first,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: appFontFamily,
            color: onColor,
            fontSize: size * 0.46,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      );
    }
    if (ring == null) return face;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring!, width: 2),
      ),
      child: face,
    );
  }
}

/// 小さな見出し。
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding});
  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// まだ何もないときの案内。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 42, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            for (final a in actions)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: a),
          ],
        ],
      ),
    );
  }
}

/// 「－ 3 ＋」の数字えらび。
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 365,
    this.suffix = '',
    this.prefix = '',
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // せまい画面では、前後の言葉が別の行に折り返す。
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (prefix.isNotEmpty) Text(prefix, style: theme.textTheme.bodyLarge),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              tooltip: 'へらす',
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'ふやす',
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        if (suffix.isNotEmpty) Text(suffix, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

/// 名前を入力するだけの小さなダイアログ。キャンセルや空欄なら null。
Future<String?> askText(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  String confirm = 'OK',
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(confirm),
        ),
      ],
    ),
  );
  final trimmed = result?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// 「本当に？」の確認。
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  required String action,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(88, 44),
            backgroundColor: destructive ? scheme.error : null,
            foregroundColor: destructive ? scheme.onError : null,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// 下から出るシート。中身が長いときはスクロールでき、キーボードにも隠れない。
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: builder(context),
        ),
      ),
    ),
  );
}

/// お知らせを出しておく時間。
const noticeDuration = Duration(seconds: 3);

/// お知らせを出しているかもしれない間は true。
bool _noticeShowing = false;

/// 画面下に短いお知らせを出す。前のお知らせは引っこめる。
///
/// 「取り消す」があっても [noticeDuration] で消える。お知らせ自体をタップしたとき、
/// 画面のどこかをタップしたとき（[NoticeDismisser]）、タブを切り替えたときにも消える。
void showNotice(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  _noticeShowing = true;
  messenger.showSnackBar(
    SnackBar(
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: messenger.hideCurrentSnackBar,
        child: Text(message),
      ),
      duration: noticeDuration,
      persist: false,
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );
}

/// いま出ているお知らせを引っこめる。
void hideNotice(BuildContext context) {
  _noticeShowing = false;
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
}

/// 画面のどこかをタップしたら、お知らせを引っこめる。
///
/// 指を離した知らせは、ボタンなどの「タップされた」より先にここへ届く。
/// そのため、お知らせを出したタップそのもので消えることはなく、
/// 「取り消す」のタップも、消える動きの途中でちゃんと届く。
class NoticeDismisser extends StatelessWidget {
  const NoticeDismisser({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) {
        if (_noticeShowing) hideNotice(context);
      },
      child: child,
    );
  }
}

/// 別の画面やシートを開いたら、お知らせを引っこめる。
class NoticeNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final context = navigator?.context;
    if (context != null) hideNotice(context);
  }
}

/// 家族を1人えらぶ、横並びの顔ぶれ。
class MemberPicker extends StatelessWidget {
  const MemberPicker({
    super.key,
    required this.members,
    required this.onSelected,
    this.selectedId,
    this.allowAnyone = false,
    this.anyoneSelected = false,
    this.onAnyone,
  });

  final List<Member> members;
  final String? selectedId;
  final ValueChanged<Member> onSelected;

  /// 先頭に「だれでも」を出す。
  final bool allowAnyone;
  final bool anyoneSelected;
  final VoidCallback? onAnyone;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (allowAnyone)
          ChoiceChip(
            avatar: const MemberAvatar(null, size: 24),
            label: const Text('だれでも'),
            selected: anyoneSelected,
            onSelected: (_) => onAnyone?.call(),
          ),
        for (final m in members)
          ChoiceChip(
            avatar: MemberAvatar(m, size: 24),
            label: Text(m.name),
            selected: !anyoneSelected && selectedId == m.id,
            onSelected: (_) => onSelected(m),
          ),
      ],
    );
  }
}

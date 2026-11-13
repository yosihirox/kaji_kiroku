import 'package:flutter/material.dart';

import '../../domain/catalog.dart';
import '../../domain/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';

/// はじめての設定: あいさつ → 名前と家族 → 最初の家事えらび。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final _myName = TextEditingController();
  final _family = <TextEditingController>[TextEditingController()];

  /// 名前ごとにえらんだ色。先頭が自分、そのあとが家族の順。
  final _colors = <int>[memberColors[0], memberColors[1]];

  /// まだだれも使っていない色（なければ順番に）。
  int _nextColor() => memberColors.firstWhere(
    (c) => !_colors.contains(c),
    orElse: () => memberColors[_colors.length % memberColors.length],
  );
  final _selected = <ChoreTemplate>{...choreTemplates.where((t) => t.starter)};

  @override
  void dispose() {
    _myName.dispose();
    for (final c in _family) {
      c.dispose();
    }
    super.dispose();
  }

  void _finish({required bool withChores}) {
    context.readStore.completeOnboarding(
      myName: _myName.text,
      familyNames: [for (final c in _family) c.text],
      myColor: _colors[0],
      familyColors: _colors.sublist(1),
      // 一覧と同じ順番で登録する。
      templates: withChores
          ? choreTemplates.where(_selected.contains).toList()
          : const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (_step) {
            0 => _Welcome(
              key: const ValueKey(0),
              onNext: () => setState(() => _step = 1),
            ),
            1 => _buildNames(context),
            _ => _buildChores(context),
          },
        ),
      ),
    );
  }

  Widget _buildNames(BuildContext context) {
    final theme = Theme.of(context);
    final canNext = _myName.text.trim().isNotEmpty;
    return _StepFrame(
      key: const ValueKey(1),
      step: 1,
      title: 'だれが使いますか？',
      message: '家事の担当や「やった人」に使う名前です。ニックネームで大丈夫です。',
      onBack: () => setState(() => _step = 0),
      footer: FilledButton(
        onPressed: canNext ? () => setState(() => _step = 2) : null,
        child: const Text('つぎへ'),
      ),
      children: [
        const SectionLabel('あなたの名前', padding: EdgeInsets.fromLTRB(4, 8, 4, 8)),
        _NameWithColor(
          controller: _myName,
          color: _colors[0],
          autofocus: true,
          hint: '例: なな',
          onChanged: (_) => setState(() {}),
          onColor: (c) => setState(() => _colors[0] = c),
        ),
        const SectionLabel('いっしょに使う家族'),
        for (var i = 0; i < _family.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _NameWithColor(
              controller: _family[i],
              color: _colors[i + 1],
              hint: i == 0 ? '例: パパ' : '名前',
              onChanged: (_) => setState(() {}),
              onColor: (c) => setState(() => _colors[i + 1] = c),
              onRemove: _family.length > 1
                  ? () => setState(() {
                      _family.removeAt(i).dispose();
                      _colors.removeAt(i + 1);
                    })
                  : null,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _family.length >= 6
                ? null
                : () => setState(() {
                    _colors.add(_nextColor());
                    _family.add(TextEditingController());
                  }),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('もう1人追加'),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '色は、担当ややった人の目印になります。名前も色も、あとから設定で変えられます。'
          'ひとりで使う場合は家族の欄は空のままで大丈夫です。',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildChores(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _StepFrame(
      key: const ValueKey(2),
      step: 2,
      title: 'よくやる家事をえらびましょう',
      message: 'くり返しの設定まで入った状態で登録されます。あとからいくらでも変えられます。',
      onBack: () => setState(() => _step = 1),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => _finish(withChores: true),
              child: Text('${_selected.length}件の家事ではじめる'),
            ),
          ),
          TextButton(
            onPressed: () => _finish(withChores: false),
            child: const Text('えらばずにはじめる'),
          ),
        ],
      ),
      children: [
        for (final g in store.visibleGenres)
          if (choreTemplates.any((t) => t.genreId == g.id)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Row(
                children: [
                  GenreIcon(g, size: 28),
                  const SizedBox(width: 8),
                  Text(g.name, style: theme.textTheme.titleSmall),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in choreTemplates.where((t) => t.genreId == g.id))
                  FilterChip(
                    avatar: _selected.contains(t)
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: scheme.onPrimaryContainer,
                          )
                        : null,
                    label: Text(t.name),
                    selected: _selected.contains(t),
                    onSelected: (on) => setState(() {
                      on ? _selected.add(t) : _selected.remove(t);
                    }),
                  ),
              ],
            ),
          ],
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({super.key, required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);

    Widget point(IconData icon, Color color, String title, String body) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint(color, context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: onTint(color, context), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/app_icon.png',
                  width: 76,
                  height: 76,
                  excludeFromSemantics: true,
                ),
                const SizedBox(height: 24),
                Text('家事きろく', style: theme.textTheme.displaySmall),
                const SizedBox(height: 8),
                Text(
                  '家族の「やること」と「やったこと」を、\nみんなで見える化。',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 36),
                point(
                  Icons.wb_sunny_rounded,
                  scheme.primary,
                  '今日やることが、ひと目でわかる',
                  '丸をタップするだけで完了できます。',
                ),
                point(
                  Icons.event_repeat_rounded,
                  const Color(0xFF4A90D9),
                  '「第2・第4月曜」も、おまかせ',
                  '毎月の掃除も、ゴミの日も忘れません。',
                ),
                point(
                  Icons.volunteer_activism_rounded,
                  colors.celebrate,
                  'がんばりが、家族に伝わる',
                  '誰が何をやったかが残ります。',
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onNext, child: const Text('はじめる')),
          ),
        ),
      ],
    );
  }
}

/// 2ページ目以降の共通の枠（戻る・見出し・下のボタン）。
class _StepFrame extends StatelessWidget {
  const _StepFrame({
    super.key,
    required this.step,
    required this.title,
    required this.message,
    required this.onBack,
    required this.footer,
    required this.children,
  });

  final int step;
  final String title;
  final String message;
  final VoidCallback onBack;
  final Widget footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'もどる',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Spacer(),
              Text(
                '$step / 2',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            children: [
              Text(title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: footer,
        ),
      ],
    );
  }
}

/// 名前の入力と、その人の色えらび。左の丸は、いまの色と頭文字の見本。
class _NameWithColor extends StatelessWidget {
  const _NameWithColor({
    required this.controller,
    required this.color,
    required this.hint,
    required this.onChanged,
    required this.onColor,
    this.onRemove,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final int color;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<int> onColor;
  final VoidCallback? onRemove;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final name = controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MemberAvatar(
              Member(id: '', name: name.isEmpty ? '？' : name, color: color),
              size: 40,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: autofocus,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: hint,
                  suffixIcon: onRemove == null
                      ? null
                      : IconButton(
                          tooltip: 'この人を消す',
                          onPressed: onRemove,
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 50),
          child: MemberColorPicker(
            selected: color,
            onSelected: onColor,
            size: 30,
          ),
        ),
      ],
    );
  }
}

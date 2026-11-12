import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models.dart';
import '../widgets/common.dart';
import '../widgets/store_scope.dart';

/// 買い物: 家族で共有する買い物リスト。
///
/// 買うものを足す → 店でカゴに入れたらチェック → 「買い物おわり」で、
/// 買い出し1件として「がんばり」に記録する。
class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _newListFocus = FocusNode();
  String? _listId;

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _newListFocus.dispose();
    super.dispose();
  }

  void _add(String listId, [String? name]) {
    final text = (name ?? _input.text).trim();
    if (text.isEmpty) return;
    context.readStore.addShoppingItem(listId, text);
    if (name == null) {
      _input.clear();
      _inputFocus.requestFocus();
    }
  }

  /// メニューの「リストを追加」。上の「＋ リスト」欄に入力してもらう。
  void _addList() => _newListFocus.requestFocus();

  void _createList(String name) {
    if (name.trim().isEmpty) return;
    final list = context.readStore.addShoppingList(name);
    setState(() => _listId = list.id);
  }

  Future<void> _renameList(ShoppingList list) async {
    final name = await askText(
      context,
      title: 'リストの名前',
      initial: list.name,
      confirm: '保存',
    );
    if (name == null || !mounted) return;
    context.readStore.renameShoppingList(list.id, name);
  }

  Future<void> _deleteList(ShoppingList list) async {
    final ok = await confirm(
      context,
      title: '「${list.name}」を削除しますか？',
      message: '中の品物も一緒に消えます。',
      action: '削除',
      destructive: true,
    );
    if (!ok || !mounted) return;
    context.readStore.deleteShoppingList(list.id);
    setState(() => _listId = null);
  }

  void _finish(ShoppingList list) {
    final store = context.readStore;
    final trip = store.finishShopping(list.id);
    if (trip == null) return;
    HapticFeedback.lightImpact();
    showNotice(
      context,
      'おつかれさま！${trip.count}点の買い出しを「がんばり」に記録しました',
      actionLabel: '取り消す',
      onAction: () => store.undoShopping(trip),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lists = store.shoppingLists;
    if (lists.isEmpty) return const Scaffold();
    final list = lists.firstWhere(
      (l) => l.id == _listId,
      orElse: () => lists.first,
    );
    final items = store.shoppingItems(list.id);
    final toBuy = items.where((i) => !i.inCart).toList();
    final inCart = items.where((i) => i.inCart).toList();
    final suggestions = store.shoppingSuggestions(list.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('買い物'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'リストの操作',
            onSelected: (v) => switch (v) {
              'rename' => _renameList(list),
              'delete' => _deleteList(list),
              _ => _addList(),
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'add', child: Text('リストを追加')),
              PopupMenuItem(
                value: 'rename',
                child: Text('「${list.name}」の名前を変える'),
              ),
              if (lists.length > 1)
                PopupMenuItem(
                  value: 'delete',
                  child: Text('「${list.name}」を削除'),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final l in lists)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_listLabel(l)),
                      selected: l.id == list.id,
                      onSelected: (_) => setState(() => _listId = l.id),
                    ),
                  ),
                _NewListField(focusNode: _newListFocus, onSubmit: _createList),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _input,
              focusNode: _inputFocus,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: '買うものを追加',
                prefixIcon: const Icon(Icons.add_shopping_cart_rounded),
                suffixIcon: IconButton(
                  tooltip: '追加',
                  onPressed: () => _add(list.id),
                  icon: Icon(Icons.arrow_upward_rounded, color: scheme.primary),
                ),
              ),
              onSubmitted: (_) => _add(list.id),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (suggestions.isNotEmpty)
                  SectionLabel(
                    'よく買うものから追加',
                    padding: const EdgeInsets.fromLTRB(4, 6, 0, 0),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          store.showShoppingSuggestions ? '表示' : '非表示',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: store.showShoppingSuggestions,
                            onChanged: store.setShowShoppingSuggestions,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (suggestions.isNotEmpty &&
                    store.showShoppingSuggestions) ...[
                  // 横に流して、品物の一覧が下に押し出されないようにする。
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: suggestions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => ActionChip(
                        avatar: Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: scheme.primary,
                        ),
                        label: Text(suggestions[i]),
                        onPressed: () => _add(list.id, suggestions[i]),
                      ),
                    ),
                  ),
                ],
                if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.shopping_basket_rounded,
                    title: '買うものはありません',
                    message: '思いついたときに足しておくと、買い物に行く人がまとめて買えます。',
                  ),
                if (toBuy.isNotEmpty) ...[
                  SectionLabel('買うもの  ${toBuy.length}点'),
                  _ItemsCard(items: toBuy),
                ],
                if (inCart.isNotEmpty) ...[
                  SectionLabel('カゴに入れた  ${inCart.length}点'),
                  _ItemsCard(items: inCart),
                ],
              ],
            ),
          ),
          if (inCart.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _finish(list),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text('買い物おわり（${inCart.length}点）'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _listLabel(ShoppingList l) {
    final n = context.store.shoppingItems(l.id).where((i) => !i.inCart).length;
    return n == 0 ? l.name : '${l.name}  $n';
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items});
  final List<ShoppingItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(indent: 56),
            _SwipeToDelete(
              key: ValueKey(items[i].id),
              onDelete: () => context.readStore.removeShoppingItem(items[i].id),
              child: _ItemTile(items[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile(this.item);
  final ShoppingItem item;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final checked = item.inCart;

    return InkWell(
      onTap: () =>
          showAppSheet<void>(context, builder: (_) => _ItemEditor(item: item)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 14, 2),
        child: Row(
          children: [
            Tooltip(
              message: checked ? 'カゴから出す' : 'カゴに入れた',
              child: InkResponse(
                radius: 26,
                onTap: () {
                  HapticFeedback.selectionClick();
                  store.updateShoppingItem(item.id, inCart: !checked);
                },
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: checked
                          ? Icon(
                              Icons.check_circle_rounded,
                              key: const ValueKey(true),
                              size: 30,
                              color: scheme.primary,
                            )
                          : Icon(
                              Icons.circle_outlined,
                              key: const ValueKey(false),
                              size: 30,
                              color: scheme.outline,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            if (item.quantityLabel != null) ...[
              _QuantityPill(item.quantityLabel!, dimmed: checked),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: checked ? scheme.onSurfaceVariant : null,
                      fontWeight: checked ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  if (item.note.isNotEmpty)
                    Text(item.note, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: '${store.memberById(item.addedById)?.name ?? 'だれか'}が追加',
              child: MemberAvatar(store.memberById(item.addedById), size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

/// 数の左に出す「2個」の札。
class _QuantityPill extends StatelessWidget {
  const _QuantityPill(this.label, {this.dimmed = false});
  final String label;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dimmed ? scheme.surfaceContainerHigh : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleSmall?.copyWith(
          color: dimmed ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 左にスワイプすると「削除」ボタンが出る行。
class _SwipeToDelete extends StatefulWidget {
  const _SwipeToDelete({
    super.key,
    required this.child,
    required this.onDelete,
  });
  final Widget child;
  final VoidCallback onDelete;

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete>
    with SingleTickerProviderStateMixin {
  static const _buttonWidth = 104.0;
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dragUpdate(DragUpdateDetails d) {
    _controller.value -= d.primaryDelta! / _buttonWidth;
  }

  void _dragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final open = v < -300 || (v <= 300 && _controller.value > 0.5);
    open ? _controller.forward() : _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return GestureDetector(
      onHorizontalDragUpdate: _dragUpdate,
      onHorizontalDragEnd: _dragEnd,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final offset = -_controller.value * _buttonWidth;
          return Stack(
            children: [
              if (_controller.value > 0)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: _buttonWidth,
                      height: double.infinity,
                      child: Material(
                        color: scheme.error,
                        child: InkWell(
                          onTap: widget.onDelete,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete_rounded,
                                color: scheme.onError,
                                size: 22,
                              ),
                              Text(
                                '削除',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: scheme.onError,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(offset, 0),
                child: Material(color: theme.cardTheme.color, child: child),
              ),
              // 開いているときに行をタップしたら、閉じるだけにする。
              if (_controller.value > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  right: _buttonWidth,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _controller.reverse,
                  ),
                ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// 「＋ リスト」。タップするとその場で入力欄になり、すぐにキーボードが出る。
class _NewListField extends StatefulWidget {
  const _NewListField({required this.focusNode, required this.onSubmit});
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;

  @override
  State<_NewListField> createState() => _NewListFieldState();
}

class _NewListFieldState extends State<_NewListField> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_changed);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_changed);
    _text.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  void _submit() {
    final name = _text.text.trim();
    if (name.isEmpty) {
      widget.focusNode.unfocus();
      return;
    }
    widget.onSubmit(name);
    _text.clear();
    widget.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = widget.focusNode.hasFocus || _text.text.isNotEmpty;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: active ? 200 : 104,
      child: TextField(
        controller: _text,
        focusNode: widget.focusNode,
        textInputAction: TextInputAction.done,
        style: theme.textTheme.labelLarge,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: scheme.surface,
          hintText: active ? '例: ホームセンター' : 'リスト',
          hintStyle: theme.textTheme.labelLarge?.copyWith(
            color: active ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          prefixIcon: const Icon(Icons.add_rounded, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
          suffixIcon: active
              ? IconButton(
                  tooltip: 'リストを追加',
                  visualDensity: VisualDensity.compact,
                  onPressed: _submit,
                  icon: Icon(Icons.check_rounded, color: scheme.primary),
                )
              : null,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
        ),
        onSubmitted: (_) => _submit(),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}

/// 品物の名前・数・メモの変更と削除。
class _ItemEditor extends StatefulWidget {
  const _ItemEditor({required this.item});
  final ShoppingItem item;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _note = TextEditingController(text: widget.item.note);
  late int? _quantity = widget.item.quantity;
  late String _unit = widget.item.unit;
  late final _bigQuantity = TextEditingController(
    text: (widget.item.quantity ?? 0) > 10 ? '${widget.item.quantity}' : '',
  );

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _bigQuantity.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final store = context.readStore;
    store.updateShoppingItem(widget.item.id, name: name, note: _note.text);
    store.setShoppingQuantity(widget.item.id, _quantity, unit: _unit);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = shoppingUnits.contains(_unit)
        ? shoppingUnits
        : [_unit, ...shoppingUnits];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('品物を編集', style: theme.textTheme.titleLarge),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: '品物'),
        ),
        SectionLabel(
          '数',
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
          trailing: _quantity == null
              ? null
              : Text(
                  '$_quantity$_unit',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('なし'),
              selected: _quantity == null,
              onSelected: (_) => setState(() {
                _quantity = null;
                _bigQuantity.clear();
              }),
            ),
            for (var n = 1; n <= 10; n++)
              ChoiceChip(
                label: Text('$n'),
                selected: _quantity == n,
                onSelected: (_) => setState(() {
                  _quantity = n;
                  _bigQuantity.clear();
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _bigQuantity,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(
                  labelText: '11以上は入力',
                  hintText: '例: 12',
                ),
                onChanged: (v) => setState(() {
                  final n = int.tryParse(v);
                  _quantity = n == null || n <= 0 ? null : n;
                }),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 128,
              child: DropdownButtonFormField<String>(
                initialValue: _unit,
                decoration: const InputDecoration(labelText: '単位'),
                menuMaxHeight: 320,
                items: [
                  for (final u in units)
                    DropdownMenuItem(value: u, child: Text(u)),
                ],
                onChanged: (u) => setState(() => _unit = u ?? _unit),
              ),
            ),
          ],
        ),
        const SectionLabel('メモ', padding: EdgeInsets.fromLTRB(0, 18, 0, 8)),
        TextField(
          controller: _note,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: '例: 低脂肪のもの、特売なら2つ'),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              onPressed: () {
                context.readStore.removeShoppingItem(widget.item.id);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: const Text('リストから消す'),
            ),
            const Spacer(),
            FilledButton(onPressed: _save, child: const Text('保存')),
          ],
        ),
      ],
    );
  }
}

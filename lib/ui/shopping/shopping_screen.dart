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
  String? _listId;

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
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

  Future<void> _addList() async {
    final name = await askText(
      context,
      title: 'リストを追加',
      hint: '例: ホームセンター',
      confirm: '追加',
    );
    if (name == null || !mounted) return;
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
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('リスト'),
                  onPressed: _addList,
                ),
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
                if (suggestions.isNotEmpty) ...[
                  const SectionLabel(
                    'よく買うものから追加',
                    padding: EdgeInsets.fromLTRB(4, 14, 4, 8),
                  ),
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
            _ItemTile(items[i], key: ValueKey(items[i].id)),
          ],
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile(this.item, {super.key});
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

/// 品物の名前・メモの変更と削除。
class _ItemEditor extends StatefulWidget {
  const _ItemEditor({required this.item});
  final ShoppingItem item;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _note = TextEditingController(text: widget.item.note);

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    context.readStore.updateShoppingItem(
      widget.item.id,
      name: name,
      note: _note.text,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          autofocus: widget.item.note.isEmpty,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: '数やメモ',
            hintText: '例: 2本、低脂肪のもの',
          ),
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

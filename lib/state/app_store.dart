/// アプリの状態を持ち、変更を画面に知らせて保存するクラス。
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/app_data.dart';
import '../data/storage.dart';
import '../domain/agenda.dart';
import '../domain/catalog.dart';
import '../domain/dates.dart';
import '../domain/models.dart';
import '../domain/notifications.dart';
import '../domain/recurrence.dart';
import '../domain/report.dart';

/// 「買い物おわり」を取り消すための控え。
class ShoppingTrip {
  const ShoppingTrip({required this.recordId, required this.itemIds});
  final String recordId;
  final List<String> itemIds;
  int get count => itemIds.length;
}

class AppStore extends ChangeNotifier {
  AppStore(this._storage, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const storageKey = 'state_v2';
  static const legacyStorageKey = 'state_v1';
  static const brokenBackupKey = 'state_v2_broken';

  /// 買った品物の履歴を残す件数。
  static const _boughtHistoryLimit = 400;

  final KeyValueStorage _storage;
  final DateTime Function() _clock;
  final _random = Random();
  var _seq = 0;

  AppData _data = AppData();
  Future<void> _saving = Future.value();
  Agenda? _agenda;
  DateTime? _lastToday;

  // ---- 読み込みと保存 ----

  /// 保存してあるデータを読む。0.1 のデータしかなければ引き継ぐ。
  Future<void> load() async {
    String? raw;
    var fromLegacy = false;
    try {
      raw = await _storage.read(storageKey);
      if (raw == null) {
        raw = await _storage.read(legacyStorageKey);
        fromLegacy = raw != null;
      }
    } catch (_) {
      raw = null; // 保存先が使えない環境では、空の状態から始める。
    }
    var migrated = false;
    if (raw != null) {
      try {
        _data = decodeAppData(raw);
        migrated = fromLegacy;
      } catch (_) {
        // 読めないデータは別の場所に残して、空の状態から始める。
        try {
          await _storage.write(brokenBackupKey, raw);
        } catch (_) {}
        _data = AppData();
      }
    }
    _lastToday = today;
    _agenda = null;
    notifyListeners();
    // 前の版から引き継いだデータは、すぐに新しい形で保存しておく。
    if (migrated) _save();
  }

  /// 保存が終わるまで待つ（テスト用）。
  Future<void> flush() => _saving;

  void _changed() {
    _agenda = null;
    notifyListeners();
    _save();
  }

  void _save() {
    final snapshot = _data.encode();
    _saving = _saving.then((_) async {
      try {
        await _storage.write(storageKey, snapshot);
      } catch (_) {
        // 保存に失敗しても、画面の操作は続けられるようにする。
      }
    });
  }

  String _newId() {
    final t = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final s = (_seq++).toRadixString(36);
    final r = _random.nextInt(1 << 20).toRadixString(36);
    return '$t-$s$r';
  }

  // ---- 時刻 ----

  DateTime get now => _clock();
  DateTime get today => dateOnly(_clock());

  /// 日付が変わっていたら画面を更新する。アプリを開いたままの夜越しに備える。
  void refreshClock() {
    final t = today;
    if (_lastToday != null && _lastToday == t) return;
    _lastToday = t;
    _agenda = null;
    notifyListeners();
  }

  // ---- 参照 ----

  bool get onboarded => _data.onboarded;
  Appearance get appearance => _data.appearance;
  NotificationSettings get notifications => _data.notifications;

  List<Member> get members => List.unmodifiable(_data.members);
  String? get currentMemberId => _data.currentMemberId;
  Member? get currentMember => memberById(_data.currentMemberId);

  Member? memberById(String? id) {
    if (id == null) return null;
    for (final m in _data.members) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// 並び順どおりの全ジャンル。
  List<Genre> get genres =>
      [..._data.genres]..sort((a, b) => a.order.compareTo(b.order));

  List<Genre> get visibleGenres => genres.where((g) => !g.hidden).toList();

  /// ジャンルを引く。消えていたら「その他」を返す。
  Genre genreById(String id) {
    Genre? other;
    for (final g in _data.genres) {
      if (g.id == id) return g;
      if (g.id == otherGenreId) other = g;
    }
    return other ?? _data.genres.first;
  }

  /// 一覧に出す家事（名前順）。
  List<Chore> get chores =>
      _data.chores.where((c) => !c.archived).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Chore? choreById(String id) {
    for (final c in _data.chores) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Record> get records => List.unmodifiable(_data.records);

  Record? recordById(String id) {
    for (final r in _data.records) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// ホーム画面のやること。変更があるまで使い回す。
  Agenda get agenda => _agenda ??= buildAgenda(
    chores: _data.chores,
    records: _data.records,
    today: today,
  );

  /// 下のタブに出すバッジの件数。
  int get badgeCount => agenda.pendingCount(
    memberId: notifications.badgeMineOnly ? currentMemberId : null,
  );

  DateTime? nextDue(Chore chore) => nextDueDate(chore, _data.records, today);

  /// 繰り返しの次回を確かめるための「最後に手をつけた日」。
  DateTime? lastTouched(String choreId) =>
      lastTouchedDate(choreId, _data.records);

  Report report(ReportPeriod period) => buildReport(
    members: _data.members,
    chores: _data.chores,
    records: _data.records,
    thanks: _data.thanks,
    period: period,
  );

  List<PlannedNotice> get plannedNotices => planNotices(
    agenda: agenda,
    settings: notifications,
    memberId: currentMemberId,
    messages: _data.messages,
    members: _data.members,
  );

  /// ホームで日付をえらんだときの、その日の家事。
  AgendaDay dayItems(DateTime date) =>
      buildDayItems(chores: _data.chores, records: _data.records, date: date);

  /// 今日家事をした人と件数（多い順）。
  List<MemberCount> get todayDoneCounts => doneCountsBetween(
    members: _data.members,
    records: _data.records,
    from: today,
    to: today,
  );

  /// 直近1週間（今日を含む7日）の、人ごとの件数（多い順）。
  List<MemberCount> get weekDoneCounts => doneCountsBetween(
    members: _data.members,
    records: _data.records,
    from: addDays(today, -(messageDays - 1)),
    to: today,
  );

  // ---- はじめての設定 ----

  /// 名前と家族、最初の家事を登録して使い始める。
  void completeOnboarding({
    required String myName,
    List<String> familyNames = const [],
    List<ChoreTemplate> templates = const [],
  }) {
    final names = [
      myName,
      ...familyNames,
    ].map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) names.add('わたし');
    _data.members = [
      for (var i = 0; i < names.length; i++)
        Member(
          id: _newId(),
          name: names[i],
          color: memberColors[i % memberColors.length],
        ),
    ];
    _data.currentMemberId = _data.members.first.id;
    for (final t in templates) {
      _data.chores.add(_fromTemplate(t));
    }
    if (_data.lists.isEmpty) _data.lists = defaultShoppingLists();
    _data.onboarded = true;
    _changed();
  }

  Chore _fromTemplate(ChoreTemplate t) => Chore(
    id: _newId(),
    name: t.name,
    genreId: t.genreId,
    start: t.startFor(today),
    repeat: t.repeat,
    dueMinutes: t.dueMinutes,
  );

  // ---- メンバー ----

  Member addMember(String name) {
    final used = {for (final m in _data.members) m.color};
    final color = memberColors.firstWhere(
      (c) => !used.contains(c),
      orElse: () => memberColors[_data.members.length % memberColors.length],
    );
    final member = Member(id: _newId(), name: name.trim(), color: color);
    _data.members.add(member);
    _data.currentMemberId ??= member.id;
    _changed();
    return member;
  }

  void updateMember(String id, {String? name, int? color}) {
    final i = _data.members.indexWhere((m) => m.id == id);
    if (i < 0) return;
    _data.members[i] = _data.members[i].copyWith(
      name: name?.trim(),
      color: color,
    );
    _changed();
  }

  /// メンバーを外す。過去の記録は「がんばり」に残る。最後の1人は外せない。
  void removeMember(String id) {
    if (_data.members.length <= 1) return;
    _data.members.removeWhere((m) => m.id == id);
    _data.chores = [
      for (final c in _data.chores)
        c.assigneeId == id ? c.copyWith(assigneeId: null) : c,
    ];
    if (_data.currentMemberId == id) {
      _data.currentMemberId = _data.members.first.id;
    }
    _changed();
  }

  void setCurrentMember(String id) {
    if (memberById(id) == null || _data.currentMemberId == id) return;
    _data.currentMemberId = id;
    _changed();
  }

  // ---- ジャンル ----

  Genre addGenre(String name, String icon, int color) {
    final maxOrder = _data.genres.fold<int>(-1, (m, g) => max(m, g.order));
    final genre = Genre(
      id: _newId(),
      name: name.trim(),
      icon: icon,
      color: color,
      order: maxOrder + 1,
    );
    _data.genres.add(genre);
    _changed();
    return genre;
  }

  void updateGenre(
    String id, {
    String? name,
    String? icon,
    int? color,
    bool? hidden,
  }) {
    final i = _data.genres.indexWhere((g) => g.id == id);
    if (i < 0) return;
    _data.genres[i] = _data.genres[i].copyWith(
      name: name?.trim(),
      icon: icon,
      color: color,
      hidden: hidden,
    );
    _changed();
  }

  /// 自作のジャンルを消す。中の家事は「その他」に移す。
  void deleteGenre(String id) {
    final genre = _data.genres.where((g) => g.id == id).firstOrNull;
    if (genre == null || genre.builtIn) return;
    _data.chores = [
      for (final c in _data.chores)
        c.genreId == id ? c.copyWith(genreId: otherGenreId) : c,
    ];
    _data.genres.removeWhere((g) => g.id == id);
    final muted = {..._data.notifications.mutedGenreIds}..remove(id);
    _data.notifications = _data.notifications.copyWith(mutedGenreIds: muted);
    _changed();
  }

  /// ジャンルを並べ替える。位置は [genres]（並び順どおり）での番号。
  void reorderGenres(int oldIndex, int newIndex) {
    final sorted = genres;
    if (oldIndex < 0 || oldIndex >= sorted.length) return;
    final moved = sorted.removeAt(oldIndex);
    sorted.insert(newIndex.clamp(0, sorted.length), moved);
    _data.genres = [
      for (var i = 0; i < sorted.length; i++) sorted[i].copyWith(order: i),
    ];
    _changed();
  }

  // ---- 家事 ----

  /// 新しい家事の ID を作る。
  String newChoreId() => _newId();

  /// 家事を追加する。同じ ID があれば置き換える。
  void saveChore(Chore chore) {
    final i = _data.chores.indexWhere((c) => c.id == chore.id);
    if (i >= 0) {
      _data.chores[i] = chore;
    } else {
      _data.chores.add(chore);
    }
    _changed();
  }

  Chore addFromTemplate(ChoreTemplate template) {
    final chore = _fromTemplate(template);
    _data.chores.add(chore);
    _changed();
    return chore;
  }

  /// 家事を消す。これまでの記録がある家事は、「がんばり」に残すため一覧から隠すだけにする。
  void deleteChore(String id) {
    final hasHistory = _data.records.any((r) => r.choreId == id && r.isDone);
    if (hasHistory) {
      _data.chores = [
        for (final c in _data.chores)
          c.id == id ? c.copyWith(archived: true) : c,
      ];
    } else {
      _data.chores.removeWhere((c) => c.id == id);
      _data.records.removeWhere((r) => r.choreId == id);
    }
    _changed();
  }

  // ---- 記録 ----

  /// 予定の1回分を完了にする。[doneById] を省くと、この端末を使っている人。
  Record complete(Occurrence o, {String? doneById}) =>
      _resolve(o, RecordStatus.done, doneById ?? currentMemberId);

  /// 今回はやらない。
  Record skip(Occurrence o) => _resolve(o, RecordStatus.skipped, null);

  Record _resolve(Occurrence o, RecordStatus status, String? doneById) {
    // 「やった日からN日後」は予定日がやった日で決まるので、記録は今日の分として残す。
    final date = o.chore.repeat.type == RepeatType.afterDone
        ? today
        : dateOnly(o.date);
    _data.records.removeWhere(
      (r) => r.choreId == o.chore.id && !r.unplanned && r.date == date,
    );
    final record = Record(
      id: _newId(),
      choreId: o.chore.id,
      date: date,
      status: status,
      doneById: doneById,
      at: now,
    );
    _data.records.add(record);
    _changed();
    return record;
  }

  /// 記録を取り消す（未完了に戻す）。スタンプも一緒に消える。
  void undoRecord(String recordId) {
    _data.records.removeWhere((r) => r.id == recordId);
    _data.thanks.removeWhere((t) => t.recordId == recordId);
    _changed();
  }

  /// 実際にやった人を付け替える。
  void setDoneBy(String recordId, String memberId) {
    final i = _data.records.indexWhere((r) => r.id == recordId);
    if (i < 0) return;
    final r = _data.records[i];
    _data.records[i] = Record(
      id: r.id,
      choreId: r.choreId,
      date: r.date,
      status: RecordStatus.done,
      doneById: memberId,
      at: r.at,
      unplanned: r.unplanned,
      note: r.note,
    );
    _changed();
  }

  /// 予定にない家事を「やったよ」と記録する。
  Record recordUnplanned(Chore chore, {String? doneById, String note = ''}) {
    final record = Record(
      id: _newId(),
      choreId: chore.id,
      date: today,
      status: RecordStatus.done,
      doneById: doneById ?? currentMemberId,
      at: now,
      unplanned: true,
      note: note,
    );
    _data.records.add(record);
    _changed();
    return record;
  }

  /// 名前だけで予定外の家事を記録する。同じ名前の家事があればそれに付ける。
  Record recordUnplannedByName(
    String name,
    String genreId, {
    String? doneById,
  }) {
    final trimmed = name.trim();
    var chore = _data.chores
        .where(
          (c) => c.name == trimmed && (!c.archived || c.genreId == genreId),
        )
        .firstOrNull;
    if (chore == null) {
      chore = Chore(
        id: _newId(),
        name: trimmed,
        genreId: genreId,
        start: today,
        archived: true,
      );
      _data.chores.add(chore);
    }
    return recordUnplanned(chore, doneById: doneById);
  }

  // ---- スタンプ ----

  List<Thanks> thanksFor(String recordId) =>
      _data.thanks.where((t) => t.recordId == recordId).toList();

  /// この端末を使っている人から、記録にスタンプを送る。
  /// 同じスタンプをもう一度送ると取り消し、別のスタンプなら付け替える。
  void toggleThanks(String recordId, String stamp) {
    final from = currentMemberId;
    if (from == null || recordById(recordId) == null) return;
    final mine = _data.thanks
        .where((t) => t.recordId == recordId && t.fromId == from)
        .firstOrNull;
    _data.thanks.removeWhere((t) => t.recordId == recordId && t.fromId == from);
    if (mine?.stamp != stamp) {
      _data.thanks.add(
        Thanks(
          id: _newId(),
          recordId: recordId,
          fromId: from,
          stamp: stamp,
          at: now,
        ),
      );
    }
    _changed();
  }

  // ---- 買い物 ----

  List<ShoppingList> get shoppingLists =>
      [..._data.lists]..sort((a, b) => a.order.compareTo(b.order));

  /// リストの中の、まだ買っていない品物（追加した順）。
  List<ShoppingItem> shoppingItems(String listId) =>
      _data.items.where((i) => i.listId == listId && !i.isBought).toList()
        ..sort((a, b) => a.addedAt.compareTo(b.addedAt));

  /// すべてのリストの、まだカゴに入れていない品物の数。
  int get shoppingTodoCount =>
      _data.items.where((i) => !i.isBought && !i.inCart).length;

  ShoppingList addShoppingList(String name) {
    final maxOrder = _data.lists.fold<int>(-1, (m, l) => max(m, l.order));
    final list = ShoppingList(
      id: _newId(),
      name: name.trim(),
      order: maxOrder + 1,
    );
    _data.lists.add(list);
    _changed();
    return list;
  }

  void renameShoppingList(String id, String name) {
    final i = _data.lists.indexWhere((l) => l.id == id);
    if (i < 0) return;
    _data.lists[i] = _data.lists[i].copyWith(name: name.trim());
    _changed();
  }

  /// リストを中の品物ごと消す。最後の1つは消せない。
  void deleteShoppingList(String id) {
    if (_data.lists.length <= 1) return;
    _data.lists.removeWhere((l) => l.id == id);
    _data.items.removeWhere((i) => i.listId == id);
    _changed();
  }

  /// 品物を追加する。同じ名前がまだ残っていれば、それを返すだけにする。
  ShoppingItem? addShoppingItem(
    String listId,
    String name, {
    String note = '',
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final existing = _data.items
        .where((i) => i.listId == listId && !i.isBought && i.name == trimmed)
        .firstOrNull;
    if (existing != null) return existing;
    final item = ShoppingItem(
      id: _newId(),
      listId: listId,
      name: trimmed,
      note: note.trim(),
      addedById: currentMemberId,
      addedAt: now,
    );
    _data.items.add(item);
    _changed();
    return item;
  }

  void updateShoppingItem(
    String id, {
    String? name,
    String? note,
    bool? inCart,
  }) {
    final i = _data.items.indexWhere((x) => x.id == id);
    if (i < 0) return;
    _data.items[i] = _data.items[i].copyWith(
      name: name?.trim(),
      note: note?.trim(),
      inCart: inCart,
    );
    _changed();
  }

  /// 品物の数と単位を決める。[quantity] が null なら数を外す。
  void setShoppingQuantity(String id, int? quantity, {String? unit}) {
    final i = _data.items.indexWhere((x) => x.id == id);
    if (i < 0) return;
    final q = quantity == null || quantity <= 0 ? null : quantity;
    _data.items[i] = _data.items[i].copyWith(
      quantity: q,
      unit: unit ?? _data.items[i].unit,
    );
    _changed();
  }

  void removeShoppingItem(String id) {
    _data.items.removeWhere((i) => i.id == id);
    _changed();
  }

  /// 追加の候補。よく買うものを先に、足りなければ定番を足す。
  List<String> shoppingSuggestions(String listId, {int limit = 12}) {
    final current = {
      for (final i in _data.items)
        if (i.listId == listId && !i.isBought) i.name,
    };
    final counts = <String, int>{};
    final lastBought = <String, DateTime>{};
    for (final i in _data.items) {
      if (!i.isBought || i.listId != listId) continue;
      counts[i.name] = (counts[i.name] ?? 0) + 1;
      final at = i.boughtAt!;
      if (lastBought[i.name]?.isBefore(at) ?? true) lastBought[i.name] = at;
    }
    final history = counts.keys.toList()
      ..sort((a, b) {
        final c = counts[b]!.compareTo(counts[a]!);
        return c != 0 ? c : lastBought[b]!.compareTo(lastBought[a]!);
      });
    final isFirstList =
        shoppingLists.isNotEmpty && shoppingLists.first.id == listId;
    final result = <String>[];
    for (final name in [...history, if (isFirstList) ...shoppingStarters]) {
      if (current.contains(name) || result.contains(name)) continue;
      result.add(name);
      if (result.length >= limit) break;
    }
    return result;
  }

  /// カゴに入れた品物を購入済みにして、「買い出し」1件として記録する。
  /// カゴが空なら何もしない。
  ShoppingTrip? finishShopping(String listId, {String? doneById}) {
    final list = _data.lists.where((l) => l.id == listId).firstOrNull;
    final inCart = _data.items
        .where((i) => i.listId == listId && !i.isBought && i.inCart)
        .toList();
    if (list == null || inCart.isEmpty) return null;
    final who = doneById ?? currentMemberId;
    final at = now;
    final ids = {for (final i in inCart) i.id};
    _data.items = [
      for (final i in _data.items)
        ids.contains(i.id)
            ? i.copyWith(inCart: false, boughtById: who, boughtAt: at)
            : i,
    ];
    _pruneBoughtHistory();

    var chore = choreById(shoppingTripChoreId);
    if (chore == null) {
      chore = Chore(
        id: shoppingTripChoreId,
        name: '買い出し',
        genreId: shoppingGenreId,
        start: today,
        archived: true,
      );
      _data.chores.add(chore);
    }
    final record = recordUnplanned(
      chore,
      doneById: who,
      note: '${list.name}・${inCart.length}点',
    );
    return ShoppingTrip(recordId: record.id, itemIds: ids.toList());
  }

  /// 「買い物おわり」を取り消して、品物をカゴに戻す。
  void undoShopping(ShoppingTrip trip) {
    final ids = trip.itemIds.toSet();
    _data.items = [
      for (final i in _data.items)
        ids.contains(i.id)
            ? i.copyWith(inCart: true, boughtById: null, boughtAt: null)
            : i,
    ];
    undoRecord(trip.recordId);
  }

  void _pruneBoughtHistory() {
    final bought = _data.items.where((i) => i.isBought).toList()
      ..sort((a, b) => b.boughtAt!.compareTo(a.boughtAt!));
    if (bought.length <= _boughtHistoryLimit) return;
    final drop = {for (final i in bought.skip(_boughtHistoryLimit)) i.id};
    _data.items.removeWhere((i) => drop.contains(i.id));
  }

  // ---- メッセージ ----

  /// メッセージを出しておく日数。
  static const messageDays = 7;

  /// 古いメッセージを消すまでの日数。
  static const _messageKeepDays = 60;

  /// 直近1週間のメッセージ（新しい順）。
  List<FamilyMessage> get recentMessages {
    final from = addDays(today, -(messageDays - 1));
    return _data.messages.where((m) => !dateOnly(m.at).isBefore(from)).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
  }

  /// この端末を使っている人から [toId] にメッセージを送る。
  FamilyMessage? sendMessage(String toId, String text) {
    final from = currentMemberId;
    final trimmed = text.trim();
    if (from == null || trimmed.isEmpty || memberById(toId) == null) {
      return null;
    }
    final message = FamilyMessage(
      id: _newId(),
      fromId: from,
      toId: toId,
      text: trimmed,
      at: now,
    );
    final keepFrom = addDays(today, -_messageKeepDays);
    _data.messages.removeWhere((m) => m.at.isBefore(keepFrom));
    _data.messages.add(message);
    _changed();
    return message;
  }

  /// 自分が送ったメッセージを消す。ほかの人のメッセージは消せない。
  bool deleteMessage(String id) {
    final before = _data.messages.length;
    _data.messages.removeWhere(
      (m) => m.id == id && m.fromId == currentMemberId,
    );
    if (_data.messages.length == before) return false;
    _changed();
    return true;
  }

  // ---- 設定 ----

  bool get showShoppingSuggestions => _data.showShoppingSuggestions;

  void setShowShoppingSuggestions(bool value) {
    if (_data.showShoppingSuggestions == value) return;
    _data.showShoppingSuggestions = value;
    _changed();
  }

  void updateNotifications(NotificationSettings settings) {
    _data.notifications = settings;
    _changed();
  }

  void setAppearance(Appearance appearance) {
    if (_data.appearance == appearance) return;
    _data.appearance = appearance;
    _changed();
  }

  // ---- データの書き出し・読み込み ----

  /// いまのデータを、バックアップ用の文字列にする。
  String exportData() => _data.encode();

  /// バックアップの文字列でいまのデータを置き換える。読めなければ false。
  bool importData(String raw) {
    final AppData data;
    try {
      data = decodeAppData(raw.trim());
    } catch (_) {
      return false;
    }
    if (data.members.isEmpty) return false;
    _data = data;
    _changed();
    return true;
  }

  /// すべて消して、はじめての設定からやり直す。
  void resetAll() {
    _data = AppData();
    _changed();
  }
}

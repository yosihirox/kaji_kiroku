/// アプリの状態を持ち、端末に保存するクラス。
///
/// 試作版では端末の中だけに保存する。家族での共有（Firebase）は次の段階で
/// このクラスの保存先を差し替えて対応する。
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'recurrence.dart';

/// 保存先。試作版は端末内、次の段階で Firebase に差し替える。
abstract class StateStorage {
  Future<String?> load();
  Future<void> save(String json);
}

/// テスト用など、メモリにだけ持つ保存先。
class MemoryStorage implements StateStorage {
  String? data;
  @override
  Future<String?> load() async => data;
  @override
  Future<void> save(String json) async => data = json;
}

/// ホーム画面の1行分（ある家事のある予定日）。
class AgendaItem {
  AgendaItem({required this.chore, required this.date, this.record});

  final Chore chore;
  final DateTime date;

  /// 完了・スキップ済みならその記録。
  final Record? record;

  bool get isDone => record?.status == RecordStatus.done;
  bool get isResolved => record != null;
}

/// ホーム画面の1日分。
class AgendaDay {
  AgendaDay(this.date, this.items);
  final DateTime date;
  final List<AgendaItem> items;
}

const _memberColors = [
  0xFF4E79A7,
  0xFFE15759,
  0xFF59A14F,
  0xFFF28E2B,
  0xFFB07AA1,
  0xFF76B7B2,
];

List<Genre> defaultGenres() {
  final list = [
    ('cooking', '料理', 'cooking', 0xFFF28E2B),
    ('shopping', '買い物', 'shopping', 0xFF59A14F),
    ('laundry', '洗濯', 'laundry', 0xFF4E79A7),
    ('cleaning', '掃除', 'cleaning', 0xFF76B7B2),
    ('pet', 'ペット', 'pet', 0xFF9C755F),
    ('childcare', '子守', 'childcare', 0xFFFF9DA7),
    ('education', '教育', 'education', 0xFF6A5ACD),
    ('other', 'その他', 'other', 0xFF8C8C8C),
  ];
  return [
    for (var i = 0; i < list.length; i++)
      Genre(
        id: list[i].$1,
        name: list[i].$2,
        iconKey: list[i].$3,
        colorValue: list[i].$4,
        builtIn: true,
        order: i,
      ),
  ];
}

class AppStore extends ChangeNotifier {
  AppStore(this._storage, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final StateStorage _storage;
  final DateTime Function() _clock;
  final _random = Random();

  List<Member> members = [];
  List<Genre> genres = [];
  List<Chore> chores = [];
  List<Record> records = [];

  /// この端末を使っている人。
  String? currentMemberId;

  DateTime get today => dateOnly(_clock());

  Member? get currentMember => memberById(currentMemberId);

  Future<void> load() async {
    final raw = await _storage.load();
    if (raw == null) {
      _seed();
      await _persist();
      return;
    }
    final j = jsonDecode(raw) as Map<String, dynamic>;
    members = [
      for (final m in j['members'] as List) Member.fromJson(m as Map<String, dynamic>)
    ];
    genres = [
      for (final g in j['genres'] as List) Genre.fromJson(g as Map<String, dynamic>)
    ];
    chores = [
      for (final c in j['chores'] as List) Chore.fromJson(c as Map<String, dynamic>)
    ];
    records = [
      for (final r in j['records'] as List) Record.fromJson(r as Map<String, dynamic>)
    ];
    currentMemberId = j['currentMember'] as String?;
    if (members.isEmpty) _seed();
    notifyListeners();
  }

  void _seed() {
    final me = Member(id: newId(), name: 'わたし', colorValue: _memberColors[0]);
    members = [me];
    genres = defaultGenres();
    chores = [];
    records = [];
    currentMemberId = me.id;
  }

  Future<void> _persist() => _storage.save(jsonEncode({
        'version': 1,
        'members': [for (final m in members) m.toJson()],
        'genres': [for (final g in genres) g.toJson()],
        'chores': [for (final c in chores) c.toJson()],
        'records': [for (final r in records) r.toJson()],
        'currentMember': currentMemberId,
      }));

  Future<void> _changed() async {
    notifyListeners();
    await _persist();
  }

  String newId() {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = _random.nextInt(0x7fffffff).toRadixString(36);
    return '$t$r';
  }

  // ---- 参照 ----

  Member? memberById(String? id) {
    if (id == null) return null;
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  Genre genreById(String id) => genres.firstWhere(
        (g) => g.id == id,
        orElse: () => genres.firstWhere((g) => g.id == 'other',
            orElse: () => genres.first),
      );

  Chore? choreById(String id) {
    for (final c in chores) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Genre> get visibleGenres =>
      (genres.where((g) => !g.hidden).toList()..sort((a, b) => a.order.compareTo(b.order)));

  List<Chore> get activeChores => chores.where((c) => !c.archived).toList();

  // ---- メンバー ----

  Future<void> addMember(String name) async {
    members.add(Member(
      id: newId(),
      name: name,
      colorValue: _memberColors[members.length % _memberColors.length],
    ));
    await _changed();
  }

  Future<void> renameMember(String id, String name) async {
    memberById(id)?.name = name;
    await _changed();
  }

  /// メンバーを外す。過去の記録は「（退出したメンバー）」として残る。
  Future<void> removeMember(String id) async {
    if (members.length <= 1) return;
    members.removeWhere((m) => m.id == id);
    for (final c in chores) {
      if (c.assigneeId == id) c.assigneeId = null;
    }
    if (currentMemberId == id) currentMemberId = members.first.id;
    await _changed();
  }

  Future<void> setCurrentMember(String id) async {
    currentMemberId = id;
    await _changed();
  }

  // ---- ジャンル ----

  Future<void> addGenre(String name, String iconKey, int colorValue) async {
    final maxOrder = genres.fold<int>(0, (m, g) => max(m, g.order));
    genres.add(Genre(
      id: newId(),
      name: name,
      iconKey: iconKey,
      colorValue: colorValue,
      order: maxOrder + 1,
    ));
    await _changed();
  }

  Future<void> updateGenre(Genre g,
      {String? name, String? iconKey, int? colorValue, bool? hidden}) async {
    if (name != null) g.name = name;
    if (iconKey != null) g.iconKey = iconKey;
    if (colorValue != null) g.colorValue = colorValue;
    if (hidden != null) g.hidden = hidden;
    await _changed();
  }

  /// 自作ジャンルを消す。中の家事は「その他」に移す。
  Future<void> deleteGenre(Genre g) async {
    if (g.builtIn) return;
    for (final c in chores) {
      if (c.genreId == g.id) c.genreId = 'other';
    }
    genres.remove(g);
    await _changed();
  }

  // ---- 家事 ----

  Future<void> saveChore(Chore chore) async {
    final i = chores.indexWhere((c) => c.id == chore.id);
    if (i >= 0) {
      chores[i] = chore;
    } else {
      chores.add(chore);
    }
    await _changed();
  }

  Future<void> deleteChore(String id) async {
    chores.removeWhere((c) => c.id == id);
    // 実績は「がんばり」に残したいので、記録がある家事は非表示にするだけでもよいが、
    // 試作版では家事ごと消すと記録も消す。
    records.removeWhere((r) => r.choreId == id);
    await _changed();
  }

  // ---- 記録 ----

  Record? recordFor(String choreId, DateTime date) {
    final d = dateOnly(date);
    for (final r in records) {
      if (r.choreId == choreId && !r.unplanned && r.date == d) return r;
    }
    return null;
  }

  DateTime? lastDoneDate(String choreId) {
    DateTime? last;
    for (final r in records) {
      if (r.choreId != choreId || r.status != RecordStatus.done) continue;
      // afterDone は「実際にやった日」から数える。
      final d = dateOnly(r.at);
      if (last == null || d.isAfter(last)) last = d;
    }
    return last;
  }

  /// 予定日の家事を完了にする。[doneById] を省くと「この端末の人」。
  Future<void> complete(Chore chore, DateTime date, {String? doneById}) async {
    _removeRecord(chore.id, date);
    records.add(Record(
      id: newId(),
      choreId: chore.id,
      date: dateOnly(date),
      status: RecordStatus.done,
      doneById: doneById ?? currentMemberId,
      at: _clock(),
    ));
    await _changed();
  }

  /// 今回はやらない。
  Future<void> skip(Chore chore, DateTime date) async {
    _removeRecord(chore.id, date);
    records.add(Record(
      id: newId(),
      choreId: chore.id,
      date: dateOnly(date),
      status: RecordStatus.skipped,
      at: _clock(),
    ));
    await _changed();
  }

  /// 完了・スキップを取り消す。
  Future<void> undo(Chore chore, DateTime date) async {
    _removeRecord(chore.id, date);
    await _changed();
  }

  Future<void> deleteRecord(Record record) async {
    records.removeWhere((r) => r.id == record.id);
    await _changed();
  }

  void _removeRecord(String choreId, DateTime date) {
    final d = dateOnly(date);
    records.removeWhere((r) => r.choreId == choreId && !r.unplanned && r.date == d);
  }

  /// 予定にない家事を「やったよ」と記録する。
  Future<void> recordUnplanned(Chore chore, {String? doneById}) async {
    records.add(Record(
      id: newId(),
      choreId: chore.id,
      date: today,
      status: RecordStatus.done,
      doneById: doneById ?? currentMemberId,
      at: _clock(),
      unplanned: true,
    ));
    await _changed();
  }

  /// 名前だけで予定外の家事を記録する（一覧には出さない家事として作る）。
  Future<void> recordUnplannedByName(String name, String genreId,
      {String? doneById}) async {
    final chore = Chore(
      id: newId(),
      name: name,
      genreId: genreId,
      startDate: today,
      repeat: const Repeat.none(),
      archived: true,
    );
    chores.add(chore);
    await recordUnplanned(chore, doneById: doneById);
  }

  // ---- ホーム画面 ----

  /// 期限を過ぎて未完了の家事。家事ごとに一番新しい1回分だけ出す。
  List<AgendaItem> overdue({int lookbackDays = 30}) {
    final from = addDays(today, -lookbackDays);
    final yesterday = addDays(today, -1);
    final items = <AgendaItem>[];
    for (final c in activeChores) {
      final List<DateTime> dates;
      switch (c.repeat.type) {
        case RepeatType.none:
          dates = c.startDate.isBefore(today) ? [dateOnly(c.startDate)] : [];
        case RepeatType.afterDone:
          final next = c.repeat.nextAfterDone(c.startDate, lastDoneDate(c.id));
          dates = next.isBefore(today) ? [next] : [];
        default:
          dates = c.repeat.occurrencesBetween(from, yesterday, c.startDate);
      }
      for (final d in dates.reversed) {
        final rec = recordFor(c.id, d);
        if (rec != null) break; // それ以降は片付いている
        items.add(AgendaItem(chore: c, date: d));
        break;
      }
    }
    items.sort((a, b) => a.date.compareTo(b.date));
    return items;
  }

  /// 今日から [days] 日分の予定。完了済みも含める（チェック済みで表示する）。
  List<AgendaDay> upcoming({int days = 7}) {
    final end = addDays(today, days - 1);
    final byDay = <DateTime, List<AgendaItem>>{};
    for (var i = 0; i < days; i++) {
      byDay[addDays(today, i)] = [];
    }
    for (final c in activeChores) {
      final last = lastDoneDate(c.id);
      final dates = c.repeat.occurrencesBetween(today, end, c.startDate, lastDone: last);
      for (final d in dates) {
        byDay[d]?.add(AgendaItem(chore: c, date: d, record: recordFor(c.id, d)));
      }
      // afterDone で今日以降に完了済みの回は、次回が先へずれるので別途表示する。
      if (c.repeat.type == RepeatType.afterDone) {
        for (final r in records) {
          if (r.choreId == c.id &&
              !r.unplanned &&
              !r.date.isBefore(today) &&
              !r.date.isAfter(end) &&
              !dates.contains(r.date)) {
            byDay[r.date]?.add(AgendaItem(chore: c, date: r.date, record: r));
          }
        }
      }
    }
    // 予定外の「ついでにやった」は今日の欄に出す。
    for (final r in records) {
      if (r.unplanned && r.date == today) {
        final c = choreById(r.choreId);
        if (c != null) byDay[today]!.add(AgendaItem(chore: c, date: today, record: r));
      }
    }
    return [
      for (final e in byDay.entries)
        AgendaDay(
          e.key,
          e.value
            ..sort((a, b) {
              if (a.isResolved != b.isResolved) return a.isResolved ? 1 : -1;
              return a.chore.name.compareTo(b.chore.name);
            }),
        ),
    ];
  }

  /// アイコンのバッジに出す件数（期限切れ＋今日の未完了）。
  int badgeCount({bool onlyMine = false}) {
    bool mine(Chore c) =>
        !onlyMine || c.assigneeId == null || c.assigneeId == currentMemberId;
    final todayItems = upcoming(days: 1).first.items;
    return overdue().where((i) => mine(i.chore)).length +
        todayItems.where((i) => !i.isResolved && mine(i.chore)).length;
  }

  // ---- がんばり ----

  /// 期間内に完了した記録（新しい順）。
  List<Record> doneBetween(DateTime from, DateTime to) {
    final f = dateOnly(from);
    final t = dateOnly(to);
    final list = records.where((r) {
      if (r.status != RecordStatus.done) return false;
      final d = dateOnly(r.at);
      return !d.isBefore(f) && !d.isAfter(t);
    }).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }
}

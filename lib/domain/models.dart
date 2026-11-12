/// アプリで扱うデータの型。
///
/// 「家事の定義（[Chore]）」と「毎回の実施記録（[Record]）」を分けている。
/// こうすると「担当予定者」と「実際にやった人」を毎回別々に残せる。
/// どの型も変更できない値で、変えるときは copyWith で新しい値を作る。
library;

import 'dates.dart';
import 'recurrence.dart';

const _keep = Object();

int _int(Object? v, int fallback) => v is num ? v.toInt() : fallback;
int? _intOrNull(Object? v) => v is num ? v.toInt() : null;
String _str(Object? v, [String fallback = '']) => v is String ? v : fallback;
bool _bool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;
DateTime _time(Object? v) =>
    (v is String ? DateTime.tryParse(v) : null) ??
    DateTime.fromMillisecondsSinceEpoch(0);

/// 家族のメンバー。
class Member {
  const Member({required this.id, required this.name, required this.color});

  final String id;
  final String name;

  /// ARGB の色。
  final int color;

  Member copyWith({String? name, int? color}) =>
      Member(id: id, name: name ?? this.name, color: color ?? this.color);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  factory Member.fromJson(Map<String, dynamic> j) => Member(
    id: _str(j['id']),
    name: _str(j['name'], '？'),
    color: _int(j['color'], 0xFF2E9E8F),
  );
}

/// 家事のジャンル（料理・掃除など）。初期ジャンルと、ユーザーが作ったジャンルがある。
class Genre {
  const Genre({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.builtIn = false,
    this.hidden = false,
    this.order = 0,
  });

  final String id;
  final String name;

  /// アイコンのキー（画面側の一覧から引く）。
  final String icon;
  final int color;
  final bool builtIn;
  final bool hidden;
  final int order;

  Genre copyWith({
    String? name,
    String? icon,
    int? color,
    bool? hidden,
    int? order,
  }) => Genre(
    id: id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    builtIn: builtIn,
    hidden: hidden ?? this.hidden,
    order: order ?? this.order,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'builtIn': builtIn,
    'hidden': hidden,
    'order': order,
  };

  factory Genre.fromJson(Map<String, dynamic> j) => Genre(
    id: _str(j['id']),
    name: _str(j['name'], '？'),
    icon: _str(j['icon'], 'other'),
    color: _int(j['color'], 0xFF8A8F98),
    builtIn: _bool(j['builtIn']),
    hidden: _bool(j['hidden']),
    order: _int(j['order'], 0),
  );
}

/// 家事の定義。繰り返しルールを持つ。
class Chore {
  const Chore({
    required this.id,
    required this.name,
    required this.genreId,
    required this.start,
    this.repeat = const Repeat.none(),
    this.dueMinutes,
    this.assigneeId,
    this.memo = '',
    this.archived = false,
  });

  final String id;
  final String name;
  final String genreId;

  /// 初回の日付（繰り返しの起点）。1回だけの家事では期限日。
  final DateTime start;
  final Repeat repeat;

  /// 「何時までに」。0:00 からの分。決めないときは null。
  final int? dueMinutes;

  /// 担当予定者。null は「だれでも」。
  final String? assigneeId;
  final String memo;

  /// 家事の一覧や予定に出さないもの（予定外の記録のためだけに作った家事など）。
  final bool archived;

  Chore copyWith({
    String? name,
    String? genreId,
    DateTime? start,
    Repeat? repeat,
    Object? dueMinutes = _keep,
    Object? assigneeId = _keep,
    String? memo,
    bool? archived,
  }) => Chore(
    id: id,
    name: name ?? this.name,
    genreId: genreId ?? this.genreId,
    start: start ?? this.start,
    repeat: repeat ?? this.repeat,
    dueMinutes: identical(dueMinutes, _keep)
        ? this.dueMinutes
        : dueMinutes as int?,
    assigneeId: identical(assigneeId, _keep)
        ? this.assigneeId
        : assigneeId as String?,
    memo: memo ?? this.memo,
    archived: archived ?? this.archived,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'genreId': genreId,
    'start': dateKey(start),
    'repeat': repeat.toJson(),
    'due': dueMinutes,
    'assignee': assigneeId,
    'memo': memo,
    'archived': archived,
  };

  factory Chore.fromJson(Map<String, dynamic> j) => Chore(
    id: _str(j['id']),
    name: _str(j['name'], '？'),
    genreId: _str(j['genreId'], 'other'),
    start: parseDateKey(_str(j['start'], '2026-01-01')),
    repeat: j['repeat'] is Map
        ? Repeat.fromJson((j['repeat'] as Map).cast<String, dynamic>())
        : const Repeat.none(),
    dueMinutes: _intOrNull(j['due']),
    assigneeId: j['assignee'] as String?,
    memo: _str(j['memo']),
    archived: _bool(j['archived']),
  );
}

enum RecordStatus { done, skipped }

/// 1回分の実施記録。予定日に対する完了・スキップ、または予定外の実施。
class Record {
  const Record({
    required this.id,
    required this.choreId,
    required this.date,
    required this.status,
    required this.at,
    this.doneById,
    this.unplanned = false,
    this.note = '',
  });

  final String id;
  final String choreId;

  /// どの予定日の分か。予定外の実施ではやった日。
  final DateTime date;
  final RecordStatus status;

  /// 実際にやった人（スキップのときは null）。
  final String? doneById;

  /// 記録した日時。「がんばり」はこの日時で集計する。
  final DateTime at;

  /// 予定にない「ついでにやった」記録か。
  final bool unplanned;

  /// ひとことメモ（買い出しの「スーパー・5点」など）。
  final String note;

  bool get isDone => status == RecordStatus.done;

  Map<String, dynamic> toJson() => {
    'id': id,
    'choreId': choreId,
    'date': dateKey(date),
    'status': status.name,
    'doneBy': doneById,
    'at': at.toIso8601String(),
    'unplanned': unplanned,
    if (note.isNotEmpty) 'note': note,
  };

  factory Record.fromJson(Map<String, dynamic> j) => Record(
    id: _str(j['id']),
    choreId: _str(j['choreId']),
    date: parseDateKey(_str(j['date'], '2026-01-01')),
    status: RecordStatus.values.asNameMap()[j['status']] ?? RecordStatus.done,
    doneById: j['doneBy'] as String?,
    at: _time(j['at']),
    unplanned: _bool(j['unplanned']),
    note: _str(j['note']),
  );
}

/// 完了した家事に家族が送る「ありがとう」などのスタンプ。
class Thanks {
  const Thanks({
    required this.id,
    required this.recordId,
    required this.fromId,
    required this.stamp,
    required this.at,
  });

  final String id;
  final String recordId;
  final String fromId;

  /// スタンプのキー（[stampKeys] のどれか）。
  final String stamp;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'id': id,
    'recordId': recordId,
    'from': fromId,
    'stamp': stamp,
    'at': at.toIso8601String(),
  };

  factory Thanks.fromJson(Map<String, dynamic> j) => Thanks(
    id: _str(j['id']),
    recordId: _str(j['recordId']),
    fromId: _str(j['from']),
    stamp: _str(j['stamp'], stampKeys.first),
    at: _time(j['at']),
  );
}

/// スタンプの種類と、その表示名。
const stampLabels = <String, String>{
  'thanks': 'ありがとう',
  'great': 'すごい！',
  'helped': 'たすかった',
  'otsukare': 'おつかれさま',
};
final stampKeys = stampLabels.keys.toList(growable: false);

/// 買い物リスト（「スーパー」「ドラッグストア」など）。
class ShoppingList {
  const ShoppingList({required this.id, required this.name, this.order = 0});

  final String id;
  final String name;
  final int order;

  ShoppingList copyWith({String? name, int? order}) =>
      ShoppingList(id: id, name: name ?? this.name, order: order ?? this.order);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'order': order};

  factory ShoppingList.fromJson(Map<String, dynamic> j) => ShoppingList(
    id: _str(j['id']),
    name: _str(j['name'], '買い物'),
    order: _int(j['order'], 0),
  );
}

/// 買い物の数につける単位。よく使うものから順に並べる。
const shoppingUnits = <String>[
  '個',
  'パック',
  '本',
  '袋',
  '枚',
  '箱',
  '玉',
  '束',
  '缶',
  '切れ',
  '房',
  '尾',
  '丁',
  '株',
  'kg',
  'g',
  'L',
  'ml',
  'セット',
  '組',
  '足',
  '台',
];

/// 単位をえらばなかったときの単位。
const defaultShoppingUnit = '個';

/// 買い物リストの品物。
///
/// 「買うもの」→ カゴに入れた（[inCart]）→ 買い物おわりで購入済み（[boughtAt]）と進む。
/// 購入済みの品物は、次に追加するときの候補として残す。
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.listId,
    required this.name,
    required this.addedAt,
    this.note = '',
    this.quantity,
    this.unit = defaultShoppingUnit,
    this.addedById,
    this.inCart = false,
    this.boughtById,
    this.boughtAt,
  });

  final String id;
  final String listId;
  final String name;

  /// メモ（「低脂肪のやつ」など）。0.2 までは数もここに書いていた。
  final String note;

  /// 買う数。null は数を決めていない。
  final int? quantity;

  /// 数の単位（「個」「パック」など）。
  final String unit;
  final String? addedById;
  final DateTime addedAt;
  final bool inCart;
  final String? boughtById;
  final DateTime? boughtAt;

  bool get isBought => boughtAt != null;

  /// 「2個」のような表示。数がなければ null。
  String? get quantityLabel => quantity == null ? null : '$quantity$unit';

  ShoppingItem copyWith({
    String? name,
    String? note,
    Object? quantity = _keep,
    String? unit,
    bool? inCart,
    Object? boughtById = _keep,
    Object? boughtAt = _keep,
  }) => ShoppingItem(
    id: id,
    listId: listId,
    name: name ?? this.name,
    note: note ?? this.note,
    quantity: identical(quantity, _keep) ? this.quantity : quantity as int?,
    unit: unit ?? this.unit,
    addedById: addedById,
    addedAt: addedAt,
    inCart: inCart ?? this.inCart,
    boughtById: identical(boughtById, _keep)
        ? this.boughtById
        : boughtById as String?,
    boughtAt: identical(boughtAt, _keep)
        ? this.boughtAt
        : boughtAt as DateTime?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'listId': listId,
    'name': name,
    if (note.isNotEmpty) 'note': note,
    if (quantity != null) 'quantity': quantity,
    if (unit != defaultShoppingUnit) 'unit': unit,
    'addedBy': addedById,
    'addedAt': addedAt.toIso8601String(),
    'inCart': inCart,
    if (boughtById != null) 'boughtBy': boughtById,
    if (boughtAt != null) 'boughtAt': boughtAt!.toIso8601String(),
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
    id: _str(j['id']),
    listId: _str(j['listId']),
    name: _str(j['name'], '？'),
    note: _str(j['note']),
    quantity: _intOrNull(j['quantity']),
    unit: _str(j['unit'], defaultShoppingUnit),
    addedById: j['addedBy'] as String?,
    addedAt: _time(j['addedAt']),
    inCart: _bool(j['inCart']),
    boughtById: j['boughtBy'] as String?,
    boughtAt: j['boughtAt'] is String ? DateTime.tryParse(j['boughtAt']) : null,
  );
}

/// 家族に送るひとことメッセージ。ホームと「がんばり」に1週間出す。
class FamilyMessage {
  const FamilyMessage({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.text,
    required this.at,
  });

  final String id;
  final String fromId;
  final String toId;
  final String text;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': fromId,
    'to': toId,
    'text': text,
    'at': at.toIso8601String(),
  };

  factory FamilyMessage.fromJson(Map<String, dynamic> j) => FamilyMessage(
    id: _str(j['id']),
    fromId: _str(j['from']),
    toId: _str(j['to']),
    text: _str(j['text']),
    at: _time(j['at']),
  );
}

/// 通知の設定。
class NotificationSettings {
  const NotificationSettings({
    this.morningSummary = true,
    this.morningMinutes = 7 * 60,
    this.beforeDue = true,
    this.beforeDueMinutes = 30,
    this.overdueReminder = true,
    this.overdueMinutes = 20 * 60,
    this.familyDone = false,
    this.shopping = true,
    this.thanks = true,
    this.messages = true,
    this.quietHours = true,
    this.quietStart = 22 * 60,
    this.quietEnd = 7 * 60,
    this.mutedGenreIds = const {},
    this.badgeMineOnly = false,
  });

  /// 朝のまとめ「今日は3件、うちあなたの担当は1件」。
  final bool morningSummary;
  final int morningMinutes;

  /// 時刻を決めた家事の、期限の少し前。
  final bool beforeDue;
  final int beforeDueMinutes;

  /// やり忘れリマインド。
  final bool overdueReminder;
  final int overdueMinutes;

  /// 家族が家事を完了したとき。
  final bool familyDone;

  /// 買い物リストの動き。
  final bool shopping;

  /// スタンプをもらったとき。
  final bool thanks;

  /// 家族からメッセージが届いたとき。
  final bool messages;

  /// おやすみ時間（この間は音を鳴らさない）。
  final bool quietHours;
  final int quietStart;
  final int quietEnd;

  /// 通知を止めているジャンル。
  final Set<String> mutedGenreIds;

  /// バッジの件数を自分の担当だけにするか。
  final bool badgeMineOnly;

  /// [minutes]（0:00 からの分）がおやすみ時間に入るか。
  bool isQuiet(int minutes) {
    if (!quietHours || quietStart == quietEnd) return false;
    return quietStart < quietEnd
        ? minutes >= quietStart && minutes < quietEnd
        : minutes >= quietStart || minutes < quietEnd;
  }

  NotificationSettings copyWith({
    bool? morningSummary,
    int? morningMinutes,
    bool? beforeDue,
    int? beforeDueMinutes,
    bool? overdueReminder,
    int? overdueMinutes,
    bool? familyDone,
    bool? shopping,
    bool? thanks,
    bool? messages,
    bool? quietHours,
    int? quietStart,
    int? quietEnd,
    Set<String>? mutedGenreIds,
    bool? badgeMineOnly,
  }) => NotificationSettings(
    morningSummary: morningSummary ?? this.morningSummary,
    morningMinutes: morningMinutes ?? this.morningMinutes,
    beforeDue: beforeDue ?? this.beforeDue,
    beforeDueMinutes: beforeDueMinutes ?? this.beforeDueMinutes,
    overdueReminder: overdueReminder ?? this.overdueReminder,
    overdueMinutes: overdueMinutes ?? this.overdueMinutes,
    familyDone: familyDone ?? this.familyDone,
    shopping: shopping ?? this.shopping,
    thanks: thanks ?? this.thanks,
    messages: messages ?? this.messages,
    quietHours: quietHours ?? this.quietHours,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
    mutedGenreIds: mutedGenreIds ?? this.mutedGenreIds,
    badgeMineOnly: badgeMineOnly ?? this.badgeMineOnly,
  );

  Map<String, dynamic> toJson() => {
    'morningSummary': morningSummary,
    'morningMinutes': morningMinutes,
    'beforeDue': beforeDue,
    'beforeDueMinutes': beforeDueMinutes,
    'overdueReminder': overdueReminder,
    'overdueMinutes': overdueMinutes,
    'familyDone': familyDone,
    'shopping': shopping,
    'thanks': thanks,
    'messages': messages,
    'quietHours': quietHours,
    'quietStart': quietStart,
    'quietEnd': quietEnd,
    'mutedGenres': mutedGenreIds.toList()..sort(),
    'badgeMineOnly': badgeMineOnly,
  };

  factory NotificationSettings.fromJson(Map<String, dynamic> j) {
    const d = NotificationSettings();
    return NotificationSettings(
      morningSummary: _bool(j['morningSummary'], d.morningSummary),
      morningMinutes: _int(j['morningMinutes'], d.morningMinutes),
      beforeDue: _bool(j['beforeDue'], d.beforeDue),
      beforeDueMinutes: _int(j['beforeDueMinutes'], d.beforeDueMinutes),
      overdueReminder: _bool(j['overdueReminder'], d.overdueReminder),
      overdueMinutes: _int(j['overdueMinutes'], d.overdueMinutes),
      familyDone: _bool(j['familyDone'], d.familyDone),
      shopping: _bool(j['shopping'], d.shopping),
      thanks: _bool(j['thanks'], d.thanks),
      messages: _bool(j['messages'], d.messages),
      quietHours: _bool(j['quietHours'], d.quietHours),
      quietStart: _int(j['quietStart'], d.quietStart),
      quietEnd: _int(j['quietEnd'], d.quietEnd),
      mutedGenreIds: {
        ...(j['mutedGenres'] as List? ?? const []).whereType<String>(),
      },
      badgeMineOnly: _bool(j['badgeMineOnly'], d.badgeMineOnly),
    );
  }
}

/// 画面の明るさの設定。
enum Appearance { system, light, dark }

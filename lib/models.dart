/// アプリで扱うデータの型。
///
/// 「家事の定義（Chore）」と「毎回の実施記録（Record）」を分けているのがポイント。
/// こうすると「担当予定者」と「実際にやった人」を毎回別々に残せる。
library;

import 'recurrence.dart';

/// 家族のメンバー。
class Member {
  Member({required this.id, required this.name, required this.colorValue});

  final String id;
  String name;
  int colorValue;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': colorValue,
      };

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: j['id'] as String,
        name: j['name'] as String,
        colorValue: j['color'] as int,
      );
}

/// 家事のジャンル（料理・掃除など）。初期ジャンルとユーザーが作ったジャンルがある。
class Genre {
  Genre({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    this.builtIn = false,
    this.hidden = false,
    this.order = 0,
  });

  final String id;
  String name;
  String iconKey;
  int colorValue;
  final bool builtIn;
  bool hidden;
  int order;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': iconKey,
        'color': colorValue,
        'builtIn': builtIn,
        'hidden': hidden,
        'order': order,
      };

  factory Genre.fromJson(Map<String, dynamic> j) => Genre(
        id: j['id'] as String,
        name: j['name'] as String,
        iconKey: j['icon'] as String,
        colorValue: j['color'] as int,
        builtIn: j['builtIn'] as bool? ?? false,
        hidden: j['hidden'] as bool? ?? false,
        order: j['order'] as int? ?? 0,
      );
}

/// 家事の定義。繰り返しルールを持つ。
class Chore {
  Chore({
    required this.id,
    required this.name,
    required this.genreId,
    required this.startDate,
    required this.repeat,
    this.assigneeId,
    this.memo = '',
    this.archived = false,
  });

  final String id;
  String name;
  String genreId;

  /// 初回の日付（繰り返しの起点）。時刻は持たない。
  DateTime startDate;
  Repeat repeat;

  /// 担当予定者。null は「誰でも」。
  String? assigneeId;
  String memo;

  /// 予定外の「ついでにやった」記録のためだけに作った家事など、一覧に出さないもの。
  bool archived;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'genreId': genreId,
        'start': dateKey(startDate),
        'repeat': repeat.toJson(),
        'assignee': assigneeId,
        'memo': memo,
        'archived': archived,
      };

  factory Chore.fromJson(Map<String, dynamic> j) => Chore(
        id: j['id'] as String,
        name: j['name'] as String,
        genreId: j['genreId'] as String,
        startDate: parseDateKey(j['start'] as String),
        repeat: Repeat.fromJson(j['repeat'] as Map<String, dynamic>),
        assigneeId: j['assignee'] as String?,
        memo: j['memo'] as String? ?? '',
        archived: j['archived'] as bool? ?? false,
      );
}

enum RecordStatus { done, skipped }

/// 1回分の実施記録。予定日に対する完了・スキップ、または予定外の実施。
class Record {
  Record({
    required this.id,
    required this.choreId,
    required this.date,
    required this.status,
    required this.at,
    this.doneById,
    this.unplanned = false,
  });

  final String id;
  final String choreId;

  /// どの予定日の分か。予定外の実施ではやった日。
  final DateTime date;
  final RecordStatus status;

  /// 実際にやった人（スキップ時は null）。
  final String? doneById;
  final DateTime at;

  /// 予定にない「ついでにやった」記録か。
  final bool unplanned;

  Map<String, dynamic> toJson() => {
        'id': id,
        'choreId': choreId,
        'date': dateKey(date),
        'status': status.name,
        'doneBy': doneById,
        'at': at.toIso8601String(),
        'unplanned': unplanned,
      };

  factory Record.fromJson(Map<String, dynamic> j) => Record(
        id: j['id'] as String,
        choreId: j['choreId'] as String,
        date: parseDateKey(j['date'] as String),
        status: RecordStatus.values.byName(j['status'] as String),
        doneById: j['doneBy'] as String?,
        at: DateTime.parse(j['at'] as String),
        unplanned: j['unplanned'] as bool? ?? false,
      );
}

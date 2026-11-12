/// 保存するデータ全体と、その読み書き（古い形式からの引き継ぎを含む）。
library;

import 'dart:convert';

import '../domain/catalog.dart';
import '../domain/models.dart';

/// いまの保存形式の番号。
const currentDataVersion = 2;

/// アプリが持つデータ全体。
class AppData {
  AppData({
    List<Member>? members,
    List<Genre>? genres,
    List<Chore>? chores,
    List<Record>? records,
    List<Thanks>? thanks,
    List<ShoppingList>? lists,
    List<ShoppingItem>? items,
    List<FamilyMessage>? messages,
    this.notifications = const NotificationSettings(),
    this.appearance = Appearance.system,
    this.currentMemberId,
    this.onboarded = false,
    this.showShoppingSuggestions = true,
  }) : members = members ?? [],
       genres = genres ?? defaultGenres(),
       chores = chores ?? [],
       records = records ?? [],
       thanks = thanks ?? [],
       lists = lists ?? [],
       items = items ?? [],
       messages = messages ?? [];

  List<Member> members;
  List<Genre> genres;
  List<Chore> chores;
  List<Record> records;
  List<Thanks> thanks;
  List<ShoppingList> lists;
  List<ShoppingItem> items;
  List<FamilyMessage> messages;
  NotificationSettings notifications;
  Appearance appearance;

  /// この端末を使っている人。
  String? currentMemberId;

  /// はじめての設定が済んでいるか。
  bool onboarded;

  /// 買い物画面に「よく買うものから追加」を出すか。
  bool showShoppingSuggestions;

  Map<String, dynamic> toJson() => {
    'version': currentDataVersion,
    'members': [for (final m in members) m.toJson()],
    'genres': [for (final g in genres) g.toJson()],
    'chores': [for (final c in chores) c.toJson()],
    'records': [for (final r in records) r.toJson()],
    'thanks': [for (final t in thanks) t.toJson()],
    'lists': [for (final l in lists) l.toJson()],
    'items': [for (final i in items) i.toJson()],
    'messages': [for (final m in messages) m.toJson()],
    'notifications': notifications.toJson(),
    'appearance': appearance.name,
    'currentMember': currentMemberId,
    'onboarded': onboarded,
    'showShoppingSuggestions': showShoppingSuggestions,
  };

  String encode() => jsonEncode(toJson());
}

/// 保存した文字列からデータを復元する。壊れていたら [FormatException] を投げる。
AppData decodeAppData(String raw) {
  final Object? decoded = jsonDecode(raw);
  if (decoded is! Map) throw const FormatException('データの形が違います');
  final j = decoded.cast<String, dynamic>();
  final version = j['version'] is num ? (j['version'] as num).toInt() : 1;
  if (version > currentDataVersion) {
    throw const FormatException('新しいバージョンのアプリで作られたデータです');
  }

  List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) => [
    for (final e in j[key] as List? ?? const [])
      if (e is Map) parse(e.cast<String, dynamic>()),
  ];

  final data = AppData(
    members: list('members', Member.fromJson),
    genres: list('genres', Genre.fromJson),
    chores: list('chores', Chore.fromJson),
    records: list('records', Record.fromJson),
    thanks: list('thanks', Thanks.fromJson),
    lists: list('lists', ShoppingList.fromJson),
    items: list('items', ShoppingItem.fromJson),
    messages: list('messages', FamilyMessage.fromJson),
    notifications: j['notifications'] is Map
        ? NotificationSettings.fromJson(
            (j['notifications'] as Map).cast<String, dynamic>(),
          )
        : const NotificationSettings(),
    appearance:
        Appearance.values.asNameMap()[j['appearance']] ?? Appearance.system,
    currentMemberId: j['currentMember'] as String?,
    onboarded: j['onboarded'] is bool ? j['onboarded'] as bool : false,
    showShoppingSuggestions: j['showShoppingSuggestions'] is bool
        ? j['showShoppingSuggestions'] as bool
        : true,
  );
  if (version < 2) _migrateFromV1(data);
  _repair(data);
  return data;
}

/// 試作版 0.1 のデータを引き継ぐ。
///
/// メンバー・ジャンル・家事・記録はそのまま読める。初期の色だけ新しい配色に置き換え、
/// 0.1 にはなかった買い物リストを用意する。
void _migrateFromV1(AppData data) {
  data.onboarded = data.members.isNotEmpty;
  data.members = [
    for (final m in data.members)
      legacyMemberColors.contains(m.color)
          ? m.copyWith(
              color:
                  memberColors[legacyMemberColors.indexOf(m.color) %
                      memberColors.length],
            )
          : m,
  ];
  final fresh = {for (final g in defaultGenres()) g.id: g};
  data.genres = [
    for (final g in data.genres)
      g.builtIn && legacyGenreColors[g.id] == g.color && fresh[g.id] != null
          ? g.copyWith(color: fresh[g.id]!.color)
          : g,
  ];
}

/// 読み込んだデータの、つじつまが合わないところを直す。
void _repair(AppData data) {
  if (data.genres.isEmpty) data.genres = defaultGenres();
  if (!data.genres.any((g) => g.id == otherGenreId)) {
    data.genres.add(
      defaultGenres()
          .firstWhere((g) => g.id == otherGenreId)
          .copyWith(order: data.genres.length),
    );
  }
  if (data.members.isEmpty) {
    data.onboarded = false;
    data.currentMemberId = null;
  } else if (!data.members.any((m) => m.id == data.currentMemberId)) {
    data.currentMemberId = data.members.first.id;
  }
  if (data.onboarded && data.lists.isEmpty) {
    data.lists = defaultShoppingLists();
  }
}

List<ShoppingList> defaultShoppingLists() => [
  for (var i = 0; i < defaultShoppingListNames.length; i++)
    ShoppingList(id: 'list-$i', name: defaultShoppingListNames[i], order: i),
];

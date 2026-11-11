/// はじめから用意しておくもの: 初期ジャンル、色、よくある家事、よく買うもの。
library;

import 'models.dart';
import 'recurrence.dart';

/// メンバーに順番に割り当てる色。
///
/// グラフで人を見分ける色にもなるので、色の見え方がちがう人でも隣どうしを
/// 区別できる並びにしてある（順番を入れ替えないこと）。赤は「やり忘れ」の色
/// として空けてある。
const memberColors = <int>[
  0xFF2A78D6, // あお
  0xFFEB6834, // オレンジ
  0xFF1BAF7A, // みどり
  0xFFEDA100, // きいろ
  0xFFE87BA4, // ピンク
  0xFF008300, // ふかみどり
  0xFF6250D6, // むらさき
];

/// ジャンルに選べる色。
const genreColors = <int>[
  0xFFF0892B,
  0xFF4FAE6B,
  0xFF4A90D9,
  0xFF1FA5A0,
  0xFFA8754E,
  0xFFEA6C97,
  0xFF7C70D8,
  0xFF8A8F98,
  0xFFDDAA1A,
  0xFFE05A4F,
  0xFF5166C9,
  0xFF86B536,
];

/// 消せない「その他」ジャンルの ID。ジャンルを消したときの家事の移動先。
const otherGenreId = 'other';

/// 買い物ジャンルの ID。買い出しの記録に使う。
const shoppingGenreId = 'shopping';

/// 買い物リストを「買い物おわり」にしたときの記録先になる家事の ID。
const shoppingTripChoreId = 'sys-shopping-trip';

List<Genre> defaultGenres() {
  const list = [
    ('cooking', '料理', 0xFFF0892B),
    (shoppingGenreId, '買い物', 0xFF4FAE6B),
    ('laundry', '洗濯', 0xFF4A90D9),
    ('cleaning', '掃除', 0xFF1FA5A0),
    ('pet', 'ペット', 0xFFA8754E),
    ('childcare', '子守', 0xFFEA6C97),
    ('education', '教育', 0xFF7C70D8),
    (otherGenreId, 'その他', 0xFF8A8F98),
  ];
  return [
    for (var i = 0; i < list.length; i++)
      Genre(
        id: list[i].$1,
        name: list[i].$2,
        icon: list[i].$1,
        color: list[i].$3,
        builtIn: true,
        order: i,
      ),
  ];
}

/// 試作版 0.1 の初期ジャンルの色。データを引き継ぐとき、新しい色に置き換える。
const legacyGenreColors = <String, int>{
  'cooking': 0xFFF28E2B,
  'shopping': 0xFF59A14F,
  'laundry': 0xFF4E79A7,
  'cleaning': 0xFF76B7B2,
  'pet': 0xFF9C755F,
  'childcare': 0xFFFF9DA7,
  'education': 0xFF6A5ACD,
  'other': 0xFF8C8C8C,
};

/// 試作版 0.1 のメンバーの色。
const legacyMemberColors = <int>[
  0xFF4E79A7,
  0xFFE15759,
  0xFF59A14F,
  0xFFF28E2B,
  0xFFB07AA1,
  0xFF76B7B2,
];

/// よくある家事。選ぶだけで、繰り返しまで入った状態で登録できる。
class ChoreTemplate {
  const ChoreTemplate(
    this.name,
    this.genreId,
    this.repeat, {
    this.dueMinutes,
    this.month,
    this.day,
    this.starter = false,
  });

  final String name;
  final String genreId;
  final Repeat repeat;
  final int? dueMinutes;

  /// 毎年の家事の月日（[Repeat.yearly] のときだけ使う）。
  final int? month;
  final int? day;

  /// はじめての設定で、最初から選んでおくか。
  final bool starter;

  /// [today] に登録するときの開始日。
  DateTime startFor(DateTime today) {
    if (repeat.type != RepeatType.yearly || month == null) {
      return DateTime(today.year, today.month, today.day);
    }
    final thisYear = DateTime(today.year, month!, day ?? 1);
    return thisYear.isBefore(DateTime(today.year, today.month, today.day))
        ? DateTime(today.year + 1, month!, day ?? 1)
        : thisYear;
  }
}

const _weekdays = Repeat.weekly(Repeat.weekdaysOnly);

const choreTemplates = <ChoreTemplate>[
  // 料理
  ChoreTemplate('朝ごはん作り', 'cooking', Repeat.daily()),
  ChoreTemplate('晩ごはん作り', 'cooking', Repeat.daily(), starter: true),
  ChoreTemplate('食器洗い', 'cooking', Repeat.daily(), starter: true),
  ChoreTemplate('お弁当作り', 'cooking', _weekdays),
  ChoreTemplate('献立を考える', 'cooking', Repeat.weekly({7})),
  ChoreTemplate('冷蔵庫の整理', 'cooking', Repeat.monthlyDay(0)),
  // 買い物
  ChoreTemplate('食材の買い出し', 'shopping', Repeat.weekly({6}), starter: true),
  ChoreTemplate('日用品の買い出し', 'shopping', Repeat.monthlyDay(1)),
  // 洗濯
  ChoreTemplate('洗濯', 'laundry', Repeat.daily(), starter: true),
  ChoreTemplate('洗濯物をたたむ', 'laundry', Repeat.daily()),
  ChoreTemplate('シーツ交換', 'laundry', Repeat.weekly({6}, interval: 2)),
  ChoreTemplate('アイロンがけ', 'laundry', Repeat.weekly({7})),
  ChoreTemplate('洗濯槽の掃除', 'laundry', Repeat.monthlyDay(1), starter: true),
  // 掃除
  ChoreTemplate('掃除機がけ', 'cleaning', Repeat.weekly({3, 6})),
  ChoreTemplate('お風呂掃除', 'cleaning', Repeat.daily(), starter: true),
  ChoreTemplate('トイレ掃除', 'cleaning', Repeat.weekly({6}), starter: true),
  ChoreTemplate(
    '燃えるゴミ出し',
    'cleaning',
    Repeat.weekly({2, 5}),
    dueMinutes: 8 * 60,
    starter: true,
  ),
  ChoreTemplate(
    '資源ゴミ出し',
    'cleaning',
    Repeat.monthlyNth({2, 4}, 1),
    dueMinutes: 8 * 60,
  ),
  ChoreTemplate('排水口の掃除', 'cleaning', Repeat.afterDone(14)),
  ChoreTemplate('エアコンフィルター掃除', 'cleaning', Repeat.monthlyDay(1, interval: 3)),
  ChoreTemplate('換気扇の掃除', 'cleaning', Repeat.monthlyDay(1, interval: 6)),
  ChoreTemplate('大掃除', 'cleaning', Repeat.yearly(), month: 12, day: 28),
  // ペット
  ChoreTemplate('ペットのごはん', 'pet', Repeat.daily()),
  ChoreTemplate('ペットの散歩', 'pet', Repeat.daily()),
  ChoreTemplate('ペットのトイレ掃除', 'pet', Repeat.daily()),
  // 子守
  ChoreTemplate('保育園の準備', 'childcare', _weekdays),
  ChoreTemplate('送り迎え', 'childcare', _weekdays),
  ChoreTemplate('お風呂に入れる', 'childcare', Repeat.daily()),
  ChoreTemplate('寝かしつけ', 'childcare', Repeat.daily()),
  // 教育
  ChoreTemplate('宿題を見る', 'education', _weekdays),
  ChoreTemplate('連絡帳のチェック', 'education', _weekdays),
  ChoreTemplate('習い事の送迎', 'education', Repeat.weekly({6})),
  // その他
  ChoreTemplate('植物の水やり', 'other', Repeat.daily(3)),
  ChoreTemplate('布団を干す', 'other', Repeat.weekly({7})),
  ChoreTemplate('家計簿をつける', 'other', Repeat.weekly({7})),
];

/// 買い物リストに、履歴がまだ少ないうちに出しておく候補。
const shoppingStarters = <String>[
  '牛乳',
  '卵',
  '食パン',
  '豆腐',
  '納豆',
  'ヨーグルト',
  'バナナ',
  '玉ねぎ',
  'トイレットペーパー',
  'ティッシュ',
  '洗濯洗剤',
  '食器用洗剤',
];

/// 最初から用意しておく買い物リストの名前。
const defaultShoppingListNames = ['スーパー', 'ドラッグストア'];

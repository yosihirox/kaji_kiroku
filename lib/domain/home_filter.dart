/// ホームの「絞り込み」の条件。
///
/// 保存はしない。アプリを閉じると何も絞り込んでいない状態に戻る。
library;

import 'agenda.dart';
import 'dates.dart';

/// 完了・未完了などの状態での絞り込み。
enum StatusFilter { all, pending, overdue, done, skipped }

const statusFilterLabels = {
  StatusFilter.all: 'すべて',
  StatusFilter.pending: '未完了',
  StatusFilter.overdue: 'やり忘れ',
  StatusFilter.done: '完了',
  StatusFilter.skipped: 'スキップ',
};

/// 時刻を決めているかでの絞り込み。
enum TimeFilter { all, timed, untimed }

const timeFilterLabels = {
  TimeFilter.all: 'すべて',
  TimeFilter.timed: '時刻あり',
  TimeFilter.untimed: '時刻なし',
};

/// 担当の絞り込みで「だれでも」をあらわす値。
const anyoneId = '';

/// 期間で絞り込むときに、一度に出す日数の上限。
const maxFilterDays = 92;

class HomeFilter {
  const HomeFilter({
    this.keyword = '',
    this.status = StatusFilter.all,
    this.from,
    this.to,
    this.genreIds = const {},
    this.choreIds = const {},
    this.assigneeIds = const {},
    this.doneByIds = const {},
    this.time = TimeFilter.all,
  });

  /// 家事の名前・メモ・ジャンル名・記録のひとことに含まれる言葉。
  final String keyword;
  final StatusFilter status;

  /// 期間。どちらも null なら、いつもの「やり忘れ＋1週間」。
  final DateTime? from;
  final DateTime? to;

  /// 空なら絞り込まない。
  final Set<String> genreIds;
  final Set<String> choreIds;

  /// 担当予定者。「だれでも」は [anyoneId]。
  final Set<String> assigneeIds;

  /// 実際にやった人。
  final Set<String> doneByIds;
  final TimeFilter time;

  static const none = HomeFilter();

  bool get hasPeriod => from != null && to != null;

  bool get isActive => conditionCount > 0;

  /// えらんでいる条件の数（ボタンのバッジに出す）。
  int get conditionCount => [
    keyword.trim().isNotEmpty,
    status != StatusFilter.all,
    hasPeriod,
    genreIds.isNotEmpty,
    choreIds.isNotEmpty,
    assigneeIds.isNotEmpty,
    doneByIds.isNotEmpty,
    time != TimeFilter.all,
  ].where((b) => b).length;

  /// 期間の日付（古い順）。期間がなければ空。
  List<DateTime> get periodDays {
    if (!hasPeriod) return const [];
    final a = dateOnly(from!);
    final b = dateOnly(to!);
    final start = a.isAfter(b) ? b : a;
    final end = a.isAfter(b) ? a : b;
    final count = (daysBetween(start, end) + 1).clamp(1, maxFilterDays);
    return [for (var i = 0; i < count; i++) addDays(start, i)];
  }

  HomeFilter copyWith({
    String? keyword,
    StatusFilter? status,
    DateTime? from,
    DateTime? to,
    bool clearPeriod = false,
    Set<String>? genreIds,
    Set<String>? choreIds,
    Set<String>? assigneeIds,
    Set<String>? doneByIds,
    TimeFilter? time,
  }) => HomeFilter(
    keyword: keyword ?? this.keyword,
    status: status ?? this.status,
    from: clearPeriod ? null : (from ?? this.from),
    to: clearPeriod ? null : (to ?? this.to),
    genreIds: genreIds ?? this.genreIds,
    choreIds: choreIds ?? this.choreIds,
    assigneeIds: assigneeIds ?? this.assigneeIds,
    doneByIds: doneByIds ?? this.doneByIds,
    time: time ?? this.time,
  );

  /// [o] が条件に合うか（期間は別に見る）。
  ///
  /// [genreName] はキーワードをジャンル名でも探すためのもの。
  bool matches(
    Occurrence o, {
    required DateTime today,
    String Function(String genreId)? genreName,
  }) {
    final chore = o.chore;
    switch (status) {
      case StatusFilter.all:
        break;
      case StatusFilter.pending:
        if (!o.isPending) return false;
      case StatusFilter.overdue:
        final late = o.overdue || (o.isPending && o.date.isBefore(today));
        if (!late) return false;
      case StatusFilter.done:
        if (!o.isDone) return false;
      case StatusFilter.skipped:
        if (!o.isSkipped) return false;
    }
    if (genreIds.isNotEmpty && !genreIds.contains(chore.genreId)) return false;
    if (choreIds.isNotEmpty && !choreIds.contains(chore.id)) return false;
    if (assigneeIds.isNotEmpty &&
        !assigneeIds.contains(chore.assigneeId ?? anyoneId)) {
      return false;
    }
    if (doneByIds.isNotEmpty &&
        !(o.isDone && doneByIds.contains(o.record!.doneById))) {
      return false;
    }
    switch (time) {
      case TimeFilter.all:
        break;
      case TimeFilter.timed:
        if (chore.dueMinutes == null) return false;
      case TimeFilter.untimed:
        if (chore.dueMinutes != null) return false;
    }
    final words = keyword
        .toLowerCase()
        .split(RegExp(r'[\s　]+'))
        .where((w) => w.isNotEmpty);
    if (words.isNotEmpty) {
      final text = [
        chore.name,
        chore.memo,
        o.record?.note ?? '',
        genreName?.call(chore.genreId) ?? '',
      ].join('\n').toLowerCase();
      if (!words.every(text.contains)) return false;
    }
    return true;
  }
}

import 'package:flutter/material.dart' show DateUtils;

import '../l10n/l10n.dart';
import '../models/workout.dart';
import '../state/fit_state.dart';
import '../widgets/ui_kit.dart' show sentenceCase;

/// Small read-only lookups used by the Minimal Today and Stats screens.
/// Nothing here writes state.
class MinimalInsights {
  const MinimalInsights._();

  /// Name of the Stats tab and screen title in Minimal mode.
  static String statsLabel() => t.localeName.startsWith('en') ? 'Stats' : sentenceCase(t.progress);

  static int daysSince(DateTime date) =>
      DateUtils.dateOnly(DateTime.now()).difference(DateUtils.dateOnly(date)).inDays;

  /// Date of the most recent personal record for [record], or null when the
  /// exercise has no history.
  static DateTime? lastPrDate(PersonalRecord record) {
    var best = 0.0;
    DateTime? date;
    for (final entry in fit.exerciseHistory(record.id).reversed) {
      var current = 0.0;
      for (final set in entry.ex.workingSets) {
        final score = record.kind == PrKind.weight && fit.isAssisted(record.id)
            ? fit.liftScore(record.id, set)
            : record.kind.score(set);
        if (score > current) current = score;
      }
      if (current > best + 0.0001) {
        best = current;
        date = entry.date;
      }
    }
    return date;
  }

  /// Muscles whose last working set was [minDays] or more days ago, longest
  /// gap first.
  static List<({String muscle, int days})> coldMuscles({int minDays = 6, int limit = 3}) {
    final last = <String, DateTime>{};
    for (final session in fit.sessions) {
      final day = DateUtils.dateOnly(session.day);
      for (final exercise in session.exercises) {
        if (exercise.workingSets.isEmpty || !fit.countsForMuscles(exercise.id)) continue;
        final current = last[exercise.primary];
        if (current == null || day.isAfter(current)) last[exercise.primary] = day;
      }
    }
    final out = <({String muscle, int days})>[
      for (final entry in last.entries)
        if (daysSince(entry.value) >= minDays) (muscle: entry.key, days: daysSince(entry.value)),
    ]..sort((a, b) => b.days.compareTo(a.days));
    return out.take(limit).toList();
  }

  /// Exercises done at least three times whose last PR is [minDays] or more
  /// days old, longest gap first.
  static List<({PersonalRecord record, int days})> stuckRecords({int minDays = 21, int limit = 3}) {
    final out = <({PersonalRecord record, int days})>[];
    for (final record in fit.personalRecords) {
      if (fit.exerciseHistory(record.id).length < 3) continue;
      final date = lastPrDate(record);
      if (date == null) continue;
      final days = daysSince(date);
      if (days >= minDays) out.add((record: record, days: days));
    }
    out.sort((a, b) => b.days.compareTo(a.days));
    return out.take(limit).toList();
  }

  /// The routine to offer as one-tap "Up next": today's planned routine if
  /// there is one, otherwise the routine done longest ago (never done first).
  static Routine? nextRoutine() {
    final planned = fit.todayRoutine;
    if (planned != null && planned.exerciseIds.isNotEmpty) return planned;
    final all = [
      for (final routine in fit.activeRoutines)
        if (routine.exerciseIds.isNotEmpty) routine,
    ];
    if (all.isEmpty) return null;
    Routine best = all.first;
    DateTime? bestDate = fit.lastDoneOf(best.id);
    for (final routine in all.skip(1)) {
      final date = fit.lastDoneOf(routine.id);
      if (bestDate == null) break;
      if (date == null || date.isBefore(bestDate)) {
        best = routine;
        bestDate = date;
      }
    }
    return best;
  }

  /// Sessions and volume from Monday up to the same weekday, [weeksAgo] weeks
  /// back, so this week is compared with the same stretch of last week.
  static ({int sessions, double volume}) weekTotals(int weeksAgo) {
    final today = DateUtils.dateOnly(DateTime.now());
    final offset = today.weekday - DateTime.monday;
    final start = today.subtract(Duration(days: offset + 7 * weeksAgo));
    final end = start.add(Duration(days: offset));
    var sessions = 0;
    var volume = 0.0;
    for (final session in fit.sessions) {
      final day = DateUtils.dateOnly(session.day);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      sessions++;
      volume += session.volume;
    }
    return (sessions: sessions, volume: volume);
  }

  /// "+8%" / "−3%" / "0%", or null when there is nothing to compare against.
  static String? change(num current, num previous) {
    if (previous <= 0) return null;
    final pct = ((current - previous) / previous * 100).round();
    if (pct == 0) return '0%';
    return '${pct > 0 ? '+' : '−'}${pct.abs()}%';
  }
}

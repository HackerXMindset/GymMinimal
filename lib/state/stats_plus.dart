part of 'fit_state.dart';

/// Every card on the Stats screens that is switchable from Settings.
/// [group] is the section it sits in, on both the main and the Minimal Stats.
/// What "Essentials" keeps on. Everything else is switched off by that preset.
const kEssentialStats = {
  'score', 'trends', 'stalled', 'zones', 'tonnage', 'load', 'weekReport', 'deload',
  'x_level', 'x_trend', 'x_prs', 't_ready', 't_miles', 't_load', 't_weekly',
  'm_insights', 'm_recovery', 'm_balance', 'm_totals', 'm_week', 'm_heat',
  'g_ready', 'g_zones', 'g_rhr', 'g_sleep8',
};

class StatCardInfo {
  const StatCardInfo(this.id, this.group, this.title, this.hint);
  final String id;
  final String group;
  final String title;
  final String hint;

  /// True for the cards that read Garmin data. They exist only while the
  /// Garmin switch is on.
  bool get garmin => group.startsWith('g_');
}

const kStatGroups = <(String, String)>[
  ('progress', 'Progress'),
  ('muscles', 'Muscles'),
  ('consistency', 'Consistency'),
  ('load', 'Load and recovery'),
  ('body', 'Body and food'),
  ('summary', 'Summaries'),
  ('exercise', 'On each exercise'),
  ('minimal', 'Also in Minimal'),
  ('g_before', 'Garmin · before you lift'),
  ('g_during', 'Garmin · during the workout'),
  ('g_ex', 'Garmin · by exercise'),
  ('g_after', 'Garmin · after the workout'),
  ('g_months', 'Garmin · over months'),
];

const kStatCards = <StatCardInfo>[
  StatCardInfo('score', 'progress', 'Strength score', 'One 0 to 100 score, and a score for each muscle.'),
  StatCardInfo('trends', 'progress', 'Trend on every lift', 'A small line and the change for each lift you train.'),
  StatCardInfo('stalled', 'progress', 'Stalled lifts', 'Lifts that have not moved for 3 weeks.'),
  StatCardInfo('prtime', 'progress', 'PR timeline', 'How many records you set each week.'),
  StatCardInfo('zones', 'muscles', 'Muscle volume zones', 'Weekly sets per muscle against a target band. Press and hold a muscle to set its priority.'),
  StatCardInfo('freq', 'muscles', 'Training frequency', 'How often each muscle is trained per week.'),
  StatCardInfo('tonnage', 'muscles', 'Volume by day type', 'Weekly volume split into push, pull, legs and core.'),
  StatCardInfo('mostDone', 'muscles', 'Most-done exercises', 'The five exercises you do most.'),
  StatCardInfo('weeks', 'consistency', 'Weeks', 'Week streak and sessions per week against your goal.'),
  StatCardInfo('when', 'consistency', 'When you train', 'Weekday and time of day.'),
  StatCardInfo('length', 'consistency', 'Session length', 'Length trend and your longest gap.'),
  StatCardInfo('load', 'load', 'Training load and readiness', 'Load ratio, readiness score and deload or plateau alerts.'),
  StatCardInfo('effort', 'load', 'Effort check', 'How close to failure your sets are. Needs RPE or RIR logged.'),
  StatCardInfo('rest', 'load', 'Rest between sets', 'Your real rest time. Counts only sessions logged from now on.'),
  StatCardInfo('restReps', 'load', 'Rest against reps', 'How the length of your rest changes the reps on the next set. Needs sets ticked off live.'),
  StatCardInfo('deload', 'load', 'Deload signal', 'Signs that a lighter week would help: load, stalled lifts, effort and, with Garmin on, heart and sleep.'),
  StatCardInfo('food', 'body', 'Food on training and rest days', 'Calories and protein on both kinds of day. Needs food logged.'),
  StatCardInfo('cardio', 'body', 'Lifting and cardio', 'Cardio minutes next to lifting minutes. Needs cardio logged.'),
  StatCardInfo('fourWeeks', 'summary', 'This 4 weeks vs the last 4', 'Sessions, volume, sets, session length and records.'),
  StatCardInfo('weekReport', 'summary', 'Weekly report card', 'A summary of this week you can share.'),
  StatCardInfo('x_level', 'exercise', 'Strength level', 'Your level on the main barbell lifts, from your estimated 1RM against bodyweight.'),
  StatCardInfo('x_volume', 'exercise', 'Sets and frequency', 'Sets per week on this lift and how often you train it.'),
  StatCardInfo('x_trend', 'exercise', 'Trend and stall tag', 'Change over 90 days, and a tag when a lift is stalled.'),
  StatCardInfo('x_prs', 'exercise', 'PR history', 'The dates you set records on an exercise.'),
  StatCardInfo('x_ranges', 'exercise', 'Best weight by rep range', 'The heaviest weight you have done for each rep count.'),
  StatCardInfo('x_effort', 'exercise', 'Effort on this lift', 'How close to failure this lift usually is.'),
  StatCardInfo('x_rest', 'exercise', 'Rest on this lift', 'Your real rest between sets on this lift.'),
  StatCardInfo('x_pace', 'exercise', 'Pace', 'Pace per session on rowing, running and other distance work.'),
  StatCardInfo('t_ready', 'exercise', 'Ready for more?', 'Whether you hit your target reps (or hold time) on every set. The target is set in Stats cards.'),
  StatCardInfo('t_easier', 'exercise', 'Same load, easier', 'RPE at the same weight, session by session. Needs RPE logged.'),
  StatCardInfo('t_rm', 'exercise', 'Estimated rep maxes', 'Your 3 and 10 rep max, and the change over 8 weeks.'),
  StatCardInfo('t_rhythm', 'exercise', 'PR rhythm', 'Days since the last record, records a month and the usual jump.'),
  StatCardInfo('t_miles', 'exercise', 'Milestones', 'Rep, hold, distance or assist milestones and the next one.'),
  StatCardInfo('t_load', 'exercise', 'Effective load', 'What you really move, counting bodyweight and assist.'),
  StatCardInfo('t_drop', 'exercise', 'Rep drop-off', 'How much your reps or holds fall from the first set to the last.'),
  StatCardInfo('t_weekly', 'exercise', 'Per week', 'Reps, minutes, distance or hours per week, whatever fits the exercise.'),
  StatCardInfo('t_next', 'exercise', 'Next step', 'When a bodyweight move is ready for weight, or how a weighted move compares with your bodyweight.'),
  StatCardInfo('t_typical', 'exercise', 'Typical set', 'The band or load and the reps you usually do.'),
  StatCardInfo('t_freq', 'exercise', 'Frequency', 'How often you do it, the longest gap and the week streak.'),
  StatCardInfo('t_forecast', 'exercise', 'Forecast', 'When you reach the next milestone at your current pace.'),
  StatCardInfo('t_hold', 'exercise', 'Hold quality', 'Average hold, longest hold and how it fades over the sets.'),
  StatCardInfo('t_sides', 'exercise', 'Left and right', 'Whether one side is behind the other.'),
  StatCardInfo('t_bests', 'exercise', 'Best efforts', 'Your fastest time at 1, 3, 5, 10 and 21.1 km.'),
  StatCardInfo('t_eff', 'exercise', 'Efficiency and pace', 'Distance per heartbeat, average heart rate or reps a minute. Needs heart rate or timed sets.'),
  StatCardInfo('t_totals', 'exercise', 'Lifetime totals', 'Sessions, sets and the total reps, time, distance or volume.'),
  StatCardInfo('t_sleep', 'exercise', 'Sleep and energy', 'Your sleep and energy ratings on days you do this exercise.'),
  StatCardInfo('t_time', 'exercise', 'Best time', 'Your best weekday and time of day for this exercise.'),
  StatCardInfo('m_insights', 'minimal', 'Insights', 'Plain-English notes about your week, as in the main Stats.'),
  StatCardInfo('m_recovery', 'minimal', 'Recovery by muscle', 'Which muscles are still recovering.'),
  StatCardInfo('m_level', 'minimal', 'Strength level', 'Your level for the lift picked in Estimated strength trend.'),
  StatCardInfo('m_balance', 'minimal', 'Lift balance', 'How your main lifts compare with each other.'),
  StatCardInfo('m_readiness', 'minimal', 'Sleep and energy', 'Your average sleep and energy ratings.'),
  StatCardInfo('m_bodyweight', 'minimal', 'Bodyweight', 'Trend and latest weight.'),
  StatCardInfo('m_measures', 'minimal', 'Measurements', 'Your latest body measurements.'),
  StatCardInfo('m_heat', 'minimal', 'Body heat map', 'A body map of which muscles you trained lately, and the ones you have not.'),
  StatCardInfo('m_radar', 'minimal', 'Muscle radar', 'Your muscle balance as a radar chart.'),
  StatCardInfo('m_health', 'minimal', 'Health', 'Sleep, resting heart rate and the other Health Connect numbers you picked.'),
  StatCardInfo('m_week', 'minimal', 'This week', 'A bar for each day of this week.'),
  StatCardInfo('m_effect', 'minimal', 'Sleep and energy effect', 'How your sleep and energy ratings change your sessions.'),
  StatCardInfo('m_totals', 'minimal', 'Streak and all-time totals', 'Your day streak, and sessions, sets and volume since day one.'),
  StatCardInfo('g_ready', 'g_before', 'Readiness', 'A score from sleep, HRV and resting heart rate against your own average.'),
  StatCardInfo('g_rhr', 'g_before', 'Resting heart rate', 'The last 12 days.'),
  StatCardInfo('g_hrv', 'g_before', 'HRV', 'The last 14 nights. Shows only if your watch shares HRV with Health Connect.'),
  StatCardInfo('g_sleeplift', 'g_before', 'Sleep against your lifts', 'How you lift after longer and after shorter sleep.'),
  StatCardInfo('g_hrset', 'g_during', 'Heart rate by set', 'The heart rate of each set in your last session.'),
  StatCardInfo('g_hrdrop', 'g_during', 'Heart rate drop after a set', 'How far your heart rate falls in the minute after a set.'),
  StatCardInfo('g_zones', 'g_during', 'Time in heart rate zones', 'Zones 1 to 5 over 30 days and in the last session.'),
  StatCardInfo('g_hrex', 'g_ex', 'Heart rate per exercise', 'Which exercises raise your heart rate most.'),
  StatCardInfo('g_hrsame', 'g_ex', 'Same weight, lower heart rate', 'Lifts where the same weight now costs your heart less (or more).'),
  StatCardInfo('g_watch', 'g_ex', 'Watch count against your log', 'Reps your watch counted against the reps you logged. Needs a FIT file.'),
  StatCardInfo('g_energy', 'g_ex', 'Heart load by exercise', 'How your heart\'s work splits between exercises.'),
  StatCardInfo('g_recover', 'g_after', 'Recovery with sleep', 'Muscle recovery time, stretched or shortened by last night\'s sleep.'),
  StatCardInfo('g_rhrnext', 'g_after', 'Resting heart rate next morning', 'Whether heavy sessions raise your resting heart rate the next day.'),
  StatCardInfo('g_hreffort', 'g_after', 'Heart effort against your RPE', 'Sessions that felt easy but your heart worked hard, or the reverse.'),
  StatCardInfo('g_burn', 'g_after', 'Burned and eaten', 'Calories burned from Health Connect against calories eaten in the food log.'),
  StatCardInfo('g_calm', 'g_months', 'Stronger, calmer heart', 'Strength and resting heart rate, week by week.'),
  StatCardInfo('g_sleep8', 'g_months', 'Sleep, 8 nights', 'Hours slept over the last 8 nights.'),
  StatCardInfo('g_z45', 'g_months', 'Hard minutes a week', 'Minutes a week in zones 4 and 5.'),
];

mixin StatsPlus on FitCore, ToolsState, LibraryState, SettingsState, TimelineState, StatsState, NutritionState {
  // ---- Settings -----------------------------------------------------------

  /// Ids of the cards the person switched off. Everything is on by default.
  final Set<String> statsOff = {};

  /// Muscle id to -1 (low), 0 (normal), 1 (high). Normal is not stored.
  final Map<String, int> musclePriority = {};

  bool statOn(String id) => !statsOff.contains(id);

  void setStatOn(String id, bool on) {
    if (on) {
      statsOff.remove(id);
    } else {
      statsOff.add(id);
    }
    _persist();
    notifyListeners();
  }

  /// All cards on, or only the essential ones.
  void applyStatPreset({required bool essentials}) {
    statsOff.clear();
    if (essentials) {
      statsOff.addAll([for (final c in kStatCards) if (!kEssentialStats.contains(c.id)) c.id]);
    }
    _persist();
    notifyListeners();
  }

  int priorityOf(String muscle) => musclePriority[muscle] ?? 0;

  void setMusclePriority(String muscle, int value) {
    if (value == 0) {
      musclePriority.remove(muscle);
    } else {
      musclePriority[muscle] = value.clamp(-1, 1);
    }
    _persist();
    notifyListeners();
  }

  /// The weekly set range a muscle should sit in. Priority moves it by 20%.
  (double, double) zoneBand(String muscle) {
    final k = switch (priorityOf(muscle)) {
      1 => 1.2,
      -1 => 0.8,
      _ => 1.0,
    };
    return (10 * k, 20 * k);
  }

  // ---- Small helpers ------------------------------------------------------

  DateTime get _today => _dayKey(DateTime.now());

  String _lift(String id, [String? fallback]) => t.catalogName(id, exerciseById(id)?.name ?? fallback ?? id);

  /// Sessions per exercise id, newest first, for every exercise ever logged.
  Map<String, List<({DateTime date, LoggedExercise ex})>> get _allHistory => _remember('history', _historyIndex);

  /// Best estimated 1RM per session for [id], oldest first. Deload weeks are left out.
  List<({DateTime date, double v})> _oneRmByDate(String id) => [
        for (final h in progressHistory(id).reversed)
          if (h.ex.bestOneRm > 0) (date: h.date, v: h.ex.bestOneRm),
      ];

  // ---- Progress -----------------------------------------------------------

  /// 0 to 100 from the bodyweight-ratio levels of the main barbell lifts.
  ({int score, String tier, List<({String id, String name, String muscle, double score})> lifts, List<({String muscle, double score})> muscles})?
      get strengthScore => _remember('strengthScore', () {
            final lifts = <({String id, String name, String muscle, double score})>[];
            for (final id in StatsState._ratioSteps.keys) {
              final rel = relativeStrength(id);
              if (rel == null) continue;
              final pos = rel.level >= 4 ? 4.0 : rel.level + rel.toNext;
              lifts.add((
                id: id,
                name: _lift(id),
                muscle: exerciseById(id)?.primary ?? '',
                score: (pos / 4 * 100).clamp(0.0, 100.0),
              ));
            }
            if (lifts.isEmpty) return null;
            final overall = lifts.fold(0.0, (a, l) => a + l.score) / lifts.length;
            final byMuscle = <String, List<double>>{};
            for (final l in lifts) {
              if (l.muscle.isNotEmpty) (byMuscle[l.muscle] ??= []).add(l.score);
            }
            final muscles = [
              for (final e in byMuscle.entries) (muscle: e.key, score: e.value.reduce((a, b) => a + b) / e.value.length),
            ]..sort((a, b) => b.score.compareTo(a.score));
            return (
              score: overall.round(),
              tier: t.dotsLevelName((overall / 20).floor().clamp(0, 4)),
              lifts: lifts,
              muscles: muscles,
            );
          }, (_today, latestBodyweight?.kg, profile.weightKg, profile.sex));

  /// A small line and the change over [days] for each lift that is trained.
  List<({String id, String name, List<double> values, double pct})> liftTrends({int days = 90, int limit = 8}) =>
      _remember(('trends', days, limit), () {
        final out = <({String id, String name, List<double> values, double pct})>[];
        for (final tracked in trackedExercises) {
          if (!goalFits(tracked.id)) continue;
          final points = exerciseTrend(tracked.id, days: days);
          if (points.length < 2) continue;
          final values = [for (final p in points) p.value];
          final first = values.first;
          if (first <= 0) continue;
          out.add((id: tracked.id, name: _lift(tracked.id, tracked.name), values: values, pct: (values.last - first) / first * 100));
          if (out.length >= limit) break;
        }
        return out;
      }, _today);

  /// Whole weeks a lift has gone without a new best, or null when it is moving
  /// or not trained any more. A lift counts as stalled after 3 flat weeks.
  int? stalledWeeks(String id) {
    if (!goalFits(id)) return null;
    final series = _oneRmByDate(id);
    if (series.length < 3) return null;
    var best = series.first.v;
    var gain = series.first.date;
    var since = 0;
    for (var i = 1; i < series.length; i++) {
      if (series[i].v > best * 1.005) {
        best = series[i].v;
        gain = series[i].date;
        since = 0;
      } else {
        since++;
      }
    }
    final days = _today.difference(_dayKey(gain)).inDays;
    final quiet = _today.difference(_dayKey(series.last.date)).inDays;
    if (days < 21 || since < 2 || quiet > 21) return null;
    return days ~/ 7;
  }

  List<({String id, String name, int weeks})> get stalledLifts => _remember('stalled', () {
        final out = <({String id, String name, int weeks})>[];
        for (final tracked in trackedExercises) {
          final weeks = stalledWeeks(tracked.id);
          if (weeks != null) out.add((id: tracked.id, name: _lift(tracked.id, tracked.name), weeks: weeks));
        }
        out.sort((a, b) => b.weeks.compareTo(a.weeks));
        return out;
      }, _today);

  /// Every time a lift's best estimated 1RM went up, newest first.
  List<({DateTime date, String id, String name, double kg})> get prEvents => _remember('prEvents', () {
        final out = <({DateTime date, String id, String name, double kg})>[];
        for (final id in _allHistory.keys) {
          if (!goalFits(id) || isCardio(id) || isTimed(id)) continue;
          final series = _oneRmByDate(id);
          if (series.length < 2) continue;
          var best = series.first.v;
          for (var i = 1; i < series.length; i++) {
            if (series[i].v > best + 0.0001) {
              best = series[i].v;
              out.add((date: series[i].date, id: id, name: _lift(id), kg: best));
            }
          }
        }
        out.sort((a, b) => b.date.compareTo(a.date));
        return out;
      });

  List<({DateTime date, double kg})> exercisePrs(String id) => [
        for (final e in prEvents)
          if (e.id == id) (date: e.date, kg: e.kg),
      ];

  /// Records set per week, oldest first, the current week last.
  List<int> prsByWeek(int weeks) {
    final start = shiftDays(weekStartDate, -7 * (weeks - 1));
    final out = List<int>.filled(weeks, 0);
    for (final e in prEvents) {
      final i = _dayKey(e.date).difference(start).inDays ~/ 7;
      if (_dayKey(e.date).isBefore(start) || i < 0 || i >= weeks) continue;
      out[i]++;
    }
    return out;
  }

  // ---- Muscles ------------------------------------------------------------

  /// Strength change of the lifts that train [muscle]: last 4 weeks against the
  /// 8 weeks before. Null when there is nothing to compare.
  double? _muscleStrengthChange(String muscle) {
    final recent = _today.subtract(const Duration(days: 28));
    final older = _today.subtract(const Duration(days: 84));
    final changes = <double>[];
    for (final tracked in trackedExercises) {
      if (exerciseById(tracked.id)?.primary != muscle || !goalFits(tracked.id)) continue;
      var now = 0.0;
      var before = 0.0;
      for (final p in _oneRmByDate(tracked.id)) {
        final d = _dayKey(p.date);
        if (!d.isBefore(recent)) {
          now = math.max(now, p.v);
        } else if (!d.isBefore(older)) {
          before = math.max(before, p.v);
        }
      }
      if (now > 0 && before > 0) changes.add((now - before) / before * 100);
    }
    if (changes.isEmpty) return null;
    return changes.reduce((a, b) => a + b) / changes.length;
  }

  /// Weekly sets per muscle (4-week average) with its zone and a progress check.
  /// zone is under, building, best or over. check is Productive, Stagnating,
  /// Too few sets, or null when there is no strength data to judge by.
  List<({String id, double perWeek, double lo, double hi, String zone, String? check})> get muscleZones =>
      _remember('zones', () {
        final sets = muscleSetsOver(28);
        final out = <({String id, double perWeek, double lo, double hi, String zone, String? check})>[];
        for (final m in kMuscles) {
          final perWeek = (sets[m.id] ?? 0) / 4;
          final (lo, hi) = zoneBand(m.id);
          final zone = perWeek < lo * 0.7
              ? 'under'
              : perWeek < lo
                  ? 'building'
                  : perWeek <= hi
                      ? 'best'
                      : 'over';
          String? check;
          if (perWeek > 0) {
            final change = _muscleStrengthChange(m.id);
            if (perWeek < lo * 0.7) {
              check = 'Too few sets';
            } else if (change != null) {
              check = change >= 1 ? 'Productive' : 'Stagnating';
            }
          }
          out.add((id: m.id, perWeek: perWeek, lo: lo, hi: hi, zone: zone, check: check));
        }
        out.sort((a, b) => b.perWeek.compareTo(a.perWeek));
        return out;
      }, (_today, Object.hashAll(musclePriority.entries.map((e) => (e.key, e.value)))));

  /// Sets in the last [days] split into push, pull, legs and core.
  Map<String, double> familySets({int days = 28}) {
    final out = <String, double>{'push': 0, 'pull': 0, 'legs': 0, 'core': 0};
    muscleSetsOver(days).forEach((id, n) {
      final f = muscleFamily(id);
      out[f] = (out[f] ?? 0) + n;
    });
    return out;
  }

  /// Sessions per week that train each muscle, over the last [days].
  Map<String, double> muscleFrequency({int days = 28}) => _remember(('freq', days), () {
        final start = _today.subtract(Duration(days: days - 1));
        final counts = <String, int>{};
        for (final s in sessions) {
          if (_dayKey(s.day).isBefore(start)) continue;
          final hit = <String>{};
          for (final e in s.exercises) {
            if (e.workingSets.isEmpty || !countsForMuscles(e.id)) continue;
            hit.add(e.primary);
          }
          for (final m in hit) {
            counts[m] = (counts[m] ?? 0) + 1;
          }
        }
        return {for (final e in counts.entries) e.key: e.value / (days / 7)};
      }, _today);

  /// Volume per week, oldest first, split by push, pull, legs and core.
  List<({DateTime start, Map<String, double> kg})> tonnageByFamily(int weeks, {int endBack = 0}) =>
      _remember(('tonnage', weeks, endBack), () {
        final first = shiftDays(weekStartDate, -7 * (weeks - 1 + endBack));
        final out = [for (var i = 0; i < weeks; i++) (start: shiftDays(first, 7 * i), kg: <String, double>{})];
        for (final s in sessions) {
          final day = _dayKey(s.day);
          final i = day.difference(first).inDays ~/ 7;
          if (day.isBefore(first) || i < 0 || i >= weeks) continue;
          for (final e in s.exercises) {
            if (!countsForMuscles(e.id)) continue;
            final f = muscleFamily(e.primary);
            out[i].kg[f] = (out[i].kg[f] ?? 0) + e.volume;
          }
        }
        return out;
      }, (_today, weekStartDay));

  /// The exercises done on the most sessions.
  List<({String id, String name, int count, int daysAgo})> mostDone(int n) => _remember(('mostDone', n), () {
        final all = [
          for (final e in _allHistory.entries)
            (id: e.key, name: _lift(e.key, e.value.first.ex.name), count: e.value.length, daysAgo: _today.difference(_dayKey(e.value.first.date)).inDays),
        ]..sort((a, b) => b.count != a.count ? b.count.compareTo(a.count) : a.daysAgo.compareTo(b.daysAgo));
        return all.take(n).toList();
      }, _today);

  // ---- Consistency --------------------------------------------------------

  /// Training days per week, oldest first, the current week last.
  List<int> sessionsPerWeek(int weeks) => _remember(('spw', weeks), () {
        final first = shiftDays(weekStartDate, -7 * (weeks - 1));
        final days = List.generate(weeks, (_) => <DateTime>{});
        for (final s in sessions) {
          final day = _dayKey(s.day);
          final i = day.difference(first).inDays ~/ 7;
          if (day.isBefore(first) || i < 0 || i >= weeks) continue;
          days[i].add(day);
        }
        return [for (final d in days) d.length];
      }, (_today, weekStartDay));

  /// Weeks in a row that reached the weekly goal. A week that is still running
  /// does not break the streak.
  int get weekStreak => _remember('weekStreak', () {
        final counts = sessionsPerWeek(104);
        var n = 0;
        for (var i = counts.length - 1; i >= 0; i--) {
          if (counts[i] >= weeklyTarget) {
            n++;
          } else if (i != counts.length - 1) {
            break;
          }
        }
        return n;
      }, (_today, weekStartDay, weeklyTarget));

  /// Session starts as weekday (row, in week order) by time of day:
  /// morning, midday, evening, night.
  List<List<int>> trainingTimes({int weeks = 12}) => _remember(('times', weeks), () {
        final grid = List.generate(7, (_) => List<int>.filled(4, 0));
        final from = _today.subtract(Duration(days: weeks * 7 - 1));
        for (final s in sessions) {
          if (_dayKey(s.day).isBefore(from)) continue;
          final row = (s.day.weekday - weekStartDay + 7) % 7;
          final h = s.day.hour;
          final col = h >= 5 && h < 11
              ? 0
              : h >= 11 && h < 16
                  ? 1
                  : h >= 16 && h < 21
                      ? 2
                      : 3;
          grid[row][col]++;
        }
        return grid;
      }, (_today, weekStartDay));

  /// Length in minutes of the last [n] sessions, oldest first.
  List<int> sessionMinutes(int n) {
    final list = [for (final s in sessions) if (s.durationSec >= 300) (s.date, (s.durationSec / 60).round())]
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final tail = list.length > n ? list.sublist(list.length - n) : list;
    return [for (final e in tail) e.$2];
  }

  /// The most days between two training days, and when it ended.
  ({int days, DateTime ended})? get longestGap => _remember('gap', () {
        final days = <DateTime>{for (final s in sessions) _dayKey(s.day)}.toList()..sort();
        if (days.length < 2) return null;
        var best = 0;
        var ended = days.last;
        for (var i = 1; i < days.length; i++) {
          final gap = days[i].difference(days[i - 1]).inDays - 1;
          if (gap > best) {
            best = gap;
            ended = days[i];
          }
        }
        return best <= 0 ? null : (days: best, ended: ended);
      });

  // ---- Load and recovery --------------------------------------------------

  double _sessionLoad(LoggedSession s) {
    final sets = [for (final e in s.exercises) ...e.workingSets];
    final effort = sets.isEmpty ? 1.0 : sets.fold(0.0, (a, st) => a + _setEffort(st)) / sets.length;
    return s.durationSec / 60 * effort;
  }

  /// Minutes times effort, this week against your usual week. [ratio] is null
  /// until there are two weeks of history. [rated] is true when RPE or RIR was
  /// logged, otherwise every set counts as normal effort.
  ({double acute, double usual, double? ratio, bool rated}) get trainingLoad => _remember('load', () {
        final from7 = _today.subtract(const Duration(days: 6));
        final from28 = _today.subtract(const Duration(days: 27));
        var acute = 0.0;
        var total = 0.0;
        var rated = false;
        DateTime? oldest;
        for (final s in sessions) {
          final day = _dayKey(s.day);
          if (oldest == null || day.isBefore(oldest)) oldest = day;
          if (day.isBefore(from28)) continue;
          final load = _sessionLoad(s);
          total += load;
          if (!day.isBefore(from7)) acute += load;
          if (!rated) rated = s.exercises.any((e) => e.workingSets.any((st) => st.rpe != null));
        }
        final usual = total / 4;
        final enough = oldest != null && _today.difference(oldest).inDays >= 14;
        return (acute: acute, usual: usual, ratio: enough && usual > 0 ? acute / usual : null, rated: rated);
      }, _today);

  /// Load balance, recovery and weekly volume, each 0 to 100, and the mix.
  ({int score, int balance, int recovery, int volume})? get readiness => _remember('readiness', () {
        if (sessions.length < 3) return null;
        final load = trainingLoad;
        final r = load.ratio;
        final balance = r == null
            ? 70
            : r >= 0.8 && r <= 1.3
                ? 100
                : r < 0.8
                    ? (100 - (0.8 - r) * 100).clamp(50, 100).round()
                    : (100 - (r - 1.3) * 150).clamp(0, 100).round();
        final recovery = overallRecovery();
        final week = muscleSetsOver(7).values.fold(0.0, (a, b) => a + b);
        final usual = muscleSetsOver(28).values.fold(0.0, (a, b) => a + b) / 4;
        final v = usual <= 0 ? 1.0 : week / usual;
        final volume = v >= 0.7 && v <= 1.3 ? 100 : (100 - ((v < 0.7 ? 0.7 - v : v - 1.3) * 100)).clamp(40, 100).round();
        return (
          score: (balance * 0.4 + recovery * 0.4 + volume * 0.2).round(),
          balance: balance,
          recovery: recovery,
          volume: volume,
        );
      }, _today);

  /// Deload and plateau alerts, most important first.
  List<({String kind, String text})> get loadAlerts => _remember('alerts', () {
        final out = <({String kind, String text})>[];
        final r = trainingLoad.ratio;
        if (r != null && r > 1.3) {
          out.add((kind: 'deload', text: 'This week is ${r.toStringAsFixed(1)}× your usual load. An easier week would help you recover.'));
        }
        final weeks = sessionsPerWeek(12);
        var run = 0;
        for (var i = weeks.length - 1; i >= 0; i--) {
          if (weeks[i] == 0 && i != weeks.length - 1) break;
          if (weeks[i] > 0) run++;
        }
        final lastDeload = sessions.where((s) => s.deload).fold<DateTime?>(null, (a, s) => a == null || s.date.isAfter(a) ? s.date : a);
        final weeksSinceDeload = lastDeload == null ? run : _today.difference(_dayKey(lastDeload)).inDays ~/ 7;
        if (run >= 6 && weeksSinceDeload >= 6) {
          out.add((kind: 'deload', text: '$run weeks of training in a row without a deload week.'));
        }
        final flat = stalledLifts;
        if (flat.length >= 2) {
          out.add((kind: 'plateau', text: '${flat.length} lifts have not moved for 3 weeks: ${flat.take(3).map((e) => e.name).join(', ')}.'));
        }
        return out;
      }, _today);

  /// How close to failure the working sets were. Counts sets that have an RPE.
  /// hard is 0 or 1 reps left, good is 2 or 3, easy is 4 or more.
  ({int hard, int good, int easy, int total})? effortSpread({String? id, int days = 28}) {
    final from = _today.subtract(Duration(days: days - 1));
    var hard = 0, good = 0, easy = 0;
    for (final s in sessions) {
      if (_dayKey(s.day).isBefore(from)) continue;
      for (final e in s.exercises) {
        if (id != null && e.id != id) continue;
        for (final st in e.workingSets) {
          final rpe = st.rpe;
          if (rpe == null) continue;
          if (rpe >= 9) {
            hard++;
          } else if (rpe >= 7) {
            good++;
          } else {
            easy++;
          }
        }
      }
    }
    final total = hard + good + easy;
    if (total < (id == null ? 5 : 3)) return null;
    return (hard: hard, good: good, easy: easy, total: total);
  }

  /// Seconds between one set and the next on the same exercise. Only sets
  /// ticked off live carry a time, so sessions before this feature have none.
  List<int> _restGaps(LoggedExercise e) {
    final out = <int>[];
    for (var i = 1; i < e.sets.length; i++) {
      final a = e.sets[i - 1].at, b = e.sets[i].at;
      if (a == null || b == null || !e.sets[i].counts || !e.sets[i - 1].counts) continue;
      final gap = b - a;
      if (gap >= 15 && gap <= 1200) out.add(gap);
    }
    return out;
  }

  /// Average rest in seconds, and the average per session (oldest first, last
  /// 8). Null with fewer than 3 measured rests.
  ({int avg, List<int> series, int sessions})? restStats({String? id, int days = 90}) {
    final from = _today.subtract(Duration(days: days - 1));
    final all = <int>[];
    final per = <(DateTime, int)>[];
    for (final s in sessions) {
      if (_dayKey(s.day).isBefore(from)) continue;
      final gaps = <int>[];
      for (final e in s.exercises) {
        if (id != null && e.id != id) continue;
        gaps.addAll(_restGaps(e));
      }
      if (gaps.isEmpty) continue;
      all.addAll(gaps);
      per.add((s.date, (gaps.reduce((a, b) => a + b) / gaps.length).round()));
    }
    if (all.length < 3) return null;
    per.sort((a, b) => a.$1.compareTo(b.$1));
    final tail = per.length > 8 ? per.sublist(per.length - 8) : per;
    return (avg: (all.reduce((a, b) => a + b) / all.length).round(), series: [for (final p in tail) p.$2], sessions: per.length);
  }

  /// Working sets of one exercise per week, oldest first, the current week last.
  List<int> exerciseWeeklySets(String id, int weeks) {
    final first = shiftDays(weekStartDate, -7 * (weeks - 1));
    final out = List<int>.filled(weeks, 0);
    for (final h in _allHistory[id] ?? const <({DateTime date, LoggedExercise ex})>[]) {
      final day = _dayKey(h.date);
      final i = day.difference(first).inDays ~/ 7;
      if (day.isBefore(first) || i < 0 || i >= weeks) continue;
      out[i] += h.ex.workingSets.length;
    }
    return out;
  }

  /// Sessions per week that included [id], over the last 4 weeks.
  double exerciseFrequency(String id) {
    final from = _today.subtract(const Duration(days: 27));
    final n = (_allHistory[id] ?? const <({DateTime date, LoggedExercise ex})>[]).where((h) => !_dayKey(h.date).isBefore(from)).length;
    return n / 4;
  }

  // ---- Body, cardio and food ----------------------------------------------

  /// Average kcal and protein on training days and on rest days, over the last
  /// [days]. Null until both kinds of day have at least 2 logged days.
  ({int trainDays, int restDays, double trainKcal, double restKcal, double trainProtein, double restProtein})? foodByDayType({int days = 30}) {
    var tn = 0, rn = 0;
    var tk = 0.0, rk = 0.0, tp = 0.0, rp = 0.0;
    for (var i = 0; i < days; i++) {
      final d = _today.subtract(Duration(days: i));
      if (entriesOn(d).isEmpty) continue;
      final m = totalOn(d);
      if (_hasSessionOn(d)) {
        tn++;
        tk += m.kcal.toDouble();
        tp += m.protein.toDouble();
      } else {
        rn++;
        rk += m.kcal.toDouble();
        rp += m.protein.toDouble();
      }
    }
    if (tn < 2 || rn < 2) return null;
    return (trainDays: tn, restDays: rn, trainKcal: tk / tn, restKcal: rk / rn, trainProtein: tp / tn, restProtein: rp / rn);
  }

  bool _isCardioEx(LoggedExercise e) => isCardio(e.id) || loggedDistance(e);

  /// Per week, oldest first: lifting minutes, cardio minutes and cardio km.
  List<({DateTime start, int liftMin, int cardioMin, double km})> cardioWeekly(int weeks) => _remember(('cardio', weeks), () {
        final first = shiftDays(weekStartDate, -7 * (weeks - 1));
        final out = [for (var i = 0; i < weeks; i++) (start: shiftDays(first, 7 * i), lift: 0.0, cardio: 0.0, km: 0.0)];
        for (final s in sessions) {
          final day = _dayKey(s.day);
          final i = day.difference(first).inDays ~/ 7;
          if (day.isBefore(first) || i < 0 || i >= weeks) continue;
          var cardioSec = 0.0, km = 0.0;
          var lifts = false;
          for (final e in s.exercises) {
            if (_isCardioEx(e)) {
              for (final st in e.sets) {
                cardioSec += (st.sec ?? 0);
                km += (st.km ?? 0);
              }
            } else {
              lifts = true;
            }
          }
          final liftSec = lifts ? math.max(0, s.durationSec - cardioSec) : 0;
          out[i] = (start: out[i].start, lift: out[i].lift + liftSec / 60, cardio: out[i].cardio + cardioSec / 60, km: out[i].km + km);
        }
        return [for (final w in out) (start: w.start, liftMin: w.lift.round(), cardioMin: w.cardio.round(), km: w.km)];
      }, (_today, weekStartDay));

  bool get hasCardioLogged => cardioWeekly(8).any((w) => w.cardioMin > 0 || w.km > 0);

  /// Rowing is shown per 500 m, everything else per km.
  bool paceIsRowing(String id) => (exerciseById(id)?.name ?? '').toLowerCase().contains('row') && loggedDistanceAny(id);

  bool loggedDistanceAny(String id) =>
      (_allHistory[id] ?? const []).any((h) => h.ex.sets.any((s) => (s.km ?? 0) > 0 && (s.sec ?? 0) > 0));

  /// Best pace of each session in seconds, oldest first. Lower is faster.
  List<double> paceSeries(String id) {
    final per = paceIsRowing(id) ? 2.0 : 1.0;
    final out = <double>[];
    for (final h in (_allHistory[id] ?? const []).reversed) {
      double? best;
      for (final st in h.ex.sets) {
        final km = st.km ?? 0, sec = st.sec ?? 0;
        if (km <= 0 || sec <= 0) continue;
        final pace = sec / (km * per);
        if (best == null || pace < best) best = pace;
      }
      if (best != null) out.add(best);
    }
    return out;
  }

  String paceText(double seconds) {
    final s = seconds.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ---- Summaries ----------------------------------------------------------

  /// The 28 days ending today ([back] 0) or the 28 days before them ([back] 1).
  ({int sessions, double volume, int sets, int avgMin, int prs}) fourWeeks(int back) => _remember(('four', back), () {
        final end = _today.subtract(Duration(days: 28 * back));
        final start = end.subtract(const Duration(days: 27));
        var n = 0, sets = 0, secs = 0;
        var volume = 0.0;
        for (final s in sessions) {
          final day = _dayKey(s.day);
          if (day.isBefore(start) || day.isAfter(end)) continue;
          n++;
          volume += s.volume;
          sets += s.setCount;
          secs += s.durationSec;
        }
        final prs = prEvents.where((e) {
          final d = _dayKey(e.date);
          return !d.isBefore(start) && !d.isAfter(end);
        }).length;
        return (sessions: n, volume: volume, sets: sets, avgMin: n == 0 ? 0 : (secs / n / 60).round(), prs: prs);
      }, _today);

  /// This week at a glance, with last week for comparison.
  ({int sessions, double volume, int prs, int avgMin, List<String> muscles, int lastSessions, double lastVolume}) get weekReport =>
      _remember('weekReport', () {
        final start = weekStartDate;
        final lastStart = shiftDays(start, -7);
        var n = 0, secs = 0, ln = 0;
        var volume = 0.0, lv = 0.0;
        for (final s in sessions) {
          final day = _dayKey(s.day);
          if (!day.isBefore(start)) {
            n++;
            secs += s.durationSec;
            volume += s.volume;
          } else if (!day.isBefore(lastStart)) {
            ln++;
            lv += s.volume;
          }
        }
        final sets = muscleSetsBetween(start, DateTime.now().add(const Duration(minutes: 1))).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return (
          sessions: n,
          volume: volume,
          prs: prsThisWeek,
          avgMin: n == 0 ? 0 : (secs / n / 60).round(),
          muscles: [for (final e in sets.where((e) => e.value > 0).take(3)) muscleLabel(e.key)],
          lastSessions: ln,
          lastVolume: lv,
        );
      }, (_today, weekStartDay));
}

part of 'fit_state.dart';

/// The kinds of exercise the exercise page has its own stats for. The kind
/// comes from the exercise's own flags (cardio, timed, assisted, reps only,
/// equipment), so changing a flag changes the stats.
enum ExType { loaded, bodyweight, band, weighted, assisted, hold, stretch, cardio, conditioning, sport }

/// The six stats each kind gets, in order. The ids are the ones in [kStatCards].
const kTypeStats = <ExType, List<String>>{
  ExType.loaded: ['x_level', 't_ready', 't_easier', 't_rm', 'x_volume', 't_rhythm'],
  ExType.bodyweight: ['t_miles', 't_load', 't_ready', 't_drop', 't_weekly', 't_next'],
  ExType.band: ['t_ready', 't_easier', 't_typical', 'x_volume', 't_drop', 't_freq'],
  ExType.weighted: ['x_level', 't_load', 't_easier', 't_rm', 't_ready', 't_next'],
  ExType.assisted: ['t_load', 't_miles', 't_ready', 't_forecast', 't_rhythm', 't_freq'],
  ExType.hold: ['t_hold', 't_miles', 't_ready', 't_weekly', 't_sides', 't_forecast'],
  ExType.stretch: ['t_hold', 't_sides', 't_weekly', 't_freq', 't_totals', 't_time'],
  ExType.cardio: ['t_bests', 't_eff', 't_weekly', 't_forecast', 't_miles', 't_freq'],
  ExType.conditioning: ['t_eff', 't_drop', 't_weekly', 't_totals', 't_rhythm', 't_time'],
  ExType.sport: ['t_weekly', 't_eff', 't_freq', 't_totals', 't_sleep', 't_time'],
};

typedef StatRow = ({String label, String value, String? note});

const _conditioningWords = ['burpee', 'jumping jack', 'mountain climber', 'jump rope', 'skipping', 'battle rope', 'box jump', 'swing', 'sled', 'sprawl'];

double _medianOf(List<double> v) {
  if (v.isEmpty) return 0;
  final s = [...v]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

/// Least-squares slope of [ys] against [xs].
double _slopeOf(List<double> xs, List<double> ys) {
  final n = xs.length;
  if (n < 2) return 0;
  final mx = xs.reduce((a, b) => a + b) / n;
  final my = ys.reduce((a, b) => a + b) / n;
  var num = 0.0, den = 0.0;
  for (var i = 0; i < n; i++) {
    num += (xs[i] - mx) * (ys[i] - my);
    den += (xs[i] - mx) * (xs[i] - mx);
  }
  return den == 0 ? 0 : num / den;
}

String _mdShort(DateTime d) => '${d.day}/${d.month}';

mixin StatsMore on FitCore, ToolsState, LibraryState, SettingsState, StatsState, HealthState, NutritionState, StatsPlus, GarminState {
  // ---- Which kind of exercise ----------------------------------------------

  ExType exerciseType(String id) {
    final ex = exerciseById(id);
    if (ex == null) return ExType.loaded;
    final kind = kindOf(ex);
    if (isCardio(id) || kind == 'cardio') return ExType.cardio;
    if (kind == 'sport') return ExType.sport;
    if (kind == 'stretch') return ExType.stretch;
    if (isTimed(id)) return ExType.hold;
    if (isAssisted(id)) return ExType.assisted;
    final name = ex.name.toLowerCase();
    if (_conditioningWords.any(name.contains)) return ExType.conditioning;
    if (ex.equipment == 'Band') return ExType.band;
    if (ex.equipment == 'Weighted') return ExType.weighted;
    if (isRepsOnly(id)) return ExType.bodyweight;
    if (kind == 'calisthenics' && _hasLoadedHistory(id)) return ExType.weighted;
    return ExType.loaded;
  }

  double get _bodyKg => latestBodyweight?.kg ?? profile.weightKg;

  List<({DateTime date, LoggedExercise ex})> _hist(String id) => _allHistory[id] ?? const [];

  /// The number a session of [e] is judged by, for each kind of exercise.
  double? _metricOf(LoggedExercise e, ExType type) {
    final w = e.workingSets;
    if (w.isEmpty) return null;
    double? pos(num v) => v > 0 ? v.toDouble() : null;
    if (type == ExType.loaded || type == ExType.band || type == ExType.weighted) return pos(e.bestOneRm);
    if (type == ExType.bodyweight || type == ExType.conditioning) return pos(w.map((s) => s.reps).reduce(math.max));
    if (type == ExType.assisted) return w.map((s) => s.weight).reduce(math.min);
    if (type == ExType.hold || type == ExType.stretch) return pos(w.map((s) => s.sec ?? 0).reduce(math.max));
    final secs = w.fold<int>(0, (a, s) => a + (s.sec ?? 0));
    if (type == ExType.cardio) {
      final km = w.map((s) => s.km ?? 0).reduce(math.max);
      return km > 0 ? km : pos(secs / 60);
    }
    return pos(secs / 60);
  }

  /// One number per session, oldest first, and whether higher is better.
  ({List<({DateTime date, double v})> points, bool up, ExType type})? exMetric(String id) => _remember(('exMetric', id), () {
        final type = exerciseType(id);
        final pts = <({DateTime date, double v})>[];
        for (final h in progressHistory(id).reversed) {
          final v = _metricOf(h.ex, type);
          if (v != null) pts.add((date: h.date, v: v));
        }
        if (pts.isEmpty) return null;
        return (points: pts, up: type != ExType.assisted, type: type);
      }, (_today, exerciseType(id)));

  // ---- Ready for more (#2) --------------------------------------------------

  ({double pct, int hit, int total, String detail, String advice, bool ready})? readyFor(String id) {
    final type = exerciseType(id);
    if (type == ExType.cardio || type == ExType.sport || type == ExType.conditioning) return null;
    final hist = progressHistory(id);
    if (hist.isEmpty) return null;
    final sets = hist.first.ex.workingSets;
    if (sets.isEmpty) return null;
    final timed = type == ExType.hold || type == ExType.stretch;
    final target = timed ? readySeconds : readyReps;
    var pool = sets;
    String at = '';
    if (type == ExType.loaded || type == ExType.weighted) {
      final top = sets.map((s) => s.weight).reduce(math.max);
      if (top <= 0) return null;
      pool = [for (final s in sets) if (s.weight >= top * 0.97) s];
      at = ' at ${weightLabel(top)}';
    }
    final hit = pool.where((s) => (timed ? (s.sec ?? 0) : s.reps) >= target).length;
    final ready = hit == pool.length;
    final unit = timed ? '$target s' : '$target reps';
    final String advice;
    if (type == ExType.loaded || type == ExType.weighted) {
      final top = pool.map((s) => s.weight).reduce(math.max);
      final step = progressFor(id) ?? 2.5;
      advice = ready
          ? 'Every set reached $target reps. Try ${weightLabel(top + (step > 0 ? step : 2.5))}.'
          : 'Reach $target reps on every set$at, then add weight.';
    } else if (type == ExType.bodyweight) {
      advice = ready ? 'Every set reached $target reps. Add weight or a harder variation.' : 'Reach $target reps on every set, then add weight.';
    } else if (type == ExType.band) {
      advice = ready ? 'Every set reached $target reps. Try a heavier band.' : 'Reach $target reps on every set, then use a heavier band.';
    } else if (type == ExType.assisted) {
      advice = ready ? 'Every set reached $target reps. Lower the assist.' : 'Reach $target reps on every set, then lower the assist.';
    } else {
      advice = ready ? 'Every hold reached $target s. Aim longer.' : 'Hold $target s on every set, then go longer.';
    }
    return (
      pct: pool.isEmpty ? 0.0 : hit / pool.length * 100,
      hit: hit,
      total: pool.length,
      detail: '$hit of ${pool.length} ${timed ? 'holds' : 'sets'} at $unit$at',
      advice: advice,
      ready: ready,
    );
  }

  // ---- Same load, easier (#4) ------------------------------------------------

  /// RPE at the weight you last used, session by session. Needs RPE logged.
  ({List<double> rpe, double weight, int reps, double? first})? easierSeries(String id) {
    final hist = progressHistory(id);
    if (hist.length < 3) return null;
    final type = exerciseType(id);
    final loaded = type == ExType.loaded || type == ExType.weighted;
    double refW = 0;
    for (final h in hist) {
      final rated = h.ex.workingSets.where((s) => s.rpe != null).toList();
      if (rated.isEmpty) continue;
      refW = rated.map((s) => s.weight).reduce(math.max);
      break;
    }
    if (loaded && refW <= 0) return null;
    final out = <double>[];
    var reps = 0;
    for (final h in hist.take(10)) {
      final at = [
        for (final s in h.ex.workingSets)
          if (s.rpe != null && (!loaded || (s.weight - refW).abs() <= refW * 0.03)) s,
      ];
      if (at.isEmpty) continue;
      if (out.isEmpty) reps = at.map((s) => s.reps).reduce(math.max);
      out.add(at.fold(0.0, (a, s) => a + s.rpe!) / at.length);
    }
    if (out.length < 3) return null;
    final series = out.reversed.toList();
    return (rpe: series, weight: refW, reps: reps, first: series.first);
  }

  // ---- Estimated rep maxes (#11) ---------------------------------------------

  List<StatRow>? repMaxes(String id) {
    final m = exMetric(id);
    if (m == null || m.points.length < 2) return null;
    final now = DateTime.now();
    double bestIn(int fromDays, int toDays) {
      var b = 0.0;
      for (final p in m.points) {
        final age = now.difference(p.date).inDays;
        if (age >= fromDays && age < toDays) b = math.max(b, p.v);
      }
      return b;
    }

    final cur = bestIn(0, 56);
    if (cur <= 0) return null;
    final prev = bestIn(56, 112);
    StatRow row(int reps) {
      final w = cur / (1 + reps / 30);
      final d = prev > 0 ? w - prev / (1 + reps / 30) : null;
      return (
        label: '${reps}RM',
        value: weightLabel(w),
        note: d == null || d.abs() < 0.05 ? null : '${d > 0 ? '+' : '−'}${weightLabel(d.abs())} in 8 weeks',
      );
    }

    return [row(3), row(10)];
  }

  // ---- PR rhythm (#17) and PR dates --------------------------------------------

  List<DateTime> _prDates(String id) {
    final m = exMetric(id);
    if (m == null) return const [];
    final out = <DateTime>[];
    var best = m.points.first.v;
    for (final p in m.points.skip(1)) {
      if (m.up ? p.v > best : p.v < best) {
        out.add(p.date);
        best = p.v;
      }
    }
    return out;
  }

  List<StatRow>? prRhythm(String id) {
    final m = exMetric(id);
    if (m == null || m.points.length < 3) return null;
    final dates = _prDates(id);
    if (dates.length < 2) return null;
    final last = dates.last;
    final days = DateTime.now().difference(last).inDays;
    final since = m.points.where((p) => p.date.isAfter(last)).length;
    final span = math.max(30, math.min(180, DateTime.now().difference(m.points.first.date).inDays));
    final recent = dates.where((d) => DateTime.now().difference(d).inDays <= span).length;
    final jumps = <double>[];
    var best = m.points.first.v;
    for (final p in m.points.skip(1)) {
      if (m.up ? p.v > best : p.v < best) {
        jumps.add((p.v - best).abs());
        best = p.v;
      }
    }
    final jump = _medianOf(jumps);
    return [
      (label: 'Last PR', value: days == 0 ? 'today' : '$days days', note: since <= 0 ? null : '$since sessions ago'),
      (label: 'PRs a month', value: (recent / (span / 30)).toStringAsFixed(1), note: null),
      (label: 'Typical jump', value: '${m.up ? '+' : '−'}${_amount(jump, m.type)}', note: null),
    ];
  }

  String _unitOf(ExType t) => switch (t) {
        ExType.loaded || ExType.band || ExType.weighted || ExType.assisted => 'kg',
        ExType.bodyweight || ExType.conditioning => 'reps',
        ExType.hold || ExType.stretch => 's',
        ExType.cardio => 'km',
        ExType.sport => 'min',
      };

  String _amount(double v, ExType t) => switch (t) {
        ExType.loaded || ExType.band || ExType.weighted || ExType.assisted => weightLabel(v),
        ExType.bodyweight || ExType.conditioning => '${fmt(v.round())} reps',
        ExType.hold || ExType.stretch => '${fmt(v.round())} s',
        ExType.cardio => '${fmt(double.parse(v.toStringAsFixed(1)))} km',
        ExType.sport => '${fmt(v.round())} min',
      };

  // ---- Milestones (#5) and forecast (#6) ---------------------------------------

  ({List<double> steps, double best, int done, double? next, String unit, bool down})? ladder(String id) {
    final m = exMetric(id);
    if (m == null) return null;
    final type = m.type;
    List<double> steps;
    switch (type) {
      case ExType.bodyweight:
      case ExType.conditioning:
        steps = [1, 5, 10, 15, 20, 25, 30, 40, 50];
      case ExType.hold:
      case ExType.stretch:
        steps = [15, 30, 45, 60, 90, 120, 180, 300];
      case ExType.cardio:
        final byKm = _hist(id).any((h) => h.ex.sets.any((s) => (s.km ?? 0) > 0));
        steps = byKm ? [1, 3, 5, 10, 21.1, 42.2] : [10, 20, 30, 45, 60, 90];
      case ExType.assisted:
        final start = m.points.first.v;
        if (start <= 0) return null;
        steps = {for (final f in [0.75, 0.5, 0.25]) (start * f / 2.5).round() * 2.5, 0.0}.where((v) => v < start).toList()
          ..sort((a, b) => b.compareTo(a));
      case ExType.loaded:
      case ExType.band:
      case ExType.weighted:
      case ExType.sport:
        return null;
    }
    final down = type == ExType.assisted;
    final best = down ? m.points.map((p) => p.v).reduce(math.min) : m.points.map((p) => p.v).reduce(math.max);
    final done = steps.where((s) => down ? best <= s : best >= s).length;
    final pending = steps.where((s) => down ? best > s : best < s).toList();
    final unit = type == ExType.cardio ? (steps.last > 40 && steps.first == 10 ? 'min' : 'km') : _unitOf(type);
    return (steps: steps, best: best, done: done, next: pending.isEmpty ? null : pending.first, unit: unit, down: down);
  }

  ({double target, DateTime date, double perWeek, String unit, bool down})? forecast(String id) {
    final m = exMetric(id);
    final l = ladder(id);
    if (m == null || l == null || l.next == null || m.points.length < 4) return null;
    final slice = m.points.length > 10 ? m.points.sublist(m.points.length - 10) : m.points;
    final t0 = slice.first.date;
    final xs = [for (final p in slice) p.date.difference(t0).inHours / 24];
    final ys = [for (final p in slice) p.v];
    final slope = _slopeOf(xs, ys);
    if (l.down ? slope >= -0.0001 : slope <= 0.0001) return null;
    final last = slice.last;
    final days = (l.next! - last.v) / slope;
    if (!days.isFinite || days <= 0 || days > 365) return null;
    return (
      target: l.next!,
      date: DateTime.now().add(Duration(days: days.ceil())),
      perWeek: slope * 7,
      unit: l.unit,
      down: l.down,
    );
  }

  // ---- Effective load (#3) -----------------------------------------------------

  List<StatRow>? effectiveLoad(String id) {
    final type = exerciseType(id);
    final hist = progressHistory(id);
    if (hist.isEmpty) return null;
    final bw = _bodyKg;
    if (bw <= 0) return null;
    final sets = hist.first.ex.workingSets;
    if (sets.isEmpty) return null;
    if (type == ExType.bodyweight) {
      final best = hist.expand((h) => h.ex.workingSets).map((s) => s.reps).fold(0, math.max);
      if (best <= 0) return null;
      final rm = bw * (1 + best / 30);
      return [
        (label: 'Bodyweight', value: weightLabel(bw), note: null),
        (label: 'Moved per rep', value: weightLabel(bw), note: null),
        (label: 'Est. 1RM with body', value: weightLabel(rm), note: '+${weightLabel(rm - bw)} added'),
      ];
    }
    if (type == ExType.weighted) {
      final top = sets.reduce((a, b) => a.oneRm >= b.oneRm ? a : b);
      final total = bw + top.weight;
      final rm = total * (1 + top.reps / 30);
      return [
        (label: 'Bodyweight', value: weightLabel(bw), note: null),
        (label: 'Total per rep', value: weightLabel(total), note: '${weightLabel(top.weight)} added'),
        (label: 'Est. 1RM with body', value: weightLabel(rm), note: null),
      ];
    }
    if (type == ExType.assisted) {
      final assist = sets.map((s) => s.weight).reduce(math.min);
      final everLow = hist.expand((h) => h.ex.workingSets).map((s) => s.weight).reduce(math.min);
      return [
        (label: 'Bodyweight', value: weightLabel(bw), note: null),
        (label: 'Assist', value: weightLabel(assist), note: null),
        (label: 'You lift', value: weightLabel(math.max(0.0, bw - assist)), note: 'best ${weightLabel(math.max(0.0, bw - everLow))}'),
      ];
    }
    return null;
  }

  // ---- Rep drop-off (#10) --------------------------------------------------------

  ({List<double> values, double pct, bool timed})? dropOff(String id) {
    final hist = progressHistory(id);
    if (hist.isEmpty) return null;
    final type = exerciseType(id);
    final timed = type == ExType.hold || type == ExType.stretch;
    final v = [for (final s in hist.first.ex.workingSets) (timed ? (s.sec ?? 0) : s.reps).toDouble()];
    if (v.length < 2 || v.first <= 0) return null;
    return (values: v, pct: (v.last - v.first) / v.first * 100, timed: timed);
  }

  // ---- Weekly amount (#12) -------------------------------------------------------

  ({List<double> values, String unit, double avg, double thisWeek})? weeklyAmount(String id, {int weeks = 8, int back = 0}) {
    final type = exerciseType(id);
    final first = shiftDays(weekStartDate, -7 * (weeks - 1) - 7 * weeks * back);
    final out = List<double>.filled(weeks, 0);
    final hasKm = _hist(id).any((h) => h.ex.sets.any((s) => (s.km ?? 0) > 0));
    for (final h in _hist(id)) {
      final day = _dayKey(h.date);
      final i = day.difference(first).inDays ~/ 7;
      if (day.isBefore(first) || i < 0 || i >= weeks) continue;
      final w = h.ex.workingSets;
      switch (type) {
        case ExType.bodyweight:
        case ExType.conditioning:
          out[i] += w.fold<int>(0, (a, s) => a + s.reps);
        case ExType.hold:
        case ExType.stretch:
          out[i] += w.fold<int>(0, (a, s) => a + (s.sec ?? 0)) / 60;
        case ExType.cardio:
          out[i] += hasKm ? w.fold<double>(0, (a, s) => a + (s.km ?? 0)) : w.fold<int>(0, (a, s) => a + (s.sec ?? 0)) / 60;
        case ExType.sport:
          out[i] += w.fold<int>(0, (a, s) => a + (s.sec ?? 0)) / 3600;
        case ExType.loaded:
        case ExType.band:
        case ExType.weighted:
        case ExType.assisted:
          out[i] += w.length;
      }
    }
    if (out.where((v) => v > 0).length < 2) return null;
    final unit = switch (type) {
      ExType.bodyweight || ExType.conditioning => 'reps',
      ExType.hold || ExType.stretch => 'min',
      ExType.cardio => hasKm ? 'km' : 'min',
      ExType.sport => 'h',
      _ => 'sets',
    };
    return (values: out, unit: unit, avg: out.fold(0.0, (a, b) => a + b) / weeks, thisWeek: out.last);
  }

  // ---- Typical set (#13) -----------------------------------------------------------

  List<StatRow>? typicalSet(String id) {
    final hist = progressHistory(id).take(5).toList();
    final sets = [for (final h in hist) ...h.ex.workingSets];
    if (sets.length < 3) return null;
    final w = _medianOf([for (final s in sets) s.weight]);
    final r = _medianOf([for (final s in sets) s.reps.toDouble()]);
    return [
      (label: w > 0 ? 'Band or load' : 'Band', value: w > 0 ? weightLabel(w) : 'none', note: null),
      (label: 'Reps', value: fmt(r.round()), note: 'median of ${sets.length} sets'),
    ];
  }

  // ---- Frequency (#18) ---------------------------------------------------------------

  List<StatRow>? frequencyStats(String id) {
    final days = {for (final h in _hist(id)) _dayKey(h.date)}.toList()..sort();
    if (days.length < 3) return null;
    final gaps = <double>[];
    var longest = 0;
    DateTime? longestEnd;
    for (var i = 1; i < days.length; i++) {
      final g = days[i].difference(days[i - 1]).inDays;
      gaps.add(g.toDouble());
      if (g > longest) {
        longest = g;
        longestEnd = days[i];
      }
    }
    final recent = gaps.length > 12 ? gaps.sublist(gaps.length - 12) : gaps;
    var streak = 0;
    final weeksWith = {for (final d in days) (d.difference(weekStartDate).inDays / 7).floor()};
    for (var w = 0; w >= -52; w--) {
      if (weeksWith.contains(w)) {
        streak++;
      } else if (w != 0) {
        break;
      }
    }
    return [
      (label: 'Every', value: '${_medianOf(recent).toStringAsFixed(recent.isEmpty ? 0 : 1)} days', note: null),
      (label: 'Longest gap', value: '$longest days', note: longestEnd == null ? null : 'ended ${_mdShort(longestEnd)}'),
      (label: 'Week streak', value: '$streak', note: null),
    ];
  }

  // ---- Hold quality (#9) ------------------------------------------------------------------

  List<StatRow>? holdQuality(String id) {
    final hist = progressHistory(id);
    if (hist.isEmpty) return null;
    final sets = hist.first.ex.workingSets.where((s) => (s.sec ?? 0) > 0).toList();
    if (sets.isEmpty) return null;
    final secs = [for (final s in sets) s.sec!.toDouble()];
    final avg = secs.reduce((a, b) => a + b) / secs.length;
    final ever = hist.expand((h) => h.ex.workingSets).map((s) => s.sec ?? 0).reduce(math.max);
    final drop = secs.length < 2 ? null : (secs.last - secs.first) / secs.first * 100;
    return [
      (label: 'Average hold', value: '${avg.round()} s', note: '${sets.length} sets'),
      (label: 'Longest', value: '$ever s', note: null),
      if (drop != null) (label: 'Drop over sets', value: '${drop.round()}%', note: '${secs.first.round()} → ${secs.last.round()} s'),
    ];
  }

  // ---- Left and right (#16) -------------------------------------------------------------------

  ({double left, double right, double gap, String unit})? sidesBalance(String id) {
    final sets = [for (final h in progressHistory(id).take(8)) ...h.ex.workingSets.where((s) => s.sided)];
    if (sets.length < 3) return null;
    final l = sets.fold(0, (a, s) => a + s.left!) / sets.length;
    final r = sets.fold(0, (a, s) => a + s.right!) / sets.length;
    final top = math.max(l, r);
    if (top <= 0) return null;
    final t = exerciseType(id);
    return (left: l, right: r, gap: (l - r).abs() / top * 100, unit: t == ExType.hold || t == ExType.stretch ? 's' : 'reps');
  }

  // ---- Best efforts (#7) -----------------------------------------------------------------------

  List<({double km, int sec, DateTime date})> bestEfforts(String id) {
    final out = <({double km, int sec, DateTime date})>[];
    for (final d in const [1.0, 3.0, 5.0, 10.0, 21.1]) {
      int? best;
      DateTime? when;
      for (final h in _hist(id)) {
        for (final s in h.ex.sets) {
          final km = s.km ?? 0, sec = s.sec ?? 0;
          if (km < d * 0.98 || sec <= 0) continue;
          final time = (sec / km * d).round();
          if (best == null || time < best) {
            best = time;
            when = h.date;
          }
        }
      }
      if (best != null && when != null) out.add((km: d, sec: best, date: when));
    }
    return out;
  }

  // ---- Efficiency (#8) ---------------------------------------------------------------------------

  /// Cardio: metres per heartbeat. Sport: average heart rate. Conditioning:
  /// reps a minute. Each needs the data it is made from.
  ({List<double> values, String unit, String title, bool lowerBetter})? efficiency(String id) {
    final type = exerciseType(id);
    final out = <double>[];
    if (type == ExType.cardio) {
      for (final s in sessions.reversed) {
        final hr = s.hrAvg;
        if (hr == null || hr <= 0) continue;
        for (final e in s.exercises) {
          if (e.id != id) continue;
          final km = e.sets.fold(0.0, (a, x) => a + (x.km ?? 0));
          final sec = e.sets.fold(0, (a, x) => a + (x.sec ?? 0));
          if (km <= 0 || sec <= 0) continue;
          out.add(km * 1000 / (sec / 60) / hr);
        }
      }
      return out.length < 3 ? null : (values: out, unit: 'm per beat', title: 'Efficiency', lowerBetter: false);
    }
    if (type == ExType.sport) {
      for (final s in sessions.reversed) {
        final hr = s.hrAvg;
        if (hr != null && s.exercises.any((e) => e.id == id)) out.add(hr.toDouble());
      }
      return out.length < 3 ? null : (values: out, unit: 'bpm', title: 'Average heart rate', lowerBetter: true);
    }
    if (type == ExType.conditioning) {
      for (final h in _hist(id).reversed) {
        final timed = h.ex.workingSets.where((s) => (s.sec ?? 0) > 0 && s.reps > 0).toList();
        if (timed.isEmpty) continue;
        final reps = timed.fold(0, (a, s) => a + s.reps);
        final sec = timed.fold(0, (a, s) => a + s.sec!);
        out.add(reps / (sec / 60));
      }
      return out.length < 3 ? null : (values: out, unit: 'reps/min', title: 'Pace', lowerBetter: false);
    }
    return null;
  }

  // ---- Lifetime totals (#19) ------------------------------------------------------------------------

  List<StatRow>? lifetimeTotals(String id) {
    final hist = _hist(id);
    if (hist.length < 2) return null;
    var sets = 0, reps = 0, secs = 0;
    var km = 0.0, vol = 0.0;
    for (final h in hist) {
      for (final s in h.ex.workingSets) {
        sets++;
        reps += s.reps;
        secs += s.sec ?? 0;
        km += s.km ?? 0;
        vol += s.volume;
      }
    }
    final type = exerciseType(id);
    final String bigLabel, bigValue;
    if (km > 0) {
      bigLabel = 'Distance';
      bigValue = '${fmt(double.parse(km.toStringAsFixed(1)))} km';
    } else if (secs > 0) {
      bigLabel = 'Time';
      bigValue = secs >= 3600 ? '${(secs / 3600).toStringAsFixed(1)} h' : '${(secs / 60).round()} min';
    } else if (type == ExType.loaded || type == ExType.weighted || type == ExType.band) {
      bigLabel = 'Volume';
      bigValue = vol >= 1000 ? '${fmt(double.parse((vol / 1000).toStringAsFixed(1)))} t' : weightLabel(vol);
    } else {
      bigLabel = 'Reps';
      bigValue = fmt(reps);
    }
    return [
      (label: 'Sessions', value: '${hist.length}', note: '$sets sets'),
      (label: bigLabel, value: bigValue, note: null),
      (label: 'Since', value: _mdShort(hist.last.date), note: '${hist.last.date.year}'),
    ];
  }

  // ---- Sleep and energy on this exercise (#21) ----------------------------------------------------------

  List<StatRow>? sleepEnergyFor(String id) {
    final withX = <LoggedSession>[], without = <LoggedSession>[];
    for (final s in sessions) {
      (s.exercises.any((e) => e.id == id) ? withX : without).add(s);
    }
    double? avg(List<LoggedSession> l, int? Function(LoggedSession) f) {
      final v = [for (final s in l) ?f(s)];
      return v.length < 3 ? null : v.fold(0, (a, b) => a + b) / v.length;
    }

    final rows = <StatRow>[];
    final sw = avg(withX, (s) => s.sleep), so = avg(without, (s) => s.sleep);
    final ew = avg(withX, (s) => s.energy), eo = avg(without, (s) => s.energy);
    if (sw != null && so != null) rows.add((label: 'Sleep rating', value: sw.toStringAsFixed(1), note: 'other days ${so.toStringAsFixed(1)}'));
    if (ew != null && eo != null) rows.add((label: 'Energy rating', value: ew.toStringAsFixed(1), note: 'other days ${eo.toStringAsFixed(1)}'));
    if (garminOn) {
      double? hours(List<LoggedSession> l) {
        final v = [for (final s in l) ?garminValue('sleep', s.day)];
        return v.length < 3 ? null : v.reduce((a, b) => a + b) / v.length / 60;
      }

      final hw = hours(withX), ho = hours(without);
      if (hw != null && ho != null) rows.add((label: 'Night before', value: '${hw.toStringAsFixed(1)} h', note: 'other days ${ho.toStringAsFixed(1)} h'));
    }
    return rows.isEmpty ? null : rows;
  }

  // ---- Best time of day (#22) -----------------------------------------------------------------------------

  ({List<double?> weekday, List<double?> part, int bestDay, int bestPart})? timeOfDayFor(String id) {
    final type = exerciseType(id);
    final byDay = List.generate(7, (_) => <double>[]);
    final byPart = List.generate(3, (_) => <double>[]);
    var top = 0.0;
    final rows = <(DateTime, double)>[];
    for (final s in sessions) {
      for (final e in s.exercises) {
        if (e.id != id) continue;
        final v = _metricOf(e, type);
        if (v == null) continue;
        rows.add((s.day, v));
        top = math.max(top, v);
      }
    }
    if (rows.length < 6 || top <= 0) return null;
    for (final r in rows) {
      final score = type == ExType.assisted ? (top - r.$2 + 1) / (top + 1) : r.$2 / top;
      byDay[r.$1.weekday - 1].add(score);
      byPart[r.$1.hour < 11 ? 0 : (r.$1.hour < 16 ? 1 : 2)].add(score);
    }
    double? mean(List<double> v) => v.length < 2 ? null : v.reduce((a, b) => a + b) / v.length;
    final wd = [for (final v in byDay) mean(v)];
    final pt = [for (final v in byPart) mean(v)];
    if (wd.whereType<double>().length < 2) return null;
    int best(List<double?> l) {
      var bi = 0;
      for (var i = 1; i < l.length; i++) {
        if ((l[i] ?? -1) > (l[bi] ?? -1)) bi = i;
      }
      return bi;
    }

    return (weekday: wd, part: pt, bestDay: best(wd), bestPart: best(pt));
  }

  // ---- Next variation / versus bodyweight (#25) ---------------------------------------------------------------

  List<StatRow>? versusBodyweight(String id) {
    final type = exerciseType(id);
    final hist = progressHistory(id);
    if (hist.isEmpty) return null;
    final bw = _bodyKg;
    if (type == ExType.bodyweight) {
      final best = hist.expand((h) => h.ex.workingSets).map((s) => s.reps).fold(0, math.max);
      if (best <= 0) return null;
      final need = readyReps + 2;
      return [
        (
          label: 'Weighted version',
          value: best >= need ? 'Ready' : 'Not yet',
          note: best >= need ? '$best clean reps' : '$best of $need reps',
        ),
      ];
    }
    if (type == ExType.weighted && bw > 0) {
      final top = hist.expand((h) => h.ex.workingSets).map((s) => s.weight).fold(0.0, math.max);
      return [
        (label: 'Added load', value: '${(top / bw * 100).round()}%', note: 'of bodyweight, ${weightLabel(top)}'),
        (label: 'Total load', value: '${((bw + top) / bw).toStringAsFixed(2)}×', note: 'bodyweight'),
      ];
    }
    return null;
  }

  // ===========================================================================
  // Garmin cards. Every one returns null while Garmin data is off.
  // ===========================================================================

  double _perfIndex(LoggedSession s, Map<String, double> best) {
    final v = <double>[];
    for (final e in s.exercises) {
      final top = best[e.id];
      if (top == null || top <= 0 || e.bestOneRm <= 0) continue;
      v.add(e.bestOneRm / top);
    }
    return v.isEmpty ? -1 : v.reduce((a, b) => a + b) / v.length;
  }

  Map<String, double> get _bestOneRm => _remember('bestOneRm', () {
        final out = <String, double>{};
        for (final s in sessions) {
          for (final e in s.exercises) {
            if (e.bestOneRm > (out[e.id] ?? 0)) out[e.id] = e.bestOneRm;
          }
        }
        return out;
      });

  /// A readiness score from last night's sleep, HRV and resting heart rate
  /// against your own 28-day average. It is an estimate, not Garmin's score.
  ({int score, String word, double? sleepH, double? hrv, double? hrvBase, double? rhr, double? rhrBase})? get garminReadiness {
    if (!garminOn) return null;
    final now = DateTime.now();
    double? latest(String key) => garminValue(key, now) ?? garminValue(key, now.subtract(const Duration(days: 1)));
    final sleep = latest('sleep');
    final hrv = latest('hrv');
    final rhr = latest('restingHr');
    final hrvBase = garminBaseline('hrv');
    final rhrBase = garminBaseline('restingHr');
    final parts = <(double, double)>[];
    if (sleep != null) parts.add(((sleep / 60 / 7.5 * 100).clamp(0, 100).toDouble(), 0.4));
    if (hrv != null && hrvBase != null && hrvBase > 0) parts.add(((80 + (hrv / hrvBase - 1) * 200).clamp(0, 100).toDouble(), 0.35));
    if (rhr != null && rhrBase != null) parts.add(((80 - (rhr - rhrBase) * 8).clamp(0, 100).toDouble(), 0.25));
    if (parts.length < 2) return null;
    final w = parts.fold(0.0, (a, p) => a + p.$2);
    final score = (parts.fold(0.0, (a, p) => a + p.$1 * p.$2) / w).round();
    return (
      score: score,
      word: score >= 80 ? 'Ready to push' : (score >= 60 ? 'Fair' : 'Take it easier'),
      sleepH: sleep == null ? null : sleep / 60,
      hrv: hrv,
      hrvBase: hrvBase,
      rhr: rhr,
      rhrBase: rhrBase,
    );
  }

  /// Strength on days after longer sleep against days after shorter sleep.
  ({int n, double longH, double shortH, double longPerf, double shortPerf})? get sleepVsLifts {
    if (!garminOn) return null;
    final best = _bestOneRm;
    final pairs = <(double, double)>[];
    for (final s in sessions) {
      final sleep = garminValue('sleep', s.day);
      final perf = _perfIndex(s, best);
      if (sleep == null || perf < 0 || s.deload) continue;
      pairs.add((sleep / 60, perf));
    }
    if (pairs.length < 8) return null;
    final med = _medianOf([for (final p in pairs) p.$1]);
    final longer = [for (final p in pairs) if (p.$1 >= med) p];
    final shorter = [for (final p in pairs) if (p.$1 < med) p];
    if (longer.length < 3 || shorter.length < 3) return null;
    double mean(List<(double, double)> l, int i) => l.fold(0.0, (a, p) => a + (i == 0 ? p.$1 : p.$2)) / l.length;
    return (n: pairs.length, longH: mean(longer, 0), shortH: mean(shorter, 0), longPerf: mean(longer, 1) * 100, shortPerf: mean(shorter, 1) * 100);
  }

  /// Heart rate per set in the last session that has it.
  ({DateTime date, List<({String name, int hr, int peak, int? drop, int reps, double kg})> sets})? get heartBySet {
    if (!garminOn) return null;
    for (final s in sessions) {
      final rows = <({String name, int hr, int peak, int? drop, int reps, double kg})>[];
      for (final e in s.exercises) {
        for (final st in e.sets) {
          if (st.hr == null) continue;
          rows.add((name: t.catalogName(e.id, e.name), hr: st.hr!, peak: st.hrPeak ?? st.hr!, drop: st.hrDrop, reps: st.reps, kg: st.weight));
        }
      }
      if (rows.length >= 3) return (date: s.date, sets: rows);
    }
    return null;
  }

  /// Heart rate drop in the minute after a set, per session (oldest first).
  ({List<double> perSession, double latest})? get heartDrops {
    if (!garminOn) return null;
    final out = <double>[];
    for (final s in sessions) {
      final v = [for (final e in s.exercises) for (final st in e.sets) ?st.hrDrop];
      if (v.length >= 3) out.add(v.reduce((a, b) => a + b) / v.length);
      if (out.length >= 10) break;
    }
    if (out.isEmpty) return null;
    return (perSession: out.reversed.toList(), latest: out.first);
  }

  /// Time in zones 1 to 5 over [days], and in the last session.
  ({List<int> total, List<int> last, DateTime lastDate, int sessions})? zoneTime({int days = 30}) {
    if (!garminOn) return null;
    final from = _today.subtract(Duration(days: days - 1));
    final total = List<int>.filled(5, 0);
    List<int>? last;
    DateTime? lastDate;
    var n = 0;
    for (final s in sessions) {
      final h = s.hrHist;
      if (h == null) continue;
      final z = zoneSeconds(h, maxHr);
      last ??= z;
      lastDate ??= s.date;
      if (_dayKey(s.day).isBefore(from)) continue;
      n++;
      for (var i = 0; i < 5; i++) {
        total[i] += z[i];
      }
    }
    if (last == null || lastDate == null || last.fold(0, (a, b) => a + b) < 60) return null;
    return (total: total, last: last, lastDate: lastDate, sessions: n);
  }

  /// Minutes in zones 4 and 5, per week, oldest first.
  List<double>? zoneMinutesByWeek({int weeks = 8, int back = 0}) {
    if (!garminOn) return null;
    final first = shiftDays(weekStartDate, -7 * (weeks - 1) - 7 * weeks * back);
    final out = List<double>.filled(weeks, 0);
    var any = false;
    for (final s in sessions) {
      final h = s.hrHist;
      final day = _dayKey(s.day);
      if (h == null || day.isBefore(first)) continue;
      final i = day.difference(first).inDays ~/ 7;
      if (i < 0 || i >= weeks) continue;
      final z = zoneSeconds(h, maxHr);
      out[i] += (z[3] + z[4]) / 60;
      any = true;
    }
    return any ? out : null;
  }

  /// Average heart rate per exercise over [days].
  List<({String id, String name, int hr, int sets})>? heartByExercise({int days = 60}) {
    if (!garminOn) return null;
    final from = _today.subtract(Duration(days: days - 1));
    final sum = <String, int>{}, n = <String, int>{};
    for (final s in sessions) {
      if (_dayKey(s.day).isBefore(from)) continue;
      for (final e in s.exercises) {
        for (final st in e.sets) {
          if (st.hr == null) continue;
          sum[e.id] = (sum[e.id] ?? 0) + st.hr!;
          n[e.id] = (n[e.id] ?? 0) + 1;
        }
      }
    }
    final out = [
      for (final k in sum.keys)
        if (n[k]! >= 2) (id: k, name: _lift(k), hr: (sum[k]! / n[k]!).round(), sets: n[k]!),
    ]..sort((a, b) => b.hr.compareTo(a.hr));
    return out.length < 2 ? null : out.take(6).toList();
  }

  /// The same weight at a lower (or higher) heart rate than the first time.
  List<({String name, double kg, int from, int to})>? get sameWeightHeart {
    if (!garminOn) return null;
    final out = <({String name, double kg, int from, int to})>[];
    for (final tracked in trackedExercises) {
      final byKg = <double, List<int>>{};
      for (final h in _hist(tracked.id).reversed) {
        for (final st in h.ex.workingSets) {
          if (st.hr == null || st.weight <= 0) continue;
          final kg = (st.weight / 2.5).round() * 2.5;
          (byKg[kg] ??= []).add(st.hr!);
        }
      }
      for (final e in byKg.entries) {
        if (e.value.length < 4) continue;
        final half = e.value.length ~/ 2;
        final a = e.value.take(half).reduce((x, y) => x + y) / half;
        final b = e.value.skip(half).reduce((x, y) => x + y) / (e.value.length - half);
        if ((b - a).abs() < 3) continue;
        out.add((name: _lift(tracked.id, tracked.name), kg: e.key, from: a.round(), to: b.round()));
      }
    }
    out.sort((a, b) => (a.to - a.from).compareTo(b.to - b.from));
    return out.isEmpty ? null : out.take(4).toList();
  }

  /// Reps the watch counted against reps you logged.
  ({int logged, int watch, int sets, List<({String name, int logged, int watch})> last})? get watchVsLog {
    if (!garminOn) return null;
    var logged = 0, watch = 0, sets = 0;
    final last = <({String name, int logged, int watch})>[];
    var lastDone = false;
    for (final s in sessions) {
      final rows = <({String name, int logged, int watch})>[];
      for (final e in s.exercises) {
        for (final st in e.sets) {
          if (st.watch == null) continue;
          logged += st.reps;
          watch += st.watch!;
          sets++;
          rows.add((name: t.catalogName(e.id, e.name), logged: st.reps, watch: st.watch!));
        }
      }
      if (!lastDone && rows.isNotEmpty) {
        last.addAll(rows);
        lastDone = true;
      }
    }
    return sets < 3 ? null : (logged: logged, watch: watch, sets: sets, last: last);
  }

  /// How the heart's work in the last 30 days splits between exercises.
  List<({String name, double pct})>? heartLoadShare({int days = 30}) {
    if (!garminOn) return null;
    final from = _today.subtract(Duration(days: days - 1));
    final load = <String, double>{};
    for (final s in sessions) {
      if (_dayKey(s.day).isBefore(from)) continue;
      for (final e in s.exercises) {
        for (final st in e.sets) {
          if (st.hr == null) continue;
          load[e.id] = (load[e.id] ?? 0) + math.max(0, st.hr! - 60) * math.max(1, st.reps);
        }
      }
    }
    final total = load.values.fold(0.0, (a, b) => a + b);
    if (load.length < 2 || total <= 0) return null;
    final rows = [for (final e in load.entries) (name: _lift(e.key), pct: e.value / total * 100)]
      ..sort((a, b) => b.pct.compareTo(a.pct));
    return rows.take(6).toList();
  }

  /// Muscles still recovering, with the hours left stretched or shortened by
  /// last night's sleep. Short sleep slows recovery, long sleep helps it.
  ({double factor, double? sleepH, List<({String muscle, int hours, int base})> rows})? get recoveryWithSleep {
    if (!garminOn) return null;
    final now = DateTime.now();
    final sleep = garminValue('sleep', now) ?? garminValue('sleep', now.subtract(const Duration(days: 1)));
    if (sleep == null) return null;
    final h = sleep / 60;
    final factor = h < 6 ? 1.25 : (h < 7 ? 1.1 : (h >= 8 ? 0.9 : 1.0));
    final rows = <({String muscle, int hours, int base})>[];
    for (final e in muscleRecovery().entries) {
      if (e.value >= 0.95) continue;
      final base = hoursUntilRecovered(e.key);
      if (base == null) continue;
      rows.add((muscle: e.key, hours: (base * factor).round(), base: base));
    }
    rows.sort((a, b) => b.hours.compareTo(a.hours));
    return rows.isEmpty ? null : (factor: factor, sleepH: h, rows: rows.take(5).toList());
  }

  /// Resting heart rate the morning after hard and light sessions.
  ({int n, double heavy, double light})? get rhrAfterSessions {
    if (!garminOn) return null;
    final mean = garminDays['restingHr']?.values.toList() ?? const <double>[];
    if (mean.length < 8) return null;
    final avg = mean.reduce((a, b) => a + b) / mean.length;
    final pairs = <(double, double)>[];
    for (final s in sessions) {
      final next = garminValue('restingHr', s.day.add(const Duration(days: 1)));
      if (next == null) continue;
      pairs.add((s.volume, next - avg));
    }
    if (pairs.length < 6) return null;
    pairs.sort((a, b) => a.$1.compareTo(b.$1));
    final k = pairs.length ~/ 3;
    final light = pairs.take(k).map((p) => p.$2).reduce((a, b) => a + b) / k;
    final heavy = pairs.skip(pairs.length - k).map((p) => p.$2).reduce((a, b) => a + b) / k;
    return (n: pairs.length, heavy: heavy, light: light);
  }

  /// Heart rate next to your own effort rating, session by session.
  List<({DateTime date, double rpe, int hr})>? get heartVsEffort {
    if (!garminOn) return null;
    final out = <({DateTime date, double rpe, int hr})>[];
    for (final s in sessions) {
      final hr = s.hrAvg;
      final rated = [for (final e in s.exercises) for (final st in e.workingSets) ?st.rpe];
      if (hr == null || rated.length < 3) continue;
      out.add((date: s.date, rpe: rated.reduce((a, b) => a + b) / rated.length, hr: hr));
      if (out.length >= 8) break;
    }
    return out.length < 3 ? null : out.reversed.toList();
  }

  /// Calories burned (Health Connect) against calories eaten (food log), last 7 days.
  List<({DateTime day, double burned, double eaten})>? get burnAndEat {
    if (!garminOn) return null;
    final now = _today;
    final out = <({DateTime day, double burned, double eaten})>[];
    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final burned = garminValue('totalKcal', d) ?? ((garminValue('activeKcal', d) ?? 0) > 0 ? garminValue('activeKcal', d)! : 0.0);
      out.add((day: d, burned: burned, eaten: totalOn(d).kcal));
    }
    return out.any((r) => r.burned > 0) ? out : null;
  }

  /// Strength against resting heart rate, week by week.
  ({List<double> strength, List<double> rhr})? get calmerHeart {
    if (!garminOn) return null;
    const weeks = 10;
    final first = shiftDays(weekStartDate, -7 * (weeks - 1));
    final best = _bestOneRm;
    final strength = List<List<double>>.generate(weeks, (_) => []);
    for (final s in sessions) {
      final day = _dayKey(s.day);
      if (day.isBefore(first) || s.deload) continue;
      final i = day.difference(first).inDays ~/ 7;
      if (i < 0 || i >= weeks) continue;
      final p = _perfIndex(s, best);
      if (p >= 0) strength[i].add(p * 100);
    }
    final rhrMap = garminDays['restingHr'] ?? const <String, double>{};
    final rhr = List<List<double>>.generate(weeks, (_) => []);
    for (final e in rhrMap.entries) {
      final d = DateTime.tryParse(e.key);
      if (d == null || d.isBefore(first)) continue;
      final i = d.difference(first).inDays ~/ 7;
      if (i >= 0 && i < weeks) rhr[i].add(e.value);
    }
    double avg(List<double> l) => l.reduce((a, b) => a + b) / l.length;
    final sv = [for (final l in strength) if (l.isNotEmpty) avg(l)];
    final rv = [for (final l in rhr) if (l.isNotEmpty) avg(l)];
    return sv.length < 3 || rv.length < 3 ? null : (strength: sv, rhr: rv);
  }

  /// Signs that a lighter week would help. [on] counts the ones that fire.
  ({int on, int of, List<({String text, bool on})> flags})? get deloadSignal {
    if (sessions.length < 6) return null;
    final flags = <({String text, bool on})>[];
    final load = trainingLoad.ratio;
    if (load != null) flags.add((text: 'This week is ${load.toStringAsFixed(1)}× your usual load', on: load > 1.3));
    final stalled = stalledLifts.length;
    flags.add((text: '$stalled ${stalled == 1 ? 'lift has' : 'lifts have'} not moved for 3 weeks', on: stalled >= 2));
    final alerts = loadAlerts.where((a) => a.kind == 'deload' && a.text.contains('weeks of training')).isNotEmpty;
    flags.add((text: 'Many weeks in a row without a deload', on: alerts));
    final spread = effortSpread();
    if (spread != null) flags.add((text: '${(spread.hard / spread.total * 100).round()}% of sets were near failure', on: spread.hard / spread.total > 0.5));
    if (garminOn) {
      final rhr = garminSeries('restingHr', 3).whereType<double>().toList();
      final rb = garminBaseline('restingHr');
      if (rhr.isNotEmpty && rb != null) {
        final d = rhr.last - rb;
        flags.add((text: 'Resting heart rate ${d >= 0 ? '+' : '−'}${d.abs().round()} bpm vs usual', on: d >= 3));
      }
      final hrv = garminSeries('hrv', 3).whereType<double>().toList();
      final hb = garminBaseline('hrv');
      if (hrv.isNotEmpty && hb != null && hb > 0) {
        final d = (hrv.last / hb - 1) * 100;
        flags.add((text: 'HRV ${d >= 0 ? '+' : '−'}${d.abs().round()}% vs usual', on: d <= -10));
      }
      final sleep = garminSeries('sleep', 5).whereType<double>().toList();
      if (sleep.length >= 3) {
        final avg = sleep.reduce((a, b) => a + b) / sleep.length / 60;
        flags.add((text: 'Sleep averaged ${avg.toStringAsFixed(1)} h lately', on: avg < 6.5));
      }
    }
    if (flags.length < 3) return null;
    return (on: flags.where((f) => f.on).length, of: flags.length, flags: flags);
  }

  /// How rest between sets changes reps on the next set at the same weight.
  List<({String label, double dReps, int n})>? get restVsReps {
    final buckets = <(String, int, int)>[('Under 1 min', 0, 60), ('1 to 1.5 min', 60, 90), ('1.5 to 2.5 min', 90, 150), ('Over 2.5 min', 150, 1201)];
    final sum = List<double>.filled(4, 0);
    final cnt = List<int>.filled(4, 0);
    for (final s in sessions) {
      for (final e in s.exercises) {
        for (var i = 1; i < e.sets.length; i++) {
          final a = e.sets[i - 1], b = e.sets[i];
          if (a.at == null || b.at == null || !a.counts || !b.counts) continue;
          if ((a.weight - b.weight).abs() > math.max(0.5, a.weight * 0.02)) continue;
          final rest = b.at! - a.at!;
          if (rest < 15 || rest > 1200) continue;
          final k = buckets.indexWhere((x) => rest >= x.$2 && rest < x.$3);
          if (k < 0) continue;
          sum[k] += (b.reps - a.reps).toDouble();
          cnt[k]++;
        }
      }
    }
    if (cnt.fold(0, (a, b) => a + b) < 12 || cnt.where((c) => c >= 3).length < 2) return null;
    return [
      for (var k = 0; k < 4; k++)
        if (cnt[k] >= 3) (label: buckets[k].$1, dReps: sum[k] / cnt[k], n: cnt[k]),
    ];
  }
}

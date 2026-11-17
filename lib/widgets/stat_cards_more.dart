part of 'stat_cards.dart';

// ---------------------------------------------------------------------------
// Shared shapes: tiles, a line, bars, a meter, a ladder, a zone strip.

Widget _tiles(GymColors gc, List<StatRow> rows) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const SizedBox(width: 12),
        _tile(gc, rows[i].label, rows[i].value, note: rows[i].note),
      ],
    ]);

String _hms(int sec) => sec >= 3600
    ? '${sec ~/ 3600}:${((sec % 3600) ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}'
    : _mmss(sec);

String _hm(double minutes) {
  final m = minutes.round();
  return m >= 60 ? '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}' : '$m min';
}

Widget _text(GymColors gc, String s, {bool strong = false, Color? color, double size = 12}) => Text(
      s,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTheme.f(size, weight: strong ? FontWeight.w700 : FontWeight.w500, color: color ?? (strong ? gc.text : gc.textSecondary)),
    );

Widget _trend(List<double> values, {String Function(double)? scale, Color? color, double height = 56}) =>
    TrendChart(values: values, height: height, color: color, scale: scale);

Widget _chip(GymColors gc, String label, bool done) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: done ? gc.sage.withValues(alpha: 0.18) : gc.bgRaised2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        done ? '✓ $label' : label,
        style: AppTheme.f(11.5, weight: FontWeight.w600, color: done ? gc.sage : gc.textSecondary),
      ),
    );

/// A bar split into zones, with the minutes of each underneath.
class _ZoneStrip extends StatelessWidget {
  const _ZoneStrip({required this.label, required this.seconds});

  final String label;
  final List<int> seconds;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final colors = [gc.info, gc.sage, gc.brass, gc.warn, gc.danger];
    final total = seconds.fold(0, (a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _text(gc, label, strong: true)),
          _text(gc, _hm(total / 60), size: 11.5),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Row(children: [
              for (var i = 0; i < 5; i++)
                if (seconds[i] > 0) Expanded(flex: seconds[i], child: Container(color: colors[i])),
            ]),
          ),
        ),
        const SizedBox(height: 5),
        Row(children: [
          for (var i = 0; i < 5; i++)
            Expanded(
              child: Text('Z${i + 1} ${(seconds[i] / 60).round()}m',
                  style: AppTheme.f(10, weight: FontWeight.w600, color: seconds[i] > 0 ? colors[i] : gc.textTertiary)),
            ),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise page, by kind of exercise

Widget? _typeCard(String key, String id, bool flat) => switch (key) {
      'x_level' => _xLevel(id, flat),
      'x_volume' => _xVolume(id, flat),
      't_ready' => _tReady(id, flat),
      't_easier' => _tEasier(id, flat),
      't_rm' => _tRows(id, flat, 'Estimated rep maxes', fit.repMaxes(id)),
      't_rhythm' => _tRows(id, flat, 'PR rhythm', fit.prRhythm(id)),
      't_miles' => _tMiles(id, flat),
      't_load' => _tRows(id, flat, fit.exerciseType(id) == ExType.weighted ? 'Total load' : 'Effective load', fit.effectiveLoad(id)),
      't_drop' => _tDrop(id, flat),
      't_weekly' => _tWeekly(id, flat),
      't_next' => _tRows(id, flat, fit.exerciseType(id) == ExType.weighted ? 'Versus bodyweight' : 'Next step', fit.versusBodyweight(id)),
      't_typical' => _tRows(id, flat, 'Typical set', fit.typicalSet(id)),
      't_freq' => _tRows(id, flat, 'Frequency', fit.frequencyStats(id)),
      't_forecast' => _tForecast(id, flat),
      't_hold' => _tRows(id, flat, 'Hold quality', fit.holdQuality(id)),
      't_sides' => _tSides(id, flat),
      't_bests' => _tBests(id, flat),
      't_eff' => _tEfficiency(id, flat),
      't_totals' => _tRows(id, flat, 'Lifetime totals', fit.lifetimeTotals(id)),
      't_sleep' => _tRows(id, flat, 'Sleep and energy', fit.sleepEnergyFor(id)),
      't_time' => _tTime(id, flat),
      _ => null,
    };

Widget? _tRows(String id, bool flat, String title, List<StatRow>? rows) {
  if (rows == null || rows.isEmpty) return null;
  return Builder(builder: (context) => _Shell(flat: flat, title: title, child: _tiles(context.gc, rows)));
}

Widget? _tReady(String id, bool flat) {
  final r = fit.readyFor(id);
  if (r == null) return null;
  final timed = fit.exerciseType(id) == ExType.hold || fit.exerciseType(id) == ExType.stretch;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Ready for more?',
      trailing: _side(gc, timed ? 'target ${fit.readySeconds} s' : 'target ${fit.readyReps} reps', color: r.ready ? gc.sage : null),
      foot: _note(gc, r.advice),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _big(gc, '${r.hit}/${r.total}', size: 22),
          const SizedBox(width: 10),
          Expanded(child: _text(gc, r.detail)),
        ]),
        const SizedBox(height: 8),
        _HBar(value: r.pct, max: 100, color: r.ready ? gc.sage : gc.accent, height: 8),
      ]),
    );
  });
}

Widget? _tEasier(String id, bool flat) {
  final d = fit.easierSeries(id);
  if (d == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final change = d.rpe.last - d.rpe.first;
    return _Shell(
      flat: flat,
      title: 'Same load, easier',
      trailing: _side(gc, d.weight > 0 ? '${fit.weightLabel(d.weight)} × ${d.reps}' : '${d.reps} reps'),
      foot: _note(
        gc,
        change.abs() < 0.3
            ? 'The same effort as before at this load.'
            : (change < 0
                ? 'RPE fell from ${d.rpe.first.toStringAsFixed(1)} to ${d.rpe.last.toStringAsFixed(1)}. The same load feels easier.'
                : 'RPE rose from ${d.rpe.first.toStringAsFixed(1)} to ${d.rpe.last.toStringAsFixed(1)}. The same load feels harder.'),
      ),
      child: _trend(d.rpe, color: change <= 0 ? gc.sage : gc.warn, scale: (v) => 'RPE ${v.toStringAsFixed(1)}'),
    );
  });
}

String _ladderLabel(ExType type, String unit, double v) {
  if (type == ExType.assisted) return fit.weightLabel(v);
  if (unit == 'km') return '${fmt(double.parse(v.toStringAsFixed(1)))} km';
  if (unit == 's') return v >= 60 && v % 30 == 0 ? '${fmt(v / 60)} min' : '${fmt(v.round())} s';
  if (unit == 'min') return '${fmt(v.round())} min';
  return fmt(v.round());
}

Widget? _tMiles(String id, bool flat) {
  final l = fit.ladder(id);
  if (l == null) return null;
  final type = fit.exerciseType(id);
  final title = switch (type) {
    ExType.assisted => 'Assist to zero',
    ExType.hold || ExType.stretch => 'Hold milestones',
    ExType.cardio => l.unit == 'km' ? 'Distance ladder' : 'Time ladder',
    _ => 'Milestones',
  };
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: title,
      trailing: _side(gc, '${l.done} of ${l.steps.length}'),
      foot: _note(
        gc,
        l.next == null
            ? 'Every milestone reached.'
            : (type == ExType.assisted ? 'Next: ${fit.weightLabel(l.next!)} of assist or less.' : 'Next: ${_ladderLabel(type, l.unit, l.next!)}.'),
      ),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in l.steps) _chip(gc, _ladderLabel(type, l.unit, s), l.down ? l.best <= s : l.best >= s),
      ]),
    );
  });
}

Widget? _tDrop(String id, bool flat) {
  final d = fit.dropOff(id);
  if (d == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: d.timed ? 'Hold drop-off' : 'Rep drop-off',
      trailing: _side(gc, d.pct.abs() < 1 ? 'steady' : '${d.pct > 0 ? '+' : '−'}${d.pct.abs().round()}% by the last set', color: d.pct < -25 ? gc.warn : null),
      foot: _note(gc, 'Your last session, set by set: ${d.values.map((v) => v.round()).join(' · ')}${d.timed ? ' s' : ''}.'),
      child: _MiniBars(values: d.values, height: 44),
    );
  });
}

Widget? _tWeekly(String id, bool flat) {
  final first = fit.weeklyAmount(id);
  if (first == null) return null;
  final type = fit.exerciseType(id);
  if (first.unit == 'sets' && type != ExType.assisted) return null;
  final title = switch (first.unit) {
    'reps' => 'Reps per week',
    'min' => 'Minutes per week',
    'km' => 'Km per week',
    'h' => 'Hours per week',
    _ => 'Sets per week',
  };
  final limit = fit.weeksOfHistory ~/ 8;
  String fmtV(double v) => first.unit == 'km' || first.unit == 'h' ? v.toStringAsFixed(1) : v.round().toString();
  return PastSwipe(
    limit: limit,
    builder: (context, back, go) {
      final gc = context.gc;
      final d = back == 0 ? first : fit.weeklyAmount(id, back: back);
      final range = '${back * 8 + 1} to ${back * 8 + 8} weeks ago';
      return _Shell(
        flat: flat,
        title: title,
        trailing: _pager(gc, back, limit, go, _side(gc, back == 0 ? 'this week ${fmtV(first.thisWeek)}' : range)),
        foot: _note(gc, d == null ? 'Nothing logged in these weeks.' : 'About ${fmtV(d.avg)} ${d.unit} a week over 8 weeks.'),
        child: d == null
            ? const SizedBox(height: 40)
            : _MiniBars(
                values: d.values,
                height: 40,
                first: '${back * 8 + 8} weeks ago',
                last: back == 0 ? 'This week' : '${back * 8 + 1} weeks ago',
              ),
      );
    },
  );
}

Widget? _tForecast(String id, bool flat) {
  final f = fit.forecast(id);
  if (f == null) return null;
  final type = fit.exerciseType(id);
  final target = type == ExType.assisted ? '${fit.weightLabel(f.target)} of assist' : _ladderLabel(type, f.unit, f.target);
  return Builder(builder: (context) {
    final gc = context.gc;
    final per = f.perWeek.abs();
    final perText = type == ExType.assisted ? fit.weightLabel(per) : _ladderLabel(type, f.unit, per < 1 ? double.parse(per.toStringAsFixed(1)) : per);
    return _Shell(
      flat: flat,
      title: 'Forecast',
      foot: _note(gc, 'At ${f.down ? '−' : '+'}$perText a week, from your last sessions. It moves if your pace does.'),
      child: Row(children: [
        _big(gc, _dm(f.date), size: 22),
        const SizedBox(width: 10),
        Expanded(child: _text(gc, 'to reach $target')),
      ]),
    );
  });
}

Widget? _tSides(String id, bool flat) {
  final d = fit.sidesBalance(id);
  if (d == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final top = math.max(d.left, d.right);
    Widget side(String label, double v, bool weaker) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 42, child: _text(gc, label)),
            Expanded(child: _HBar(value: v, max: top, color: weaker && d.gap >= 10 ? gc.warn : gc.accent, height: 8)),
            SizedBox(width: 62, child: Text('${v.toStringAsFixed(1)} ${d.unit}', textAlign: TextAlign.end, style: AppTheme.f(11.5, weight: FontWeight.w700, color: gc.text))),
          ]),
        );
    return _Shell(
      flat: flat,
      title: 'Left and right',
      trailing: _side(gc, d.gap < 5 ? 'even' : '${d.gap.round()}% apart', color: d.gap >= 15 ? gc.warn : null),
      foot: d.gap >= 10 ? _note(gc, 'Start with the weaker side and match its count on the other.') : null,
      child: Column(children: [side('Left', d.left, d.left < d.right), side('Right', d.right, d.right < d.left)]),
    );
  });
}

Widget? _tBests(String id, bool flat) {
  final rows = fit.bestEfforts(id);
  if (rows.isEmpty) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Best efforts',
      foot: _note(gc, 'Worked out from your pace on sets at least that long.'),
      child: Column(children: [
        for (final r in rows)
          _line(
            gc,
            _text(gc, '${fmt(double.parse(r.km.toStringAsFixed(1)))} km', strong: true, size: 13),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _text(gc, _dm(r.date), size: 11),
              const SizedBox(width: 10),
              _text(gc, _hms(r.sec), strong: true, size: 13),
            ]),
          ),
      ]),
    );
  });
}

Widget? _tEfficiency(String id, bool flat) {
  final d = fit.efficiency(id);
  if (d == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final change = d.values.last - d.values.first;
    final better = d.lowerBetter ? change < 0 : change > 0;
    return _Shell(
      flat: flat,
      title: d.title,
      trailing: _side(gc, '${d.values.last.toStringAsFixed(d.values.last >= 100 ? 0 : 1)} ${d.unit}'),
      foot: _note(gc, change.abs() < 0.01 ? 'No change yet.' : (better ? 'Better than your first sessions.' : 'Worse than your first sessions.')),
      child: _trend(d.values, color: better ? gc.sage : gc.warn, scale: (v) => v.toStringAsFixed(v >= 100 ? 0 : 1)),
    );
  });
}

Widget? _tTime(String id, bool flat) {
  final d = fit.timeOfDayFor(id);
  if (d == null) return null;
  const parts = ['morning', 'afternoon', 'evening'];
  return Builder(builder: (context) {
    final gc = context.gc;
    final known = d.weekday.whereType<double>().toList();
    final lo = known.reduce(math.min) * 0.9;
    return _Shell(
      flat: flat,
      title: 'Best time',
      trailing: _side(gc, '${t.weekdayShort(d.bestDay + 1)}, ${parts[d.bestPart]}'),
      foot: _note(gc, 'Your results by weekday, compared with your best on this exercise.'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _MiniBars(values: [for (final v in d.weekday) v == null ? 0.0 : v - lo], height: 44),
        const SizedBox(height: 4),
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Text(t.weekdayInitial(i + 1),
                  textAlign: TextAlign.center,
                  style: AppTheme.f(10.5, weight: i == d.bestDay ? FontWeight.w700 : FontWeight.w500, color: i == d.bestDay ? gc.text : gc.textTertiary)),
            ),
        ]),
      ]),
    );
  });
}

// ---------------------------------------------------------------------------
// Own data: rest against reps, deload signal

Widget? _restReps(bool flat) {
  final rows = fit.restVsReps;
  if (rows == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Rest against reps',
      foot: _note(gc, 'Change in reps from one set to the next at the same weight, by how long you rested.'),
      child: Column(children: [
        for (final r in rows)
          _line(
            gc,
            _text(gc, r.label, strong: true),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _text(gc, '${r.n} sets', size: 11),
              const SizedBox(width: 10),
              _text(gc, '${r.dReps >= 0 ? '+' : '−'}${r.dReps.abs().toStringAsFixed(1)} reps', strong: true, color: r.dReps >= -0.5 ? gc.sage : gc.warn, size: 13),
            ]),
          ),
      ]),
    );
  });
}

Widget? _deload(bool flat) {
  final d = fit.deloadSignal;
  if (d == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final hot = d.on >= 3;
    return _Shell(
      flat: flat,
      title: 'Deload signal',
      trailing: _side(gc, '${d.on} of ${d.of}', color: hot ? gc.warn : (d.on > 0 ? gc.brass : gc.sage)),
      foot: _note(gc, hot ? 'Several signs agree. A lighter week would likely help.' : (d.on == 0 ? 'No signs of fatigue. Keep going.' : 'Watch it. One or two signs is normal.')),
      child: Column(children: [
        _HBar(value: d.on.toDouble(), max: d.of.toDouble(), color: hot ? gc.warn : gc.accent, height: 8),
        const SizedBox(height: 8),
        for (final f in d.flags)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(f.on ? Icons.circle : Icons.circle_outlined, size: 9, color: f.on ? gc.warn : gc.textTertiary),
              const SizedBox(width: 8),
              Expanded(child: Text(f.text, style: AppTheme.s(12, color: f.on ? gc.text : gc.textSecondary))),
            ]),
          ),
      ]),
    );
  });
}

// ---------------------------------------------------------------------------
// Garmin

Widget? _gReady(bool flat) {
  final r = fit.garminReadiness;
  if (r == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final color = r.score >= 80 ? gc.sage : (r.score >= 60 ? gc.brass : gc.warn);
    return _Shell(
      flat: flat,
      title: 'Readiness',
      trailing: _side(gc, 'estimate'),
      foot: _note(gc, 'Worked out here from Health Connect against your own 28-day average. It is not the Garmin score, which Garmin keeps to itself.'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _big(gc, '${r.score}', unit: '/ 100', size: 26),
          const SizedBox(width: 12),
          Expanded(child: _text(gc, r.word, strong: true, color: color, size: 13)),
        ]),
        const SizedBox(height: 8),
        _HBar(value: r.score.toDouble(), max: 100, color: color, height: 8),
        const SizedBox(height: 12),
        _tiles(gc, [
          (label: 'Sleep', value: r.sleepH == null ? '–' : _hm(r.sleepH! * 60), note: null),
          (label: 'HRV', value: r.hrv == null ? '–' : '${r.hrv!.round()} ms', note: r.hrvBase == null ? null : 'usual ${r.hrvBase!.round()}'),
          (label: 'Resting HR', value: r.rhr == null ? '–' : '${r.rhr!.round()}', note: r.rhrBase == null ? null : 'usual ${r.rhrBase!.round()}'),
        ]),
      ]),
    );
  });
}

Widget? _gSeries(bool flat, {required String key, required int days, required String title, required String unit, required bool lowerBetter}) {
  if (!fit.garminOn) return null;
  final v = fit.garminSeries(key, days).whereType<double>().toList();
  if (v.length < 4) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final avg = v.reduce((a, b) => a + b) / v.length;
    final d = v.last - avg;
    final good = lowerBetter ? d <= 0 : d >= 0;
    return _Shell(
      flat: flat,
      title: title,
      trailing: _side(gc, '${v.last.round()} $unit'),
      foot: _note(gc, 'Average ${avg.round()} $unit over ${v.length} readings. Latest is ${d.abs() < 0.5 ? 'right on it' : '${d.abs().round()} ${d > 0 ? 'above' : 'below'}'}.'),
      child: _trend(v, color: good ? gc.sage : gc.warn, scale: (x) => x.round().toString()),
    );
  });
}

Widget? _gSleepLift(bool flat) {
  final d = fit.sleepVsLifts;
  if (d == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final diff = d.longPerf - d.shortPerf;
    Widget row(String label, double hours, double perf, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 92, child: _text(gc, '$label ${hours.toStringAsFixed(1)} h')),
            Expanded(child: _HBar(value: perf - 60, max: 45, color: color, height: 8)),
            SizedBox(width: 46, child: Text('${perf.round()}%', textAlign: TextAlign.end, style: AppTheme.f(11.5, weight: FontWeight.w700, color: gc.text))),
          ]),
        );
    return _Shell(
      flat: flat,
      title: 'Sleep against your lifts',
      trailing: _side(gc, '${d.n} sessions'),
      foot: _note(gc, diff.abs() < 1 ? 'Sleep makes no clear difference to your lifts yet.' : 'You lift ${diff.abs().round()}% ${diff > 0 ? 'better' : 'worse'} after the longer nights. The bars are each session against your best.'),
      child: Column(children: [
        row('Longer', d.longH, d.longPerf, gc.sage),
        row('Shorter', d.shortH, d.shortPerf, gc.warn),
      ]),
    );
  });
}

Widget? _gHrSet(bool flat) {
  final d = fit.heartBySet;
  if (d == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final top = d.sets.reduce((a, b) => a.peak >= b.peak ? a : b);
    return _Shell(
      flat: flat,
      title: 'Heart rate by set',
      trailing: _side(gc, _dm(d.date)),
      foot: _note(gc, 'Peak ${top.peak} bpm on ${top.name}. Each bar is the average over one set.'),
      child: _MiniBars(values: [for (final s in d.sets) math.max(0, s.hr - 50).toDouble()], height: 52, first: 'Set 1', last: 'Set ${d.sets.length}'),
    );
  });
}

Widget? _gHrDrop(bool flat) {
  final d = fit.heartDrops;
  if (d == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Heart rate drop after a set',
      trailing: _side(gc, 'in the next minute'),
      foot: _note(gc, 'A bigger drop means your heart recovers faster between sets.'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _big(gc, '−${d.latest.round()}', unit: 'bpm', size: 24),
        if (d.perSession.length >= 2) ...[
          const SizedBox(height: 8),
          _trend(d.perSession, color: gc.sage, height: 48, scale: (v) => v.round().toString()),
        ],
      ]),
    );
  });
}

Widget? _gZones(bool flat) {
  final d = fit.zoneTime();
  if (d == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Time in heart rate zones',
      trailing: _side(gc, 'max ${fit.maxHr} bpm${fit.maxHrAuto ? ' (auto)' : ''}'),
      child: Column(children: [
        if (d.sessions > 0) _ZoneStrip(label: 'Last 30 days · ${d.sessions} sessions', seconds: d.total),
        _ZoneStrip(label: 'Last session · ${_dm(d.lastDate)}', seconds: d.last),
      ]),
    );
  });
}

Widget? _gHrEx(bool flat) {
  final rows = fit.heartByExercise();
  if (rows == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Heart rate per exercise',
      trailing: _side(gc, 'last 60 days'),
      child: Column(children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 104, child: _text(gc, r.name)),
              Expanded(child: _HBar(value: math.max(0, r.hr - 50).toDouble(), max: math.max(10, fit.maxHr - 50).toDouble(), color: gc.accent, height: 7)),
              SizedBox(width: 62, child: Text('${r.hr} bpm', textAlign: TextAlign.end, style: AppTheme.f(11.5, weight: FontWeight.w700, color: gc.text))),
            ]),
          ),
      ]),
    );
  });
}

Widget? _gHrSame(bool flat) {
  final rows = fit.sameWeightHeart;
  if (rows == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Same weight, lower heart rate',
      foot: _note(gc, 'Average heart rate on sets at the same weight, earlier against later.'),
      child: Column(children: [
        for (final r in rows)
          _line(
            gc,
            _text(gc, '${r.name} · ${fit.weightLabel(r.kg)}', strong: true),
            _text(gc, '${r.from} → ${r.to} bpm', strong: true, color: r.to < r.from ? gc.sage : gc.warn, size: 12.5),
          ),
      ]),
    );
  });
}

Widget? _gWatch(bool flat) {
  final d = fit.watchVsLog;
  if (d == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final pct = d.logged == 0 ? 0 : d.watch / d.logged * 100;
    return _Shell(
      flat: flat,
      title: 'Watch count against your log',
      trailing: _side(gc, '${d.sets} sets'),
      foot: _note(gc, 'The watch counts reps itself. A gap can mean either of you missed one.'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _big(gc, '${pct.round()}%', size: 24),
          const SizedBox(width: 10),
          Expanded(child: _text(gc, 'of your logged reps were counted by the watch')),
        ]),
        const SizedBox(height: 6),
        for (final r in d.last.take(6))
          _line(
            gc,
            _text(gc, r.name),
            _text(gc, 'you ${r.logged} · watch ${r.watch}', strong: true, color: r.logged == r.watch ? gc.sage : gc.warn, size: 11.5),
          ),
      ]),
    );
  });
}

Widget? _gEnergy(bool flat) {
  final rows = fit.heartLoadShare();
  if (rows == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Heart load by exercise',
      trailing: _side(gc, 'last 30 days'),
      foot: _note(gc, 'How your heart\'s work splits between exercises, from heart rate and reps. Garmin gives calories for the whole session only, so this is the honest per-exercise view.'),
      child: Column(children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 104, child: _text(gc, r.name)),
              Expanded(child: _HBar(value: r.pct, max: 100, color: gc.accent, height: 7)),
              SizedBox(width: 40, child: Text('${r.pct.round()}%', textAlign: TextAlign.end, style: AppTheme.f(11.5, weight: FontWeight.w700, color: gc.text))),
            ]),
          ),
      ]),
    );
  });
}

Widget? _gRecover(bool flat) {
  final d = fit.recoveryWithSleep;
  if (d == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    String left(int h) => h >= 24 ? '${(h / 24).ceil()}d' : '${h}h';
    final note = d.factor > 1.01
        ? 'Last night was ${_hm(d.sleepH! * 60)}. Short sleep adds about ${((d.factor - 1) * 100).round()}% to recovery time.'
        : (d.factor < 0.99 ? 'Last night was ${_hm(d.sleepH! * 60)}. Good sleep shortens recovery by about ${((1 - d.factor) * 100).round()}%.' : 'Last night was ${_hm(d.sleepH! * 60)}, so recovery time is unchanged.');
    return _Shell(
      flat: flat,
      title: 'Recovery with sleep',
      foot: _note(gc, note),
      child: Column(children: [
        for (final r in d.rows)
          _line(
            gc,
            _text(gc, t.muscle(r.muscle), strong: true),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (r.hours != r.base) ...[_text(gc, 'was ${left(r.base)}', size: 11), const SizedBox(width: 10)],
              _text(gc, left(r.hours), strong: true, size: 13),
            ]),
          ),
      ]),
    );
  });
}

Widget? _gRhrNext(bool flat) {
  final d = fit.rhrAfterSessions;
  if (d == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    String s(double v) => '${v >= 0 ? '+' : '−'}${v.abs().toStringAsFixed(1)} bpm';
    return _Shell(
      flat: flat,
      title: 'Resting heart rate next morning',
      trailing: _side(gc, '${d.n} sessions'),
      foot: _note(gc, d.heavy - d.light >= 1.5 ? 'Your hardest sessions leave your heart working harder the next morning. Worth a lighter day after them.' : 'Hard sessions do not move your resting heart rate much.'),
      child: _tiles(gc, [
        (label: 'After heavy days', value: s(d.heavy), note: 'vs your usual'),
        (label: 'After light days', value: s(d.light), note: 'vs your usual'),
      ]),
    );
  });
}

Widget? _gHrEffort(bool flat) {
  final rows = fit.heartVsEffort;
  if (rows == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final avgHr = rows.fold(0, (a, r) => a + r.hr) / rows.length;
    final odd = rows.where((r) => (r.rpe <= 6.5 && r.hr >= avgHr + 8) || (r.rpe >= 8.5 && r.hr <= avgHr - 8)).length;
    return _Shell(
      flat: flat,
      title: 'Heart effort against your RPE',
      foot: _note(gc, odd == 0 ? 'Your effort ratings and your heart agree.' : '$odd ${odd == 1 ? 'session' : 'sessions'} where how it felt and how your heart worked did not match.'),
      child: Column(children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 44, child: _text(gc, _dm(r.date), size: 11)),
              Expanded(child: _HBar(value: r.rpe, max: 10, color: gc.brass, height: 6)),
              SizedBox(width: 38, child: Text('RPE ${r.rpe.toStringAsFixed(0)}', textAlign: TextAlign.end, style: AppTheme.f(10.5, weight: FontWeight.w600, color: gc.textSecondary))),
              const SizedBox(width: 8),
              Expanded(child: _HBar(value: math.max(0, r.hr - 50).toDouble(), max: math.max(10, fit.maxHr - 50).toDouble(), color: gc.danger, height: 6)),
              SizedBox(width: 30, child: Text('${r.hr}', textAlign: TextAlign.end, style: AppTheme.f(10.5, weight: FontWeight.w600, color: gc.textSecondary))),
            ]),
          ),
      ]),
    );
  });
}

Widget? _gBurn(bool flat) {
  final rows = fit.burnAndEat;
  if (rows == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final today = rows.lastWhere((r) => r.burned > 0, orElse: () => rows.last);
    final net = today.eaten - today.burned;
    return _Shell(
      flat: flat,
      title: 'Burned and eaten',
      trailing: _side(gc, today.day == rows.last.day ? 'today' : _dm(today.day)),
      foot: _note(gc, 'Burned comes from Health Connect and includes resting burn. Eaten comes from your food log. The bars are burned over 7 days.'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _tiles(gc, [
          (label: 'Burned', value: '${fmt(today.burned.round())} kcal', note: null),
          (label: 'Eaten', value: today.eaten > 0 ? '${fmt(today.eaten.round())} kcal' : '–', note: null),
          (label: 'Balance', value: today.eaten > 0 ? '${net >= 0 ? '+' : '−'}${fmt(net.abs().round())}' : '–', note: today.eaten > 0 ? (net >= 0 ? 'surplus' : 'deficit') : null),
        ]),
        const SizedBox(height: 10),
        _MiniBars(values: [for (final r in rows) r.burned], height: 36),
      ]),
    );
  });
}

Widget? _gCalm(bool flat) {
  final d = fit.calmerHeart;
  if (d == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final sUp = d.strength.last >= d.strength.first;
    final rDown = d.rhr.last <= d.rhr.first;
    return _Shell(
      flat: flat,
      title: 'Stronger, calmer heart',
      foot: _note(gc, sUp && rDown ? 'You got stronger while your resting heart rate came down. That is the sign of good training.' : 'Strength and resting heart rate, a week at a time.'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _note(gc, 'Strength, % of your best'),
        _trend(d.strength, color: gc.accent, height: 44, scale: (v) => '${v.round()}%'),
        const SizedBox(height: 8),
        _note(gc, 'Resting heart rate, bpm'),
        _trend(d.rhr, color: rDown ? gc.sage : gc.warn, height: 44, scale: (v) => v.round().toString()),
      ]),
    );
  });
}

Widget? _gSleep8(bool flat) {
  if (!fit.garminOn) return null;
  if (fit.garminSeries('sleep', 8).whereType<double>().length < 3) return null;
  final limit = fit.garminHistoryDays ~/ 8;
  return PastSwipe(
    limit: limit,
    builder: (context, back, go) {
      final gc = context.gc;
      final v = fit.garminSeries('sleep', 8, back: back);
      final have = v.whereType<double>().toList();
      final avg = have.isEmpty ? 0.0 : have.reduce((a, b) => a + b) / have.length / 60;
      return _Shell(
        flat: flat,
        title: 'Sleep, 8 nights',
        trailing: _pager(
          gc,
          back,
          limit,
          go,
          _side(gc, have.isEmpty ? (back == 0 ? 'no readings' : '${back * 8 + 1} to ${back * 8 + 8} nights ago') : 'average ${avg.toStringAsFixed(1)} h', color: avg > 0 && avg < 6.5 ? gc.warn : null),
        ),
        foot: _note(gc, have.isEmpty ? 'No sleep readings in these nights.' : 'The line is 7.5 hours.'),
        child: _MiniBars(
          values: [for (final x in v) (x ?? 0) / 60],
          goal: 7.5,
          height: 48,
          first: back == 0 ? '8 nights ago' : '${back * 8 + 8} nights ago',
          last: back == 0 ? 'Last night' : '${back * 8 + 1} nights ago',
        ),
      );
    },
  );
}

Widget? _gZ45(bool flat) {
  if (fit.zoneMinutesByWeek() == null) return null;
  final limit = fit.weeksOfHistory ~/ 8;
  return PastSwipe(
    limit: limit,
    builder: (context, back, go) {
      final gc = context.gc;
      final v = fit.zoneMinutesByWeek(back: back);
      return _Shell(
        flat: flat,
        title: 'Hard minutes a week',
        trailing: _pager(gc, back, limit, go, _side(gc, back == 0 && v != null ? 'this week ${v.last.round()} min' : '${back * 8 + 1} to ${back * 8 + 8} weeks ago')),
        foot: _note(gc, v == null ? 'No heart rate in these weeks.' : 'Minutes in zones 4 and 5, where the heart works hardest.'),
        child: v == null ? const SizedBox(height: 40) : _MiniBars(values: v, height: 40, first: '${back * 8 + 8} weeks ago', last: back == 0 ? 'This week' : '${back * 8 + 1} weeks ago'),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Minimal: the cards the main Stats had and Minimal did not

Widget? _mHeat(bool flat) => fit.sessions.isEmpty ? null : MinimalBodyMap(flat: flat);

Widget? _mRadar(bool flat) => fit.sessions.isEmpty ? null : MuscleRadarCard(flat: flat);

Widget? _mHealth(bool flat) => fit.healthShown.isEmpty ? null : HealthCard(flat: flat);

Widget? _mWeek(bool flat) {
  if (fit.sessions.isEmpty) return null;
  final limit = fit.weeksOfHistory;
  return PastSwipe(limit: limit, builder: (context, back, go) => _weekBars(context, flat, back, limit, go));
}

Widget _weekBars(BuildContext context, bool flat, int back, int limit, void Function(int) go) {
  final gc = context.gc;
  final start = shiftDays(fit.weekStartDate, -7 * back);
  final sets = List<int>.filled(7, 0);
  for (final s in fit.sessions) {
    final i = DateTime(s.day.year, s.day.month, s.day.day).difference(start).inDays;
    if (i >= 0 && i < 7) sets[i] += s.setCount;
  }
  final total = sets.fold(0, (a, b) => a + b);
  final top = sets.fold(0, math.max);
  final today = back == 0 ? fit.todayIndex : -1;
  return _Shell(
    flat: flat,
    title: _weekName(start, back),
    trailing: _pager(gc, back, limit, go, _side(gc, '$total sets')),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 64,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(sets[i] > 0 ? '${sets[i]}' : '', style: AppTheme.f(10.5, weight: FontWeight.w700, color: i == today ? gc.text : gc.textSecondary)),
                const SizedBox(height: 3),
                Container(
                  height: top == 0 ? 4 : 4 + 36 * sets[i] / top,
                  decoration: BoxDecoration(
                    color: sets[i] == 0 ? gc.bgRaised2 : (i == today ? gc.text : gc.text.withValues(alpha: 0.32)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 4),
      Row(children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Text(t.weekdayInitial(fit.weekdayAt(i)),
                textAlign: TextAlign.center,
                style: AppTheme.f(10.5, weight: i == today ? FontWeight.w700 : FontWeight.w500, color: i == today ? gc.text : gc.textTertiary)),
          ),
        ],
      ]),
    ]),
  );
}

Widget? _mEffect(bool flat) {
  if (fit.readinessRecent.rated <= 0) return null;
  final effect = fit.readinessEffect;
  final String headline;
  if (effect == null) {
    headline = t.readinessWaiting;
  } else if (effect.pct.abs() < 3) {
    headline = effect.sleep ? t.readinessSleepNone : t.readinessEnergyNone;
  } else if (effect.pct < 0) {
    headline = effect.sleep ? t.readinessSleepLess(-effect.pct) : t.readinessEnergyLess(-effect.pct);
  } else {
    headline = effect.sleep ? t.readinessSleepMore(effect.pct) : t.readinessEnergyMore(effect.pct);
  }
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Effect on your lifting',
      foot: _note(gc, effect == null ? t.readinessWaitingHint : t.readinessHint),
      child: Text(headline, style: AppTheme.f(13.5, weight: FontWeight.w700, color: gc.text, height: 1.3)),
    );
  });
}

Widget? _mTotals(bool flat) {
  if (fit.sessions.isEmpty) return null;
  final hours = fit.totalTime.inHours;
  final lifted = fit.liftedSpanOf(fit.totalVolumeKg);
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Streak and all-time',
      trailing: _side(gc, t.streakDays(fit.currentStreak)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _tiles(gc, [
          (label: 'Sessions', value: groupedInt(fit.totalSessions), note: null),
          (label: 'Sets', value: groupedInt(fit.totalSets), note: null),
        ]),
        const SizedBox(height: 10),
        _tiles(gc, [
          (label: 'Time', value: hours >= 1 ? '${groupedInt(hours)} ${t.unitHours}' : '${fit.totalTime.inMinutes} min', note: null),
          (label: 'Lifted', value: '${lifted.$1} ${lifted.$2}', note: null),
        ]),
      ]),
    );
  });
}

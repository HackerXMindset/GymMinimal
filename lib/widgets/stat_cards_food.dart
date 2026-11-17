part of 'stat_cards.dart';

// The food cards: the Minimal food tracker's own stats, and the few that put
// food next to training. All of them hide until there is a food log to read.

bool get _hasFood => fit.foodLog.isNotEmpty;

String _dayText(DateTime d) {
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day ? 'Today' : _dm(d);
}

String _energy(double kcal) => fit.miniShownValue('kcal', kcal);

Widget? _nWeek(bool flat) {
  if (!_hasFood) return null;
  final limit = fit.foodWeeksBack;
  return PastSwipe(
    limit: limit,
    builder: (context, back, go) {
      final gc = context.gc;
      final v = fit.foodWeek('kcal', back);
      final start = shiftDays(fit.weekStartDate, -7 * back);
      final logged = v.whereType<double>().toList();
      final avg = logged.isEmpty ? 0.0 : logged.reduce((a, b) => a + b) / logged.length;
      final goal = fit.miniTarget('kcal', DateTime.now());
      return _Shell(
        flat: flat,
        title: back == 0 ? 'Calories this week' : 'Calories · ${_weekName(start, back)}',
        trailing: _pager(gc, back, limit, go, _side(gc, logged.isEmpty ? 'nothing logged' : 'average ${_energy(avg)} ${fit.energyUnit}')),
        child: _MiniBars(
          values: [for (final x in v) fit.energyOf(x ?? 0).toDouble()],
          goal: goal == null ? null : fit.energyOf(goal).toDouble(),
          height: 48,
          first: _dm(start),
          last: _dm(start.add(const Duration(days: 6))),
        ),
      );
    },
  );
}

Widget? _nMacros(bool flat) {
  final s = fit.macroSplit;
  if (s == null) return null;
  final total = s.p + s.c + s.f;
  if (total <= 0) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final parts = [('Protein', s.p, gc.accent, 4), ('Carbs', s.c, gc.info, 4), ('Fat', s.f, gc.warn, 9)];
    return _Shell(
      flat: flat,
      title: 'Where the energy comes from',
      trailing: _side(gc, _dayText(s.day)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 8,
            child: Row(children: [
              for (final p in parts) Expanded(flex: math.max(1, (p.$2 / total * 1000).round()), child: ColoredBox(color: p.$3)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final p in parts) _tile(gc, p.$1, '${(p.$2 / total * 100).round()}%', note: '${(p.$2 / p.$4).round()} g'),
        ]),
      ]),
    );
  });
}

/// Daily energy or protein for 30 days as a chart that follows the chart style.
Widget? _nTrend(String k, bool flat) {
  if (!_hasFood) return null;
  final series = fit.foodSeries(k, 30);
  final today = DateTime.now();
  final values = <double>[];
  final labels = <String>[];
  for (var i = 0; i < series.length; i++) {
    final x = series[i];
    if (x == null) continue;
    values.add(k == 'kcal' ? fit.energyOf(x).toDouble() : x.roundToDouble());
    labels.add(_dm(DateTime(today.year, today.month, today.day - (series.length - 1 - i))));
  }
  if (values.length < 4) return null;
  final avg = values.reduce((a, b) => a + b) / values.length;
  final target = fit.miniTarget(k, today);
  var hit = 0;
  if (k == 'protein' && target != null) {
    for (final x in series) {
      if (x != null && x >= target * 0.9) hit++;
    }
  }
  return Builder(builder: (context) {
    final gc = context.gc;
    final unit = fit.miniUnit(k);
    return _Shell(
      flat: flat,
      title: k == 'kcal' ? 'Calories, 30 days' : 'Protein, 30 days',
      trailing: _side(gc, 'average ${avg.round()} $unit'),
      foot: _note(
        gc,
        k == 'kcal'
            ? (target == null ? '${values.length} days logged.' : 'Target ${_energy(target)} $unit. ${values.length} days logged.')
            : (target == null ? '${values.length} days logged.' : 'Reached the target on $hit of ${values.length} days.'),
      ),
      child: TrendChart(
        values: values,
        labels: labels,
        height: 84,
        color: k == 'kcal' ? gc.accent : null,
        scale: (v) => '${v.round()}',
      ),
    );
  });
}

Widget? _nHit(bool flat) {
  final d = fit.daysOnTarget(28);
  if (d == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Days on target',
      trailing: _side(gc, '${d.logged} days logged'),
      foot: _note(gc, 'Energy within 10% of the target, and protein at 90% or more. Last 28 days.'),
      child: _tiles(gc, [
        (label: 'Energy', value: '${d.kcalHit} of ${d.logged}', note: null),
        (label: 'Protein', value: '${d.proteinHit} of ${d.logged}', note: null),
        (label: 'Both', value: '${d.both} of ${d.logged}', note: null),
      ]),
    );
  });
}

Widget? _nMeals(bool flat) {
  final rows = fit.mealShare(14);
  final total = rows.fold(0.0, (a, r) => a + r.kcal);
  if (rows.isEmpty || total <= 0) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Calories by meal',
      trailing: _side(gc, '14 days'),
      child: Column(children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 84, child: _text(gc, mealName(r.meal))),
              Expanded(child: _HBar(value: r.kcal, max: total, color: gc.accent)),
              const SizedBox(width: 8),
              SizedBox(width: 36, child: Text('${(r.kcal / total * 100).round()}%', textAlign: TextAlign.right, style: AppTheme.f(11.5, weight: FontWeight.w700, color: gc.text))),
            ]),
          ),
      ]),
    );
  });
}

Widget? _nTimes(bool flat) {
  final h = fit.eatingHours(14);
  final total = h.fold(0.0, (a, b) => a + b);
  if (total <= 0) return null;
  var peak = 0;
  for (var i = 1; i < h.length; i++) {
    if (h[i] > h[peak]) peak = i;
  }
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'When you eat',
      trailing: _side(gc, 'most at ${peak * 2}:00 to ${peak * 2 + 2}:00'),
      foot: _note(gc, 'Energy in each two hour block over 14 days. Food added for an earlier day counts as noon.'),
      child: _MiniBars(values: h, height: 44, first: '0:00', last: '22:00'),
    );
  });
}

Widget? _nTop(bool flat) {
  final top = fit.topFoods(30);
  if (top.length < 2) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Most eaten foods',
      trailing: _side(gc, '30 days'),
      child: Column(children: [
        for (final f in top)
          _line(
            gc,
            _text(gc, f.name, strong: true),
            _text(gc, '${_energy(f.kcal)} ${fit.energyUnit} · ${f.times}×'),
          ),
      ]),
    );
  });
}

Widget? _nWater(bool flat) {
  final v = fit.foodSeries('water', 14);
  final have = v.whereType<double>().where((x) => x > 0).toList();
  if (have.length < 2) return null;
  final avg = have.reduce((a, b) => a + b) / have.length;
  final goal = fit.miniTarget('water', DateTime.now());
  return Builder(builder: (context) {
    final gc = context.gc;
    final today = DateTime.now();
    return _Shell(
      flat: flat,
      title: 'Water, 14 days',
      trailing: _side(gc, 'average ${fit.waterLabel(avg.round())}'),
      child: _MiniBars(
        values: [for (final x in v) x ?? 0.0],
        goal: goal,
        height: 44,
        first: _dm(DateTime(today.year, today.month, today.day - 13)),
        last: 'Today',
      ),
    );
  });
}

Widget? _nLift(bool flat) {
  final d = fit.liftDayFood(30);
  if (d == null) return null;
  final diff = d.proteinLift - d.proteinRest;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Lifting days and rest days',
      trailing: _side(gc, '${d.liftDays} and ${d.restDays} days'),
      foot: _note(
        gc,
        diff.abs() < 3
            ? 'You eat about the same protein on both.'
            : 'You eat ${diff.abs().round()} g ${diff > 0 ? 'more' : 'less'} protein on lifting days.',
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _tiles(gc, [
          (label: 'Protein, lifting', value: '${d.proteinLift.round()} g', note: null),
          (label: 'Protein, rest', value: '${d.proteinRest.round()} g', note: null),
        ]),
        const SizedBox(height: 10),
        _tiles(gc, [
          (label: 'Energy, lifting', value: '${_energy(d.kcalLift)} ${fit.energyUnit}', note: null),
          (label: 'Energy, rest', value: '${_energy(d.kcalRest)} ${fit.energyUnit}', note: null),
        ]),
      ]),
    );
  });
}

Widget? _nWeight(bool flat) {
  final rows = fit.foodVsWeight(8);
  if (rows == null) return null;
  final shown = rows.where((r) => r.kcal != null || r.kg != null).toList().reversed.take(6).toList();
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Calories and bodyweight',
      trailing: _side(gc, 'week by week'),
      foot: _note(gc, 'Average energy a day, and how the weight moved from the week before.'),
      child: Column(children: [
        for (final r in shown)
          _line(
            gc,
            _text(gc, _dm(r.start)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _text(gc, r.kcal == null ? '—' : '${_energy(r.kcal!)} ${fit.energyUnit}', strong: true),
              const SizedBox(width: 12),
              SizedBox(
                width: 64,
                child: Text(
                  r.change == null ? (r.kg == null ? '' : fit.weightLabel(r.kg!)) : '${r.change! >= 0 ? '+' : '−'}${fit.weightLabel(r.change!.abs())}',
                  textAlign: TextAlign.right,
                  style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.textSecondary),
                ),
              ),
            ]),
          ),
      ]),
    );
  });
}

Widget? _nBefore(bool flat) {
  final d = fit.eatBeforeLifting;
  if (d == null) return null;
  final pct = d.fastedLoad <= 0 ? 0.0 : (d.fedLoad - d.fastedLoad) / d.fastedLoad * 100;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Eating before you lift',
      trailing: _side(gc, pct.abs() < 1 ? 'no difference' : '${_signed(pct)} when fed'),
      foot: _note(gc, 'Average load per set. Fed means 30 g of carbs or more in the 3 hours before. A pattern in your own data, not proof.'),
      child: _tiles(gc, [
        (label: 'Fed', value: fit.weightLabel(d.fedLoad), note: '${d.fed} sessions'),
        (label: 'Fasted', value: fit.weightLabel(d.fastedLoad), note: '${d.fasted} sessions'),
        (label: 'Carbs before', value: '${d.carbs.round()} g', note: null),
      ]),
    );
  });
}

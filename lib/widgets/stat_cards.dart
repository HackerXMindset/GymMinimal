import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../screens/nutrition_screen.dart' show mealName;
import '../screens/progress_screen.dart' show MinimalBodyMap, showBodyweightSheet;
import '../screens/share_sheet.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'charts.dart';
import 'check_in.dart' show checkInWord;
import 'glass.dart';
import 'health_cards.dart' show HealthCard;
import 'muscle_radar.dart' show MuscleRadarCard;
import 'past_swipe.dart';
import 'ui_kit.dart';

part 'stat_cards_more.dart';
part 'stat_cards_food.dart';

/// The cards added to the Stats screens. Both the main Stats and the Minimal
/// Stats draw them from here, so each statistic exists once. [flat] is the
/// Minimal look: no raised card, just a heading and a hairline.
///
/// Every card hides itself when it has nothing to show, and every card has a
/// switch in Settings (see [kStatCards]).
class StatCards {
  const StatCards._();

  /// The cards of [group], already filtered by the Settings switches and by
  /// whether there is data. Empty when the whole group is off or empty.
  static List<Widget> group(String group, {required bool flat, Set<String> skip = const {}}) {
    final out = <Widget>[];
    for (final info in kStatCards) {
      if (info.group != group || !fit.statOn(info.id) || skip.contains(info.id)) continue;
      if (!fit.statGroupAvailable(info.group)) continue;
      final card = _build(info.id, flat);
      if (card != null) out.add(card);
    }
    return out;
  }

  /// One card by id, or null when it is switched off or has nothing to show.
  static Widget? one(String id, {required bool flat}) {
    if (!fit.statOn(id)) return null;
    final info = kStatCards.where((c) => c.id == id);
    if (info.isNotEmpty && !fit.statGroupAvailable(info.first.group)) return null;
    return _build(id, flat);
  }

  /// The five Garmin sections, each with its heading, or nothing while the
  /// Garmin switch is off. [head] makes the heading for a section.
  static List<Widget> garmin({required bool flat, required Widget Function(String label) head}) {
    if (!fit.garminOn) return const [];
    final out = <Widget>[];
    for (final g in kStatGroups) {
      if (!g.$1.startsWith('g_')) continue;
      final cards = group(g.$1, flat: flat);
      if (cards.isEmpty) continue;
      out.add(head(g.$2));
      out.addAll(cards);
    }
    return out;
  }

  /// The food sections, each with its heading, or nothing while the food
  /// tracker is off.
  static List<Widget> food({required bool flat, required Widget Function(String label) head}) {
    if (!fit.miniFoodOn) return const [];
    final out = <Widget>[];
    for (final g in kStatGroups) {
      if (!g.$1.startsWith('f_')) continue;
      final cards = group(g.$1, flat: flat);
      if (cards.isEmpty) continue;
      out.add(head(g.$2));
      out.addAll(cards);
    }
    return out;
  }

  /// The stacked weekly volume (push, pull, legs, core) with its legend, for a
  /// screen that already has its own frame. [back] steps whole windows back.
  static Widget? tonnageBars({required int weeks, int back = 0}) {
    final data = fit.tonnageByFamily(weeks, endBack: back * weeks);
    if (data.every((w) => w.kg.values.every((v) => v <= 0))) return null;
    const keys = ['push', 'pull', 'legs', 'core'];
    return Builder(builder: (context) {
      final gc = context.gc;
      final colors = [gc.accent, gc.sage, gc.info, gc.warn];
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _StackBars(
          bars: [for (final w in data) [for (final k in keys) w.kg[k] ?? 0]],
          colors: colors,
          height: 54,
          first: _dm(data.first.start),
          last: _dm(data.last.start),
        ),
        const SizedBox(height: 8),
        _legend(gc, [for (var i = 0; i < keys.length; i++) ('${keys[i][0].toUpperCase()}${keys[i].substring(1)}', colors[i])]),
      ]);
    });
  }

  /// Whether the card would show right now, ignoring its switch. Null for the
  /// cards of the exercise page, which depend on which exercise is open.
  static bool? hasData(String id) {
    final info = kStatCards.where((c) => c.id == id);
    if (info.isEmpty || info.first.group == 'exercise') return null;
    if (!fit.statGroupAvailable(info.first.group)) return null;
    return _build(id, true) != null;
  }

  /// The label of a section.
  static String groupLabel(String group) => kStatGroups.firstWhere((g) => g.$1 == group).$2;

  /// The cards of the exercise page for [id]. [standard] adds the rep-range
  /// bests that Minimal already shows by itself.
  static List<Widget> forExercise(String id, {required bool flat, bool standard = false}) {
    final out = <Widget>[];
    void add(String key, Widget? w) {
      if (fit.statOn(key) && w != null) out.add(w);
    }

    // The six stats of this kind of exercise first, then the ones every
    // exercise has. A stat that is in the first list is not drawn twice.
    final typed = kTypeStats[fit.exerciseType(id)] ?? const <String>[];
    for (final key in typed) {
      add(key, _typeCard(key, id, flat));
    }
    final type = fit.exerciseType(id);
    final loadedKind = type == ExType.loaded || type == ExType.weighted || type == ExType.band;
    add('x_trend', _xTrend(id, flat));
    add('x_prs', _xPrs(id, flat));
    if (standard && loadedKind) add('x_ranges', _xRanges(id, flat));
    add('x_effort', _xEffort(id, flat));
    add('x_rest', _xRest(id, flat));
    add('x_pace', _xPace(id, flat));
    return out;
  }

  static Widget? _build(String id, bool flat) => switch (id) {
        'score' => _score(flat),
        'trends' => _trends(flat),
        'stalled' => _stalled(flat),
        'prtime' => _prTime(flat),
        'zones' => _ZonesCard(flat: flat),
        'freq' => _freq(flat),
        'tonnage' => _tonnage(flat),
        'mostDone' => _mostDone(flat),
        'weeks' => _weeks(flat),
        'when' => _when(flat),
        'length' => _length(flat),
        'load' => _load(flat),
        'effort' => _effort(flat),
        'rest' => _rest(flat),
        'food' => _food(flat),
        'cardio' => _cardio(flat),
        'fourWeeks' => _fourWeeks(flat),
        'weekReport' => _WeekCard(flat: flat),
        'm_insights' => _mInsights(flat),
        'm_recovery' => _mRecovery(flat),
        'm_balance' => _mBalance(flat),
        'm_readiness' => _mReadiness(flat),
        'm_bodyweight' => _mBodyweight(flat),
        'm_measures' => _mMeasures(flat),
        'm_heat' => _mHeat(flat),
        'm_radar' => _mRadar(flat),
        'm_health' => _mHealth(flat),
        'm_week' => _mWeek(flat),
        'm_effect' => _mEffect(flat),
        'm_totals' => _mTotals(flat),
        'restReps' => _restReps(flat),
        'deload' => _deload(flat),
        'g_ready' => _gReady(flat),
        'g_rhr' => _gSeries(flat, key: 'restingHr', days: 12, title: 'Resting heart rate', unit: 'bpm', lowerBetter: true),
        'g_hrv' => _gSeries(flat, key: 'hrv', days: 14, title: 'HRV', unit: 'ms', lowerBetter: false),
        'g_sleeplift' => _gSleepLift(flat),
        'g_hrset' => _gHrSet(flat),
        'g_hrdrop' => _gHrDrop(flat),
        'g_zones' => _gZones(flat),
        'g_hrex' => _gHrEx(flat),
        'g_hrsame' => _gHrSame(flat),
        'g_watch' => _gWatch(flat),
        'g_energy' => _gEnergy(flat),
        'g_recover' => _gRecover(flat),
        'g_rhrnext' => _gRhrNext(flat),
        'g_hreffort' => _gHrEffort(flat),
        'g_burn' => _gBurn(flat),
        'g_calm' => _gCalm(flat),
        'g_sleep8' => _gSleep8(flat),
        'g_z45' => _gZ45(flat),
        'n_week' => _nWeek(flat),
        'n_macros' => _nMacros(flat),
        'n_trend' => _nTrend('kcal', flat),
        'n_protein' => _nTrend('protein', flat),
        'n_hit' => _nHit(flat),
        'n_meals' => _nMeals(flat),
        'n_times' => _nTimes(flat),
        'n_top' => _nTop(flat),
        'n_water' => _nWater(flat),
        'n_lift' => _nLift(flat),
        'n_weight' => _nWeight(flat),
        'n_before' => _nBefore(flat),
        _ => null,
      };
}

// ---------------------------------------------------------------------------
// Shared pieces

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _dm(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String _mmss(int sec) => '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

/// The name of the week that starts on [start], [back] weeks ago.
String _weekName(DateTime start, int back) {
  if (back == 0) return 'This week';
  if (back == 1) return 'Last week';
  return '${_dm(start)} – ${_dm(start.add(const Duration(days: 6)))}';
}

/// Arrows either side of [middle] that step back and forward through time.
Widget _pager(GymColors gc, int back, int limit, void Function(int) go, Widget middle) {
  Widget arrow(IconData icon, VoidCallback? onTap) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Icon(icon, size: 18, color: onTap == null ? gc.textTertiary.withValues(alpha: 0.3) : gc.textSecondary),
        ),
      );
  return Row(mainAxisSize: MainAxisSize.min, children: [
    arrow(Icons.chevron_left, back < limit ? () => go(1) : null),
    middle,
    arrow(Icons.chevron_right, back > 0 ? () => go(-1) : null),
  ]);
}

String _signed(num pct) => pct.round() == 0 ? '0%' : '${pct > 0 ? '+' : '−'}${pct.abs().round()}%';

/// The frame of one card.
class _Shell extends StatelessWidget {
  const _Shell({required this.flat, required this.title, required this.child, this.trailing, this.foot});

  final bool flat;
  final String title;
  final Widget child;
  final Widget? trailing;
  final Widget? foot;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final head = Row(children: [
      Expanded(
        child: Text(
          flat ? title : title.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: flat
              ? AppTheme.f(12.5, weight: FontWeight.w700, color: gc.text)
              : AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4),
        ),
      ),
      if (trailing != null) trailing!,
    ]);
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      head,
      SizedBox(height: flat ? 8 : 14),
      child,
      if (foot != null) ...[SizedBox(height: flat ? 8 : 12), foot!],
    ]);
    if (flat) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: gc.border))),
        child: body,
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(color: gc.bgRaised, borderRadius: BorderRadius.circular(22)),
      child: body,
    );
  }
}

Widget _note(GymColors gc, String text) =>
    Text(text, style: AppTheme.s(11.5, color: gc.textTertiary, height: 1.35));

Widget _side(GymColors gc, String text, {Color? color}) =>
    Text(text, style: AppTheme.f(11.5, weight: FontWeight.w600, color: color ?? gc.textSecondary));

Widget _big(GymColors gc, String value, {String? unit, double size = 28}) => Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value, style: AppTheme.f(size, weight: FontWeight.w800, color: gc.text, height: 1.05)),
        if (unit != null) ...[
          const SizedBox(width: 5),
          Text(unit, style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary)),
        ],
      ],
    );

Widget _tile(GymColors gc, String label, String value, {String? note, Color? noteColor}) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(10.5, weight: FontWeight.w500, color: gc.textSecondary)),
        const SizedBox(height: 3),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(17, weight: FontWeight.w700, color: gc.text, height: 1.05)),
        if (note != null) ...[
          const SizedBox(height: 2),
          Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(10.5, weight: FontWeight.w600, color: noteColor ?? gc.textTertiary)),
        ],
      ]),
    );

Widget _line(GymColors gc, Widget left, Widget right, {VoidCallback? onTap, bool last = false}) {
  final row = Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [Expanded(child: left), const SizedBox(width: 10), right]),
  );
  if (onTap == null) return row;
  return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
}

/// A row of bars. [goal] draws a line across them.
class _MiniBars extends StatelessWidget {
  const _MiniBars({required this.values, this.height = 54, this.goal, this.first, this.last});

  final List<double> values;
  final double height;
  final double? goal;
  final String? first;
  final String? last;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final top = math.max(values.fold(0.0, math.max), goal ?? 0.0);
    final scale = top <= 0 ? 1.0 : top;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: height,
        child: Stack(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: math.max(2.0, height * values[i] / scale),
                      decoration: BoxDecoration(
                        color: gc.accent.withValues(alpha: values[i] <= 0 ? 0.12 : (i == values.length - 1 ? 0.95 : 0.55)),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
          if (goal != null && goal! > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: (height * goal! / scale).clamp(0.0, height - 1),
              child: Container(height: 1, color: gc.textTertiary.withValues(alpha: 0.8)),
            ),
        ]),
      ),
      if (first != null || last != null) ...[
        const SizedBox(height: 5),
        Row(children: [
          Text(first ?? '', style: AppTheme.f(9.5, color: gc.textTertiary)),
          const Spacer(),
          Text(last ?? '', style: AppTheme.f(9.5, color: gc.textTertiary)),
        ]),
      ],
    ]);
  }
}

/// Bars made of stacked parts, one list of parts per bar.
class _StackBars extends StatelessWidget {
  const _StackBars({required this.bars, required this.colors, this.height = 60, this.first, this.last});

  final List<List<double>> bars;
  final List<Color> colors;
  final double height;
  final String? first;
  final String? last;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final totals = [for (final b in bars) b.fold(0.0, (a, v) => a + v)];
    final top = totals.fold(0.0, math.max);
    final scale = top <= 0 ? 1.0 : top;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: height,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < bars.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: totals[i] <= 0
                      ? Container(height: 2, color: gc.accent.withValues(alpha: 0.12))
                      : SizedBox(
                          height: math.max(2.0, height * totals[i] / scale),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                            child: Column(children: [
                              for (var p = bars[i].length - 1; p >= 0; p--)
                                if (bars[i][p] > 0)
                                  Expanded(
                                    flex: math.max(1, (bars[i][p] / totals[i] * 1000).round()),
                                    child: Container(color: colors[p % colors.length]),
                                  ),
                            ]),
                          ),
                        ),
                ),
              ),
            ),
        ]),
      ),
      if (first != null || last != null) ...[
        const SizedBox(height: 5),
        Row(children: [
          Text(first ?? '', style: AppTheme.f(9.5, color: gc.textTertiary)),
          const Spacer(),
          Text(last ?? '', style: AppTheme.f(9.5, color: gc.textTertiary)),
        ]),
      ],
    ]);
  }
}

Widget _legend(GymColors gc, List<(String, Color)> items) => Wrap(spacing: 12, runSpacing: 4, children: [
      for (final (label, color) in items)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 5),
          Text(label, style: AppTheme.f(10.5, weight: FontWeight.w500, color: gc.textSecondary)),
        ]),
    ]);

/// A thin bar, optionally with a shaded target band between [lo] and [hi].
class _HBar extends StatelessWidget {
  const _HBar({required this.value, required this.max, required this.color, this.lo, this.hi, this.height = 6});

  final double value;
  final double max;
  final Color color;
  final double? lo;
  final double? hi;
  final double height;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final m = max <= 0 ? 1.0 : max;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : 100.0;
      double at(double v) => (w * (v / m)).clamp(0.0, w).toDouble();
      return SizedBox(
        height: height,
        width: w,
        child: Stack(children: [
          Container(decoration: BoxDecoration(color: gc.bgRaised2, borderRadius: BorderRadius.circular(height))),
          if (lo != null && hi != null)
            Positioned(
              left: at(lo!),
              width: math.max(0.0, at(hi!) - at(lo!)),
              top: 0,
              bottom: 0,
              child: Container(color: gc.sage.withValues(alpha: 0.28)),
            ),
          Positioned(
            left: 0,
            width: at(value),
            top: 0,
            bottom: 0,
            child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height))),
          ),
        ]),
      );
    });
  }
}

/// A small sheet that explains how a number is worked out.
void _explain(BuildContext context, String title, String text) {
  final gc = context.gc;
  showAppSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheet) => Container(
      padding: sheetPad(sheet),
      decoration: sheetDecoration(gc),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SheetHandle(),
        const SizedBox(height: 16),
        SheetTitle(title),
        const SizedBox(height: 10),
        Text(text, style: AppTheme.s(13, color: gc.textSecondary, height: 1.45)),
      ]),
    ),
  );
}

Widget _info(BuildContext context, GymColors gc, String title, String text) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _explain(context, title, text),
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text('How this is worked out', style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.accent)),
      ),
    );

// ---------------------------------------------------------------------------
// Progress

Widget? _score(bool flat) {
  final s = fit.strengthScore;
  if (s == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Strength score',
      trailing: _side(gc, s.tier),
      foot: _info(
        context,
        gc,
        'Strength score',
        'Each main lift you have trained in the last 90 days gets a level from your estimated 1RM divided by your bodyweight, '
            'from Beginner to Elite. The score is the average of those levels on a 0 to 100 scale, and each muscle shows the '
            'average of its lifts. It needs a logged bodyweight and at least one of the main barbell lifts.',
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _big(gc, '${s.score}', unit: '/ 100'),
        const SizedBox(height: 12),
        for (final m in s.muscles.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 78, child: Text(muscleLabel(m.muscle), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.textSecondary))),
              Expanded(child: _HBar(value: m.score, max: 100, color: gc.accent)),
              SizedBox(width: 34, child: Text('${m.score.round()}', textAlign: TextAlign.end, style: AppTheme.f(11.5, weight: FontWeight.w700, color: gc.text))),
            ]),
          ),
      ]),
    );
  });
}

Widget? _trends(bool flat) {
  final list = fit.liftTrends();
  if (list.isEmpty) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Trend on every lift',
      trailing: _side(gc, '90 days'),
      child: Column(children: [
        for (final e in list)
          _line(
            gc,
            Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.text)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 64, child: Sparkline(values: e.values, height: 22, color: e.pct >= 0 ? gc.sage : gc.warn)),
              SizedBox(
                width: 48,
                child: Text(_signed(e.pct),
                    textAlign: TextAlign.end,
                    style: AppTheme.f(12, weight: FontWeight.w700, color: e.pct > 0.5 ? gc.sage : (e.pct < -0.5 ? gc.warn : gc.textSecondary))),
              ),
            ]),
            onTap: () => fit.openExercise(e.id),
          ),
      ]),
    );
  });
}

Widget? _stalled(bool flat) {
  final list = fit.stalledLifts;
  if (list.isEmpty) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Stalled lifts',
      trailing: _side(gc, '${list.length}', color: gc.warn),
      foot: _note(gc, 'No new best for 3 weeks or more while you kept training the lift.'),
      child: Column(children: [
        for (final e in list.take(5))
          _line(
            gc,
            Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.text)),
            _side(gc, 'flat ${e.weeks} weeks', color: gc.warn),
            onTap: () => fit.openExercise(e.id),
          ),
      ]),
    );
  });
}

Widget? _prTime(bool flat) {
  final events = fit.prEvents;
  if (events.isEmpty) return null;
  final weeks = fit.prsByWeek(12);
  final recent = weeks.skip(8).fold(0, (a, b) => a + b);
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'PR timeline',
      trailing: _side(gc, '$recent in 4 weeks'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _MiniBars(
          values: [for (final w in weeks) w.toDouble()],
          height: 44,
          first: '12 weeks ago',
          last: 'This week',
        ),
        const SizedBox(height: 10),
        _line(
          gc,
          Text('Latest: ${events.first.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(12, weight: FontWeight.w600, color: gc.text)),
          _side(gc, '${fit.weightLabel(events.first.kg)} · ${_dm(events.first.date)}'),
          onTap: () => fit.openExercise(events.first.id),
        ),
      ]),
    );
  });
}

// ---------------------------------------------------------------------------
// Muscles

Color _zoneColor(GymColors gc, String zone) => switch (zone) {
      'under' => gc.warn,
      'building' => gc.warn.withValues(alpha: 0.65),
      'best' => gc.sage,
      _ => gc.info,
    };

String _zoneName(String zone) => switch (zone) {
      'under' => 'Under',
      'building' => 'Building',
      'best' => 'Best',
      _ => 'Over',
    };

class _ZonesCard extends StatefulWidget {
  const _ZonesCard({required this.flat});
  final bool flat;

  @override
  State<_ZonesCard> createState() => _ZonesCardState();
}

class _ZonesCardState extends State<_ZonesCard> {
  bool _all = false;

  Future<void> _priority(String id) async {
    final gc = context.gc;
    await showAppSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Container(
        padding: sheetPad(sheet),
        decoration: sheetDecoration(gc),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHandle(),
          const SizedBox(height: 16),
          SheetTitle('${muscleLabel(id)} priority', subtitle: 'High moves the weekly target up by 20%, Low moves it down by 20%.'),
          const SizedBox(height: 14),
          OptionGroup([
            for (final (value, label, detail) in [
              (1, 'High', '12 to 24 sets a week'),
              (0, 'Normal', '10 to 20 sets a week'),
              (-1, 'Low', '8 to 16 sets a week'),
            ])
              OptionItem(label,
                  detail: detail,
                  selected: fit.priorityOf(id) == value,
                  onTap: () {
                    fit.setMusclePriority(id, value);
                    Navigator.pop(sheet);
                  }),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return AnimatedBuilder(
      animation: fit,
      builder: (context, _) {
        final raw = fit.muscleZones;
        if (raw.every((z) => z.perWeek <= 0)) return const SizedBox.shrink();
        const order = {'under': 0, 'building': 1, 'over': 2, 'best': 3};
        final zones = [...raw]
          ..sort((a, b) {
            final byZone = order[a.zone]!.compareTo(order[b.zone]!);
            return byZone != 0 ? byZone : a.perWeek.compareTo(b.perWeek);
          });
        final shown = _all ? zones : zones.take(6).toList();
        final top = math.max(zones.map((z) => z.hi * 1.35).reduce(math.max), zones.map((z) => z.perWeek).reduce(math.max));
        final fam = fit.familySets();
        String perWeek(String k) => (fam[k]! / 4).toStringAsFixed(fam[k]! / 4 >= 10 ? 0 : 1);
        return _Shell(
          flat: widget.flat,
          title: 'Muscle volume zones',
          trailing: _side(gc, 'sets a week'),
          foot: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _note(gc, 'Push ${perWeek('push')} · Pull ${perWeek('pull')} · Legs ${perWeek('legs')} · Core ${perWeek('core')} sets a week, last 4 weeks.'),
            const SizedBox(height: 4),
            _note(gc, 'The shaded band is the target. Press and hold a muscle to change its priority.'),
          ]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final z in shown)
              GestureDetector(
                key: ValueKey('zone-${z.id}'),
                behavior: HitTestBehavior.opaque,
                onLongPress: () => _priority(z.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          '${muscleLabel(z.id)}${fit.priorityOf(z.id) > 0 ? '  ↑' : (fit.priorityOf(z.id) < 0 ? '  ↓' : '')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.text),
                        ),
                      ),
                      Text('${z.perWeek.toStringAsFixed(1)} · ${_zoneName(z.zone)}',
                          style: AppTheme.f(11.5, weight: FontWeight.w600, color: _zoneColor(gc, z.zone))),
                    ]),
                    const SizedBox(height: 5),
                    _HBar(value: z.perWeek, max: top, lo: z.lo, hi: z.hi, color: _zoneColor(gc, z.zone)),
                    if (z.check != null) ...[
                      const SizedBox(height: 4),
                      Text(z.check!,
                          style: AppTheme.f(10.5,
                              weight: FontWeight.w600,
                              color: z.check == 'Productive' ? gc.sage : (z.check == 'Stagnating' ? gc.warn : gc.textTertiary))),
                    ],
                  ]),
                ),
              ),
            if (zones.length > 6)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _all = !_all),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_all ? 'Show fewer' : 'Show all ${zones.length}',
                      style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.accent)),
                ),
              ),
          ]),
        );
      },
    );
  }
}

Widget? _freq(bool flat) {
  final f = fit.muscleFrequency();
  if (f.isEmpty) return null;
  final list = f.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Training frequency',
      trailing: _side(gc, 'times a week'),
      foot: _note(gc, 'Sessions that train the muscle, averaged over 4 weeks. Two a week is a common target.'),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final e in list)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: gc.accent.withValues(alpha: (0.08 + e.value / 3 * 0.3).clamp(0.08, 0.4)),
              borderRadius: BorderRadius.circular(flat ? 4 : 10),
            ),
            child: Text('${muscleLabel(e.key)} ${e.value.toStringAsFixed(1)}×',
                style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.text)),
          ),
      ]),
    );
  });
}

Widget? _tonnage(bool flat) {
  final bars = StatCards.tonnageBars(weeks: 8);
  if (bars == null) return null;
  final last = fit.tonnageByFamily(8).last.kg.values.fold(0.0, (a, b) => a + b);
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Volume by day type',
      trailing: _side(gc, '${fit.volumeValue(last)} ${fit.volumeUnit} this week'),
      child: bars,
    );
  });
}

Widget? _mostDone(bool flat) {
  final list = fit.mostDone(5);
  if (list.length < 2) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Most-done exercises',
      child: Column(children: [
        for (final (i, e) in list.indexed)
          _line(
            gc,
            Row(children: [
              SizedBox(width: 20, child: Text('${i + 1}', style: AppTheme.f(12, weight: FontWeight.w700, color: gc.textTertiary))),
              Expanded(child: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.text))),
            ]),
            _side(gc, '${e.count} sessions · ${e.daysAgo == 0 ? 'today' : '${e.daysAgo}d ago'}'),
            onTap: () => fit.openExercise(e.id),
          ),
      ]),
    );
  });
}

// ---------------------------------------------------------------------------
// Consistency

Widget? _weeks(bool flat) {
  if (fit.sessions.isEmpty) return null;
  final goal = fit.weeklyTarget;
  final streak = fit.weekStreak;
  final limit = fit.weeksOfHistory ~/ 12;
  return PastSwipe(
    limit: limit,
    builder: (context, back, go) {
      final gc = context.gc;
      final counts = fit.sessionsPerWeek(12, back: back);
      return _Shell(
        flat: flat,
        title: 'Weeks',
        trailing: _pager(gc, back, limit, go, _side(gc, 'Goal $goal a week')),
        foot: _note(gc, back == 0 ? 'Training days in each of the last 12 weeks. The line is your weekly goal.' : 'Training days in the 12 weeks ending ${back * 12} weeks ago.'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _big(gc, '$streak', unit: streak == 1 ? 'week in a row' : 'weeks in a row'),
            const Spacer(),
            if (back == 0) _side(gc, '${counts.last} of $goal this week'),
          ]),
          const SizedBox(height: 12),
          _MiniBars(values: [for (final c in counts) c.toDouble()], goal: goal.toDouble(), height: 48),
        ]),
      );
    },
  );
}

Widget? _when(bool flat) {
  final grid = fit.trainingTimes();
  final total = grid.fold(0, (a, row) => a + row.fold(0, (b, v) => b + v));
  if (total < 5) return null;
  const cols = ['Morning', 'Midday', 'Evening', 'Night'];
  const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  var best = 0, bestRow = 0, bestCol = 0;
  for (var r = 0; r < 7; r++) {
    for (var c = 0; c < 4; c++) {
      if (grid[r][c] > best) {
        best = grid[r][c];
        bestRow = r;
        bestCol = c;
      }
    }
  }
  final bestDay = names[fit.weekdayAt(bestRow) - 1];
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'When you train',
      trailing: _side(gc, 'last 12 weeks'),
      foot: _note(gc, 'Most sessions: $bestDay ${cols[bestCol].toLowerCase()}.'),
      child: Column(children: [
        Row(children: [
          const SizedBox(width: 22),
          for (final c in cols)
            Expanded(child: Center(child: Text(c, style: AppTheme.f(9.5, weight: FontWeight.w600, color: gc.textTertiary)))),
        ]),
        const SizedBox(height: 4),
        for (var r = 0; r < 7; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(children: [
              SizedBox(width: 22, child: Text(letters[fit.weekdayAt(r) - 1], style: AppTheme.f(10.5, weight: FontWeight.w600, color: gc.textTertiary))),
              for (var c = 0; c < 4; c++)
                Expanded(
                  child: Container(
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: grid[r][c] == 0 ? gc.bgRaised2.withValues(alpha: 0.6) : gc.accent.withValues(alpha: (0.25 + 0.75 * grid[r][c] / best).clamp(0.25, 1.0)),
                      borderRadius: BorderRadius.circular(flat ? 2 : 4),
                    ),
                  ),
                ),
            ]),
          ),
      ]),
    );
  });
}

Widget? _length(bool flat) {
  final mins = fit.sessionMinutes(12);
  if (mins.length < 3) return null;
  final avg = (mins.reduce((a, b) => a + b) / mins.length).round();
  final gap = fit.longestGap;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Session length',
      trailing: _side(gc, 'average $avg min'),
      foot: gap == null ? null : _note(gc, 'Longest break between training days: ${gap.days} days, ended ${_dm(gap.ended)}.'),
      child: _MiniBars(values: [for (final m in mins) m.toDouble()], height: 44, first: 'Older', last: 'Latest ${mins.last} min'),
    );
  });
}

// ---------------------------------------------------------------------------
// Load and recovery

Widget? _load(bool flat) {
  final ready = fit.readiness;
  final alerts = fit.loadAlerts;
  if (ready == null && alerts.isEmpty) return null;
  final load = fit.trainingLoad;
  return Builder(builder: (context) {
    final gc = context.gc;
    final ratio = load.ratio;
    Widget meter(String label, int value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 70, child: Text(label, style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.textSecondary))),
            Expanded(child: _HBar(value: value.toDouble(), max: 100, color: value >= 70 ? gc.sage : (value >= 50 ? gc.warn : gc.danger))),
            SizedBox(width: 30, child: Text('$value', textAlign: TextAlign.end, style: AppTheme.f(11.5, weight: FontWeight.w700, color: gc.text))),
          ]),
        );
    return _Shell(
      flat: flat,
      title: 'Training load and readiness',
      trailing: ratio == null ? null : _side(gc, '${ratio.toStringAsFixed(2)}× usual'),
      foot: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!load.rated) _note(gc, 'Every set counts as normal effort. Log RPE or RIR on your sets for a sharper read.'),
        _info(
          context,
          gc,
          'Load and readiness',
          'Load is session minutes multiplied by how hard the sets were (RPE or RIR when you log it, otherwise normal effort). '
              'The ratio compares this week with your average week over the last 4. Between 0.8 and 1.3 is the usual safe band. '
              'Readiness mixes three things: load balance (40%), how recovered your muscles are (40%), and this week\'s volume against your usual (20%).',
        ),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (ready != null) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _big(gc, '${ready.score}', unit: '/ 100 ready'),
          ]),
          const SizedBox(height: 10),
          meter('Load balance', ready.balance),
          meter('Recovery', ready.recovery),
          meter('Volume', ready.volume),
        ],
        if (ratio != null) ...[
          const SizedBox(height: 10),
          _HBar(value: ratio.clamp(0.0, 2.0).toDouble(), max: 2, lo: 0.8, hi: 1.3, color: ratio >= 0.8 && ratio <= 1.3 ? gc.sage : gc.warn),
          const SizedBox(height: 4),
          Text(
            ratio < 0.8 ? 'Below your usual load' : (ratio <= 1.3 ? 'In your usual range' : 'Above your usual load'),
            style: AppTheme.f(10.5, weight: FontWeight.w600, color: ratio >= 0.8 && ratio <= 1.3 ? gc.sage : gc.warn),
          ),
        ],
        for (final a in alerts)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(margin: const EdgeInsets.only(top: 5), width: 6, height: 6, decoration: BoxDecoration(color: gc.warn, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(a.text, style: AppTheme.s(12.5, color: gc.text, height: 1.35))),
            ]),
          ),
      ]),
    );
  });
}

Widget _effortBody(BuildContext context, ({int hard, int good, int easy, int total}) e) {
  final gc = context.gc;
  final hard = e.hard / e.total, good = e.good / e.total, easy = e.easy / e.total;
  Widget seg(double v, Color c) => v <= 0 ? const SizedBox.shrink() : Expanded(flex: math.max(1, (v * 1000).round()), child: Container(height: 10, color: c));
  final verdict = hard > 0.5
      ? 'Most sets are close to failure. That is hard to recover from.'
      : (easy > 0.5 ? 'Many sets have room to spare. You could add weight or reps.' : 'Mostly in the productive zone.');
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Row(children: [seg(easy, gc.info), seg(good, gc.sage), seg(hard, gc.warn)]),
    ),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: _side(gc, 'Easy ${(easy * 100).round()}%', color: gc.info)),
      Expanded(child: Center(child: _side(gc, 'Good ${(good * 100).round()}%', color: gc.sage))),
      Expanded(child: Align(alignment: Alignment.centerRight, child: _side(gc, 'Hard ${(hard * 100).round()}%', color: gc.warn))),
    ]),
    const SizedBox(height: 8),
    _note(gc, verdict),
  ]);
}

Widget? _effort(bool flat) {
  final e = fit.effortSpread();
  if (e == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Effort check',
      trailing: _side(gc, '${e.total} sets · 4 weeks'),
      foot: _note(gc, 'Easy is 4 or more reps left, good is 2 to 3, hard is 0 to 1.'),
      child: _effortBody(context, e),
    );
  });
}

Widget? _rest(bool flat) {
  final r = fit.restStats();
  if (r == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Rest between sets',
      trailing: _side(gc, '${r.sessions} sessions'),
      foot: _note(gc, 'Measured from when you tick one set to the next on the same exercise, in sessions logged live.'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _big(gc, _mmss(r.avg), unit: 'average'),
        if (r.series.length >= 2) ...[
          const SizedBox(height: 10),
          _MiniBars(values: [for (final s in r.series) s.toDouble()], height: 36),
        ],
      ]),
    );
  });
}

// ---------------------------------------------------------------------------
// Body, cardio and food

Widget? _food(bool flat) {
  final f = fit.foodByDayType();
  if (f == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    String diff(double a, double b) => b <= 0 ? '' : _signed((a - b) / b * 100);
    return _Shell(
      flat: flat,
      title: 'Food on training and rest days',
      trailing: _side(gc, '30 days'),
      foot: _note(gc, '${f.trainDays} training days and ${f.restDays} rest days with food logged.'),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _tile(gc, 'Training day', '${f.trainKcal.round()} kcal', note: '${f.trainProtein.round()} g protein'),
        _tile(gc, 'Rest day', '${f.restKcal.round()} kcal', note: '${f.restProtein.round()} g protein'),
        _tile(gc, 'Difference', diff(f.trainKcal, f.restKcal), note: 'kcal on training days'),
      ]),
    );
  });
}

Widget? _cardio(bool flat) {
  if (!fit.hasCardioLogged) return null;
  final weeks = fit.cardioWeekly(8);
  return Builder(builder: (context) {
    final gc = context.gc;
    final now = weeks.last;
    return _Shell(
      flat: flat,
      title: 'Lifting and cardio',
      trailing: _side(gc, 'minutes a week'),
      foot: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _legend(gc, [('Lifting', gc.accent), ('Cardio', gc.sage)]),
        const SizedBox(height: 6),
        _note(gc, 'This week: ${now.liftMin} min lifting, ${now.cardioMin} min cardio${now.km > 0 ? ', ${now.km.toStringAsFixed(1)} km' : ''}.'),
      ]),
      child: _StackBars(
        bars: [for (final w in weeks) [w.liftMin.toDouble(), w.cardioMin.toDouble()]],
        colors: [gc.accent, gc.sage],
        first: _dm(weeks.first.start),
        last: 'This week',
      ),
    );
  });
}

// ---------------------------------------------------------------------------
// Summaries

Widget? _fourWeeks(bool flat) {
  final now = fit.fourWeeks(0);
  final before = fit.fourWeeks(1);
  if (now.sessions == 0 && before.sessions == 0) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    String? delta(num a, num b) => b <= 0 ? null : _signed((a - b) / b * 100);
    Color? tone(num a, num b) => b <= 0 ? null : (a > b ? gc.sage : null);
    Widget tile(String label, String value, num a, num b) =>
        _tile(gc, label, value, note: delta(a, b), noteColor: tone(a, b));
    return _Shell(
      flat: flat,
      title: 'This 4 weeks vs the last 4',
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          tile('Sessions', '${now.sessions}', now.sessions, before.sessions),
          tile('Volume', '${fit.volumeValue(now.volume)} ${fit.volumeUnit}', now.volume, before.volume),
          tile('Sets', '${now.sets}', now.sets, before.sets),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          tile('Session', '${now.avgMin} min', now.avgMin, before.avgMin),
          tile('Records', '${now.prs}', now.prs, before.prs),
          const Expanded(child: SizedBox.shrink()),
        ]),
      ]),
    );
  });
}

/// The weekly report card. A widget of its own so it can listen to [fit].
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.flat});
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return AnimatedBuilder(
      animation: fit,
      builder: (context, _) {
        if (fit.sessions.isEmpty) return const SizedBox.shrink();
        final limit = fit.weeksOfHistory;
        return PastSwipe(
          limit: limit,
          builder: (context, back, go) {
            final r = fit.weekReportFor(back);
            final start = shiftDays(fit.weekStartDate, -7 * back);
            String? delta(num a, num b) => b <= 0 ? null : _signed((a - b) / b * 100);
            return _Shell(
              flat: flat,
              title: back == 0 ? 'Weekly report card' : _weekName(start, back),
              trailing: _pager(
                gc,
                back,
                limit,
                go,
                back == 0
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => showShareSheet(context),
                        child: Text('Share', style: AppTheme.f(12, weight: FontWeight.w700, color: gc.accent)),
                      )
                    : const SizedBox.shrink(),
              ),
              foot: r.muscles.isEmpty ? null : _note(gc, 'Most trained: ${r.muscles.join(', ')}.'),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _tile(gc, 'Sessions', '${r.sessions}', note: delta(r.sessions, r.lastSessions)),
                _tile(gc, 'Volume', '${fit.volumeValue(r.volume)} ${fit.volumeUnit}', note: delta(r.volume, r.lastVolume)),
                _tile(gc, 'Records', '${r.prs}'),
                _tile(gc, 'Session', r.avgMin == 0 ? '—' : '${r.avgMin} min'),
              ]),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// On each exercise

Widget? _xLevel(String id, bool flat) {
  final rel = fit.relativeStrength(id);
  if (rel == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Strength level',
      trailing: _side(gc, '${rel.ratio.toStringAsFixed(2)}× bodyweight'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _big(gc, t.dotsLevelName(rel.level), size: 20),
        const SizedBox(height: 10),
        Row(children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: _HBar(value: i < rel.level ? 1 : (i == rel.level ? rel.toNext : 0), max: 1, color: gc.brass, height: 4),
            ),
          ],
        ]),
      ]),
    );
  });
}

Widget? _xVolume(String id, bool flat) {
  final weeks = fit.exerciseWeeklySets(id, 8);
  if (weeks.where((w) => w > 0).length < 2) return null;
  final freq = fit.exerciseFrequency(id);
  final avg = weeks.fold(0, (a, b) => a + b) / 8;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Sets and frequency',
      trailing: _side(gc, '${freq.toStringAsFixed(1)}× a week'),
      foot: _note(gc, 'Working sets per week over 8 weeks, about ${avg.toStringAsFixed(avg >= 10 ? 0 : 1)} a week.'),
      child: _MiniBars(values: [for (final w in weeks) w.toDouble()], height: 40, first: '8 weeks ago', last: 'This week'),
    );
  });
}

Widget? _xTrend(String id, bool flat) {
  if (!fit.goalFits(id)) return null;
  final points = fit.exerciseTrend(id, days: 90);
  final weeks = fit.stalledWeeks(id);
  if (points.length < 2 && weeks == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final first = points.isEmpty ? 0.0 : points.first.value;
    final pct = points.length < 2 || first <= 0 ? null : (points.last.value - first) / first * 100;
    return _Shell(
      flat: flat,
      title: 'Trend',
      trailing: _side(gc, '90 days'),
      child: Row(children: [
        if (pct != null) _big(gc, _signed(pct), size: 22),
        const Spacer(),
        if (weeks != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: gc.warn.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(flat ? 4 : 10)),
            child: Text('Stalled · flat ${weeks}w', style: AppTheme.f(11.5, weight: FontWeight.w700, color: gc.warn)),
          )
        else if (pct != null)
          _side(gc, pct > 0.5 ? 'Moving up' : (pct < -0.5 ? 'Moving down' : 'Holding steady')),
      ]),
    );
  });
}

Widget? _xPrs(String id, bool flat) {
  final list = fit.exercisePrs(id);
  if (list.isEmpty) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'PR history',
      trailing: _side(gc, '${list.length} records'),
      child: Column(children: [
        for (final e in list.take(5))
          _line(gc, Text(_dm(e.date), style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.text)), _side(gc, '${fit.weightLabel(e.kg)} est. 1RM')),
      ]),
    );
  });
}

Widget? _xRanges(String id, bool flat) {
  if (!fit.goalFits(id) || fit.isRepsOnly(id)) return null;
  final list = fit.repRecords(id);
  if (list.length < 2) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Best weight by rep range',
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final r in list.take(12))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(color: gc.bgRaised2, borderRadius: BorderRadius.circular(flat ? 4 : 10)),
            child: Text('${r.reps} × ${fit.weightLabel(r.kg)}', style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.text)),
          ),
      ]),
    );
  });
}

Widget? _xEffort(String id, bool flat) {
  final e = fit.effortSpread(id: id, days: 90);
  if (e == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Effort on this lift',
      trailing: _side(gc, '${e.total} sets · 90 days'),
      child: _effortBody(context, e),
    );
  });
}

Widget? _xRest(String id, bool flat) {
  final r = fit.restStats(id: id);
  if (r == null) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Rest on this lift',
      trailing: _side(gc, 'average ${_mmss(r.avg)}'),
      child: r.series.length >= 2
          ? _MiniBars(values: [for (final s in r.series) s.toDouble()], height: 34)
          : _note(gc, 'Measured from tick to tick, in sessions logged live.'),
    );
  });
}

Widget? _xPace(String id, bool flat) {
  if (!fit.loggedDistanceAny(id)) return null;
  final series = fit.paceSeries(id);
  if (series.isEmpty) return null;
  final rowing = fit.paceIsRowing(id);
  final best = series.reduce(math.min);
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: rowing ? 'Pace per 500 m' : 'Pace per km',
      trailing: _side(gc, 'best ${fit.paceText(best)}'),
      foot: _note(gc, 'Best set of each session. Lower is faster.'),
      child: series.length >= 2
          ? TrendChart(values: series, height: 70, color: gc.accent, scale: (v) => fit.paceText(v))
          : _big(gc, fit.paceText(series.first), size: 22),
    );
  });
}

// ---------------------------------------------------------------------------
// Minimal only: what the main Stats already shows, as flat sections

Widget? _mInsights(bool flat) {
  if (fit.sessions.isEmpty) return null;
  final notes = fit.weekInsights;
  if (notes.isEmpty) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Insights',
      child: Column(children: [
        for (final n in notes.take(3))
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: n.exerciseId == null ? null : () => fit.openExercise(n.exerciseId!),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(n.text, style: AppTheme.s(12.5, color: gc.text, height: 1.4)),
            ),
          ),
      ]),
    );
  });
}

Widget? _mRecovery(bool flat) {
  if (fit.sessions.isEmpty) return null;
  final rec = fit.muscleRecovery();
  final tired = rec.entries.where((e) => e.value < 0.95).toList()..sort((a, b) => a.value.compareTo(b.value));
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Recovery by muscle',
      trailing: _side(gc, '${fit.overallRecovery()}% recovered'),
      child: tired.isEmpty
          ? _note(gc, 'All muscles are recovered.')
          : Column(children: [
              for (final e in tired.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    SizedBox(width: 78, child: Text(muscleLabel(e.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.textSecondary))),
                    Expanded(child: _HBar(value: e.value * 100, max: 100, color: e.value < 0.5 ? gc.warn : gc.sage)),
                    SizedBox(
                      width: 56,
                      child: Text(
                        () {
                          final h = fit.hoursUntilRecovered(e.key);
                          return h == null ? 'ready' : (h >= 24 ? '${(h / 24).ceil()}d' : '${h}h');
                        }(),
                        textAlign: TextAlign.end,
                        style: AppTheme.f(11.5, weight: FontWeight.w700, color: gc.text),
                      ),
                    ),
                  ]),
                ),
            ]),
    );
  });
}

Widget? _mBalance(bool flat) {
  final data = fit.structuralBalance;
  if (data == null || data.lifts.length < 2) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return _Shell(
      flat: flat,
      title: 'Lift balance',
      foot: _note(gc, '100% means that lift matches the others. The shaded band is even.'),
      child: Column(children: [
        for (final l in data.lifts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 110, child: Text(t.catalogName(l.id, fit.exerciseById(l.id)?.name ?? l.id), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(11.5, weight: FontWeight.w600, color: l.id == data.behind ? gc.warn : gc.textSecondary))),
              Expanded(child: _HBar(value: l.score.clamp(0.0, 1.4).toDouble(), max: 1.4, lo: 0.95, hi: 1.05, color: l.id == data.behind ? gc.warn : gc.accent)),
              SizedBox(width: 40, child: Text('${(l.score * 100).round()}%', textAlign: TextAlign.end, style: AppTheme.f(11.5, weight: FontWeight.w700, color: gc.text))),
            ]),
          ),
      ]),
    );
  });
}

Widget? _mReadiness(bool flat) {
  final r = fit.readinessRecent;
  if (r.rated <= 0) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    Widget one(String label, double? v) => _tile(gc, label, v == null ? '–' : checkInWord(v.round()));
    return _Shell(
      flat: flat,
      title: 'Sleep and energy',
      trailing: _side(gc, 'last 30 days'),
      child: Row(children: [one('Sleep', r.sleep), one('Energy', r.energy)]),
    );
  });
}

Widget? _mBodyweight(bool flat) {
  final series = fit.bodyweightSeries;
  if (series.length < 2) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    final change = series.last - series.first;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showBodyweightSheet(context),
      child: _Shell(
        flat: flat,
        title: 'Bodyweight',
        trailing: _side(gc, '${change > 0 ? '+' : (change < 0 ? '−' : '')}${fit.weightLabel(change.abs())}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _big(gc, fit.weightLabel(series.last), size: 20),
          const SizedBox(height: 8),
          TrendChart(values: series, height: 60, scale: (v) => fit.weightLabel(v)),
        ]),
      ),
    );
  });
}

Widget? _mMeasures(bool flat) {
  final keys = fit.trackedMeasures;
  if (keys.isEmpty) return null;
  return Builder(builder: (context) {
    final gc = context.gc;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: fit.goMeasures,
      child: _Shell(
        flat: flat,
        title: 'Measurements',
        child: Column(children: [
          for (final k in keys.take(6))
            _line(
              gc,
              Text(fit.measureTitle(k), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.text)),
              _side(gc, fit.measureLabel(k, fit.latestMeasure(k)!.value)),
            ),
        ]),
      ),
    );
  });
}

// ---------------------------------------------------------------------------
// Settings

/// One switch for every card on the Stats screens and the exercise pages,
/// the Garmin switch with its settings, and two presets.
Future<void> showStatCardsSheet(BuildContext context) {
  final open = <String>{};
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setOpen) => AnimatedBuilder(
        animation: fit,
        builder: (context, _) {
          final gc = context.gc;
          Widget action(String label, VoidCallback onTap, {Color? color, Key? key}) => GestureDetector(
                key: key,
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                  child: Text(label, style: AppTheme.f(12.5, weight: FontWeight.w700, color: color ?? gc.accent)),
                ),
              );
          Widget stepper(String label, String value, VoidCallback less, VoidCallback more) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(label, style: AppTheme.f(13, weight: FontWeight.w600, color: gc.text))),
                  GestureDetector(onTap: less, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.remove, size: 18, color: gc.textSecondary))),
                  SizedBox(width: 62, child: Text(value, textAlign: TextAlign.center, style: AppTheme.f(13, weight: FontWeight.w700, color: gc.text))),
                  GestureDetector(onTap: more, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.add, size: 18, color: gc.textSecondary))),
                ]),
              );
          final synced = fit.garminSynced;
          final ago = synced == null
              ? 'not read yet'
              : (DateTime.now().difference(synced).inMinutes < 2 ? 'just now' : (DateTime.now().difference(synced).inHours < 1 ? '${DateTime.now().difference(synced).inMinutes} min ago' : '${DateTime.now().difference(synced).inHours} h ago'));
          return AppSheet(children: [
            const SheetTitle('Stats cards', subtitle: 'Every card is on by default. A card with nothing to show stays hidden anyway.'),
            const SizedBox(height: 8),
            Row(children: [
              action('Essentials only', () => fit.applyStatPreset(essentials: true), key: const ValueKey('stats-preset-essentials')),
              const SizedBox(width: 14),
              action('All on', () => fit.applyStatPreset(essentials: false), key: const ValueKey('stats-preset-all')),
            ]),
            Divider(height: 18, color: gc.border),
            InkWell(
              key: const ValueKey('garmin-master'),
              onTap: () => fit.setGarminOn(!fit.garminOn),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Garmin data', style: AppTheme.f(14, weight: FontWeight.w700, color: gc.text)),
                      const SizedBox(height: 2),
                      Text('Adds heart rate, sleep and recovery cards from your watch. Off, nothing from Garmin is asked for, read or shown.',
                          style: AppTheme.s(11, color: gc.textSecondary, height: 1.3)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  TinySwitch(on: fit.garminOn),
                ]),
              ),
            ),
            if (fit.garminOn) ...[
              const SizedBox(height: 4),
              Text(fit.garminNote.isNotEmpty ? fit.garminNote : 'Health Connect: read $ago.', style: AppTheme.s(11.5, color: gc.textTertiary, height: 1.35)),
              Row(children: [
                action('Allow Health Connect', () => fit.askGarminPermissions()),
                const SizedBox(width: 14),
                action('Import FIT file', () async {
                  final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
                  final bytes = res == null || res.files.isEmpty ? null : res.files.first.bytes;
                  if (bytes != null) fit.importFit(bytes);
                }, key: const ValueKey('garmin-import')),
              ]),
              stepper(
                'Max heart rate',
                fit.maxHrAuto ? 'auto ${fit.maxHr}' : '${fit.maxHr}',
                () => fit.setMaxHr(fit.maxHr - 1),
                () => fit.setMaxHr(fit.maxHr + 1),
              ),
              if (!fit.maxHrAuto) Align(alignment: Alignment.centerRight, child: action('Back to auto', () => fit.setMaxHr(0))),
              action('Delete Garmin data', () => fit.clearGarmin(), color: gc.danger),
            ],
            Divider(height: 18, color: gc.border),
            stepper('Ready for more: reps', '${fit.readyReps}', () => fit.setReadyReps(fit.readyReps - 1), () => fit.setReadyReps(fit.readyReps + 1)),
            stepper('Ready for more: hold', '${fit.readySeconds} s', () => fit.setReadySeconds(fit.readySeconds - 5), () => fit.setReadySeconds(fit.readySeconds + 5)),
            for (final (group, label) in kStatGroups)
              if (fit.statGroupAvailable(group)) ...[
                Builder(builder: (context) {
                  final cards = kStatCards.where((c) => c.group == group).toList();
                  final on = cards.where((c) => fit.statOn(c.id)).length;
                  final isOpen = open.contains(group);
                  return InkWell(
                    key: ValueKey('stat-group-$group'),
                    onTap: () => setOpen(() => isOpen ? open.remove(group) : open.add(group)),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 6),
                      child: Row(children: [
                        Expanded(
                          child: Text(label.toUpperCase(),
                              style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4)),
                        ),
                        Text('$on of ${cards.length}', style: AppTheme.f(11, weight: FontWeight.w600, color: gc.textTertiary)),
                        const SizedBox(width: 6),
                        Icon(isOpen ? Icons.expand_less : Icons.expand_more, size: 18, color: gc.textTertiary),
                      ]),
                    ),
                  );
                }),
                if (open.contains(group))
                  for (final info in kStatCards.where((c) => c.group == group))
                    InkWell(
                      key: ValueKey('stat-card-${info.id}'),
                      onTap: () => fit.setStatOn(info.id, !fit.statOn(info.id)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(info.title, style: AppTheme.f(13, weight: FontWeight.w600, color: gc.text)),
                              const SizedBox(height: 2),
                              Text(info.hint, style: AppTheme.s(11, color: gc.textSecondary, height: 1.3)),
                              if (fit.statOn(info.id) && group != 'exercise' && StatCards.hasData(info.id) == false)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text('No data yet, so it is hidden', style: AppTheme.f(10.5, weight: FontWeight.w600, color: gc.warn)),
                                ),
                            ]),
                          ),
                          const SizedBox(width: 12),
                          TinySwitch(on: fit.statOn(info.id)),
                        ]),
                      ),
                    ),
              ],
          ]);
        },
      ),
    ),
  );
}

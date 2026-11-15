import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/workout.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/minimal_palette.dart';
import 'glass.dart';

/// Month calendar of the Minimal view. Days you trained are filled. Tap a day
/// to see the muscles and exercises of that day, and to add a workout on it.
/// It is used on Today and above the History list.
class MinimalCalendar extends StatefulWidget {
  const MinimalCalendar({super.key});

  @override
  State<MinimalCalendar> createState() => _MinimalCalendarState();
}

int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class _MinimalCalendarState extends State<MinimalCalendar> {
  late DateTime _month;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  List<LoggedSession> _sessionsOn(DateTime day) {
    final k = _key(day);
    return [for (final s in fit.sessions) if (_key(s.day) == k) s]
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  void _shift(int months) {
    setState(() {
      _month = DateTime(_month.year, _month.month + months);
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gc = minimalColors(context.gc);
    return ListenableBuilder(
      listenable: fit,
      builder: (context, _) {
        final trained = <int>{for (final s in fit.sessions) _key(s.day)};
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _header(gc),
          const SizedBox(height: 8),
          _weekdays(gc),
          const SizedBox(height: 3),
          ..._weeks(gc, trained),
          if (_selected != null) _detail(context, gc, _selected!),
        ]);
      },
    );
  }

  Widget _arrow(GymColors gc, String label, IconData icon, VoidCallback? onTap) => Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Icon(icon, size: 18, color: onTap == null ? gc.textTertiary.withValues(alpha: 0.4) : gc.textSecondary),
          ),
        ),
      );

  Widget _header(GymColors gc) => Row(children: [
        Expanded(
          child: Text(t.monthYear(_month),
              style: AppTheme.f(13, weight: FontWeight.w700, color: gc.text)),
        ),
        if (!_isCurrentMonth)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final now = DateTime.now();
              setState(() {
                _month = DateTime(now.year, now.month);
                _selected = null;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text('Today', style: AppTheme.f(11, weight: FontWeight.w700, color: gc.accent)),
            ),
          ),
        _arrow(gc, 'Previous month', Icons.chevron_left_rounded, () => _shift(-1)),
        _arrow(gc, 'Next month', Icons.chevron_right_rounded, _isCurrentMonth ? null : () => _shift(1)),
      ]);

  Widget _weekdays(GymColors gc) => Row(children: [
        for (final mark in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
          Expanded(
            child: Center(
              child: Text(mark, style: AppTheme.f(9, weight: FontWeight.w700, color: gc.textTertiary)),
            ),
          ),
      ]);

  List<Widget> _weeks(GymColors gc, Set<int> trained) {
    final first = DateTime(_month.year, _month.month, 1);
    final lead = first.weekday - DateTime.monday;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final rows = ((lead + days) / 7).ceil();
    final today = _dayOnly(DateTime.now());
    return [
      for (var r = 0; r < rows; r++)
        Row(children: [
          for (var c = 0; c < 7; c++)
            () {
              final n = r * 7 + c - lead + 1;
              if (n < 1 || n > days) return const Expanded(child: SizedBox(height: 34));
              return Expanded(child: _cell(gc, DateTime(_month.year, _month.month, n), today, trained));
            }(),
        ]),
    ];
  }

  Widget _cell(GymColors gc, DateTime date, DateTime today, Set<int> trained) {
    final did = trained.contains(_key(date));
    final isToday = _key(date) == _key(today);
    final chosen = _selected != null && _key(_selected!) == _key(date);
    final future = date.isAfter(today);
    return Semantics(
      button: true,
      selected: chosen,
      label: '${t.longDate(date)}${did ? ', trained' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selected = chosen ? null : date),
        child: Container(
          height: 31,
          margin: const EdgeInsets.all(1.5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: did ? gc.accent : gc.bgRaised,
            border: Border.all(
              color: chosen ? gc.text : isToday ? gc.textSecondary : Colors.transparent,
              width: chosen ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text('${date.day}',
              style: AppTheme.f(10.5,
                  weight: did ? FontWeight.w800 : FontWeight.w500,
                  color: did ? gc.onEmber : future ? gc.textTertiary : gc.textSecondary)),
        ),
      ),
    );
  }

  Widget _detail(BuildContext context, GymColors gc, DateTime day) {
    final today = _dayOnly(DateTime.now());
    final sessions = _sessionsOn(day);
    final canLog = !day.isAfter(today) && !fit.isSessionActive;
    final muscles = <String, int>{};
    for (final s in sessions) {
      for (final e in s.exercises) {
        if (!fit.countsForMuscles(e.id)) continue;
        final n = e.workingSets.length;
        if (n > 0) muscles[e.primary] = (muscles[e.primary] ?? 0) + n;
      }
    }
    final ranked = muscles.keys.toList()..sort((a, b) => muscles[b]!.compareTo(muscles[a]!));
    return Container(
      key: const ValueKey('minimal-calendar-day'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: gc.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(t.longDate(day),
                style: AppTheme.f(12.5, weight: FontWeight.w700, color: gc.text)),
          ),
          if (canLog)
            GestureDetector(
              key: const ValueKey('minimal-calendar-add'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _showAddWorkout(context, day),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Text('+ Add workout',
                    style: AppTheme.f(11, weight: FontWeight.w700, color: gc.accent)),
              ),
            ),
        ]),
        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(day.isAfter(today) ? 'Nothing planned yet.' : 'Nothing logged.',
                style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary)),
          )
        else ...[
          if (ranked.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Wrap(spacing: 5, runSpacing: 5, children: [
                for (final id in ranked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: gc.border),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${t.muscle(id)}  ${muscles[id]}',
                        style: AppTheme.f(10.5, weight: FontWeight.w600, color: gc.textSecondary)),
                  ),
              ]),
            ),
          for (final s in sessions) _session(gc, s),
        ],
      ]),
    );
  }

  Widget _session(GymColors gc, LoggedSession s) {
    final minutes = (s.durationSec / 60).round();
    final meta = [
      fit.volumeLabel(s.volume),
      if (minutes > 0) '$minutes min',
      t.setCount(s.setCount),
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(fit.sessionHeading(s),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.f(12, weight: FontWeight.w700, color: gc.text)),
          ),
          const SizedBox(width: 8),
          Text(meta, style: AppTheme.f(10.5, weight: FontWeight.w500, color: gc.textSecondary)),
        ]),
        const SizedBox(height: 3),
        for (final e in s.exercises)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(t.catalogName(e.id, e.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(11, weight: FontWeight.w500, color: gc.textSecondary)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(e.sets.map((x) => fit.loggedSetLabel(x, id: e.id)).join('  '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: AppTheme.f(11, weight: FontWeight.w600, color: gc.text)),
              ),
            ]),
          ),
      ]),
    );
  }

  Future<void> _showAddWorkout(BuildContext context, DateTime day) {
    final planned = fit.routinesOn(day).where((r) => r.exerciseIds.isNotEmpty).toList();
    final others = [
      for (final r in fit.routinesByLastDone)
        if (r.exerciseIds.isNotEmpty && !planned.contains(r)) r,
    ];
    return showAppDialog<void>(
      context: context,
      builder: (dctx) {
        final gc = minimalColors(dctx.gc);
        void go(VoidCallback action) {
          Navigator.of(dctx).pop();
          action();
        }

        Widget row(String label, String sub, VoidCallback onTap, {bool strong = false}) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => go(onTap),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: gc.border))),
                child: Row(children: [
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.f(13, weight: strong ? FontWeight.w700 : FontWeight.w600, color: gc.text)),
                  ),
                  if (sub.isNotEmpty)
                    Text(sub, style: AppTheme.f(10.5, weight: FontWeight.w500, color: gc.textSecondary)),
                ]),
              ),
            );

        return Theme(
          data: Theme.of(dctx).copyWith(extensions: [gc]),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Material(
                color: gc.bgRaised,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: gc.border),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 16, 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Add workout',
                          style: AppTheme.f(14, weight: FontWeight.w700, color: gc.text)),
                      const SizedBox(height: 2),
                      Text('${t.longDate(day)}  ·  no timer, just fill in what you did',
                          style: AppTheme.f(10.5, weight: FontWeight.w500, color: gc.textSecondary)),
                    ]),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        for (final r in planned)
                          row(fit.routineTitle(r), 'Planned', () => fit.startRoutine(r, on: day), strong: true),
                        for (final r in others)
                          row(fit.routineTitle(r), t.exerciseCount(r.exerciseIds.length),
                              () => fit.startRoutine(r, on: day)),
                        row('Pick exercises', '', () => fit.startPicking(on: day)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

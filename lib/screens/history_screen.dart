import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../app/desktop.dart';
import '../l10n/l10n.dart';
import '../models/workout.dart';
import '../services/file_share.dart';
import '../services/workout_history_xlsx.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/entrance.dart';
import '../widgets/sheet_page.dart';
import '../widgets/set_kind.dart';
import '../widgets/ui_kit.dart';
import 'progress_screen.dart';

GymColors _minimalHistoryColors(GymColors base) => base.copyWith(
      pageBg: const Color(0xFF0E0E0D),
      bg: const Color(0xFF141413),
      bgRaised: const Color(0xFF1B1B1A),
      bgRaised2: const Color(0xFF222221),
      border: const Color(0xFF2C2C2A),
      navBg: const Color(0xEE141413),
      text: const Color(0xFFE9E7E2),
      textSecondary: const Color(0xFF8D8A84),
      textTertiary: const Color(0xFF5F5D58),
      ember: const Color(0xFFC8A45F),
      emberDeep: const Color(0xFFA88647),
      onEmber: const Color(0xFF141413),
      emberSoft: const Color(0x35C8A45F),
      accent: const Color(0xFFC8A45F),
      accentSoft: const Color(0x35C8A45F),
      brass: const Color(0xFFC8A45F),
      sage: const Color(0xFFC8A45F),
      sageSoft: const Color(0x35C8A45F),
      mutedFill: const Color(0xFF222221),
      heatEmpty: const Color(0xFF222221),
    );

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final base = context.gc;
    final compact = fit.minimalMode;
    final gc = compact ? _minimalHistoryColors(base) : base;
    final month = fit.historyMonth;
    final list = fit.sessionsInMonth(month);
    if (compact) return _minimalHistory(context, gc, fit.sessions);
    final records = fit.recordsBySession();
    return RiseScope(
      id: 'history',
      once: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 300) return;
          final rtl = Directionality.of(context).name == 'rtl';
          final older = rtl ? v < 0 : v > 0;
          if (!older && fit.historyAtLatest) return;
          HapticFeedback.selectionClick();
          fit.shiftHistoryMonth(older ? -1 : 1);
        },
        child: SheetPage(
          title: sentenceCase(t.historyTitle),
          eyebrow: t.profile,
          onBack: fit.popRoute,
          children: DesktopScope.of(context)
              ? [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 420, child: Rise(index: 0, child: _MonthCard(key: ValueKey(month), month: month))),
                    const SizedBox(width: 24),
                    Expanded(
                      child: list.isEmpty
                          ? _empty(gc)
                          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Text(t.historyWorkouts(list.length),
                                  style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4)),
                              const SizedBox(height: 10),
                              CardFlow(minColumn: 300, maxColumns: 2, gap: 12, children: [
                                for (var i = 0; i < list.length; i++)
                                  Rise(index: i + 1, child: WorkoutHistoryCard(session: list[i], records: records[list[i]] ?? 0)),
                              ]),
                            ]),
                    ),
                  ]),
                ]
              : [
            Rise(index: 0, child: _MonthCard(key: ValueKey(month), month: month)),
            const SizedBox(height: 22),
            if (list.isEmpty)
              _empty(gc)
            else ...[
              Text(t.historyWorkouts(list.length),
                  style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4)),
              const SizedBox(height: 10),
              for (var i = 0; i < list.length; i++) ...[
                Rise(index: i + 1, child: WorkoutHistoryCard(session: list[i], records: records[list[i]] ?? 0)),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _minimalHistory(
    BuildContext context,
    GymColors gc,
    List<LoggedSession> allSessions,
  ) {
    final theme = Theme.of(context).copyWith(extensions: [gc]);
    return Theme(
      data: theme,
      child: ColoredBox(
        color: gc.bg,
        child: SafeArea(
          bottom: false,
          child: _MinimalHistoryContent(allSessions: allSessions),
        ),
      ),
    );
  }

  Widget _empty(GymColors gc) => Container(
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
        decoration: BoxDecoration(color: gc.bgRaised, borderRadius: BorderRadius.circular(22)),
        child: Column(children: [
          Icon(PhosphorIconsRegular.calendarBlank, size: 30, color: gc.textTertiary),
          const SizedBox(height: 12),
          Text(t.historyEmpty,
              textAlign: TextAlign.center, style: AppTheme.f(15, weight: FontWeight.w700, color: gc.text)),
          const SizedBox(height: 4),
          Text(t.historyEmptyHint,
              textAlign: TextAlign.center,
              style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary, height: 1.4)),
        ]),
      );
}

enum _MinimalHistoryView { list, table }

enum _MinimalHistorySort { date, exercise, set, weight, reps, volume, oneRm, muscle }

/// The one switchable column at the end of the Minimal table. Date, Exercise,
/// Set, Kg and Reps are always shown so the table fits a phone without
/// sideways scrolling.
enum _MinimalHistoryLast {
  volume('Volume', _MinimalHistorySort.volume, 56),
  oneRm('1RM', _MinimalHistorySort.oneRm, 48),
  muscle('Muscle', _MinimalHistorySort.muscle, 70);

  const _MinimalHistoryLast(this.label, this.sort, this.width);
  final String label;
  final _MinimalHistorySort sort;
  final double width;
}

class _MinimalHistoryContent extends StatefulWidget {
  const _MinimalHistoryContent({required this.allSessions});

  final List<LoggedSession> allSessions;

  @override
  State<_MinimalHistoryContent> createState() => _MinimalHistoryContentState();
}

class _MinimalHistoryContentState extends State<_MinimalHistoryContent> {
  static const _latestSessionLimit = 40;
  static const _visibleSetLimit = 200;
  final _searchController = TextEditingController();
  final Set<int> _expandedSessions = {};
  _MinimalHistoryView _view = _MinimalHistoryView.list;
  _MinimalHistorySort _sort = _MinimalHistorySort.date;
  _MinimalHistoryLast _last = _MinimalHistoryLast.volume;
  bool _descending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LoggedSession> get _recentSessions {
    final sessions = [...widget.allSessions]
      ..sort((a, b) {
        final day = b.day.compareTo(a.day);
        return day != 0 ? day : b.date.compareTo(a.date);
      });
    return sessions.take(_latestSessionLimit).toList(growable: false);
  }

  Future<void> _exportHistory() async {
    if (widget.allSessions.isEmpty) return;
    final stamp = DateTime.now().toIso8601String().split('T').first;
    try {
      await shareFile(
        'gymmane-history-$stamp.xlsx',
        workoutHistoryXlsx(widget.allSessions),
        mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        subject: 'GymMane workout history',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(t.minimalHistoryExportError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 104),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sentenceCase(t.historyTitle),
                  style: AppTheme.f(16.5, weight: FontWeight.w800, color: gc.text),
                ),
              ),
              TextButton(
                onPressed: widget.allSessions.isEmpty ? null : _exportHistory,
                style: TextButton.styleFrom(
                  foregroundColor: gc.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(t.minimalHistoryExportExcel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _viewSwitcher(gc),
          const SizedBox(height: 4),
          if (_view == _MinimalHistoryView.list) _listView(gc) else _tableView(gc),
        ],
      ),
    );
  }

  Widget _viewSwitcher(GymColors gc) {
    Widget option(String label, _MinimalHistoryView value) {
      final selected = _view == value;
      return InkWell(
        key: ValueKey('minimal-history-view-${value.name}'),
        onTap: () => setState(() => _view = value),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                color: selected ? gc.accent : Colors.transparent,
                width: 1.5,
              )),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                label,
                style: AppTheme.f(12, weight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? gc.text : gc.textTertiary),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        option('List', _MinimalHistoryView.list),
        const SizedBox(width: 16),
        option('Table', _MinimalHistoryView.table),
      ],
    );
  }

  Widget _listView(GymColors gc) {
    final sessions = _recentSessions;
    if (sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Text(
          t.historyEmpty,
          textAlign: TextAlign.start,
          style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary),
        ),
      );
    }
    return Column(
      children: [
        for (final session in sessions) _minimalWorkoutRow(session, gc),
      ],
    );
  }

  Widget _minimalWorkoutRow(LoggedSession session, GymColors gc) {
    final key = session.date.microsecondsSinceEpoch;
    final expanded = _expandedSessions.contains(key);
    final grouped = <String, _MinimalHistoryExerciseGroup>{};
    for (final exercise in session.exercises) {
      final groupKey = '${exercise.id}|${exercise.primary}';
      final group = grouped.putIfAbsent(
        groupKey,
        () => _MinimalHistoryExerciseGroup(exercise.id, exercise.name),
      );
      group.sets.addAll(exercise.sets);
    }
    final exercises = grouped.values.toList(growable: false);
    final exerciseNames = exercises
        .map((exercise) => t.catalogName(exercise.id, exercise.name))
        .join(', ');
    final setCount = exercises.fold<int>(0, (total, exercise) => total + exercise.sets.length);
    final date = intl.DateFormat('EEE d MMM').format(session.day);
    final duration = (session.durationSec / 60).round();

    return Column(
      key: ValueKey('minimal-history-session-$key'),
      children: [
        InkWell(
          onTap: () => setState(() {
            if (!_expandedSessions.add(key)) _expandedSessions.remove(key);
          }),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: gc.border.withValues(alpha: 0.8))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              fit.sessionHeading(session),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.f(12.5, weight: FontWeight.w800, color: gc.text),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(date, style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      fit.volumeLabel(session.volume),
                      style: AppTheme.f(11.5, weight: FontWeight.w700, color: gc.text),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '$duration min, $setCount sets',
                  style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary),
                ),
                if (exerciseNames.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    exerciseNames,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
                  child: Column(
                    children: [
                      for (final exercise in exercises)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  t.catalogName(exercise.id, exercise.name),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.f(11, weight: FontWeight.w500, color: gc.textSecondary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  exercise.sets.map(fit.loggedSetLabel).join('  '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: AppTheme.f(11, weight: FontWeight.w600, color: gc.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  List<_MinimalHistorySetRow> _filteredRows() {
    final query = _searchController.text.trim().toLowerCase();
    final rows = <_MinimalHistorySetRow>[];
    for (final session in widget.allSessions) {
      for (final exercise in session.exercises) {
        for (var i = 0; i < exercise.sets.length; i++) {
          final row = _MinimalHistorySetRow(
            session: session,
            exercise: exercise,
            set: exercise.sets[i],
            setNumber: i + 1,
          );
          if (query.isEmpty) {
            rows.add(row);
            continue;
          }
          final date = row.session.day;
          final searchable = [
            fit.sessionHeading(row.session),
            row.exercise.name,
            t.catalogName(row.exercise.id, row.exercise.name),
            row.exercise.primary,
            sentenceCase(row.exercise.primary),
            intl.DateFormat('yyyy-MM-dd').format(date),
            intl.DateFormat('dd MMM yy').format(date),
            intl.DateFormat('dd MMM yyyy').format(date),
            t.fullDate(date),
          ].join(' ').toLowerCase();
          if (searchable.contains(query)) rows.add(row);
        }
      }
    }
    rows.sort((a, b) {
      final comparison = switch (_sort) {
        _MinimalHistorySort.date => a.session.day.compareTo(b.session.day),
        _MinimalHistorySort.exercise => a.exercise.name.toLowerCase().compareTo(b.exercise.name.toLowerCase()),
        _MinimalHistorySort.set => a.setNumber.compareTo(b.setNumber),
        _MinimalHistorySort.weight => a.set.weight.compareTo(b.set.weight),
        _MinimalHistorySort.reps => a.set.reps.compareTo(b.set.reps),
        _MinimalHistorySort.volume => a.set.volume.compareTo(b.set.volume),
        _MinimalHistorySort.oneRm => a.set.oneRm.compareTo(b.set.oneRm),
        _MinimalHistorySort.muscle => a.exercise.primary.toLowerCase().compareTo(b.exercise.primary.toLowerCase()),
      };
      if (comparison != 0) return _descending ? -comparison : comparison;
      final latest = b.session.day.compareTo(a.session.day);
      if (latest != 0) return latest;
      final exercise = a.exercise.name.toLowerCase().compareTo(b.exercise.name.toLowerCase());
      if (exercise != 0) return exercise;
      return a.setNumber.compareTo(b.setNumber);
    });
    return rows;
  }

  Widget _tableView(GymColors gc) {
    final rows = _filteredRows();
    final visible = rows.take(_visibleSetLimit).toList(growable: false);
    final maxTable = (MediaQuery.sizeOf(context).height * 0.6).clamp(300.0, 560.0).toDouble();
    final tableHeight = (31 + visible.length * 34).clamp(31.0, maxTable).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 38,
          child: TextField(
            key: const ValueKey('minimal-history-search'),
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.text),
            cursorColor: gc.accent,
            decoration: InputDecoration(
              isDense: true,
              hintText: t.minimalHistoryFilterHint,
              hintStyle: AppTheme.f(11, weight: FontWeight.w500, color: gc.textTertiary),
              prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 15, color: gc.textTertiary),
              prefixIconConstraints: const BoxConstraints(minWidth: 34),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: Icon(PhosphorIconsRegular.x, size: 14, color: gc.textTertiary),
                    ),
              suffixIconConstraints: const BoxConstraints(minWidth: 30),
              filled: true,
              fillColor: gc.bgRaised,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: gc.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide(color: gc.accent),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text('${rows.length} sets',
              style: AppTheme.f(10, weight: FontWeight.w700, color: gc.textSecondary)),
          const Spacer(),
          Text(t.minimalHistorySortHint,
              style: AppTheme.f(9.5, weight: FontWeight.w500, color: gc.textTertiary)),
        ]),
        const SizedBox(height: 5),
        Row(children: [
          Text('Last column', style: AppTheme.f(9.5, weight: FontWeight.w500, color: gc.textTertiary)),
          const Spacer(),
          for (final option in _MinimalHistoryLast.values) ...[
            const SizedBox(width: 5),
            _lastChip(option, gc),
          ],
        ]),
        const SizedBox(height: 6),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Text(
              _searchController.text.isEmpty ? 'No sets logged yet.' : 'No sets match that search.',
              textAlign: TextAlign.center,
              style: AppTheme.f(11, weight: FontWeight.w600, color: gc.textTertiary),
            ),
          )
        else
          SizedBox(
            height: tableHeight,
            child: Column(
              children: [
                Container(
                  height: 31,
                  decoration: BoxDecoration(
                    color: gc.bgRaised,
                    border: Border(bottom: BorderSide(color: gc.border)),
                  ),
                  child: Row(children: [
                    _sortHeader(_MinimalHistorySort.date, 'Date', 52, gc),
                    _sortHeader(_MinimalHistorySort.exercise, 'Exercise', null, gc),
                    _sortHeader(_MinimalHistorySort.set, 'Set', 30, gc, right: true),
                    _sortHeader(_MinimalHistorySort.weight, 'Kg', 40, gc, right: true),
                    _sortHeader(_MinimalHistorySort.reps, 'Reps', 36, gc, right: true),
                    _sortHeader(_last.sort, _last.label, _last.width, gc, right: _last != _MinimalHistoryLast.muscle),
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [for (final row in visible) _historyTableRow(row, gc)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (rows.length > visible.length)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Showing ${visible.length} of ${rows.length} sets. Search to narrow the results.',
              style: AppTheme.f(9.5, weight: FontWeight.w500, color: gc.textTertiary),
            ),
          ),
      ],
    );
  }

  Widget _lastChip(_MinimalHistoryLast option, GymColors gc) {
    final selected = _last == option;
    return GestureDetector(
      key: ValueKey('minimal-history-last-${option.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        _last = option;
        if (_sort == _MinimalHistorySort.volume ||
            _sort == _MinimalHistorySort.oneRm ||
            _sort == _MinimalHistorySort.muscle) {
          _sort = option.sort;
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? gc.accentSoft : Colors.transparent,
          border: Border.all(color: selected ? gc.accent : gc.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(option.label,
            style: AppTheme.f(9.5, weight: FontWeight.w700, color: selected ? gc.accent : gc.textSecondary)),
      ),
    );
  }

  Widget _sortHeader(_MinimalHistorySort column, String label, double? width, GymColors gc, {bool right = false}) {
    final active = _sort == column;
    final header = InkWell(
      key: ValueKey('minimal-history-sort-${column.name}'),
      onTap: () => setState(() {
        if (_sort == column) {
          _descending = !_descending;
        } else {
          _sort = column;
          _descending = column == _MinimalHistorySort.date;
        }
      }),
      child: SizedBox(
        width: width,
        height: 31,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Row(
            mainAxisAlignment: right ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.f(9.5, weight: FontWeight.w800,
                      color: active ? gc.accent : gc.textTertiary),
                ),
              ),
              if (active)
                Icon(_descending ? PhosphorIconsBold.caretDown : PhosphorIconsBold.caretUp,
                    size: 9, color: gc.accent),
            ],
          ),
        ),
      ),
    );
    return width == null ? Expanded(child: header) : header;
  }

  Widget _historyTableRow(_MinimalHistorySetRow row, GymColors gc) {
    final date = intl.DateFormat('d MMM').format(row.session.day);
    final type = switch (row.set.kind) {
      SetKind.normal => '',
      SetKind.warmup => 'W',
      SetKind.drop => 'D',
      SetKind.failure => 'F',
      SetKind.restPause => 'RP',
      SetKind.cluster => 'C',
    };
    final weight = row.set.weight > 0 ? _metric(row.set.weight) : '—';
    final reps = row.set.reps > 0 ? '${row.set.reps}' : '—';
    final volume = row.set.volume > 0 ? _metric(row.set.volume) : '—';
    final oneRm = row.set.counts && row.set.oneRm > 0 ? _metric(row.set.oneRm) : '—';
    return Container(
      height: 34,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: gc.border.withValues(alpha: 0.65)))),
      child: Row(children: [
        _tableCell(date, 52, gc),
        _tableCell(t.catalogName(row.exercise.id, row.exercise.name), null, gc),
        _tableCell('${row.setNumber}$type', 30, gc, right: true),
        _tableCell(weight, 40, gc, right: true, muted: weight == '—'),
        _tableCell(reps, 36, gc, right: true, muted: reps == '—'),
        switch (_last) {
          _MinimalHistoryLast.volume => _tableCell(volume, _last.width, gc, right: true, muted: volume == '—'),
          _MinimalHistoryLast.oneRm => _tableCell(oneRm, _last.width, gc, right: true, muted: oneRm == '—'),
          _MinimalHistoryLast.muscle => _tableCell(t.muscle(row.exercise.primary), _last.width, gc, muted: true),
        },
      ]),
    );
  }

  Widget _tableCell(String value, double? width, GymColors gc, {bool right = false, bool muted = false}) {
    final cell = SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Align(
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.f(10, weight: FontWeight.w600,
                color: muted ? gc.textTertiary : gc.textSecondary),
          ),
        ),
      ),
    );
    return width == null ? Expanded(child: cell) : cell;
  }

  String _metric(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}

class _MinimalHistoryExerciseGroup {
  _MinimalHistoryExerciseGroup(this.id, this.name);

  final String id;
  final String name;
  final List<LoggedSet> sets = [];
}

class _MinimalHistorySetRow {
  const _MinimalHistorySetRow({
    required this.session,
    required this.exercise,
    required this.set,
    required this.setNumber,
  });

  final LoggedSession session;
  final LoggedExercise exercise;
  final LoggedSet set;
  final int setNumber;
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({super.key, required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final now = fit.monthSummary(month);
    final before = fit.monthSummary(DateTime(month.year, month.month - 1));
    final trained = {for (final s in fit.sessionsInMonth(month)) s.day.day};
    final hours = now.seconds ~/ 3600;
    final minutes = (now.seconds % 3600) ~/ 60;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: gc.bgRaised, borderRadius: BorderRadius.circular(22)),
      child: Column(children: [
        Row(children: [
          _arrow(gc, PhosphorIconsBold.caretLeft, t.notePrevMonth, () => fit.shiftHistoryMonth(-1)),
          Expanded(
            child: Text(t.monthYear(month),
                textAlign: TextAlign.center, style: AppTheme.f(16, weight: FontWeight.w800, color: gc.text)),
          ),
          _arrow(gc, PhosphorIconsBold.caretRight, t.noteNextMonth,
              fit.historyAtLatest ? null : () => fit.shiftHistoryMonth(1)),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _stat(gc, '${now.workouts}', t.statWorkouts.toUpperCase(), now.workouts - before.workouts),
          _stat(gc, hours > 0 ? '${hours}h ${minutes.toString().padLeft(2, '0')}' : '${minutes}m', t.timeCaps, null),
          _stat(gc, '${now.sets}', t.setsCaps, null),
          _stat(gc, fit.volumeLabel(now.volume), t.volume, null),
        ]),
        const SizedBox(height: 16),
        Container(height: 1, color: gc.border),
        const SizedBox(height: 12),
        _calendar(context, gc, trained),
      ]),
    );
  }

  Widget _arrow(GymColors gc, IconData icon, String label, VoidCallback? onTap) => Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
          child: Opacity(
            opacity: onTap == null ? 0.3 : 1,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: gc.bgRaised2, shape: BoxShape.circle),
              child: Icon(icon, size: 13, color: gc.text),
            ),
          ),
        ),
      );

  Widget _stat(GymColors gc, String value, String label, int? delta) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RollIn(value, style: AppTheme.f(21, weight: FontWeight.w800, color: gc.text, height: 1.1)),
          ),
          const SizedBox(height: 3),
          FitText(label, style: AppTheme.f(9, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1)),
          if (delta != null && delta != 0) ...[
            const SizedBox(height: 3),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(delta > 0 ? PhosphorIconsBold.arrowUp : PhosphorIconsBold.arrowDown,
                  size: 10, color: delta > 0 ? gc.sage : gc.textTertiary),
              const SizedBox(width: 2),
              Text('${delta.abs()}',
                  style: AppTheme.f(10.5, weight: FontWeight.w700, color: delta > 0 ? gc.sage : gc.textTertiary)),
            ]),
          ],
        ]),
      );

  Widget _calendar(BuildContext context, GymColors gc, Set<int> trained) {
    final today = DateTime.now();
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = (first.weekday - fit.weekStartDay + 7) % 7;
    return Column(children: [
      Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Text(t.weekdayInitial(fit.weekdayAt(i)).toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTheme.f(10, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1)),
          ),
      ]),
      const SizedBox(height: 6),
      for (var row = 0; row * 7 < lead + days; row++)
        Row(children: [
          for (var col = 0; col < 7; col++)
            Expanded(child: () {
              final n = row * 7 + col - lead + 1;
              if (n < 1 || n > days) return const SizedBox(height: 40);
              final day = DateTime(month.year, month.month, n);
              final on = trained.contains(n);
              final isToday = DateUtils.isSameDay(day, today);
              final future = day.isAfter(today);
              return Semantics(
                button: on,
                label: t.fullDate(day),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: future ? null : () => showDaySheet(context, day),
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? gc.accent : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !on ? Border.all(color: gc.ember, width: 1.4) : null,
                        ),
                        child: Text('$n',
                            style: AppTheme.f(13,
                                weight: on || isToday ? FontWeight.w800 : FontWeight.w500,
                                color: on
                                    ? gc.onEmber
                                    : future
                                        ? gc.textTertiary.withValues(alpha: 0.5)
                                        : gc.textSecondary)),
                      ),
                    ),
                  ),
                ),
              );
            }()),
        ]),
    ]);
  }
}

class WorkoutHistoryCard extends StatelessWidget {
  const WorkoutHistoryCard({super.key, required this.session, this.records = 0});

  final LoggedSession session;
  final int records;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final s = session;
    final start = TimeOfDay.fromDateTime(s.day);
    final clock = MaterialLocalizations.of(context)
        .formatTimeOfDay(start, alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
    final meta = [
      clock,
      if (s.durationSec >= 60) '${(s.durationSec / 60).round()} min',
      if (s.hrAvg != null) '♥ ${s.hrAvg} · ${t.hrMaxShort(s.hrMax ?? s.hrAvg!)}',
    ].join(' · ');
    final shown = s.exercises.take(4).toList();
    return Pressable(
      scale: 0.98,
      onTap: () => showDaySheet(context, s.day),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        decoration: BoxDecoration(
          color: gc.bgRaised,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: gc.bgRaised2, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text(t.weekdayShort(s.day.weekday).toUpperCase(),
                    style: AppTheme.f(9, weight: FontWeight.w800, color: gc.accent, letterSpacing: 0.8)),
                Text('${s.day.day}', style: AppTheme.f(19, weight: FontWeight.w800, color: gc.text, height: 1.15)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fit.sessionHeading(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(16, weight: FontWeight.w800, color: gc.text)),
                const SizedBox(height: 2),
                Text(meta, style: AppTheme.f(12, weight: FontWeight.w600, color: gc.textSecondary)),
                const SizedBox(height: 6),
                Text(
                    [t.exerciseCount(s.exercises.length), t.setCount(s.setCount), if (s.volume > 0) fit.volumeLabel(s.volume)]
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.textTertiary)),
              ]),
            ),
            if (records > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: gc.accentSoft, borderRadius: BorderRadius.circular(100)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(PhosphorIconsFill.trophy, size: 11, color: gc.accent),
                  const SizedBox(width: 4),
                  Text('$records', style: AppTheme.f(11.5, weight: FontWeight.w800, color: gc.accent)),
                ]),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          Container(height: 1, color: gc.border),
          const SizedBox(height: 10),
          for (final e in shown) _line(gc, e),
          if (s.exercises.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(t.historyMore(s.exercises.length - shown.length),
                  style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.textTertiary)),
            ),
        ]),
      ),
    );
  }

  Widget _line(GymColors gc, LoggedExercise e) {
    final top = fit.topSetOf(e);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
          width: 30,
          child: Text('${e.workingSets.length}×',
              style: AppTheme.f(12.5, weight: FontWeight.w700, color: gc.textTertiary)),
        ),
        Expanded(
          child: Text(t.catalogName(e.id, e.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.f(13, weight: FontWeight.w600, color: gc.text)),
        ),
        if (e.workingSets.any(fit.recordSets.contains)) ...[
          const SizedBox(width: 8),
          RecordBadge(label: sentenceCase(t.personalRecord), size: 16),
        ],
        if (top != null) ...[
          const SizedBox(width: 8),
          Text(fit.loggedSetLabel(top), style: AppTheme.f(12.5, weight: FontWeight.w700, color: gc.textSecondary)),
        ],
      ]),
    );
  }
}

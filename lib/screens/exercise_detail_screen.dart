import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../app/desktop.dart';
import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../services/exercise_match.dart';
import '../services/minimal_insights.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/minimal_palette.dart';
import '../widgets/charts.dart';
import '../widgets/dialogs.dart';
import '../widgets/entrance.dart';
import '../widgets/exercise_history_sheet.dart';
import '../widgets/exercise_media.dart';
import '../widgets/exercise_preview.dart';
import '../widgets/ruler_picker.dart';
import '../widgets/glass.dart';
import '../widgets/liquid_notch.dart';
import '../widgets/progression_sheet.dart';
import '../widgets/stat_cards.dart';
import '../widgets/stopwatch_card.dart';
import '../widgets/svg_icon.dart';
import '../widgets/timer_panel.dart';
import '../widgets/ui_kit.dart';
import '../widgets/weight_stack_sheet.dart';
import 'exercises_screen.dart' show showCreateExerciseSheet;

class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  int _rangeDays = 84;
  String _metric = '';
  bool _allHistory = false;

  String get _exId => fit.activeExercise.id;
  String? _foldFor;
  bool _howOpen = true;
  bool _similarOpen = false;

  String _fmtDate(DateTime d) => t.shortDate(d);

  Future<void> _pickMedia() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.media);
      final path = res?.files.single.path;
      if (path != null) await fit.attachExerciseMedia(_exId, path);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final base = context.gc;
    final minimal = fit.minimalMode;
    final gc = minimal ? minimalColors(base) : base;
    if (minimal) return _minimalPage(context, gc);
    final ex = fit.activeExercise;
    final fav = fit.favorites[ex.id] ?? false;
    final secondary =
        ex.secondary.map(muscleLabel).join(', ').isEmpty ? t.none : ex.secondary.map(muscleLabel).join(', ');
    final steps = fit.activeExerciseSteps(ex);
    final pr = fit.exerciseRecord(ex.id);
    final oneRm = fit.oneRmSeries(ex.id);
    final bestReps = fit.bestRepsSeries(ex.id);
    final history = fit.exerciseHistory(ex.id);
    final hasMedia = fit.hasCustomMedia(ex.id);
    final mode = fit.modeOf(ex.id);
    final custom = fit.isCustom(ex.id);
    final archived = fit.isArchived(ex.id);
    final desktop = DesktopScope.of(context);
    if (_foldFor != ex.id) {
      _foldFor = ex.id;
      _howOpen = history.isEmpty;
      _similarOpen = false;
    }
    final bar = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RoundBtn(icon: Ic.chevronLeft, onTap: fit.closeExerciseDetail),
          Row(children: [
            if (custom) ...[
              RoundAction(
                label: t.delete,
                onTap: () => _confirmDelete(context, ex),
                child: Icon(PhosphorIconsRegular.trash, size: 16, color: gc.textSecondary),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: t.editExercise,
                child: RoundAction(
                  onTap: () => showCreateExerciseSheet(context, editing: ex),
                  child: Icon(PhosphorIconsRegular.pencilSimple, size: 16, color: gc.textSecondary),
                ),
              ),
              const SizedBox(width: 10),
              if (history.isNotEmpty) ...[
                RoundAction(
                  label: t.mergeExercise,
                  onTap: () => _merge(context, ex),
                  child: Icon(PhosphorIconsRegular.gitMerge, size: 16, color: gc.textSecondary),
                ),
                const SizedBox(width: 10),
              ],
            ],
            RoundAction(
              label: t.duplicateExercise,
              onTap: () => showCreateExerciseSheet(context, copyOf: ex),
              child: Icon(PhosphorIconsRegular.copy, size: 16, color: gc.textSecondary),
            ),
            const SizedBox(width: 10),
            RoundAction(
              label: archived ? t.restoreExercise : t.archiveExercise,
              onTap: () => _toggleArchived(context, ex),
              child: Icon(archived ? PhosphorIconsFill.archive : PhosphorIconsRegular.archive,
                  size: 16, color: archived ? gc.accent : gc.textSecondary),
            ),
            const SizedBox(width: 10),
            RoundAction(
              onTap: () => fit.toggleFavorite(ex.id),
              child: _star(gc, fav),
            ),
          ]),
        ],
      ),
    );
    final media = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => showExercisePreview(context, ex),
            child: SizedBox(
              width: double.infinity,
              child: ExerciseMedia(
                  ex: ex, height: 220, radius: 22, live: true, bordered: false),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Row(
              children: [
                if (hasMedia) ...[
                  _mediaBtn(gc, PhosphorIconsRegular.arrowCounterClockwise, t.useDefaultArt,
                      () => fit.clearExerciseMedia(ex.id)),
                  const SizedBox(width: 8),
                ],
                _mediaBtn(
                  gc,
                  hasMedia ? PhosphorIconsRegular.pencilSimple : PhosphorIconsRegular.uploadSimple,
                  hasMedia ? t.changeMedia : t.addMedia,
                  _pickMedia,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final partA = <Widget>[
      AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: archived
            ? Padding(padding: const EdgeInsets.only(bottom: 16), child: _archivedBanner(gc, ex))
            : const SizedBox(width: double.infinity),
      ),
      Text(exerciseName(ex),
          style: AppTheme.f(minimal ? 21 : 26, weight: FontWeight.w800, color: gc.text, height: 1.1)),
      if (ex.aliases.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(t.alsoCalled(ex.aliases.join(', ')),
            style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary, height: 1.35)),
      ],
      SizedBox(height: minimal ? 10 : 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _meta(gc, t.primaryLabel, muscleLabel(ex.primary)),
          SizedBox(width: minimal ? 10 : 20),
          _meta(gc, t.secondaryLabel, secondary, onTap: () => _editSecondary(context, ex.id)),
          SizedBox(width: minimal ? 10 : 20),
          _meta(gc, t.equipmentLabel, t.equipment(ex.equipment)),
        ],
      ),
      SizedBox(height: minimal ? 10 : 18),
      _addToRoutineRow(context, gc, ex),
      if (!desktop) ...[
        const SizedBox(height: 10),
        _settingsRow(context, gc, ex),
      ],
      const SizedBox(height: 20),
      if (pr != null) ...[
        Container(
          padding: EdgeInsets.all(minimal ? 10 : 18),
          decoration: BoxDecoration(
            color: gc.bgRaised,
            borderRadius: BorderRadius.circular(minimal ? 6 : 20),
            border: minimal ? Border.all(color: gc.border) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardLabel(gc, t.personalRecord),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(fit.recordLabel(pr),
                              maxLines: 1,
                              style: AppTheme.f(minimal ? 24 : 30,
                                  weight: FontWeight.w800, color: gc.text, height: 1)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(fit.recordDetail(pr),
                          maxLines: 1,
                          style: AppTheme.f(12,
                              weight: FontWeight.w500, color: gc.textSecondary)),
                    ),
                  ),
                ],
              ),
              if (history.length > 1) _bests(gc, ex.id, pr.kind),
              if (pr.kind == PrKind.weight && oneRm.length > 2) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showExerciseHistorySheet(context, ex.id),
                  child: TrendChart(values: [for (final v in oneRm) fit.toDisplayWeight(fit.repMaxOf(ex.id, v))], height: 84, scale: fmt),
                ),
              ],
              if (pr.kind == PrKind.reps && bestReps.length > 2) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showExerciseHistorySheet(context, ex.id),
                  child: TrendChart(values: bestReps, height: 84, scale: (v) => '${v.round()}'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
      if (fit.goalFits(ex.id)) ...[
        _goalCard(context, gc, ex.id),
        const SizedBox(height: 20),
      ],
      if (fit.nextTargetLabel(ex.id) != null) ...[
        _nextCard(gc, ex.id),
        const SizedBox(height: 20),
      ],
      if (history.isNotEmpty)
        for (final card in StatCards.forExercise(ex.id, flat: false, standard: true)) ...[
          card,
          const SizedBox(height: 12),
        ],
    ];
    final historyPart = <Widget>[
      _heading(gc, t.history, onMore: history.isEmpty ? null : () => showExerciseHistorySheet(context, ex.id)),
      const SizedBox(height: 4),
      if (history.isEmpty)
        Text(t.noHistory,
            style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary))
      else
        for (int i = 0; i < history.length && i < 5; i++)
          _historyRow(gc, history[i], i < history.length - 1 && i < 4, mode),
      const SizedBox(height: 24),
      _notesRow(gc, ex.id),
      const SizedBox(height: 24),
    ];
    final howTo = <Widget>[
      if (steps.isNotEmpty || custom) ...[
        _fold(
          gc,
          t.howTo,
          _howOpen,
          () => setState(() => _howOpen = !_howOpen),
          trailing: custom && steps.isNotEmpty && _howOpen
              ? Semantics(
                  button: true,
                  label: t.editExercise,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showCreateExerciseSheet(context, editing: ex),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(PhosphorIconsRegular.pencilSimple, size: 17, color: gc.textTertiary),
                    ),
                  ),
                )
              : null,
          [
            if (steps.isEmpty) ...[
              Text(t.noStepsYet,
                  style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary, height: 1.45)),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Pill(
                  label: t.addSteps,
                  bg: gc.bgRaised2,
                  fg: gc.accent,
                  onTap: () => showCreateExerciseSheet(context, editing: ex),
                ),
              ),
            ],
            for (int i = 0; i < steps.length; i++) ...[
              _step(gc, i + 1, steps[i]),
              if (i < steps.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
        const SizedBox(height: 24),
      ],
    ];
    final similar = fit.similarExercises(ex, 4);
    final tail = <Widget>[
      if (desktop) ...[
        _section(gc, t.exerciseSettings),
        const SizedBox(height: 12),
        _group(gc, _settingsRows(context, gc, ex)),
        const SizedBox(height: 24),
      ],
      if (fit.runsClock(ex.id)) ...[
        _section(gc, t.stopwatch),
        const SizedBox(height: 10),
        const StopwatchCard(),
        const SizedBox(height: 24),
      ],
      if (fit.alternativesHere(ex, 3).isNotEmpty) ...[
        _notHere(gc, ex),
        const SizedBox(height: 24),
      ],
      if (similar.isNotEmpty)
        _fold(gc, t.similar, _similarOpen, () => setState(() => _similarOpen = !_similarOpen), [
          for (final s in similar) _similarRow(gc, s),
        ]),
    ];
    if (desktop) {
      return RiseScope(
        key: ValueKey(ex.id),
        id: 'exercise',
        once: false,
        child: SingleChildScrollView(
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(12, 30, 12, 48),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Rise(index: 0, child: bar),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Rise(index: 1, child: media),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Rise(index: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...partA, ...historyPart])),
                  ),
                ]),
              ),
              SizedBox(
                width: 460,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 20, 20),
                  child: Rise(index: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...howTo, ...tail])),
                ),
              ),
            ]),
          ]),
        ),
      );
    }

    return RiseScope(
      key: ValueKey(ex.id),
      id: 'exercise',
      once: false,
      child: ColoredBox(
        color: minimal && !fit.minimalWallpaperOn ? gc.bg : Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: EdgeInsets.only(top: minimal ? 4 : 12, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: riseAll([
            bar,
            if (!minimal) media,
            Padding(
              padding: EdgeInsets.all(minimal ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [...partA, ...howTo, ...historyPart, ...tail],
              ),
            ),
          ]),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Minimal exercise page
  // ---------------------------------------------------------------------------

  Widget _minimalPage(BuildContext context, GymColors gc) {
    final ex = fit.activeExercise;
    final history = fit.exerciseHistory(ex.id);
    final archived = fit.isArchived(ex.id);
    final mode = fit.modeOf(ex.id);
    final pr = fit.exerciseRecord(ex.id);
    final secondary = ex.secondary.map(muscleLabel).join(', ');
    final shown = _allHistory ? history.length : math.min(history.length, 8);
    return Theme(
      data: Theme.of(context).copyWith(extensions: [gc]),
      child: RiseScope(
        key: ValueKey(ex.id),
        id: 'exercise',
        once: false,
        child: ColoredBox(
          color: fit.minimalWallpaperOn ? Colors.transparent : gc.bg,
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(top: 4, bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: riseAll([
                  _miniBar(context, gc, ex),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (archived) ...[
                          _archivedBanner(gc, ex),
                          const SizedBox(height: 12),
                        ],
                        Text(exerciseName(ex),
                            style: AppTheme.f(17, weight: FontWeight.w700, color: gc.text, height: 1.2)),
                        const SizedBox(height: 3),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _editSecondary(context, ex.id),
                          child: Text(
                            [
                              muscleLabel(ex.primary),
                              if (secondary.isNotEmpty) secondary,
                              t.equipment(ex.equipment),
                            ].join('  ·  '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary, height: 1.35),
                          ),
                        ),
                        if (history.isEmpty) ...[
                          const SizedBox(height: 18),
                          Text(t.noHistory,
                              style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary)),
                        ] else ...[
                          const SizedBox(height: 14),
                          _miniStats(gc, ex, history, pr),
                          _miniNext(gc, ex),
                          if (pr != null) _miniRecords(gc, ex, history, pr),
                          if (fit.minimalRepRecords) _miniRepRecords(gc, ex),
                          if (pr != null) _miniChart(gc, ex, history, pr),
                          ...StatCards.forExercise(ex.id, flat: true),
                        ],
                        if (fit.goalFits(ex.id) && fit.exerciseGoals[ex.id] != null) ...[
                          const SizedBox(height: 14),
                          _goalCard(context, gc, ex.id),
                        ],
                        if (history.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _section(gc, t.history),
                          const SizedBox(height: 2),
                          for (var i = 0; i < shown; i++) _historyRow(gc, history[i], i < shown - 1, mode),
                          if (history.length > shown)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _allHistory = true),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Text('Show all ${history.length}',
                                    style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.ember)),
                              ),
                            ),
                        ],
                        const SizedBox(height: 14),
                        _addToRoutineRow(context, gc, ex),
                        if (fit.minimalShowNotes) _notesRow(gc, ex.id),
                        if (fit.runsClock(ex.id)) ...[
                          const SizedBox(height: 18),
                          _section(gc, t.stopwatch),
                          const SizedBox(height: 8),
                          const StopwatchCard(),
                        ],
                        if (fit.alternativesHere(ex, 3).isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _notHere(gc, ex),
                        ],
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniBar(BuildContext context, GymColors gc, Exercise ex) {
    final fav = fit.favorites[ex.id] ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(children: [
        RoundBtn(icon: Ic.chevronLeft, onTap: fit.closeExerciseDetail),
        const Spacer(),
        RoundAction(
          size: 30,
          label: t.favouritesOnly,
          onTap: () => fit.toggleFavorite(ex.id),
          child: _star(gc, fav),
        ),
        if (fit.minimalShowHowTo) ...[
          const SizedBox(width: 6),
          RoundAction(
            size: 30,
            label: t.howTo,
            onTap: () => showExercisePreview(context, ex),
            child: Icon(Icons.help_outline_rounded, size: 16, color: gc.textSecondary),
          ),
        ],
        const SizedBox(width: 6),
        RoundAction(
          size: 30,
          label: t.exerciseSettings,
          onTap: () => _showSettingsPopup(context, ex),
          child: Icon(Icons.settings_outlined, size: 15, color: gc.textSecondary),
        ),
        const SizedBox(width: 6),
        RoundAction(
          size: 30,
          label: t.moreOptions,
          onTap: () => _showMore(context, gc, ex),
          child: Icon(PhosphorIconsBold.dotsThree, size: 16, color: gc.textSecondary),
        ),
      ]),
    );
  }

  Future<void> _showMore(BuildContext context, GymColors gc, Exercise ex) {
    final custom = fit.isCustom(ex.id);
    final archived = fit.isArchived(ex.id);
    final hasMedia = fit.hasCustomMedia(ex.id);
    final hasHistory = fit.exerciseHistory(ex.id).isNotEmpty;
    return showAppDialog<void>(
      context: context,
      builder: (dctx) {
        Widget item(String label, VoidCallback onTap, {bool danger = false}) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(dctx).pop();
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(label,
                      style: AppTheme.f(13.5,
                          weight: FontWeight.w600, color: danger ? gc.danger : gc.text)),
                ),
              ),
            );
        final items = <Widget>[
          if (custom) item(t.editExercise, () => showCreateExerciseSheet(context, editing: ex)),
          item(t.duplicateExercise, () => showCreateExerciseSheet(context, copyOf: ex)),
          item(hasMedia ? t.changeMedia : t.addMedia, _pickMedia),
          if (hasMedia) item(t.useDefaultArt, () => fit.clearExerciseMedia(ex.id)),
          if (custom && hasHistory) item(t.mergeExercise, () => _merge(context, ex)),
          item(archived ? t.restoreExercise : t.archiveExercise, () => _toggleArchived(context, ex)),
          if (custom) item(t.delete, () => _confirmDelete(context, ex), danger: true),
        ];
        return Theme(
          data: Theme.of(dctx).copyWith(extensions: [gc]),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Material(
                color: gc.bgRaised,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: gc.border),
                ),
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < items.length; i++) ...[
                      items[i],
                      if (i < items.length - 1) Divider(height: 1, thickness: 0.7, color: gc.border),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSettingsPopup(BuildContext context, Exercise ex) {
    return showAppDialog<void>(
      context: context,
      builder: (dctx) {
        final pad = MediaQuery.viewPaddingOf(dctx);
        return AnimatedBuilder(
          animation: fit,
          builder: (_, _) {
            final gc = minimalColors(dctx.gc);
            return Theme(
              data: Theme.of(dctx).copyWith(extensions: [gc]),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14, pad.top + 24, 14, pad.bottom + 24),
                  child: Material(
                    color: gc.bgRaised,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: gc.border),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                        child: Row(children: [
                          Expanded(
                            child: Text(t.exerciseSettings,
                                style: AppTheme.f(14, weight: FontWeight.w700, color: gc.text)),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.of(dctx).pop(),
                            icon: Icon(PhosphorIconsBold.x, size: 14, color: gc.textSecondary),
                          ),
                        ]),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                          child: _group(gc, _settingsRows(dctx, gc, ex)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _miniLabel(GymColors gc, String label) => Text(label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTheme.f(9.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 0.8));

  String _ago(DateTime date) {
    final days = MinimalInsights.daysSince(date);
    return days <= 0 ? 'Today' : days == 1 ? 'Yesterday' : '${days}d ago';
  }

  Widget _miniStats(GymColors gc, Exercise ex, List<({DateTime date, LoggedExercise ex})> history, PersonalRecord? pr) {
    final sets = history.fold<int>(0, (n, h) => n + h.ex.workingSets.length);
    Widget cell(String label, String value, String sub) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _miniLabel(gc, label),
            const SizedBox(height: 4),
            FitText(value, style: AppTheme.f(19, weight: FontWeight.w800, color: gc.text, height: 1.1)),
            const SizedBox(height: 3),
            Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.f(10, weight: FontWeight.w500, color: gc.textTertiary)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: gc.border))),
      child: Row(children: [
        cell('Best', pr == null ? '–' : fit.recordLabel(pr),
            pr == null || pr.kind != PrKind.weight || fit.isAssisted(ex.id) ? '' : 'est. ${fit.rmLabel(ex.id)} ${fit.weightLabel(fit.repMaxOf(ex.id, pr.oneRm))}'),
        cell('Last done', _ago(history.first.date), _fmtDate(history.first.date)),
        cell('Sessions', '${history.length}', '$sets sets'),
      ]),
    );
  }

  Widget _miniNext(GymColors gc, Exercise ex) {
    final next = fit.nextTargetLabel(ex.id);
    if (next == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        SvgPathIcon(Ic.trendUp, size: 13, color: gc.ember),
        const SizedBox(width: 7),
        Text('Next  ', style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary)),
        Flexible(
          child: Text(next,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.f(12, weight: FontWeight.w700, color: gc.text)),
        ),
      ]),
    );
  }

  Widget _miniRecords(
      GymColors gc, Exercise ex, List<({DateTime date, LoggedExercise ex})> history, PersonalRecord pr) {
    final cells = <(String, String, DateTime?)>[];
    final oldestFirst = history.reversed.toList();
    if (pr.kind == PrKind.weight && !fit.isAssisted(ex.id)) {
      var oneRm = 0.0, setVol = 0.0;
      DateTime? oneRmDate, setVolDate;
      ({LoggedSet set, DateTime date})? heavy;
      for (final h in oldestFirst) {
        for (final st in h.ex.workingSets) {
          if (st.reps <= 0) continue;
          if (st.oneRm > oneRm + 0.001) {
            oneRm = st.oneRm;
            oneRmDate = h.date;
          }
          final v = st.weight * st.reps;
          if (v > setVol + 0.001) {
            setVol = v;
            setVolDate = h.date;
          }
          if (heavy == null || st.weight > heavy.set.weight) heavy = (set: st, date: h.date);
        }
      }
      final session = fit.bestWorkout(ex.id, PrKind.weight);
      if (heavy != null) {
        cells.add(('Heaviest set', ltr('${fit.weightLabel(heavy.set.weight)} × ${heavy.set.reps}'), heavy.date));
      }
      if (oneRm > 0) cells.add(('Est. ${fit.rmLabel(ex.id)}', fit.weightLabel(fit.repMaxOf(ex.id, oneRm)), oneRmDate));
      if (setVol > 0) cells.add(('Best set volume', fit.weightLabel(setVol), setVolDate));
      if (session != null) {
        cells.add(('Best session volume', fit.bestWorkoutLabel(session.score, PrKind.weight), session.date));
      }
    } else {
      DateTime? bestDate;
      for (final h in oldestFirst) {
        if (h.ex.workingSets.any((st) => pr.kind.score(st) >= pr.best - 0.001)) {
          bestDate = h.date;
          break;
        }
      }
      cells.add(('Best', fit.recordLabel(pr), bestDate));
      final session = fit.bestWorkout(ex.id, PrKind.reps);
      if (pr.kind == PrKind.reps && session != null) {
        cells.add(('Best session reps', fit.bestWorkoutLabel(session.score, PrKind.reps), session.date));
      }
    }
    if (cells.length < 2 && pr.kind != PrKind.weight) return const SizedBox.shrink();
    Widget cell((String, String, DateTime?) c) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _miniLabel(gc, c.$1),
              const SizedBox(height: 3),
              FitText(c.$2, style: AppTheme.f(13.5, weight: FontWeight.w700, color: gc.text)),
              if (c.$3 != null) ...[
                const SizedBox(height: 2),
                Text(_fmtDate(c.$3!), style: AppTheme.f(10, weight: FontWeight.w500, color: gc.textTertiary)),
              ],
            ]),
          ),
        );
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      rows.add(Row(children: [
        cell(cells[i]),
        const SizedBox(width: 12),
        i + 1 < cells.length ? cell(cells[i + 1]) : const Expanded(child: SizedBox.shrink()),
      ]));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _section(gc, 'Records'),
        const SizedBox(height: 2),
        ...rows,
      ]),
    );
  }

  Widget _miniRepRecords(GymColors gc, Exercise ex) {
    final records = fit.repRecords(ex.id);
    if (records.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _miniLabel(gc, 'Best weight by reps'),
        const SizedBox(height: 6),
        Row(children: [
          for (final r in records)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  border: Border.all(color: gc.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(children: [
                  Text('${r.reps} rep${r.reps == 1 ? '' : 's'}',
                      style: AppTheme.f(9.5, weight: FontWeight.w600, color: gc.textTertiary)),
                  const SizedBox(height: 2),
                  FitText(fit.weightValue(r.kg),
                      style: AppTheme.f(12.5, weight: FontWeight.w700, color: gc.text)),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _miniChart(
      GymColors gc, Exercise ex, List<({DateTime date, LoggedExercise ex})> history, PersonalRecord pr) {
    final assisted = fit.isAssisted(ex.id);
    final options = <(String, String)>[
      if (pr.kind == PrKind.weight && !assisted) ...[('1rm', fit.rmLabel(ex.id)), ('weight', 'Weight'), ('volume', 'Volume')],
      if (pr.kind == PrKind.weight && assisted) ...const [('weight', 'Assist')],
      if (pr.kind == PrKind.reps) ...const [('reps', 'Best reps'), ('total', 'Total reps')],
      if (pr.kind == PrKind.time) ...const [('time', 'Best time')],
      if (pr.kind == PrKind.distance) ...const [('distance', 'Distance')],
    ];
    if (options.isEmpty) return const SizedBox.shrink();
    final metric = options.any((o) => o.$1 == _metric) ? _metric : options.first.$1;
    double value(LoggedExercise e) {
      final w = e.workingSets;
      return switch (metric) {
        '1rm' => fit.toDisplayWeight(fit.repMaxOf(ex.id, e.bestOneRm)),
        'weight' => fit.toDisplayWeight(fit.headlineWeight(e)),
        'volume' => fit.toDisplayWeight(e.volume),
        'reps' => w.fold<int>(0, (m, s) => math.max(m, s.reps)).toDouble(),
        'total' => w.fold<int>(0, (n, s) => n + s.reps).toDouble(),
        'time' => w.fold<int>(0, (m, s) => math.max(m, s.sec ?? 0)).toDouble(),
        _ => w.fold<double>(0, (n, s) => n + (s.km ?? 0)),
      };
    }

    String label(double v) => switch (metric) {
          '1rm' || 'weight' || 'volume' => '${fmt(v.roundToDouble() == v ? v : (v * 10).round() / 10)} ${fit.units}',
          'time' => durationLabel(v.round()),
          'distance' => fit.distanceLabel(v),
          _ => '${v.round()}',
        };

    final end = DateTime.now();
    final start = _rangeDays == 0 ? DateTime(2000) : end.subtract(Duration(days: _rangeDays));
    final points = [
      for (final h in history.reversed)
        if (!h.date.isBefore(start) && value(h.ex) > 0) (date: h.date, v: value(h.ex)),
    ];
    final delta = points.length > 1 ? points.last.v - points.first.v : 0.0;
    final sign = delta >= 0 ? '+' : '−';

    Widget chip(String text, bool on, VoidCallback onTap) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(right: 5),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: on ? gc.emberSoft : Colors.transparent,
              border: Border.all(color: on ? gc.ember : gc.border),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(text,
                style: AppTheme.f(9.5, weight: FontWeight.w700, color: on ? gc.ember : gc.textTertiary)),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: options.length > 1
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final o in options) chip(o.$2, o.$1 == metric, () => setState(() => _metric = o.$1)),
                    ]),
                  )
                : _section(gc, options.first.$2),
          ),
          for (final r in const [(28, '4W'), (84, '12W'), (365, '1Y'), (0, 'All')])
            chip(r.$2, _rangeDays == r.$1, () => setState(() => _rangeDays = r.$1)),
        ]),
        const SizedBox(height: 10),
        if (points.length < 2)
          Text(t.minimalExerciseTrendEmpty, style: AppTheme.f(11, color: gc.textSecondary))
        else ...[
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(label(points.last.v), style: AppTheme.f(15, weight: FontWeight.w800, color: gc.text)),
            const SizedBox(width: 8),
            Text('$sign${label(delta.abs())} in range',
                style: AppTheme.f(10.5, weight: FontWeight.w500, color: gc.textSecondary)),
          ]),
          const SizedBox(height: 8),
          TrendChart(
            values: [for (final p in points) p.v],
            labels: [for (final p in points) _fmtDate(p.date)],
            lowerBetter: assisted,
            height: 84,
            scale: fmt,
          ),
          const SizedBox(height: 3),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_fmtDate(points.first.date),
                style: AppTheme.f(9.5, weight: FontWeight.w500, color: gc.textTertiary)),
            Text(_fmtDate(points.last.date),
                style: AppTheme.f(9.5, weight: FontWeight.w500, color: gc.textTertiary)),
          ]),
        ],
      ]),
    );
  }

  List<Widget> _settingsRows(BuildContext context, GymColors gc, Exercise ex) {
    final mode = fit.modeOf(ex.id);
    final repsOnly = fit.isRepsOnly(ex.id);
    return [
      _modeRow(context, gc, ex.id, mode),
      if (mode != 'cardio') _repsOnlyRow(gc, ex.id, repsOnly),
      if (mode == 'time') ...[
        _switchRow(
          gc,
          PhosphorIconsRegular.arrowsLeftRight,
          t.eachSide,
          t.eachSideHint,
          fit.isEachSide(ex.id),
          () => fit.toggleEachSide(ex.id),
        ),
        if (!fit.isEachSide(ex.id)) _keepCountingRow(gc, ex.id),
        _holdProgressRow(gc, ex.id),
      ] else if (mode.isEmpty)
        _switchRow(
          gc,
          PhosphorIconsRegular.arrowsLeftRight,
          t.eachSide,
          t.eachSideRepsHint,
          fit.isSidedReps(ex.id),
          () => fit.toggleSidedReps(ex.id),
        ),
      if (mode == 'cardio') _keepCountingRow(gc, ex.id),
      _restRow(gc, ex.id),
      if (ex.equipment == 'Barbell' || ex.equipment == 'Machine') _barRow(gc, ex),
      if ((ex.equipment == 'Machine' || ex.equipment == 'Cable') && mode.isEmpty && !repsOnly)
        _stackRow(context, gc, ex.id),
      _switchRow(
        gc,
        PhosphorIconsRegular.sparkle,
        t.suggestInWorkouts,
        t.suggestInWorkoutsHint,
        fit.suggests(ex.id),
        () => fit.toggleSuggest(ex.id),
      ),
      if (!repsOnly && mode.isEmpty) ...[
        _switchRow(
          gc,
          PhosphorIconsRegular.arrowFatLinesDown,
          t.assistedSetting,
          t.assistedSettingHint,
          fit.isAssisted(ex.id),
          () => fit.toggleAssisted(ex.id),
        ),
        if (fit.canPair(ex.id))
          _switchRow(
            gc,
            PhosphorIconsRegular.barbell,
            t.pairSetting,
            t.pairSettingHint,
            fit.isPaired(ex.id),
            () => fit.togglePaired(ex.id),
          ),
        _repMaxRow(context, gc, ex.id),
        _progressRow(context, gc, ex.id),
        _switchRow(
          gc,
          PhosphorIconsRegular.fire,
          t.autoWarmup,
          t.autoWarmupHint,
          fit.warmsUp(ex.id),
          () => fit.toggleAutoWarmup(ex.id),
        ),
      ],
    ];
  }

  Widget _settingsRow(BuildContext context, GymColors gc, Exercise ex) {
    final mode = fit.modeOf(ex.id);
    final values = [
      (t.restTimer, fit.restFor(ex.id) == 0 ? t.restOff : clockLabel(fit.restFor(ex.id))),
      if (mode.isEmpty)
        (t.progression, progressKindName(fit.progressRule(ex.id).kind))
      else
        (t.exerciseTypeLabel, _modeName(mode)),
    ];
    return Semantics(
      button: true,
      label: t.exerciseSettings,
      child: Pressable(
        onTap: () => _openSettings(context, ex.id),
        scale: 0.98,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: gc.bgRaised,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _rowIcon(gc, PhosphorIconsRegular.slidersHorizontal, true),
                  Expanded(
                    child: Text(t.exerciseSettings,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.f(14.5, weight: FontWeight.w600, color: gc.text)),
                  ),
                  const SizedBox(width: 12),
                  Icon(PhosphorIconsRegular.caretRight, size: 15, color: gc.textTertiary),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < values.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                        decoration: BoxDecoration(color: gc.bgRaised2, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _cardLabel(gc, values[i].$1),
                            const SizedBox(height: 4),
                            Text(values[i].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.f(13.5, weight: FontWeight.w700, color: gc.text)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSettings(BuildContext context, String id) {
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => AnimatedBuilder(
        animation: fit,
        builder: (sheet, _) {
          final gc = sheet.gc;
          final ex = fit.exerciseById(id);
          if (ex == null) return const SizedBox.shrink();
          return Container(
            padding: sheetPad(sheet),
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.86),
            decoration: sheetDecoration(gc),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const SizedBox(height: 16),
                SheetTitle(t.exerciseSettings, subtitle: exerciseName(ex)),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: _group(gc, _settingsRows(sheet, gc, ex)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _fold(GymColors gc, String label, bool open, VoidCallback onToggle, List<Widget> children,
      {Widget? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onToggle();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(children: [
                Expanded(child: _section(gc, label)),
                ?trailing,
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Icon(PhosphorIconsBold.caretDown, size: 14, color: gc.textTertiary),
                ),
              ]),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _heading(GymColors gc, String title, {VoidCallback? onMore}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(children: [
        Expanded(child: _section(gc, title)),
        if (onMore != null)
          Semantics(
            button: true,
            child: Pressable(
              onTap: onMore,
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: gc.bgRaised, borderRadius: BorderRadius.circular(15)),
                child: Text(t.healthSeeAll, style: AppTheme.f(12, weight: FontWeight.w700, color: gc.text)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _notHere(GymColors gc, Exercise ex) {
    final place = fit.activePlace!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: gc.bgRaised,
        border: Border.all(color: gc.warn.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.mapPin, size: 16, color: gc.warn),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t.notHere(t.equipment(ex.equipment).toLowerCase(), place.name),
                    style: AppTheme.f(14, weight: FontWeight.w600, color: gc.text)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 26),
            child: Text(t.notHereWhy, style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary, height: 1.4)),
          ),
          const SizedBox(height: 14),
          Text(t.altHere,
              style: AppTheme.f(10.5,
                  weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          for (final alt in fit.alternativesHere(ex, 3)) _similarRow(gc, alt),
        ],
      ),
    );
  }

  String _setsLine(LoggedExercise e) {
    final rpe = e.sets.map((s) => s.rpe).whereType<double>().toList();
    final sets = t.setCount(e.sets.length);
    if (rpe.isEmpty) return sets;
    return '$sets · ${fit.effortLabel(rpe.reduce((a, b) => a > b ? a : b))}';
  }

  String _bestOf(LoggedExercise e, String mode) {
    final working = e.workingSets;
    if (working.isEmpty) return '';
    if (mode == 'cardio') {
      final km = working.fold<double>(0, (s, x) => s + (x.km ?? 0));
      return km > 0
          ? fit.distanceLabelFor(e.id, km)
          : durationLabel(working.fold<int>(0, (s, x) => s + (x.sec ?? 0)));
    }
    return durationLabel(working.fold<int>(0, (s, x) => (x.sec ?? 0) > s ? x.sec! : s));
  }

  Widget _historyRow(GymColors gc, ({DateTime date, LoggedExercise ex}) h, bool border, String mode) {
    final e = h.ex;
    final compact = fit.minimalMode;
    final vertical = compact
        ? switch (fit.minimalRowHeight) {
            'tight' => 4.0,
            'roomy' => 9.0,
            _ => 6.0,
          }
        : 13.0;
    if (mode.isNotEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: vertical),
        decoration: BoxDecoration(
          border: border ? Border(bottom: BorderSide(color: gc.border.withValues(alpha: 0.55))) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fmtDate(h.date), style: AppTheme.f(compact ? 12.5 : 14.5, weight: FontWeight.w600, color: gc.text)),
                  const SizedBox(height: 3),
                  Text(fit.setsSummary(e.sets),
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.f(compact ? 10.5 : 12, weight: FontWeight.w500, color: gc.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(_bestOf(e, mode), style: AppTheme.f(compact ? 14 : 17, weight: FontWeight.w700, color: gc.text)),
          ],
        ),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(vertical: vertical),
      decoration: BoxDecoration(
        border: border
            ? Border(bottom: BorderSide(color: gc.border.withValues(alpha: 0.55)))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_fmtDate(h.date),
                  style: AppTheme.f(compact ? 12.5 : 14.5, weight: FontWeight.w600, color: gc.text)),
              const SizedBox(height: 3),
              Text(_setsLine(e),
                  style: AppTheme.f(compact ? 10.5 : 12, weight: FontWeight.w500, color: gc.textSecondary)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fit.weightLabel(fit.headlineWeight(e)),
                  style: AppTheme.f(17, weight: FontWeight.w700, color: gc.text)),
              const SizedBox(height: 3),
              Text(t.volumeSuffix(fit.volumeLabel(e.volume)),
                  style: AppTheme.f(compact ? 10 : 11.5, weight: FontWeight.w500, color: gc.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _notesRow(GymColors gc, String exId) {
    final n = fit.notesFor(exId).length;
    final compact = fit.minimalMode;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => fit.goNotes(exerciseId: exId, all: true),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16, vertical: compact ? 8 : 13),
          decoration: BoxDecoration(
            color: compact ? Colors.transparent : gc.bgRaised,
            border: compact ? Border(bottom: BorderSide(color: gc.border)) : null,
            borderRadius: BorderRadius.circular(compact ? 0 : 20),
          ),
          child: Row(
            children: [
              _rowIcon(gc, PhosphorIconsRegular.notebook, n > 0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleCase(t.notes),
                        style: AppTheme.f(14.5, weight: FontWeight.w500, color: gc.text)),
                    const SizedBox(height: 3),
                    Text(n == 0 ? t.noteNoneForExercise : t.noteCount(n),
                        style: AppTheme.f(11.5,
                            weight: FontWeight.w500, color: gc.textSecondary)),
                  ],
                ),
              ),
              Icon(PhosphorIconsRegular.caretRight, size: 15, color: gc.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addToRoutineRow(BuildContext context, GymColors gc, Exercise ex) {
    final n = fit.routinesWith(ex.id);
    final compact = fit.minimalMode;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: () => _pickRoutine(context, ex),
        scale: 0.98,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16, vertical: compact ? 8 : 13),
          decoration: BoxDecoration(
            color: compact ? Colors.transparent : gc.bgRaised,
            border: compact ? Border(bottom: BorderSide(color: gc.border)) : null,
            borderRadius: BorderRadius.circular(compact ? 0 : 20),
          ),
          child: Row(
            children: [
              _rowIcon(gc, PhosphorIconsRegular.listPlus, n > 0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.addToRoutine, style: AppTheme.f(14.5, weight: FontWeight.w600, color: gc.text)),
                    const SizedBox(height: 3),
                    Text(t.inRoutines(n),
                        style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: gc.text, shape: BoxShape.circle),
                child: Icon(PhosphorIconsBold.plus, size: 14, color: gc.bg),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickRoutine(BuildContext context, Exercise ex) {
    final gc = context.gc;
    final routines = [
      for (final group in fit.routineGroups) ...fit.routinesInGroup(group),
      ...fit.routinesInGroup(''),
    ];
    void pick(BuildContext sheet, String? id) {
      Navigator.pop(sheet);
      fit.addToRoutineAndEdit(id, ex.id);
    }

    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.72),
        padding: sheetPad(sheet),
        decoration: sheetDecoration(gc),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            SheetTitle(titleCase(t.addToRoutine)),
            const SizedBox(height: 4),
            Text(exerciseName(ex),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary)),
            const SizedBox(height: 14),
            Flexible(
              child: OptionGroup(
                scroll: true,
                [
                  OptionItem(
                    t.newRoutineName,
                    icon: PhosphorIconsRegular.plus,
                    onTap: () => pick(sheet, null),
                  ),
                  for (final r in routines)
                    OptionItem(
                      fit.routineTitle(r),
                      detail: fit.routineHas(r.id, ex.id)
                          ? t.alreadyInRoutine
                          : (r.group.isEmpty ? null : r.group),
                      selected: fit.routineHas(r.id, ex.id),
                      onTap: () => pick(sheet, r.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _similarRow(GymColors gc, Exercise s) {
    return GestureDetector(
      onTap: () => fit.openExercise(s.id),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
        decoration: BoxDecoration(
          color: gc.bgRaised,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: ExerciseMedia(ex: s, height: 48, radius: 14, bordered: false),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exerciseName(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.f(14.5, weight: FontWeight.w600, color: gc.text)),
                  const SizedBox(height: 4),
                  Text(t.equipment(s.equipment),
                      style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary)),
                ],
              ),
            ),
            SvgPathIcon(Ic.chevronRight, size: 15, color: gc.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _meta(GymColors gc, String label, String value, {VoidCallback? onTap}) {
    final compact = fit.minimalMode;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: _cardLabel(gc, label)),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(PhosphorIconsRegular.pencilSimple, size: 11, color: gc.textTertiary),
          ],
        ]),
        SizedBox(height: compact ? 3 : 5),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.f(compact ? 11.5 : 14.5, weight: FontWeight.w600, color: gc.text)),
      ],
    );
    return Flexible(
      child: onTap == null
          ? column
          : Semantics(
              button: true,
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: column),
            ),
    );
  }

  void _editSecondary(BuildContext context, String id) {
    showAppSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheet) => AnimatedBuilder(
        animation: fit,
        builder: (sheet, _) {
          final gc = sheet.gc;
          final ex = fit.exerciseById(id);
          if (ex == null) return const SizedBox.shrink();
          return Container(
            padding: sheetPad(sheet),
            decoration: sheetDecoration(gc),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const SizedBox(height: 16),
                SheetTitle(exerciseName(ex), subtitle: t.secondaryPickHint),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final m in kMuscles)
                    if (m.id != ex.primary)
                      Pill(
                        label: t.muscle(m.id),
                        bg: ex.secondary.contains(m.id) ? gc.ember : gc.bgRaised2,
                        fg: ex.secondary.contains(m.id) ? gc.onEmber : gc.textSecondary,
                        vPad: 7,
                        onTap: () => fit.setSecondary(
                            id,
                            ex.secondary.contains(m.id)
                                ? [...ex.secondary.where((s) => s != m.id)]
                                : [...ex.secondary, m.id]),
                      ),
                ]),
                if (fit.hasSecondaryOverride(id))
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => fit.resetSecondary(id),
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.only(top: 8),
                      alignment: Alignment.center,
                      child: Text(t.alarmReset,
                          style: AppTheme.f(13, weight: FontWeight.w600, color: gc.accent)),
                    ),
                  )
                else
                  const SizedBox(height: 18),
                PrimaryButton(label: t.done, onTap: () => Navigator.of(sheet).pop()),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Exercise ex) async {
    final ok = await askConfirm(
      context,
      title: t.deleteExerciseTitle,
      body: t.deleteExerciseBody(exerciseName(ex)),
      confirmLabel: t.delete,
      danger: true,
    );
    if (!ok) return;
    fit.closeExerciseDetail();
    fit.deleteCustomExercise(ex.id);
  }

  Future<void> _merge(BuildContext context, Exercise ex) async {
    final toId = await showAppSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MergeTargetSheet(from: ex),
    );
    if (toId == null || !context.mounted) return;
    final to = fit.exerciseById(toId);
    if (to == null) return;
    final ok = await askConfirm(
      context,
      title: t.mergeExerciseTitle,
      body: t.mergeExerciseBody(exerciseName(ex), exerciseName(to)),
      confirmLabel: t.mergeExercise,
    );
    if (!ok || !context.mounted) return;
    fit.mergeExerciseInto(ex.id, to.id);
    showNotchToast(
      context,
      t.mergedToast,
      subtitle: exerciseName(to),
      icon: PhosphorIconsRegular.gitMerge,
      accent: context.gc.accent,
    );
  }

  void _toggleArchived(BuildContext context, Exercise ex) {
    fit.toggleArchived(ex.id);
    if (!fit.isArchived(ex.id)) return;
    showNotchToast(
      context,
      t.archivedToast,
      subtitle: t.archivedToastHint,
      icon: PhosphorIconsFill.archive,
      accent: context.gc.accent,
      action: t.undo,
      onTap: () => fit.toggleArchived(ex.id),
      duration: const Duration(milliseconds: 3600),
    );
  }

  Widget _archivedBanner(GymColors gc, Exercise ex) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(color: gc.accentSoft, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(PhosphorIconsFill.archive, size: 17, color: gc.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(t.archivedBanner,
                style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.text, height: 1.35)),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => fit.toggleArchived(ex.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(t.restoreExercise,
                  style: AppTheme.f(13, weight: FontWeight.w700, color: gc.accent)),
            ),
          ),
        ]),
      );

  Widget _bests(GymColors gc, String id, PrKind record) {
    final set = record == PrKind.weight ? fit.bestSet(id) : null;
    final kind = record == PrKind.weight && fit.isAssisted(id) ? PrKind.reps : record;
    final work = fit.bestWorkout(id, kind);
    if (work == null) return const SizedBox.shrink();
    Widget cell(String label, String value, DateTime date) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _cardLabel(gc, label),
            const SizedBox(height: 6),
            FitText(value, style: AppTheme.f(17, weight: FontWeight.w700, color: gc.text, height: 1)),
            const SizedBox(height: 4),
            Text(_fmtDate(date), style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textTertiary)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(children: [
        if (set != null) cell(t.prBestSet, ltr('${fit.weightLabel(set.set.weight)} × ${set.set.reps}'), set.date),
        if (set != null) const SizedBox(width: 12),
        cell(t.prBestWorkout, fit.bestWorkoutLabel(work.score, kind), work.date),
      ]),
    );
  }

  Widget _cardLabel(GymColors gc, String label) => FitText(label.toUpperCase(),
      style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4));

  Widget _section(GymColors gc, String label) => Text(titleCase(label),
      style: AppTheme.f(fit.minimalMode ? 14 : 18, weight: FontWeight.w700, color: gc.text));

  Widget _group(GymColors gc, List<Widget> rows) {
    final compact = fit.minimalMode;
    return Container(
      decoration: BoxDecoration(
        color: compact ? Colors.transparent : gc.bgRaised,
        border: compact ? Border.all(color: gc.border) : null,
        borderRadius: BorderRadius.circular(compact ? 4 : 20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              Container(
                height: 1,
                margin: EdgeInsetsDirectional.only(start: compact ? 8 : 16),
                color: gc.border.withValues(alpha: 0.55),
              ),
          ],
        ],
      ),
    );
  }

  Widget _step(GymColors gc, int n, String text) {
    final compact = fit.minimalMode;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 19 : 24,
          height: compact ? 19 : 24,
          decoration: BoxDecoration(color: gc.emberSoft, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$n', style: AppTheme.f(compact ? 10 : 12, weight: FontWeight.w700, color: gc.ember)),
        ),
        SizedBox(width: compact ? 8 : 12),
        Expanded(
          child: Text(text,
              style: AppTheme.f(compact ? 12 : 14, weight: FontWeight.w500, color: gc.textSecondary, height: compact ? 1.35 : 1.5)),
        ),
      ],
    );
  }

  Widget _star(GymColors gc, bool fav) => FavoriteStar(on: fav);

  Widget _stackRow(BuildContext context, GymColors gc, String id) {
    final stack = fit.ownStackFor(id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showWeightStackSheet(context, id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          _rowIcon(gc, PhosphorIconsRegular.stack, stack != null),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.weightStack, style: AppTheme.f(14.5, weight: FontWeight.w500, color: gc.text)),
              const SizedBox(height: 3),
              Text(
                  stack == null
                      ? t.weightStackOff
                      : '${fit.weightValueFor(id, stack.first)}–${fit.weightValueFor(id, stack.last)} ${fit.unitsFor(id)} · ${t.stackCount(stack.length)}',
                  style: AppTheme.f(11.5, weight: FontWeight.w500, color: stack != null ? gc.accent : gc.textSecondary)),
            ]),
          ),
          Icon(PhosphorIconsRegular.caretRight, size: 15, color: gc.textTertiary),
        ]),
      ),
    );
  }

  Widget _holdProgressRow(GymColors gc, String id) {
    final step = fit.holdStepFor(id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _rowIcon(gc, PhosphorIconsRegular.trendUp, step > 0),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.holdProgress, style: AppTheme.f(14.5, weight: FontWeight.w500, color: gc.text)),
            const SizedBox(height: 3),
            Text(step > 0 ? t.holdProgressOn(step) : t.holdProgressHint,
                style: AppTheme.f(11.5, weight: FontWeight.w500, color: step > 0 ? gc.accent : gc.textSecondary)),
          ]),
        ),
        const SizedBox(width: 12),
        StepperControl(
          value: step == 0 ? t.restOff : '+$step s',
          minWidth: 44,
          btnSize: 30,
          onDec: () => fit.cycleHoldStep(id, -1),
          onInc: () => fit.cycleHoldStep(id, 1),
        ),
      ]),
    );
  }

  Widget _restRow(GymColors gc, String id) {
    final custom = fit.hasCustomRest(id);
    final seconds = fit.restFor(id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _rowIcon(gc, PhosphorIconsRegular.timer, custom),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleCase(t.restForExercise),
                    style: AppTheme.f(14.5, weight: FontWeight.w500, color: gc.text)),
                const SizedBox(height: 3),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: custom ? () => fit.setExerciseRest(id, null) : null,
                  child: Text(custom ? t.restCustom : t.restUsingDefault,
                      style: AppTheme.f(11.5,
                          weight: FontWeight.w500,
                          color: custom ? gc.accent : gc.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StepperControl(
            value: seconds == 0 ? t.restOff : clockLabel(seconds),
            minWidth: 44,
            btnSize: 30,
            gap: 3,
            fontSize: 14,
            btnRadius: 10,
            onDec: () => fit.setExerciseRest(id, seconds - 15),
            onInc: () => fit.setExerciseRest(id, seconds + 15),
            onEdit: () async {
              final v = await askRuler(context,
                  title: t.restForExercise,
                  value: seconds.toDouble(),
                  min: 0,
                  max: 600,
                  step: 5,
                  majorEvery: 6,
                  format: (v) => clockLabel(v.round()),
                  tickLabel: (v) => clockLabel(v.round()));
              if (v != null) fit.setExerciseRest(id, v.round());
            },
          ),
        ],
      ),
    );
  }

  Widget _repMaxRow(BuildContext context, GymColors gc, String id) {
    final n = fit.rmRepsOf(id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _rowIcon(gc, PhosphorIconsRegular.barbell, n > 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rep max shown', style: AppTheme.f(14.5, weight: FontWeight.w500, color: gc.text)),
                const SizedBox(height: 3),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: n > 1 ? () => fit.setRmReps(id, 1) : null,
                  child: Text(
                    n > 1 ? 'The chart and records use your ${n}RM. Tap for 1RM.' : 'The chart and records use your 1RM. Pick any rep count.',
                    style: AppTheme.f(11.5, weight: FontWeight.w500, color: n > 1 ? gc.accent : gc.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StepperControl(
            key: const ValueKey('rep-max-stepper'),
            value: '${n}RM',
            minWidth: 44,
            btnSize: 30,
            gap: 3,
            fontSize: 14,
            btnRadius: 10,
            onDec: () => fit.setRmReps(id, n - 1),
            onInc: () => fit.setRmReps(id, n + 1),
            onEdit: () async {
              final v = await askRuler(context,
                  title: 'Rep max shown',
                  value: n.toDouble(),
                  min: 1,
                  max: 30,
                  step: 1,
                  majorEvery: 5,
                  format: (v) => '${v.round()}RM',
                  tickLabel: (v) => '${v.round()}');
              if (v != null) fit.setRmReps(id, v.round());
            },
          ),
        ],
      ),
    );
  }

  Widget _barRow(GymColors gc, Exercise ex) {
    final own = fit.hasOwnBar(ex.id);
    final bar = fit.barFor(ex.id, equipment: ex.equipment);
    final step = fit.weightStep;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _rowIcon(gc, PhosphorIconsRegular.barbell, own),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleCase(t.barWeightExercise), style: AppTheme.f(14.5, weight: FontWeight.w500, color: gc.text)),
                const SizedBox(height: 3),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: own ? () => fit.setExerciseBar(ex.id, null) : null,
                  child: Text(own ? t.barWeightCustom : t.barWeightHint,
                      style: AppTheme.f(11.5, weight: FontWeight.w500, color: own ? gc.accent : gc.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StepperControl(
            value: ltr('${fmt(bar)} ${fit.units}'),
            minWidth: 56,
            btnSize: 30,
            gap: 3,
            fontSize: 14,
            btnRadius: 10,
            onDec: () => fit.setExerciseBar(ex.id, bar - step),
            onInc: () => fit.setExerciseBar(ex.id, bar + step),
            onEdit: () async {
              final v = await askNumber(context, title: t.barWeightExercise, initial: fmt(bar), decimal: true);
              if (v != null) fit.setExerciseBar(ex.id, v);
            },
          ),
        ],
      ),
    );
  }

  Widget _rowIcon(GymColors gc, IconData icon, bool on) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 14),
        child: SizedBox(
          width: 22,
          child: Icon(icon, size: 19, color: on ? gc.text : gc.textSecondary),
        ),
      );

  Widget _goalCard(BuildContext context, GymColors gc, String id) {
    final goal = fit.exerciseGoals[id];
    if (goal == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _editGoal(context, id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: gc.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Icon(PhosphorIconsRegular.target, size: 18, color: gc.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(t.goalSet, style: AppTheme.f(13.5, weight: FontWeight.w600, color: gc.text))),
            Icon(PhosphorIconsRegular.plus, size: 15, color: gc.textTertiary),
          ]),
        ),
      );
    }
    final best = fit.goalBest(id);
    final done = best >= goal.target;
    final share = goal.target <= 0 ? 1.0 : (best / goal.target).clamp(0.0, 1.0);
    final due = goal.due;
    final today = DateTime.now();
    final days = due == null ? null : DateTime(due.year, due.month, due.day).difference(DateTime(today.year, today.month, today.day)).inDays;
    final when = done || due == null
        ? null
        : days! < 0
            ? t.goalOverdue
            : '${t.goalDaysLeft(days)} · ${t.shortDate(due)}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _editGoal(context, id),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: gc.bgRaised,
          border: Border.all(color: done ? gc.ember : Colors.transparent),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardLabel(gc, t.goal),
                      const SizedBox(height: 8),
                      Text(fit.goalLabel(id, goal.target),
                          style: AppTheme.f(26, weight: FontWeight.w800, color: gc.text, height: 1)),
                    ],
                  ),
                ),
                Text(done ? t.goalReached : t.goalToGo(fit.goalLabel(id, goal.target - best)),
                    style: AppTheme.f(12.5, weight: FontWeight.w600, color: done ? gc.ember : gc.textSecondary)),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 6,
                backgroundColor: gc.bgRaised2,
                valueColor: AlwaysStoppedAnimation(done ? gc.ember : gc.accent),
              ),
            ),
            if (when != null) ...[
              const SizedBox(height: 10),
              Text(when,
                  style: AppTheme.f(11.5,
                      weight: FontWeight.w500, color: days! < 0 ? gc.ember : gc.textTertiary)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editGoal(BuildContext context, String id) async {
    final reps = fit.goalKind(id) == PrKind.reps;
    final current = fit.exerciseGoals[id];
    final best = fit.goalBest(id);
    var target = current?.target ??
        (reps ? math.max(best + 5, 10.0) : fit.fromDisplayWeight(fit.toDisplayWeight(best) + fit.weightStep * 4));
    DateTime? due = current?.due;
    String shown() => reps ? '${target.round()}' : ltr('${fit.weightValue(target)} ${fit.units}');
    await showAppSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          final gc = sheet.gc;
          void bump(int dir) => setSheet(() {
                target = reps
                    ? math.max(1, target + dir).toDouble()
                    : math.max(0, target + dir * fit.fromDisplayWeight(fit.weightStep)).toDouble();
              });
          return Container(
            padding: sheetPad(sheet),
            decoration: sheetDecoration(gc),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const SizedBox(height: 16),
                SheetTitle(titleCase(t.goal)),
                const SizedBox(height: 18),
                ToolGroup([
                  ToolRow(
                    label: reps ? t.goalTargetReps : t.targetWeight,
                    control: StepperControl(
                      value: shown(),
                      onDec: () => bump(-1),
                      onInc: () => bump(1),
                      onEdit: () async {
                        final v = await askNumber(sheet,
                            title: reps ? t.goalTargetReps : t.targetWeight,
                            initial: reps ? '${target.round()}' : fit.weightValue(target),
                            decimal: !reps);
                        if (v != null && v > 0) setSheet(() => target = reps ? v.roundToDouble() : fit.fromDisplayWeight(v));
                      },
                    ),
                  ),
                  ToolRow(
                    label: t.goalDeadline,
                    control: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: sheet,
                          initialDate: due ?? now.add(const Duration(days: 90)),
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365 * 3)),
                        );
                        if (picked != null) setSheet(() => due = picked);
                      },
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(due == null ? t.goalNoDeadline : t.shortDateYear(due!),
                            style: AppTheme.f(14, weight: FontWeight.w700, color: due == null ? gc.textTertiary : gc.text)),
                        if (due != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setSheet(() => due = null),
                            child: Icon(PhosphorIconsRegular.x, size: 14, color: gc.textTertiary),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: t.save,
                  onTap: () {
                    fit.setExerciseGoal(id, target, due);
                    Navigator.pop(sheet);
                  },
                ),
                if (current != null) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        fit.clearExerciseGoal(id);
                        Navigator.pop(sheet);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(t.goalRemove,
                            style: AppTheme.f(13, weight: FontWeight.w600, color: gc.textSecondary)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _nextCard(GymColors gc, String id) {
    final up = fit.nextTarget(id)?.up ?? fit.holdGoesUp(id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: gc.bgRaised,
        border: Border.all(color: up ? gc.ember : gc.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SvgPathIcon(Ic.trendUp, size: 18, color: up ? gc.ember : gc.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.nextTime,
                    style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4)),
                if (fit.nextWhy(id) case final why?) ...[
                  const SizedBox(height: 2),
                  Text(why, style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textTertiary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(fit.nextTargetLabel(id)!,
              style: AppTheme.f(20, weight: FontWeight.w800, color: up ? gc.ember : gc.text)),
        ],
      ),
    );
  }

  Widget _keepCountingRow(GymColors gc, String id) => _switchRow(
        gc,
        PhosphorIconsRegular.timer,
        t.keepCounting,
        t.keepCountingHint,
        fit.keepsCounting(id),
        () => fit.toggleKeepCounting(id),
      );

  Widget _switchRow(GymColors gc, IconData icon, String title, String hint, bool on,
      VoidCallback onTap) {
    return Semantics(
      button: true,
      toggled: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _rowIcon(gc, icon, on),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.f(14.5, weight: FontWeight.w500, color: gc.text)),
                    const SizedBox(height: 3),
                    Text(hint,
                        style: AppTheme.f(11.5,
                            weight: FontWeight.w500, color: gc.textSecondary, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TinySwitch(on: on),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressRow(BuildContext context, GymColors gc, String id) {
    final kind = fit.progressRule(id).kind;
    final on = fit.hasProgress(id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showProgressionSheet(context, id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: SizedBox(
                width: 22,
                child: SvgPathIcon(Ic.trendUp, size: 19, color: on ? gc.text : gc.textSecondary),
              ),
            ),
            Expanded(
              child: Text(t.progression, style: AppTheme.f(14.5, weight: FontWeight.w500, color: gc.text)),
            ),
            const SizedBox(width: 12),
            Text(progressKindName(kind), style: AppTheme.f(13, weight: FontWeight.w600, color: on ? gc.accent : gc.textSecondary)),
            const SizedBox(width: 6),
            Icon(PhosphorIconsRegular.caretRight, size: 15, color: gc.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _repsOnlyRow(GymColors gc, String id, bool on) {
    return Semantics(
      button: true,
      toggled: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => fit.toggleRepsOnly(id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _rowIcon(gc, PhosphorIconsRegular.scales, on),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fit.isTimed(id) ? t.timeOnly : t.repsOnly,
                        style: AppTheme.f(14.5, weight: FontWeight.w500, color: gc.text)),
                    const SizedBox(height: 3),
                    Text(t.repsOnlyHint,
                        style: AppTheme.f(11.5,
                            weight: FontWeight.w500, color: gc.textSecondary, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TinySwitch(on: on),
            ],
          ),
        ),
      ),
    );
  }

  String _modeName(String mode) => switch (mode) {
        'cardio' => t.typeCardio,
        'time' => t.typeTime,
        _ => t.typeReps,
      };

  Widget _modeRow(BuildContext context, GymColors gc, String id, String mode) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _pickMode(context, id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _rowIcon(gc, mode == 'cardio' ? PhosphorIconsRegular.personSimpleRun : PhosphorIconsRegular.listNumbers,
                mode.isNotEmpty),
            Expanded(
              child: Text(t.exerciseTypeLabel,
                  style: AppTheme.f(14.5, weight: FontWeight.w500, color: gc.text)),
            ),
            Text(_modeName(mode), style: AppTheme.f(13, weight: FontWeight.w600, color: gc.textSecondary)),
            const SizedBox(width: 6),
            Icon(PhosphorIconsRegular.caretRight, size: 15, color: gc.textTertiary),
          ],
        ),
      ),
    );
  }

  void _pickMode(BuildContext context, String id) {
    showAppSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => AnimatedBuilder(
        animation: fit,
        builder: (sheet, _) {
          final gc = sheet.gc;
          final now = fit.modeOf(id);
          return Container(
            padding: sheetPad(sheet),
            decoration: sheetDecoration(gc),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const SizedBox(height: 16),
                SheetTitle(t.exerciseTypeLabel),
                const SizedBox(height: 14),
                OptionGroup([
                  for (final (value, icon) in [
                    ('', PhosphorIconsRegular.barbell),
                    ('time', PhosphorIconsRegular.timer),
                    ('cardio', PhosphorIconsRegular.personSimpleRun),
                  ])
                    OptionItem(
                      _modeName(value),
                      icon: icon,
                      selected: now == value,
                      onTap: () {
                        fit.setExerciseMode(id, value);
                        Navigator.of(sheet).pop();
                      },
                    ),
                ]),
                const SizedBox(height: 12),
                Text(t.exerciseTypeHint,
                    textAlign: TextAlign.center,
                    style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textTertiary, height: 1.4)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _mediaBtn(GymColors gc, IconData icon, String semantic, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: semantic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: gc.bg.withValues(alpha: 0.82),
            shape: BoxShape.circle,
            border: Border.all(color: gc.border),
          ),
          child: Icon(icon, size: 16, color: gc.text),
        ),
      ),
    );
  }
}

class _MergeTargetSheet extends StatefulWidget {
  const _MergeTargetSheet({required this.from});

  final Exercise from;

  @override
  State<_MergeTargetSheet> createState() => _MergeTargetSheetState();
}

class _MergeTargetSheetState extends State<_MergeTargetSheet> {
  final TextEditingController _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final all = fit.mergeTargets(widget.from.id);
    final results = _q.text.trim().isEmpty ? all.take(40).toList() : all.where(exerciseSearch(_q.text)).take(60).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        padding: sheetPad(context, bottom: 16),
        decoration: sheetDecoration(gc),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            SheetTitle(t.mergeExerciseInto(exerciseName(widget.from))),
            const SizedBox(height: 14),
            SearchField(
              controller: _q,
              hint: t.searchAllExercises,
              color: gc.bgRaised2,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: OptionGroup(
                scroll: true,
                [
                  for (final ex in results)
                    OptionItem(
                      exerciseName(ex),
                      detail: muscleLabel(ex.primary),
                      onTap: () => Navigator.of(context).pop(ex.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

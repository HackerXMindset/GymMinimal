import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/live_session.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/widgets/stat_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bench = 'EIeI8Vf';

/// A bench session [daysAgo] days back at [hour]. [gap] is the seconds between
/// ticking one set and the next, 0 for a session without times.
LoggedSession _bench1(int daysAgo, double kg, {int hour = 18, double? rpe, int gap = 0, int sets = 3}) {
  final end = DateTime.now().subtract(Duration(days: daysAgo)).copyWith(hour: hour, minute: 0, second: 0, millisecond: 0);
  final base = end.millisecondsSinceEpoch ~/ 1000;
  return LoggedSession(end, 3000, [
    LoggedExercise(_bench, 'Barbell Bench Press', 'chest', [
      for (var i = 0; i < sets; i++) LoggedSet(5, kg, rpe: rpe, at: gap == 0 ? null : base + i * gap),
    ]),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    fit.setUnits('kg');
    fit.profile.weightKg = 80;
    setAppLanguage('en');
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();
  }

  group('switches and priority', () {
    test('every card is on by default, off sticks, and a reset turns them back on', () {
      for (final c in kStatCards) {
        expect(fit.statOn(c.id), isTrue, reason: c.id);
      }
      fit.setStatOn('score', false);
      expect(fit.statOn('score'), isFalse);
      final data = fit.toJson();
      fit.resetAllData();
      expect(fit.statOn('score'), isTrue);
      fit.applyBackup(data);
      expect(fit.statOn('score'), isFalse);
      fit.setStatOn('score', true);
      expect(fit.statsOff, isEmpty);
    });

    test('muscle priority moves the target band by 20% and survives a backup', () {
      expect(fit.zoneBand('chest'), (10.0, 20.0));
      fit.setMusclePriority('chest', 1);
      expect(fit.zoneBand('chest').$1, closeTo(12, 0.001));
      expect(fit.zoneBand('chest').$2, closeTo(24, 0.001));
      fit.setMusclePriority('back', -1);
      expect(fit.zoneBand('back').$1, closeTo(8, 0.001));
      final data = fit.toJson();
      fit.resetAllData();
      expect(fit.priorityOf('chest'), 0);
      fit.applyBackup(data);
      expect(fit.priorityOf('chest'), 1);
      expect(fit.priorityOf('back'), -1);
      fit.setMusclePriority('chest', 0);
      expect(fit.musclePriority.containsKey('chest'), isFalse);
    });

    test('every card id is unique and belongs to a known group', () {
      final ids = kStatCards.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
      final groups = kStatGroups.map((g) => g.$1).toSet();
      for (final c in kStatCards) {
        expect(groups, contains(c.group), reason: c.id);
      }
    });
  });

  group('calculations', () {
    test('a lift that stopped moving 4 weeks ago is stalled, one that keeps rising is not', () {
      // Rising for 4 weeks, then flat for the last 4.
      for (final (days, kg) in [(56, 80.0), (49, 82.5), (42, 85.0), (35, 87.5), (28, 90.0), (21, 90.0), (14, 90.0), (7, 90.0), (1, 90.0)]) {
        fit.sessions.add(_bench1(days, kg));
      }
      expect(fit.stalledWeeks(_bench), greaterThanOrEqualTo(3));
      expect(fit.stalledLifts.map((e) => e.id), contains(_bench));

      fit.sessions.clear();
      for (final (days, kg) in [(42, 80.0), (35, 82.5), (28, 85.0), (21, 87.5), (14, 90.0), (7, 92.5), (1, 95.0)]) {
        fit.sessions.add(_bench1(days, kg));
      }
      expect(fit.stalledWeeks(_bench), isNull);
    });

    test('records are counted per week and listed newest first', () {
      for (final (days, kg) in [(35, 80.0), (28, 85.0), (14, 90.0), (7, 90.0), (1, 95.0)]) {
        fit.sessions.add(_bench1(days, kg));
      }
      final events = fit.prEvents;
      expect(events.length, 3);
      expect(events.first.kg, greaterThan(events.last.kg));
      expect(fit.prsByWeek(12).fold(0, (a, b) => a + b), 3);
      expect(fit.exercisePrs(_bench).length, 3);
    });

    test('strength score comes from the bodyweight levels, and by muscle', () {
      expect(fit.strengthScore, isNull);
      fit.sessions.add(_bench1(3, 80)); // bench at 1.0 x bodyweight is just past Novice.
      final s = fit.strengthScore!;
      expect(s.score, inInclusiveRange(1, 100));
      expect(s.muscles.map((m) => m.muscle), contains('chest'));
    });

    test('volume zones use 4 weeks of sets and respect priority', () {
      // 3 sets in each of 4 weeks = 3 a week, far under the 10 to 20 band.
      for (final d in [2, 9, 16, 23]) {
        fit.sessions.add(_bench1(d, 80));
      }
      var chest = fit.muscleZones.firstWhere((z) => z.id == 'chest');
      expect(chest.perWeek, closeTo(3, 0.01));
      expect(chest.zone, 'under');
      expect(chest.check, 'Too few sets');
      fit.sessions.clear();
      for (final d in [2, 9, 16, 23]) {
        fit.sessions.add(_bench1(d, 80, sets: 12));
      }
      chest = fit.muscleZones.firstWhere((z) => z.id == 'chest');
      expect(chest.perWeek, closeTo(12, 0.01));
      expect(chest.zone, 'best');
      fit.setMusclePriority('chest', 1); // band 12 to 24, 12 is still inside
      expect(fit.muscleZones.firstWhere((z) => z.id == 'chest').zone, 'best');
      fit.setMusclePriority('chest', -1); // band 8 to 16
      expect(fit.muscleZones.firstWhere((z) => z.id == 'chest').hi, closeTo(16, 0.001));
    });

    test('when you train puts sessions into weekday and time-of-day cells', () {
      for (final d in [1, 2, 3, 4, 5, 6]) {
        fit.sessions.add(_bench1(d, 80, hour: 19));
      }
      final grid = fit.trainingTimes();
      expect(grid.length, 7);
      expect(grid.every((r) => r.length == 4), isTrue);
      expect(grid.fold(0, (a, r) => a + r[2]), 6, reason: 'all six start in the evening');
      expect(grid.fold(0, (a, r) => a + r[0]), 0);
    });

    test('weeks: streak counts goal weeks, the running week does not break it', () {
      fit.profile.weeklyGoal = 2;
      // A session every day for 4 weeks, so each full week reaches the goal
      // whichever weekday today is.
      for (var d = 1; d <= 28; d++) {
        fit.sessions.add(_bench1(d, 80));
      }
      expect(fit.weekStreak, greaterThanOrEqualTo(3));
      expect(fit.sessionsPerWeek(12).length, 12);
    });

    test('effort check bands the sets by reps left, and needs enough sets', () {
      fit.sessions.add(_bench1(2, 80, rpe: 9.5));
      expect(fit.effortSpread(), isNull, reason: 'only 3 sets');
      fit.sessions.add(_bench1(4, 80, rpe: 8));
      fit.sessions.add(_bench1(6, 80, rpe: 6));
      final e = fit.effortSpread()!;
      expect(e.hard, 3);
      expect(e.good, 3);
      expect(e.easy, 3);
      expect(fit.effortSpread(id: _bench, days: 90)!.total, 9);
    });

    test('rest between sets is the gap between ticks, and old sessions have none', () {
      fit.sessions.add(_bench1(2, 80));
      expect(fit.restStats(), isNull);
      fit.sessions.add(_bench1(4, 80, gap: 120));
      fit.sessions.add(_bench1(6, 80, gap: 180));
      final r = fit.restStats()!;
      expect(r.avg, 150);
      expect(r.sessions, 2);
      expect(fit.restStats(id: _bench)!.avg, 150);
    });

    test('a set ticked live remembers when, and an undo forgets it', () {
      final s = SessionSet(5, 80, true)..at = 1700000000;
      expect(s.logged.at, 1700000000);
      final back = SessionSet.fromJson(s.toJson());
      expect(back.at, 1700000000);
      final undone = SessionSet(5, 80, false)..at = 1700000000;
      expect(SessionSet.fromJson(undone.toJson()).at, isNull, reason: 'an unticked set keeps no time');
      expect(LoggedSet.fromJson(LoggedSet(5, 80, at: 42).toJson()).at, 42);
      expect(LoggedSet.fromJson(LoggedSet(5, 80).toJson()).at, isNull);
    });

    test('training load compares this week with the usual week, and needs 2 weeks of history', () {
      fit.sessions.add(_bench1(1, 80));
      expect(fit.trainingLoad.ratio, isNull);
      for (final d in [8, 15, 22]) {
        fit.sessions.add(_bench1(d, 80));
      }
      final load = fit.trainingLoad;
      expect(load.ratio, isNotNull);
      expect(load.rated, isFalse);
      expect(load.ratio!, closeTo(1.0, 0.3));
    });

    test('four weeks against the previous four', () {
      for (final d in [2, 10, 20]) {
        fit.sessions.add(_bench1(d, 80));
      }
      fit.sessions.add(_bench1(35, 80));
      expect(fit.fourWeeks(0).sessions, 3);
      expect(fit.fourWeeks(1).sessions, 1);
    });

    test('most-done lists the busiest exercises and the longest gap is found', () {
      for (final d in [2, 4, 6, 30]) {
        fit.sessions.add(_bench1(d, 80));
      }
      expect(fit.mostDone(5).first.id, _bench);
      expect(fit.mostDone(5).first.count, 4);
      expect(fit.longestGap!.days, 23);
    });

    test('sets per week and frequency on one exercise', () {
      for (final d in [1, 8, 15]) {
        fit.sessions.add(_bench1(d, 80));
      }
      final weeks = fit.exerciseWeeklySets(_bench, 8);
      expect(weeks.length, 8);
      expect(weeks.fold(0, (a, b) => a + b), 9);
      expect(fit.exerciseFrequency(_bench), closeTo(0.75, 0.001));
    });

    test('pace is per 500 m on a rowing machine and per km elsewhere', () {
      expect(fit.paceText(125), '2:05');
    });
  });

  group('screens', () {
    testWidgets('Minimal Stats shows the sections and one card per stat', (tester) async {
      fit.setMinimalMode(true);
      for (final (d, kg) in [(30.0, 80.0), (23.0, 82.5), (16.0, 85.0), (9.0, 87.5), (2.0, 90.0)]) {
        fit.sessions.add(_bench1(d.round(), kg, rpe: 8));
      }
      await pumpApp(tester);
      fit.goProgress();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('MUSCLES'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('MUSCLES'), findsOneWidget);
      // The new zones card replaces the old "Sets per muscle" section.
      expect(find.text('Muscle volume zones'), findsOneWidget);
      expect(find.text('Sets per muscle · 30 days'), findsNothing);
      await tester.scrollUntilVisible(find.text('CONSISTENCY'), 400, scrollable: find.byType(Scrollable).first);
      expect(find.text('CONSISTENCY'), findsOneWidget);
    });

    testWidgets('turning the zones card off brings the old muscle section back', (tester) async {
      fit.setMinimalMode(true);
      fit.setStatOn('zones', false);
      for (final d in [2, 9, 16]) {
        fit.sessions.add(_bench1(d, 80));
      }
      await pumpApp(tester);
      fit.goProgress();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Sets per muscle · 30 days'), 400, scrollable: find.byType(Scrollable).first);
      expect(find.text('Sets per muscle · 30 days'), findsOneWidget);
      expect(find.text('Muscle volume zones'), findsNothing);
    });

    testWidgets('main Stats draws its sections without errors', (tester) async {
      fit.setMinimalMode(false);
      for (final d in [2, 9, 16, 23]) {
        fit.sessions.add(_bench1(d, 80 + d / 2, rpe: 8, gap: 150));
      }
      await pumpApp(tester);
      fit.goProgress();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('MUSCLES'), 400, scrollable: find.byType(Scrollable).first);
      expect(find.text('MUSCLES'), findsWidgets);
    });

    testWidgets('the Stats cards sheet lists every card and a tap switches one off', (tester) async {
      fit.setMinimalMode(false);
      await pumpApp(tester);
      showStatCardsSheet(tester.element(find.byType(Scaffold).first));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('stat-group-progress')));
      await tester.pumpAndSettle();
      expect(find.text('Strength score'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stat-card-score')));
      await tester.pumpAndSettle();
      expect(fit.statOn('score'), isFalse);
    });
  });
}

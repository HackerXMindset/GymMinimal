import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/exercise.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    fit.setUnits('kg');
    fit.setMinimalMode(true);
    setAppLanguage('en');
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();
  }

  void addSession(String name, int daysAgo, List<LoggedSet> sets) => addSessionOf(fit.matchExerciseByName(name)!, daysAgo, sets);

  void addSessionOf(Exercise ex, int daysAgo, List<LoggedSet> sets) {
    final now = DateTime.now();
    fit.sessions.add(LoggedSession(
      DateTime(now.year, now.month, now.day - daysAgo, 18),
      1800,
      [LoggedExercise(ex.id, ex.name, ex.primary, sets)],
    ));
  }

  test('new Minimal options have quiet defaults', () {
    expect(fit.minimalExpandExercises, isFalse);
    expect(fit.minimalShowRecent, isTrue);
    expect(fit.minimalAnimateDemo, isTrue);
    expect(fit.minimalRepRecords, isTrue);
  });

  test('Minimal becomes the default once, then the choice stays with the person', () {
    fit.minimalDefaultApplied = false;
    fit.minimalMode = false;
    fit.applyMinimalDefaultOnce();
    expect(fit.minimalMode, isTrue);
    fit.setMinimalMode(false);
    fit.applyMinimalDefaultOnce();
    expect(fit.minimalMode, isFalse);
  });

  test('Recent lists the last exercises done, newest first, until you filter', () {
    final benchEx = fit.matchExerciseByName('Barbell Bench Press')!;
    final other = fit.allExercises.firstWhere((e) => e.id != benchEx.id);
    addSessionOf(benchEx, 9, [LoggedSet(8, 60)]);
    addSessionOf(other, 5, [LoggedSet(5, 80)]);
    addSessionOf(benchEx, 2, [LoggedSet(8, 62.5)]);

    final bench = benchEx.id;
    final squat = other.id;
    expect(fit.recentExerciseIds(), [bench, squat]);

    fit.clearExFilters();
    expect(fit.exRecentActive, isTrue);
    expect([for (final e in fit.exercisesFiltered) e.id], [bench, squat]);

    fit.setExSearch(other.name);
    expect(fit.exRecentActive, isFalse);
    fit.setExSearch('');
    expect(fit.exRecentActive, isTrue);

    fit.showAllExercises();
    expect(fit.exRecentActive, isFalse);
    expect(fit.exercisesFiltered.length, greaterThan(2));

    fit.showRecentExercises();
    expect(fit.exRecentActive, isTrue);

  });

  test('Recent falls back to All when nothing has been done and when switched off', () {
    fit.clearExFilters();
    expect(fit.exRecentActive, isFalse);
    addSession('Barbell Bench Press', 1, [LoggedSet(8, 60)]);
    expect(fit.exRecentActive, isTrue);
    fit.updateMinimalOptions(showRecent: false);
    expect(fit.exRecentActive, isFalse);
  });

  testWidgets('Minimal Exercises opens on the Recent chip', (tester) async {
    addSession('Barbell Bench Press', 3, [LoggedSet(8, 60)]);
    fit.clearExFilters();
    fit.route = 'exercises';
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Last'), findsOneWidget);
    expect(find.text('3d ago'), findsOneWidget);
  });

  testWidgets('Minimal exercise page shows stats and opens settings as a popup', (tester) async {
    for (final (daysAgo, kg) in [(40, 60.0), (30, 62.5), (20, 65.0), (10, 67.5), (3, 70.0)]) {
      addSession('Barbell Bench Press', daysAgo, [LoggedSet(10, kg), LoggedSet(8, kg), LoggedSet(5, kg + 5)]);
    }
    fit.activeExerciseId = fit.matchExerciseByName('Barbell Bench Press')!.id;
    fit.route = 'exercise-detail';
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('Similar'), findsNothing);

    await tester.tap(find.text('Volume'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(t.exerciseSettings), findsWidgets);
  });

  testWidgets('Minimal exercise page works with no history', (tester) async {
    fit.activeExerciseId = fit.matchExerciseByName('Barbell Bench Press')!.id;
    fit.route = 'exercise-detail';
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(t.noHistory), findsOneWidget);
  });

  testWidgets('How-to opens as a popup from the exercise page', (tester) async {
    fit.activeExerciseId = fit.matchExerciseByName('Barbell Bench Press')!.id;
    fit.route = 'exercise-detail';
    await pumpApp(tester);
    final name = exerciseName(fit.activeExercise);
    expect(find.text(name), findsOneWidget);
    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text(name), findsNWidgets(2));
  });
}

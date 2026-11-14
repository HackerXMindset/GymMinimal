import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/services/minimal_insights.dart';
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

  void addBenchSessions(List<(int daysAgo, double kg)> entries) {
    final bench = fit.matchExerciseByName('Barbell Bench Press')!;
    final now = DateTime.now();
    for (final (daysAgo, kg) in entries) {
      fit.sessions.add(LoggedSession(
        DateTime(now.year, now.month, now.day - daysAgo, 18),
        1800,
        [
          LoggedExercise(bench.id, bench.name, bench.primary, [LoggedSet(8, kg), LoggedSet(8, kg)]),
        ],
      ));
    }
  }

  test('change formats a percentage and refuses to divide by nothing', () {
    expect(MinimalInsights.change(110, 100), '+10%');
    expect(MinimalInsights.change(90, 100), '−10%');
    expect(MinimalInsights.change(100, 100), '0%');
    expect(MinimalInsights.change(5, 0), isNull);
  });

  testWidgets('Minimal Today offers the next routine and what needs attention', (tester) async {
    final bench = fit.matchExerciseByName('Barbell Bench Press')!;
    final routineId = fit.createRoutine('Push');
    fit.toggleRoutineExercise(routineId, bench.id);
    // The heaviest set was 60 days ago, so chest is cold and the lift has no
    // recent record.
    addBenchSessions([(60, 80), (50, 75), (45, 70), (40, 70)]);
    fit.route = 'home';

    await pumpApp(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Start Push'), findsOneWidget);
    expect(find.text('Start empty workout'), findsOneWidget);
    expect(find.text('Not trained lately'), findsOneWidget);
    expect(find.text('No PR lately'), findsOneWidget);
    expect(find.text('Last workout'), findsOneWidget);
    // Nav is sentence case.
    for (final label in ['Exercises', 'History', 'Stats', 'Settings']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('TODAY'), findsNothing);
  });

  testWidgets('Minimal Stats follows one window and steps back through it', (tester) async {
    addBenchSessions([(3, 80), (10, 80), (24, 75), (31, 75), (45, 70)]);
    fit.route = 'progress';

    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Weekly volume'), findsOneWidget);
    expect(find.text('Sessions per week'), findsOneWidget);

    await tester.tap(find.text('4W'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Earlier'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('All time'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

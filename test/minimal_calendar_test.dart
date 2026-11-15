import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/widgets/minimal_calendar.dart';
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
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();
  }

  void logToday() {
    final ex = fit.matchExerciseByName('Barbell Bench Press')!;
    final now = DateTime.now();
    fit.sessions.add(LoggedSession(
      DateTime(now.year, now.month, now.day, 12),
      0,
      [
        LoggedExercise(ex.id, ex.name, ex.primary, [LoggedSet(10, 60), LoggedSet(8, 62.5), LoggedSet(6, 65)]),
      ],
    ));
  }

  test('Achievements are switched off once for everyone, then stay the person\'s choice', () {
    fit.defaultsV5Applied = false;
    fit.gamification = true;
    fit.applyV5DefaultsOnce();
    expect(fit.gamification, isFalse);
    fit.toggleGamification();
    expect(fit.gamification, isTrue);
    fit.applyV5DefaultsOnce();
    expect(fit.gamification, isTrue);
  });

  test('calendar switches default on and can be turned off', () {
    expect(fit.minimalTodayCalendar, isTrue);
    expect(fit.minimalHistoryCalendar, isTrue);
    fit.updateMinimalOptions(todayCalendar: false, historyCalendar: false);
    expect(fit.minimalTodayCalendar, isFalse);
    expect(fit.minimalHistoryCalendar, isFalse);
  });

  testWidgets('Today has a month calendar and no date in the header', (tester) async {
    logToday();
    fit.route = 'home';
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(MinimalCalendar), findsOneWidget);
    expect(find.text(t.monthYear(DateTime.now())), findsOneWidget);
    expect(find.text(t.longDate(DateTime.now())), findsNothing);
  });

  testWidgets('tapping a trained day shows its muscles and exercises', (tester) async {
    logToday();
    fit.route = 'home';
    await pumpApp(tester);
    await tester.tap(find.text('${DateTime.now().day}'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('minimal-calendar-day')), findsOneWidget);
    final ex = fit.matchExerciseByName('Barbell Bench Press')!;
    expect(find.text('${t.muscle(ex.primary)}  3'), findsOneWidget);
    expect(find.text(t.catalogName(ex.id, ex.name)), findsOneWidget);
    expect(find.byKey(const ValueKey('minimal-calendar-add')), findsOneWidget);
  });

  testWidgets('adding a workout on a past day starts a session logged on that day', (tester) async {
    final now = DateTime.now();
    if (now.day == 1) return; // no earlier day in this month to tap
    fit.route = 'home';
    await pumpApp(tester);
    final day = DateTime(now.year, now.month, now.day - 1);
    await tester.tap(find.text('${day.day}'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing logged.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('minimal-calendar-add')));
    await tester.pumpAndSettle();
    expect(find.text('Add workout'), findsOneWidget);
    await tester.tap(find.text('Pick exercises'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(fit.route, 'train');
    expect(fit.logDay, day);
  });

  testWidgets('the month can be changed and next stops at the current month', (tester) async {
    fit.route = 'home';
    await pumpApp(tester);
    final now = DateTime.now();
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    final prev = DateTime(now.year, now.month - 1);
    expect(find.text(t.monthYear(prev)), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.text(t.monthYear(now)), findsOneWidget);
  });

  testWidgets('Today falls back to the week strip when the calendar is off', (tester) async {
    fit.updateMinimalOptions(todayCalendar: false);
    fit.route = 'home';
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(MinimalCalendar), findsNothing);
  });

  testWidgets('History list has the calendar, the table does not', (tester) async {
    logToday();
    fit.route = 'history';
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(MinimalCalendar), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('minimal-history-view-table')));
    await tester.pumpAndSettle();
    expect(find.byType(MinimalCalendar), findsNothing);
    await tester.tap(find.byKey(const ValueKey('minimal-history-view-list')));
    await tester.pumpAndSettle();
    expect(find.byType(MinimalCalendar), findsOneWidget);
  });
}

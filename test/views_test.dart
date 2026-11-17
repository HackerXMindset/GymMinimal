import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_colors.dart';
import 'package:gymmane/widgets/charts.dart';
import 'package:gymmane/widgets/past_swipe.dart';
import 'package:gymmane/widgets/stat_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bench = 'EIeI8Vf';

LoggedSession _old(int daysAgo, double kg) {
  final end = DateTime.now().subtract(Duration(days: daysAgo)).copyWith(hour: 18, minute: 0, second: 0, millisecond: 0);
  return LoggedSession(end, 3000, [
    LoggedExercise(_bench, 'Barbell Bench Press', 'chest', [for (var i = 0; i < 3; i++) LoggedSet(8, kg)]),
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

  group('rep max shown', () {
    test('1RM is the default and any other number scales the estimate', () {
      expect(fit.rmLabel(_bench), '1RM');
      expect(fit.repMaxOf(_bench, 130), 130);
      fit.setRmReps(_bench, 8);
      expect(fit.rmLabel(_bench), '8RM');
      expect(fit.repMaxOf(_bench, 130), closeTo(130 / (1 + 8 / 30), 1e-9));
      expect(fit.rmReps.length, 1);
      fit.setRmReps(_bench, 1);
      expect(fit.rmReps, isEmpty);
      fit.setRmReps(_bench, 99);
      expect(fit.rmRepsOf(_bench), 30);
    });

    test('the exercise trend follows it', () {
      fit.sessions.add(_old(3, 80));
      fit.sessions.add(_old(10, 70));
      final one = fit.exerciseTrend(_bench).map((p) => p.value).toList();
      fit.setRmReps(_bench, 8);
      final eight = fit.exerciseTrend(_bench).map((p) => p.value).toList();
      expect(eight.length, one.length);
      for (var i = 0; i < one.length; i++) {
        expect(eight[i], lessThan(one[i]));
      }
    });

    test('the choice survives a save and load', () {
      fit.setRmReps(_bench, 5);
      fit.setChartStyle('trading');
      final back = fit.exportJson();
      fit.resetAllData();
      expect(fit.rmRepsOf(_bench), 1);
      fit.importJson(back);
      expect(fit.rmRepsOf(_bench), 5);
      expect(fit.chartStyle, 'trading');
    });
  });

  group('chart style', () {
    test('only known styles are kept', () {
      fit.setChartStyle('bars');
      expect(fit.chartStyle, 'bars');
      fit.setChartStyle('nonsense');
      expect(fit.chartStyle, 'classic');
    });

    for (final style in const ['classic', 'trading', 'bars', 'dots']) {
      testWidgets('$style draws, and a touch shows a reading', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(extensions: [GymColors.dark]),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TrendChart(
                style: style,
                values: const [24, 26, 25, 27, 26, 29, 28, 31],
                labels: const ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'],
                height: 90,
                scale: (v) => '${v.round()} kg',
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final gesture = await tester.startGesture(tester.getCenter(find.byType(TrendChart)));
        await tester.pump();
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await gesture.up();
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('moving through weeks', () {
    test('how far back there is something to see', () {
      expect(fit.weeksOfHistory, 0);
      fit.sessions.add(_old(1, 80));
      fit.sessions.add(_old(30, 70));
      expect(fit.weeksOfHistory, inInclusiveRange(4, 5));
      expect(fit.weekReportFor(4).sessions + fit.weekReportFor(5).sessions, 1);
    });

    testWidgets('dragging right goes to the week before, and left comes back', (tester) async {
      final seen = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PastSwipe(
            limit: 3,
            builder: (context, back, go) {
              seen.add(back);
              return SizedBox(height: 200, child: Center(child: Text('week $back')));
            },
          ),
        ),
      ));
      expect(find.text('week 0'), findsOneWidget);
      await tester.drag(find.byType(PastSwipe), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(find.text('week 1'), findsOneWidget);
      await tester.drag(find.byType(PastSwipe), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.text('week 0'), findsOneWidget);
      await tester.drag(find.byType(PastSwipe), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.text('week 0'), findsOneWidget, reason: 'cannot go past today');
    });

    testWidgets('the Minimal week card moves back and names the week', (tester) async {
      fit.sessions.add(_old(1, 80));
      fit.sessions.add(_old(9, 70));
      fit.setMinimalMode(true);
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const GymManeApp());
      await tester.pumpAndSettle();
      fit.goProgress();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('This week').first, 400, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.text('This week').first, const Offset(250, 0));
      await tester.pumpAndSettle();
      expect(find.text('Last week'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

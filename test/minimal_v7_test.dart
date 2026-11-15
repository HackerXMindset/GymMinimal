import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/widgets/ruler_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
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

  test('new switches default on, can be turned off and reset', () {
    expect(fit.numberEntryKeyboard, isTrue);
    expect(fit.minimalWorkoutTable, isTrue);
    expect(fit.minimalNavIcons, isTrue);
    expect(fit.minimalTable, isTrue);
    fit.updateMinimalOptions(workoutTable: false, navIcons: false);
    fit.setNumberEntryKeyboard(false);
    expect(fit.minimalTable, isFalse);
    expect(fit.minimalNavIcons, isFalse);
    expect(fit.numberEntryKeyboard, isFalse);
    fit.setMinimalMode(false);
    fit.updateMinimalOptions(workoutTable: true);
    expect(fit.minimalTable, isFalse, reason: 'the table only exists in Minimal view');
    fit.resetAllData();
    expect(fit.minimalWorkoutTable, isTrue);
    expect(fit.minimalNavIcons, isTrue);
    expect(fit.numberEntryKeyboard, isTrue);
  });

  testWidgets('bottom bar shows icons, and the switch brings back text only', (tester) async {
    await pumpApp(tester);
    expect(find.byIcon(PhosphorIconsRegular.chartPie), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.barbell), findsWidgets);
    fit.updateMinimalOptions(navIcons: false);
    await tester.pumpAndSettle();
    expect(find.byIcon(PhosphorIconsRegular.chartPie), findsNothing);
    expect(find.text('Exercises'), findsWidgets);
  });

  testWidgets('number sheet opens on the keyboard in Minimal and takes typed values', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(Scaffold).first);
    final result = askRuler(context, title: 'Weight', value: 20, min: 0, max: 300, step: 0.5, unit: 'kg');
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('number-entry-field'));
    expect(field, findsOneWidget);
    expect(find.byType(RulerPicker), findsNothing);
    await tester.enterText(field, '62.5');
    await tester.pump();
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();
    expect(await result, 62.5);
  });

  testWidgets('typed value is kept inside the limits', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(Scaffold).first);
    final result = askRuler(context, title: 'Reps', value: 8, min: 0, max: 100, step: 1);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('number-entry-field')), '450');
    await tester.pump();
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();
    expect(await result, 100);
  });

  testWidgets('the corner icon switches to the scroller and the choice is remembered', (tester) async {
    await pumpApp(tester);
    var context = tester.element(find.byType(Scaffold).first);
    askRuler(context, title: 'Weight', value: 20, min: 0, max: 300, step: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('number-entry-swap')));
    await tester.pumpAndSettle();
    expect(find.byType(RulerPicker), findsOneWidget);
    expect(find.byKey(const ValueKey('number-entry-field')), findsNothing);
    expect(fit.numberEntryKeyboard, isFalse);
    await tester.tapAt(const Offset(180, 20));
    await tester.pumpAndSettle();

    context = tester.element(find.byType(Scaffold).first);
    askRuler(context, title: 'Weight', value: 20, min: 0, max: 300, step: 0.5);
    await tester.pumpAndSettle();
    expect(find.byType(RulerPicker), findsOneWidget, reason: 'opens on the last choice');
  });

  testWidgets('outside Minimal the sheet still opens on the scroller', (tester) async {
    fit.setMinimalMode(false);
    await pumpApp(tester);
    final context = tester.element(find.byType(Scaffold).first);
    askRuler(context, title: 'Weight', value: 20, min: 0, max: 300, step: 0.5);
    await tester.pumpAndSettle();
    expect(find.byType(RulerPicker), findsOneWidget);
    expect(find.byKey(const ValueKey('number-entry-field')), findsNothing);
  });

  testWidgets('live workout is a table with exercise bands, and Cards brings back the regular screen', (tester) async {
    final exercise = fit.matchExerciseByName('Barbell Bench Press')!;
    final routineId = fit.createRoutine('V7 Push');
    fit.toggleRoutineExercise(routineId, exercise.id);
    fit.startRoutine(fit.routines.singleWhere((r) => r.id == routineId));
    addTearDown(() {
      if (fit.session != null) fit.saveAndExit();
    });
    await pumpApp(tester);
    expect(fit.route, 'session');
    expect(find.text('note'), findsWidgets, reason: 'the band has ? note + and the menu');

    fit.updateMinimalOptions(workoutTable: false);
    await tester.pumpAndSettle();
    expect(find.text('note'), findsNothing, reason: 'Cards is the regular workout screen');
    expect(tester.takeException(), isNull);
  });
}

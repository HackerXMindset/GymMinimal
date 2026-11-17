import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/nutrition.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/widgets/mini_food.dart';
import 'package:gymmane/widgets/stat_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    fit.setUnits('kg');
    setAppLanguage('en');
    fit.setNutritionBeta(true);
  });

  test('the tracker needs the nutrition switch and its own switch', () {
    expect(fit.miniFoodOn, isTrue);
    fit.setMiniFood(false);
    expect(fit.miniFoodOn, isFalse);
    fit.setMiniFood(true);
    fit.setNutritionBeta(false);
    expect(fit.miniFoodOn, isFalse);
  });

  test('numbers shown keep their order and at least one stays on', () {
    fit.setMiniNum('sugar', true);
    expect(fit.miniShown, ['kcal', 'protein', 'carbs', 'fat', 'water', 'sugar']);
    for (final k in [...fit.miniShown]) {
      fit.setMiniNum(k, false);
    }
    expect(fit.miniShown.length, 1);
  });

  test('settings survive a save and load', () {
    fit.setMiniFoodFull(true);
    fit.setMiniNum('fiber', true);
    fit.setMiniTarget('fat', false);
    fit.setMiniChips(3);
    fit.setMiniChipFrom('favorites');
    fit.setMiniChipTaps(false);
    final saved = fit.miniFoodJson();
    fit.loadMiniFood(null);
    expect(fit.miniFoodFull, isFalse);
    expect(fit.miniChips, 6);
    fit.loadMiniFood(saved);
    expect(fit.miniFoodFull, isTrue);
    expect(fit.miniNums.contains('fiber'), isTrue);
    expect(fit.miniNoTarget, {'fat'});
    expect(fit.miniChips, 3);
    expect(fit.miniChipFrom, 'favorites');
    expect(fit.miniChipTaps, isFalse);
  });

  test('a target set here is the target the full Nutrition section uses', () {
    fit.setMiniGoal('protein', 160);
    expect(fit.activeGoals.protein, 160);
    expect(fit.miniTarget('protein', DateTime.now()), 160);
    fit.setMiniTarget('protein', false);
    expect(fit.miniTarget('protein', DateTime.now()), isNull);
  });

  test('food cards stay hidden with an empty log, and show with one', () {
    expect(StatCards.group('f_food', flat: true), isEmpty);
    final rice = fit.saveFood(name: 'Rice', macros: const Macros(kcal: 200, protein: 5, carbs: 44, fat: 1));
    fit.logFood(rice, servings: 2);
    expect(fit.macroSplit, isNotNull);
    expect(StatCards.one('n_macros', flat: true), isNotNull);
    expect(StatCards.one('n_week', flat: true), isNotNull);
    fit.setMiniFood(false);
    expect(StatCards.group('f_food', flat: true), isEmpty);
    expect(StatCards.food(flat: true, head: (l) => Text(l)), isEmpty);
  });

  test('a day of food gives the number rows', () {
    final rice = fit.saveFood(name: 'Rice', macros: const Macros(kcal: 200, protein: 5, carbs: 44, fat: 1));
    fit.logFood(rice, servings: 2);
    final today = DateTime.now();
    expect(fit.miniValue('kcal', today), 400);
    expect(fit.miniValue('protein', today), 10);
    expect(fit.foodSeries('kcal', 7).last, 400);
    expect(fit.foodWeek('kcal', 0).whereType<double>().fold(0.0, (a, b) => a + b), 400);
  });

  testWidgets('the strip shows on Today and quick add logs a serving', (tester) async {
    final rice = fit.saveFood(name: 'Rice', macros: const Macros(kcal: 200, protein: 5, carbs: 44, fat: 1));
    fit.logFood(rice);
    fit.updateMinimalOptions(todayCalendar: false);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: const [MiniFoodStrip()]))));
    await tester.pump();
    expect(find.text('Food today'), findsOneWidget);
    expect(find.text('Calories'), findsOneWidget);
    final before = fit.entriesOn(DateTime.now()).length;
    await tester.tap(find.text('Rice').first);
    await tester.pump();
    expect(fit.entriesOn(DateTime.now()).length, before + 1);
  });
}

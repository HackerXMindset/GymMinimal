import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../models/nutrition.dart';
import '../screens/nutrition_screen.dart' show mealName, showAddFoodSheet, showEntrySheet, showLogFoodSheet;
import '../services/food_library.dart';
import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'dialogs.dart';
import 'glass.dart';
import 'ruler_picker.dart';
import 'stat_cards.dart' show showStatCardsSheet;
import 'ui_kit.dart';

/// Opens what a tap on the Food strip should open: the small Food page, or the
/// full Nutrition section when that is switched on.
void openMiniFood(BuildContext context) {
  if (fit.miniFoodFull) {
    fit.goNutrition();
  } else {
    showMiniFoodSheet(context);
  }
}

String _num(String k, double v) => fit.miniShownValue(k, v);

/// A thin bar with the amount eaten filled in.
class _Meter extends StatelessWidget {
  const _Meter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 5,
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: gc.bgRaised2)),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0).toDouble(),
              child: ColoredBox(color: color),
            ),
          ),
        ]),
      ),
    );
  }
}

/// One number: its name, a bar toward the target, and what was eaten.
class _NumRow extends StatelessWidget {
  const _NumRow(this.k, this.day);

  final String k;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final v = fit.miniValue(k, day);
    final target = fit.miniTarget(k, day);
    final over = target != null && v > target * (k == 'kcal' ? 1.1 : 1.0) && (kMiniLimits.contains(k) || k == 'kcal');
    final color = over ? gc.warn : (k == 'water' ? gc.info : gc.accent);
    final unit = fit.miniUnit(k);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 62, child: Text(fit.miniLabel(k), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary))),
        Expanded(child: target == null ? const SizedBox.shrink() : _Meter(fraction: v / target, color: color)),
        const SizedBox(width: 10),
        SizedBox(
          width: 118,
          child: Text(
            target == null ? '${_num(k, v)} $unit' : '${_num(k, v)} / ${_num(k, target)} $unit',
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.f(11.5, weight: FontWeight.w700, color: over ? gc.warn : gc.text),
          ),
        ),
      ]),
    );
  }
}

/// A small tappable label on the strip and the Food page.
class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.onTap, this.icon, this.accent = false});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: accent ? gc.accent : gc.bgRaised2,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: accent ? gc.bg : gc.textSecondary),
            const SizedBox(width: 4),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(11.5, weight: FontWeight.w600, color: accent ? gc.bg : gc.text)),
          ),
        ]),
      ),
    );
  }
}

/// Logs one serving of [food] now, or opens its amount, with an undo.
void _quickLog(BuildContext context, FoodItem food) {
  fit.miniFoodOpen();
  final meal = fit.defaultMeal;
  if (!fit.miniChipTaps) {
    showLogFoodSheet(context, food, meal);
    return;
  }
  final e = fit.logFood(food, meal: meal);
  final bar = ScaffoldMessenger.maybeOf(context);
  bar
    ?..clearSnackBars()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 3),
      content: Text('${food.name} added to ${mealName(meal)}'),
      action: SnackBarAction(label: 'Undo', onPressed: () => fit.removeEntry(e.id)),
    ));
}

void _addWater(BuildContext context) {
  fit.miniFoodOpen();
  fit.addWater();
}

/// The Food strip on Today. Everything on it is a setting.
class MiniFoodStrip extends StatefulWidget {
  const MiniFoodStrip({super.key});

  @override
  State<MiniFoodStrip> createState() => _MiniFoodStripState();
}

class _MiniFoodStripState extends State<MiniFoodStrip> {
  @override
  void initState() {
    super.initState();
    FoodLibrary.load().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final day = DateTime.now();
    final nums = fit.miniShown;
    final chips = fit.miniChipFoods;
    return Container(
      key: const ValueKey('mini-food-strip'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: gc.bgRaised, border: Border.all(color: gc.border), borderRadius: BorderRadius.circular(4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => openMiniFood(context),
          child: Row(children: [
            Expanded(child: Text('Food today', style: AppTheme.f(10.5, weight: FontWeight.w500, color: gc.textSecondary))),
            Icon(PhosphorIconsRegular.caretRight, size: 13, color: gc.textTertiary),
          ]),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => openMiniFood(context),
          child: Column(children: [for (final k in nums) _NumRow(k, day)]),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final f in chips) _Chip(f.name, onTap: () => _quickLog(context, f)),
          _Chip('Add', icon: PhosphorIconsRegular.plus, onTap: () {
            fit.miniFoodOpen();
            showAddFoodSheet(context, fit.defaultMeal);
          }),
          if (fit.miniNums.contains('water')) _Chip('Water', icon: PhosphorIconsRegular.drop, onTap: () => _addWater(context)),
        ]),
      ]),
    );
  }
}

/// The small Food page: today's numbers, the meals with what is in them, and
/// the quick add. A sheet, so Minimal stays one screen deep.
Future<void> showMiniFoodSheet(BuildContext context) {
  fit.miniFoodOpen();
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => AnimatedBuilder(
      animation: fit,
      builder: (context, _) {
        final gc = context.gc;
        final day = fit.nutritionDay;
        final today = DateTime.now();
        final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
        final entries = fit.entriesOn(day);
        Widget arrow(IconData icon, int by) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => fit.setNutritionDay(shiftDays(day, by)),
              child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 16, color: gc.textSecondary)),
            );
        return AppSheet(children: [
          Row(children: [
            arrow(PhosphorIconsRegular.caretLeft, -1),
            Expanded(
              child: Text(
                isToday ? 'Today' : '${day.day}/${day.month}/${day.year}',
                textAlign: TextAlign.center,
                style: AppTheme.f(17, weight: FontWeight.w800, color: gc.text),
              ),
            ),
            arrow(PhosphorIconsRegular.caretRight, 1),
          ]),
          const SizedBox(height: 8),
          for (final k in fit.miniShown) _NumRow(k, day),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in fit.miniChipFoods)
              _Chip(f.name, onTap: () {
                if (fit.miniChipTaps) {
                  fit.logFood(f, meal: fit.defaultMeal);
                } else {
                  showLogFoodSheet(context, f, fit.defaultMeal);
                }
              }),
            if (fit.miniNums.contains('water')) _Chip('Water', icon: PhosphorIconsRegular.drop, onTap: fit.addWater),
          ]),
          const SizedBox(height: 6),
          for (final meal in fit.mealsShown) ...[
            Divider(height: 22, color: gc.border),
            Row(children: [
              Expanded(child: Text(mealName(meal), style: AppTheme.f(13, weight: FontWeight.w700, color: gc.text))),
              _Chip('Add', icon: PhosphorIconsRegular.plus, onTap: () => showAddFoodSheet(context, meal)),
            ]),
            for (final e in entries.where((e) => e.meal == meal))
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showEntrySheet(context, e),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.text))),
                    const SizedBox(width: 10),
                    Text('${fit.miniShownValue('kcal', e.total.kcal)} ${fit.energyUnit}', style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.textSecondary)),
                  ]),
                ),
              ),
          ],
          Divider(height: 22, color: gc.border),
          Row(children: [
            _Chip('Customize', icon: PhosphorIconsRegular.slidersHorizontal, onTap: () => showMiniFoodSettings(context)),
            const SizedBox(width: 6),
            _Chip('Full Nutrition', icon: PhosphorIconsRegular.forkKnife, onTap: () {
              Navigator.of(context).pop();
              fit.goNutrition();
            }),
          ]),
        ]);
      },
    ),
  );
}

/// Every setting of the Minimal food tracker in one sheet.
Future<void> showMiniFoodSettings(BuildContext context) {
  var rest = false;
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setLocal) => AnimatedBuilder(
        animation: fit,
        builder: (context, _) {
          final gc = context.gc;
          Widget row(String label, Widget trailing, {String? hint, VoidCallback? onTap, Key? key}) => InkWell(
                key: key,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label, style: AppTheme.f(13.5, weight: FontWeight.w600, color: gc.text)),
                        if (hint != null) ...[
                          const SizedBox(height: 2),
                          Text(hint, style: AppTheme.s(11, color: gc.textSecondary, height: 1.3)),
                        ],
                      ]),
                    ),
                    const SizedBox(width: 12),
                    trailing,
                  ]),
                ),
              );
          Widget head(String text) => Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 2),
                child: Text(text.toUpperCase(), style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4)),
              );
          final split = fit.restGoals != null;

          Future<void> editTarget(String k) async {
            final unit = fit.miniUnit(k);
            final now = fit.miniGoal(k, rest: rest && split);
            final v = await askRuler(
              context,
              title: '${fit.miniLabel(k)} target',
              value: now.toDouble(),
              min: 0,
              max: switch (k) { 'kcal' => 6000.0, 'water' => 8000.0, 'sodium' => 6000.0, _ => 500.0 },
              step: fit.miniStep(k).toDouble(),
              unit: unit == 'g' || unit == 'mg' ? unit : '',
              hint: 'Zero turns the target off.',
            );
            if (v == null) return;
            if (v <= 0) {
              fit.setMiniTarget(k, false);
            } else {
              fit.setMiniGoal(k, v.round(), rest: rest && split);
              fit.setMiniTarget(k, true);
            }
          }

          return AppSheet(children: [
            const SheetTitle('Food tracker', subtitle: 'Every part is a switch.'),
            const SizedBox(height: 6),
            row('Food on Today', TinySwitch(on: fit.miniFood), key: const ValueKey('mini-food-on'), onTap: () => fit.setMiniFood(!fit.miniFood)),
            row('Tap opens full Nutrition', TinySwitch(on: fit.miniFoodFull),
                hint: 'Off: a tap opens the small Food page.', onTap: () => fit.setMiniFoodFull(!fit.miniFoodFull)),
            head('Numbers and targets'),
            if (split)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SegToggle([
                  SegOption('Training day', !rest, () => setLocal(() => rest = false)),
                  SegOption('Rest day', rest, () => setLocal(() => rest = true)),
                ]),
              ),
            for (final k in kMiniNums)
              row(
                fit.miniLabel(k),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => editTarget(k),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Text(
                        fit.miniNoTarget.contains(k) ? 'No target' : '${_num(k, fit.miniGoal(k, rest: rest && split).toDouble())} ${fit.miniUnit(k)}',
                        style: AppTheme.f(12, weight: FontWeight.w700, color: gc.accent),
                      ),
                    ),
                  ),
                  TinySwitch(on: fit.miniNums.contains(k)),
                ]),
                onTap: () => fit.setMiniNum(k, !fit.miniNums.contains(k)),
              ),
            head('Quick add'),
            row(
              'Foods above the meals',
              StepperControl(
                value: '${fit.miniChips}',
                onDec: () => fit.setMiniChips(fit.miniChips - 1),
                onInc: () => fit.setMiniChips(fit.miniChips + 1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SegToggle([
                SegOption('Recent', fit.miniChipFrom == 'recent', () => fit.setMiniChipFrom('recent')),
                SegOption('Favorites', fit.miniChipFrom == 'favorites', () => fit.setMiniChipFrom('favorites')),
              ]),
            ),
            row('A tap logs one serving', TinySwitch(on: fit.miniChipTaps),
                hint: 'Off: a tap opens the amount first.', onTap: () => fit.setMiniChipTaps(!fit.miniChipTaps)),
            head('Meals'),
            for (final slot in fit.mealSlots)
              row(
                mealName(slot.meal),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => fit.moveMealSlot(slot.meal, -1),
                    child: Padding(padding: const EdgeInsets.all(6), child: Icon(PhosphorIconsRegular.caretUp, size: 15, color: gc.textSecondary)),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => fit.moveMealSlot(slot.meal, 1),
                    child: Padding(padding: const EdgeInsets.all(6), child: Icon(PhosphorIconsRegular.caretDown, size: 15, color: gc.textSecondary)),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => fit.removeMealSlot(slot.meal),
                    child: Padding(padding: const EdgeInsets.all(6), child: Icon(PhosphorIconsRegular.x, size: 15, color: gc.textTertiary)),
                  ),
                ]),
                onTap: () async {
                  final name = await askText(context, title: 'Meal name', initial: mealName(slot.meal));
                  if (name != null && name.trim().isNotEmpty) fit.renameMealSlot(slot.meal, name);
                },
              ),
            row('Add a meal', Icon(PhosphorIconsRegular.plus, size: 15, color: gc.textSecondary), onTap: () async {
              final name = await askText(context, title: 'New meal');
              if (name != null) fit.addMealSlot(name);
            }),
            head('Cards'),
            row('Food cards', Icon(PhosphorIconsRegular.caretRight, size: 14, color: gc.textTertiary),
                hint: 'Choose which food cards show on Stats.', onTap: () => showStatCardsSheet(context)),
            row('Open full Nutrition', Icon(PhosphorIconsRegular.caretRight, size: 14, color: gc.textTertiary), onTap: () {
              Navigator.of(context).pop();
              fit.goNutrition();
            }),
          ]);
        },
      ),
    ),
  );
}

part of 'fit_state.dart';

/// The numbers the Minimal food tracker can show, in the order they appear.
const kMiniNums = ['kcal', 'protein', 'carbs', 'fat', 'water', 'fiber', 'sugar', 'sodium'];
const _miniDefault = ['kcal', 'protein', 'carbs', 'fat', 'water'];

/// Numbers where more is worse, so passing the target turns them to a warning.
const kMiniLimits = {'sugar', 'sodium'};

/// The Minimal food tracker: a strip on Today, a small Food page, and the
/// settings behind them. It reads the same food log and targets as the full
/// Nutrition section, so nothing is entered twice.
mixin MiniFoodState on FitCore, ToolsState, LibraryState, SettingsState, StatsState, HealthState, NutritionState, StatsPlus, GarminState {
  /// The Food strip on Today and the Food page behind it.
  bool miniFood = true;

  /// Tapping the strip opens the full Nutrition section instead of the small page.
  bool miniFoodFull = false;

  /// Which numbers show.
  final Set<String> miniNums = {..._miniDefault};

  /// Numbers whose target is switched off: they show what was eaten and no bar.
  final Set<String> miniNoTarget = {};

  /// How many quick-add foods sit above the meals, 0 for none.
  int miniChips = 6;

  /// Where the quick-add foods come from: recent or favorites.
  String miniChipFrom = 'recent';

  /// A tap on a quick-add food logs one serving at once. Off, it opens the amount.
  bool miniChipTaps = true;

  bool get miniFoodOn => miniFood && nutritionBeta;

  List<String> get miniShown => [for (final k in kMiniNums) if (miniNums.contains(k)) k];

  /// Whether the cards of a Stats group exist right now: Garmin cards need the
  /// Garmin switch, food cards need the food tracker.
  bool statGroupAvailable(String group) {
    if (group.startsWith('g_')) return garminOn;
    if (group.startsWith('f_')) return miniFoodOn;
    return true;
  }

  /// Points the food log at today and loads the food library, before anything
  /// is added from the strip or the Food page.
  void miniFoodOpen() {
    final today = _dayKey(DateTime.now());
    nutritionDay = today;
    _nutritionSetOn = today;
    FoodLibrary.load().then((_) => notifyListeners());
  }

  // ---- Settings -------------------------------------------------------------

  void _miniSaved() {
    _persist();
    notifyListeners();
  }

  void setMiniFood(bool on) {
    miniFood = on;
    _miniSaved();
  }

  void setMiniFoodFull(bool on) {
    miniFoodFull = on;
    _miniSaved();
  }

  void setMiniNum(String k, bool on) {
    if (on) {
      miniNums.add(k);
    } else if (miniNums.length > 1) {
      miniNums.remove(k);
    }
    _miniSaved();
  }

  void setMiniTarget(String k, bool on) {
    if (on) {
      miniNoTarget.remove(k);
    } else {
      miniNoTarget.add(k);
    }
    _miniSaved();
  }

  void setMiniChips(int n) {
    miniChips = n.clamp(0, 12);
    _miniSaved();
  }

  void setMiniChipFrom(String v) {
    miniChipFrom = v == 'favorites' ? 'favorites' : 'recent';
    _miniSaved();
  }

  void setMiniChipTaps(bool on) {
    miniChipTaps = on;
    _miniSaved();
  }

  // ---- Numbers and targets --------------------------------------------------

  String miniLabel(String k) => const {
        'kcal': 'Calories',
        'protein': 'Protein',
        'carbs': 'Carbs',
        'fat': 'Fat',
        'water': 'Water',
        'fiber': 'Fiber',
        'sugar': 'Sugar',
        'sodium': 'Sodium',
      }[k] ?? k;

  String miniUnit(String k) => switch (k) {
        'kcal' => energyUnit,
        'water' => waterUnit,
        'sodium' => 'mg',
        _ => 'g',
      };

  /// How much of [k] was eaten on [day], in grams, millilitres or kcal.
  double miniValue(String k, DateTime day) {
    final m = totalOn(day);
    return switch (k) {
      'kcal' => m.kcal,
      'protein' => m.protein,
      'carbs' => m.carbs,
      'fat' => m.fat,
      'fiber' => m.fiber,
      'sugar' => m.sugar,
      'sodium' => m.sodium,
      'water' => waterOn(day).toDouble(),
      _ => 0.0,
    };
  }

  /// The target for [k] on [day], null when it is switched off or zero.
  double? miniTarget(String k, DateTime day) {
    if (miniNoTarget.contains(k)) return null;
    final g = goalsFor(day);
    final v = switch (k) {
      'kcal' => kcalBudgetOn(day),
      'protein' => g.protein,
      'carbs' => g.carbs,
      'fat' => g.fat,
      'fiber' => g.fiber,
      'sugar' => g.sugar,
      'sodium' => g.sodium,
      'water' => g.waterMl,
      _ => 0,
    };
    return v > 0 ? v.toDouble() : null;
  }

  /// [v] of [k] as the person reads it: kcal or kJ, litres or fl oz, grams.
  String miniShownValue(String k, double v) => switch (k) {
        'kcal' => groupedInt(energyOf(v)),
        'water' => waterValue(v.round()),
        _ => '${v.round()}',
      };

  /// The editable goal of [k], from the training-day or the rest-day set.
  int miniGoal(String k, {bool rest = false}) {
    final g = rest ? (restGoals ?? activeGoals) : activeGoals;
    return switch (k) {
      'kcal' => g.kcal,
      'protein' => g.protein,
      'carbs' => g.carbs,
      'fat' => g.fat,
      'water' => g.waterMl,
      'fiber' => g.fiber,
      'sugar' => g.sugar,
      _ => g.sodium,
    };
  }

  int miniStep(String k) => switch (k) {
        'kcal' => 50,
        'water' => 250,
        'sodium' => 100,
        'protein' || 'carbs' || 'fat' || 'sugar' => 5,
        _ => 1,
      };

  void setMiniGoal(String k, int v, {bool rest = false}) {
    final n = v < 0 ? 0 : v;
    NutritionGoals edit(NutritionGoals g) => switch (k) {
          'kcal' => g.copyWith(kcal: n),
          'protein' => g.copyWith(protein: n),
          'carbs' => g.copyWith(carbs: n),
          'fat' => g.copyWith(fat: n),
          'water' => g.copyWith(waterMl: n),
          'fiber' => g.copyWith(fiber: n),
          'sugar' => g.copyWith(sugar: n),
          _ => g.copyWith(sodium: n),
        };
    final split = restGoals;
    if (rest && split != null) {
      setRestGoals(edit(split));
    } else {
      setNutritionGoals(edit(activeGoals));
    }
  }

  // ---- Quick add --------------------------------------------------------------

  /// The foods offered above the meals.
  List<FoodItem> get miniChipFoods {
    if (miniChips <= 0) return const [];
    return _remember(('miniChips', miniChips, miniChipFrom), () {
      final out = <FoodItem>[];
      if (miniChipFrom == 'favorites') {
        for (final id in favoriteFoods) {
          final f = foodById(id);
          if (f != null) out.add(f);
          if (out.length >= miniChips) break;
        }
      } else {
        final seen = <String>{};
        for (final e in [...foodLog]..sort((a, b) => b.at.compareTo(a.at))) {
          if (e.foodId.isEmpty || !seen.add(e.foodId)) continue;
          final f = foodById(e.foodId);
          if (f != null) out.add(f);
          if (out.length >= miniChips) break;
        }
      }
      return out;
    }, (favoriteFoods.length, foods.length));
  }

  // ---- Series for the cards ---------------------------------------------------

  double? _foodDay(String k, DateTime day) {
    if (entriesOn(day).isEmpty && (k != 'water' || waterOn(day) == 0)) return null;
    return miniValue(k, day);
  }

  /// [k] on each of the last [days] days, oldest first, null for a day with
  /// nothing logged. [back] steps whole windows into the past.
  List<double?> foodSeries(String k, int days, {int back = 0}) {
    final today = _dayKey(DateTime.now());
    return [
      for (var i = days - 1; i >= 0; i--) _foodDay(k, shiftDays(today, -i - back * days)),
    ];
  }

  /// [k] on the seven days of the week [back] weeks ago.
  List<double?> foodWeek(String k, int back) {
    final start = shiftDays(weekStartDate, -7 * back);
    return [for (var i = 0; i < 7; i++) _foodDay(k, shiftDays(start, i))];
  }

  /// How far back the food log goes, in whole weeks.
  int get foodWeeksBack => _remember('foodWeeksBack', () {
        if (foodLog.isEmpty) return 0;
        var first = foodLog.first.at;
        for (final e in foodLog) {
          if (e.at.isBefore(first)) first = e.at;
        }
        final diff = weekStartDate.difference(_dayKey(first)).inDays;
        return diff <= 0 ? 0 : (diff / 7).ceil();
      });

  /// The share of energy from protein, carbs and fat on the latest day with food.
  ({DateTime day, double p, double c, double f, double kcal})? get macroSplit {
    final today = _dayKey(DateTime.now());
    for (var i = 0; i < 7; i++) {
      final d = shiftDays(today, -i);
      final m = totalOn(d);
      if (m.kcal > 0) return (day: d, p: m.protein * 4, c: m.carbs * 4, f: m.fat * 9, kcal: m.kcal);
    }
    return null;
  }

  /// Days within [days] where energy was close to the target and protein was reached.
  ({int logged, int kcalHit, int proteinHit, int both})? daysOnTarget(int days) => _remember(('daysOnTarget', days), () {
        final today = _dayKey(DateTime.now());
        var logged = 0, kcalHit = 0, proteinHit = 0, both = 0;
        for (var i = 0; i < days; i++) {
          final d = shiftDays(today, -i);
          if (entriesOn(d).isEmpty) continue;
          logged++;
          final m = totalOn(d);
          final goal = goalsFor(d);
          final budget = kcalBudgetOn(d);
          final k = budget > 0 && (m.kcal - budget).abs() <= budget * 0.1;
          final p = goal.protein > 0 && m.protein >= goal.protein * 0.9;
          if (k) kcalHit++;
          if (p) proteinHit++;
          if (k && p) both++;
        }
        return logged < 3 ? null : (logged: logged, kcalHit: kcalHit, proteinHit: proteinHit, both: both);
      }, _dayKey(DateTime.now()));

  /// Energy by meal over the last [days] days, in the order of the meals.
  List<({Meal meal, double kcal})> mealShare(int days) => _remember(('mealShare', days), () {
        final today = _dayKey(DateTime.now());
        final sums = <Meal, double>{};
        for (var i = 0; i < days; i++) {
          for (final e in entriesOn(shiftDays(today, -i))) {
            sums[e.meal] = (sums[e.meal] ?? 0) + e.total.kcal;
          }
        }
        final order = [for (final s in mealSlots) s.meal, ...sums.keys.where((m) => !mealSlots.any((s) => s.meal == m))];
        return [
          for (final m in order)
            if ((sums[m] ?? 0) > 0) (meal: m, kcal: sums[m]!),
        ];
      }, _dayKey(DateTime.now()));

  /// Energy eaten in each two hour block of the day, over the last [days] days.
  List<double> eatingHours(int days) => _remember(('eatingHours', days), () {
        final today = _dayKey(DateTime.now());
        final out = List<double>.filled(12, 0);
        for (var i = 0; i < days; i++) {
          for (final e in entriesOn(shiftDays(today, -i))) {
            out[e.at.hour ~/ 2] += e.total.kcal;
          }
        }
        return out;
      }, _dayKey(DateTime.now()));

  /// The foods that gave the most energy over the last [days] days.
  List<({String name, double kcal, double protein, int times})> topFoods(int days) => _remember(('topFoods', days), () {
        final today = _dayKey(DateTime.now());
        final sums = <String, ({String name, double kcal, double protein, int times})>{};
        for (var i = 0; i < days; i++) {
          for (final e in entriesOn(shiftDays(today, -i))) {
            final key = e.foodId.isEmpty ? e.name : e.foodId;
            final old = sums[key];
            final m = e.total;
            sums[key] = (
              name: e.name,
              kcal: (old?.kcal ?? 0) + m.kcal,
              protein: (old?.protein ?? 0) + m.protein,
              times: (old?.times ?? 0) + 1,
            );
          }
        }
        return (sums.values.toList()..sort((a, b) => b.kcal.compareTo(a.kcal))).take(5).toList();
      }, _dayKey(DateTime.now()));

  /// Average intake on days with a session against days without, over [days] days.
  ({int liftDays, int restDays, double proteinLift, double proteinRest, double kcalLift, double kcalRest})? liftDayFood(int days) =>
      _remember(('liftDayFood', days), () {
        final today = _dayKey(DateTime.now());
        final trained = <DateTime>{for (final s in sessions) _dayKey(s.day)};
        var lift = 0, rest = 0;
        var pl = 0.0, pr = 0.0, kl = 0.0, kr = 0.0;
        for (var i = 0; i < days; i++) {
          final d = shiftDays(today, -i);
          if (entriesOn(d).isEmpty) continue;
          final m = totalOn(d);
          if (trained.contains(d)) {
            lift++;
            pl += m.protein;
            kl += m.kcal;
          } else {
            rest++;
            pr += m.protein;
            kr += m.kcal;
          }
        }
        if (lift < 3 || rest < 3) return null;
        return (liftDays: lift, restDays: rest, proteinLift: pl / lift, proteinRest: pr / rest, kcalLift: kl / lift, kcalRest: kr / rest);
      }, _dayKey(DateTime.now()));

  /// Each of the last [weeks] weeks: average energy eaten, average bodyweight
  /// and how the weight moved from the week before.
  List<({DateTime start, double? kcal, double? kg, double? change})>? foodVsWeight(int weeks) =>
      _remember(('foodVsWeight', weeks), () {
        final rows = <({DateTime start, double? kcal, double? kg, double? change})>[];
        double? prev;
        for (var w = weeks - 1; w >= 0; w--) {
          final start = shiftDays(weekStartDate, -7 * w);
          var days = 0;
          var kcal = 0.0;
          for (var i = 0; i < 7; i++) {
            final d = shiftDays(start, i);
            if (entriesOn(d).isEmpty) continue;
            days++;
            kcal += totalOn(d).kcal;
          }
          final end = shiftDays(start, 7);
          final weights = [for (final b in bodyweight) if (!b.date.isBefore(start) && b.date.isBefore(end)) b.kg];
          final kg = weights.isEmpty ? null : weights.reduce((a, b) => a + b) / weights.length;
          rows.add((start: start, kcal: days >= 3 ? kcal / days : null, kg: kg, change: kg != null && prev != null ? kg - prev : null));
          if (kg != null) prev = kg;
        }
        return rows.where((r) => r.kcal != null && r.kg != null).length < 3 ? null : rows;
      }, _dayKey(DateTime.now()));

  /// How lifting went after eating carbs in the three hours before, against
  /// lifting fasted: the average load per set.
  ({int fed, int fasted, double fedLoad, double fastedLoad, double carbs})? get eatBeforeLifting =>
      _remember('eatBeforeLifting', () {
        final since = DateTime.now().subtract(const Duration(days: 120));
        var fed = 0, fasted = 0;
        var fedLoad = 0.0, fastedLoad = 0.0, carbs = 0.0;
        for (final s in sessions) {
          if (s.day.isBefore(since) || s.setCount == 0 || s.volume <= 0) continue;
          final from = s.day.subtract(const Duration(hours: 3));
          var c = 0.0;
          for (final e in [...entriesOn(_dayKey(from)), ...entriesOn(_dayKey(s.day))]) {
            if (!e.at.isBefore(from) && !e.at.isAfter(s.day)) c += e.total.carbs;
          }
          final load = s.volume / s.setCount;
          if (c >= 30) {
            fed++;
            fedLoad += load;
            carbs += c;
          } else {
            fasted++;
            fastedLoad += load;
          }
        }
        if (fed < 3 || fasted < 3) return null;
        return (fed: fed, fasted: fasted, fedLoad: fedLoad / fed, fastedLoad: fastedLoad / fasted, carbs: carbs / fed);
      }, _dayKey(DateTime.now()));

  // ---- Persistence -------------------------------------------------------------

  void loadMiniFood(Map<String, dynamic>? j) {
    miniFood = j?['on'] != false;
    miniFoodFull = j?['full'] == true;
    miniNums
      ..clear()
      ..addAll(((j?['nums'] as List?) ?? _miniDefault).whereType<String>().where(kMiniNums.contains));
    if (miniNums.isEmpty) miniNums.addAll(_miniDefault);
    miniNoTarget
      ..clear()
      ..addAll(((j?['noTarget'] as List?) ?? const []).whereType<String>());
    miniChips = ((j?['chips'] as num?)?.toInt() ?? 6).clamp(0, 12);
    miniChipFrom = j?['from'] == 'favorites' ? 'favorites' : 'recent';
    miniChipTaps = j?['taps'] != false;
  }

  Map<String, dynamic> miniFoodJson() => {
        if (!miniFood) 'on': false,
        if (miniFoodFull) 'full': true,
        'nums': miniShown,
        if (miniNoTarget.isNotEmpty) 'noTarget': miniNoTarget.toList(),
        if (miniChips != 6) 'chips': miniChips,
        if (miniChipFrom != 'recent') 'from': miniChipFrom,
        if (!miniChipTaps) 'taps': false,
      };
}

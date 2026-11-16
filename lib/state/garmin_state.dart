part of 'fit_state.dart';

/// What the Garmin cards read from Health Connect. Garmin Connect writes
/// sleep, heart rate and calories there; resting heart rate and HRV only show
/// up if the watch app shares them, and a card without them stays hidden.
const kGarminKeys = ['restingHr', 'hrv', 'sleep', 'activeKcal', 'totalKcal', 'workoutHr'];

const _garminKeepDays = 400;

mixin GarminState on FitCore, ToolsState, LibraryState, SettingsState, StatsState, HealthState, NutritionState, StatsPlus {
  /// The master switch. While it is off nothing Garmin is asked for, read,
  /// imported or shown.
  bool garminOn = false;

  /// Max heart rate for the zones. 0 means work it out.
  int maxHrSetting = 0;

  /// The rep and hold targets behind "ready for more" on the exercise page.
  int readyReps = 10;
  int readySeconds = 60;

  DateTime? garminSynced;
  String garminNote = '';
  bool garminBusy = false;
  Set<String> garminKeys = {};

  /// Metric to day (yyyy-mm-dd) to value. It grows a day at a time, so cards
  /// can look back further than the 30 days Health Connect hands over.
  final Map<String, Map<String, double>> garminDays = {};

  // ---- Settings -----------------------------------------------------------

  void setReadyReps(int v) {
    readyReps = v.clamp(3, 30);
    _persist();
    notifyListeners();
  }

  void setReadySeconds(int v) {
    readySeconds = v.clamp(10, 600);
    _persist();
    notifyListeners();
  }

  void setMaxHr(int v) {
    maxHrSetting = v == 0 ? 0 : v.clamp(120, 230);
    _persist();
    notifyListeners();
  }

  /// The typed value, else the highest rate seen in a session, else 220 minus age.
  int get maxHr {
    if (maxHrSetting > 0) return maxHrSetting;
    var seen = 0;
    for (final s in sessions) {
      seen = math.max(seen, s.hrMax ?? 0);
    }
    return seen >= 150 ? seen : 220 - profile.age;
  }

  bool get maxHrAuto => maxHrSetting == 0;

  Future<bool> setGarminOn(bool on) async {
    if (!on) {
      garminOn = false;
      _persist();
      notifyListeners();
      return true;
    }
    garminOn = true;
    garminNote = '';
    _persist();
    notifyListeners();
    final have = await HealthMetrics.grantedKeys();
    final missing = [for (final k in kGarminKeys) if (!have.contains(k)) k];
    if (missing.isNotEmpty) await HealthMetrics.requestKeys(missing);
    garminKeys = await HealthMetrics.grantedKeys();
    if (!kGarminKeys.any(garminKeys.contains)) {
      garminNote = 'Health Connect has not been allowed yet. FIT files still work.';
    }
    notifyListeners();
    await syncGarmin();
    return true;
  }

  Future<void> askGarminPermissions() async {
    await HealthMetrics.requestKeys(kGarminKeys);
    garminKeys = await HealthMetrics.grantedKeys();
    notifyListeners();
    await syncGarmin();
  }

  void clearGarmin() {
    garminDays.clear();
    garminSynced = null;
    garminNote = '';
    for (final s in sessions) {
      s.hrHist = null;
      s.kcal = null;
      for (final e in s.exercises) {
        for (final st in e.sets) {
          st
            ..hr = null
            ..hrPeak = null
            ..hrDrop = null
            ..watch = null;
        }
      }
    }
    _persist();
    notifyListeners();
  }

  // ---- Reading from Health Connect -----------------------------------------

  @override
  Future<void> syncGarmin() async {
    if (!garminOn || garminBusy) return;
    garminBusy = true;
    try {
      final keys = await HealthMetrics.grantedKeys();
      garminKeys = keys;
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day - 29);
      final to = DateTime(now.year, now.month, now.day + 1);
      var dirty = false;
      for (final key in const ['restingHr', 'hrv', 'sleep', 'activeKcal', 'totalKcal']) {
        if (!keys.contains(key)) continue;
        final rows = await HealthMetrics.readKey(key, from, to);
        if (rows == null || rows.isEmpty) continue;
        final days = _garminByDay(key, rows);
        final have = garminDays.putIfAbsent(key, () => {});
        days.forEach((k, v) {
          if (have[k] != v) {
            have[k] = v;
            dirty = true;
          }
        });
        if (have.length > _garminKeepDays) {
          final cut = (have.keys.toList()..sort()).reversed.skip(_garminKeepDays).toList();
          for (final k in cut) {
            have.remove(k);
          }
        }
      }
      if (keys.contains('workoutHr')) {
        final since = now.subtract(const Duration(days: 14));
        for (final s in sessions.where((s) => s.date.isAfter(since)).toList()) {
          final needs = s.hrHist == null ||
              s.exercises.any((e) => e.sets.any((st) => st.at != null && st.counts && st.hr == null));
          if (!needs) continue;
          final rows = await HealthMetrics.readKey(
              'workoutHr', s.day.subtract(const Duration(minutes: 1)), s.date.add(const Duration(minutes: 3)));
          if (rows != null && rows.isNotEmpty && applyHeart(s, rows) > 0) dirty = true;
          if (rows != null && s.hrHist != null) dirty = true;
        }
      }
      garminSynced = now;
      if (dirty) _persist();
      notifyListeners();
    } finally {
      garminBusy = false;
    }
  }

  Map<String, double> _garminByDay(String key, List<List<double>> rows) {
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final r in rows) {
      final day = HealthMetrics.dayKey(DateTime.fromMillisecondsSinceEpoch(r[0].round()));
      sums[day] = (sums[day] ?? 0) + r[1];
      counts[day] = (counts[day] ?? 0) + 1;
    }
    final averaged = key == 'hrv';
    return {
      for (final e in sums.entries)
        if (e.value > 0) e.key: averaged ? e.value / counts[e.key]! : e.value,
    };
  }

  // ---- Reading from a FIT file ---------------------------------------------

  /// Matches a Garmin FIT file to the logged session it belongs to and keeps
  /// the heart rate per set, the zones and the reps the watch counted. Returns
  /// a line to show the person.
  String importFit(Uint8List bytes) {
    final line = _importFit(bytes);
    garminNote = line;
    notifyListeners();
    return line;
  }

  String _importFit(Uint8List bytes) {
    if (!garminOn) return 'Turn Garmin data on first.';
    final file = parseFit(bytes);
    if (file == null) return 'This is not a FIT file, or it has nothing in it.';
    final start = file.startMs;
    if (start == null) return 'The file has no start time.';
    LoggedSession? best;
    var gap = 1 << 40;
    for (final s in sessions) {
      final d = (s.day.millisecondsSinceEpoch - start).abs();
      final inside = start >= s.day.millisecondsSinceEpoch - 1800000 && start <= s.date.millisecondsSinceEpoch + 1800000;
      if ((d <= 1800000 || inside) && d < gap) {
        best = s;
        gap = d;
      }
    }
    final when = DateTime.fromMillisecondsSinceEpoch(start);
    if (best == null) {
      return 'No logged session starts near ${when.day}/${when.month} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}.';
    }
    final n = applyHeart(best, file.samples, fitSets: file.lifted);
    best.kcal ??= file.kcal;
    best.hrAvg ??= file.hrAvg;
    best.hrMax ??= file.hrMax;
    _persist();
    notifyListeners();
    final sets = file.lifted.length;
    if (n == 0 && file.samples.isEmpty) {
      return 'Matched ${when.day}/${when.month}, but the file has no heart rate and the sets did not line up.';
    }
    return 'Matched ${when.day}/${when.month}: $n of ${best.setCount} sets now have watch data'
        '${sets == 0 ? ' (the file has no strength sets, so only the session totals were kept)' : ''}.';
  }

  // ---- Series for the cards -------------------------------------------------

  /// The last [days] days of [key], oldest first, null where there is none.
  /// Everything is null while Garmin is off.
  List<double?> garminSeries(String key, int days) {
    if (!garminOn) return List<double?>.filled(days, null);
    final map = garminDays[key];
    final now = DateTime.now();
    return [
      for (var i = days - 1; i >= 0; i--)
        map?[HealthMetrics.dayKey(DateTime(now.year, now.month, now.day - i))],
    ];
  }

  double? garminValue(String key, DateTime day) => garminOn ? garminDays[key]?[HealthMetrics.dayKey(day)] : null;

  /// The mean of [key] over the [days] days before today, null with fewer than 4 values.
  double? garminBaseline(String key, {int days = 28}) {
    final all = garminSeries(key, days + 1);
    final v = [for (var i = 0; i < all.length - 1; i++) ?all[i]];
    return v.length < 4 ? null : v.reduce((a, b) => a + b) / v.length;
  }

  /// True when at least one Garmin number exists, so the cards have a reason to show.
  bool get garminHasData => garminOn && garminDays.values.any((m) => m.isNotEmpty);

  /// Sessions that carry heart rate per set.
  bool get garminHasSetHeart => garminOn && sessions.any((s) => s.exercises.any((e) => e.sets.any((st) => st.hr != null)));

  // ---- Persistence ------------------------------------------------------------

  void loadGarmin(Map<String, dynamic>? j) {
    garminOn = j?['on'] == true;
    maxHrSetting = (j?['max'] as num?)?.toInt() ?? 0;
    readyReps = ((j?['reps'] as num?)?.toInt() ?? 10).clamp(3, 30);
    readySeconds = ((j?['secs'] as num?)?.toInt() ?? 60).clamp(10, 600);
    final at = (j?['at'] as num?)?.toInt();
    garminSynced = at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
    garminDays.clear();
    ((j?['days'] as Map?) ?? const {}).forEach((k, v) {
      if (k is! String || v is! Map) return;
      garminDays[k] = {
        for (final e in v.entries)
          if (e.key is String && e.value is num) e.key as String: (e.value as num).toDouble(),
      };
    });
  }

  Map<String, dynamic> garminJson() => {
        if (garminOn) 'on': true,
        if (maxHrSetting > 0) 'max': maxHrSetting,
        if (readyReps != 10) 'reps': readyReps,
        if (readySeconds != 60) 'secs': readySeconds,
        if (garminSynced != null) 'at': garminSynced!.millisecondsSinceEpoch,
        if (garminDays.isNotEmpty) 'days': garminDays,
      };
}

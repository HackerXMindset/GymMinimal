import 'dart:math' as math;

import '../models/workout.dart';
import 'fit_decoder.dart';

/// Heart rate worked out per set from watch samples. Pure functions, so they
/// work the same for Health Connect samples and for samples from a FIT file.
///
/// Samples are `[time in ms since the epoch, beats per minute]`, oldest first.
const hrBuckets = 37;

/// How many seconds before a set was ticked off its heart rate is read, when
/// the set has no start time of its own.
const _setLookbackSec = 45;

class SetHeart {
  const SetHeart(this.avg, this.peak, this.drop);
  final int avg;
  final int peak;

  /// How far the rate fell in the minute after the set, or null when the
  /// samples do not reach that far.
  final int? drop;
}

SetHeart? heartForWindow(List<List<double>> samples, int startMs, int endMs) {
  var sum = 0.0;
  var n = 0;
  var peak = 0.0;
  for (final s in samples) {
    if (s[0] < startMs) continue;
    if (s[0] > endMs) break;
    sum += s[1];
    n++;
    peak = math.max(peak, s[1]);
  }
  if (n < 2) return null;
  var after = 0.0;
  var m = 0;
  for (final s in samples) {
    if (s[0] < endMs + 45000) continue;
    if (s[0] > endMs + 75000) break;
    after += s[1];
    m++;
  }
  final drop = m == 0 ? null : math.max(0, (peak - after / m).round());
  return SetHeart((sum / n).round(), peak.round(), drop);
}

/// Seconds at each heart rate in 5 bpm buckets from 40.
List<int>? heartHistogram(List<List<double>> samples, int fromMs, int toMs) {
  final hist = List<int>.filled(hrBuckets, 0);
  var count = 0;
  for (var i = 0; i < samples.length; i++) {
    final t = samples[i][0];
    if (t < fromMs) continue;
    if (t > toMs) break;
    final next = i + 1 < samples.length ? samples[i + 1][0] : t + 5000;
    final secs = (math.min(next - t, 15000) / 1000).round();
    final b = ((samples[i][1] - 40) / 5).floor().clamp(0, hrBuckets - 1);
    hist[b] += math.max(1, secs);
    count++;
  }
  return count < 3 ? null : hist;
}

/// Seconds in zones 1 to 5 (50 to 60%, up to 90% and over of [maxHr]).
List<int> zoneSeconds(List<int> hist, int maxHr) {
  final zones = List<int>.filled(5, 0);
  for (var i = 0; i < hist.length; i++) {
    final pct = (40 + i * 5 + 2.5) / maxHr;
    if (pct < 0.5) continue;
    final z = pct < 0.6
        ? 0
        : pct < 0.7
            ? 1
            : pct < 0.8
                ? 2
                : pct < 0.9
                    ? 3
                    : 4;
    zones[z] += hist[i];
  }
  return zones;
}

/// Puts heart rate on the sets of [s]. A set that was ticked off live has a
/// time, which gives its window. With [fitSets] the watch's own set windows are
/// used instead, matched to the logged sets in order, and the reps the watch
/// counted are kept. Returns how many sets got something. The session totals
/// are filled too.
int applyHeart(LoggedSession s, List<List<double>> samples, {List<FitSet>? fitSets}) {
  final from = s.day.millisecondsSinceEpoch - 60000;
  final to = s.date.millisecondsSinceEpoch + 120000;
  final inside = [
    for (final r in samples)
      if (r[0] >= from && r[0] <= to && r[1] > 30 && r[1] < 240) r,
  ];
  final hasHr = inside.length >= 3;
  if (hasHr) {
    final bpm = [for (final r in inside) r[1]];
    s.hrAvg ??= (bpm.reduce((a, b) => a + b) / bpm.length).round();
    s.hrMax ??= bpm.reduce(math.max).round();
    s.hrHist = heartHistogram(inside, from, to) ?? s.hrHist;
  }

  final all = [for (final e in s.exercises) ...e.sets];
  var done = 0;
  if (fitSets != null && fitSets.isNotEmpty) {
    final n = math.min(all.length, fitSets.length);
    final ratio = n / math.max(all.length, fitSets.length);
    if (ratio < 0.6) return 0;
    for (var i = 0; i < n; i++) {
      final f = fitSets[i];
      var got = false;
      if (f.reps > 0) {
        all[i].watch = f.reps;
        got = true;
      }
      final h = hasHr ? heartForWindow(inside, f.startMs, f.endMs <= f.startMs ? f.startMs + 30000 : f.endMs) : null;
      if (h != null) {
        all[i]
          ..hr = h.avg
          ..hrPeak = h.peak
          ..hrDrop = h.drop;
        got = true;
      }
      if (got) done++;
    }
    return done;
  }
  if (!hasHr) return 0;
  for (final st in all) {
    final at = st.at;
    if (at == null || !st.counts) continue;
    final end = at * 1000;
    final h = heartForWindow(inside, end - _setLookbackSec * 1000, end);
    if (h == null) continue;
    st
      ..hr = h.avg
      ..hrPeak = h.peak
      ..hrDrop = h.drop;
    done++;
  }
  return done;
}

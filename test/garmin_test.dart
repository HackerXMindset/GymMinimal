import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/fit_decoder.dart';
import 'package:gymmane/services/health_metrics.dart';
import 'package:gymmane/services/hr_sets.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/widgets/stat_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bench = 'EIeI8Vf';

// A small FIT writer, enough to build the files the reader has to understand.
const _fitEpoch = 631065600;

List<int> _u32(int v) => [v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255];
List<int> _u16(int v) => [v & 255, (v >> 8) & 255];

List<int> _def(int local, int global, List<(int, int, int)> fields) => [
      0x40 | local,
      0,
      0,
      global & 255,
      global >> 8,
      fields.length,
      for (final f in fields) ...[f.$1, f.$2, f.$3],
    ];

Uint8List _fit(List<int> body) {
  final head = ByteData(14)
    ..setUint8(0, 14)
    ..setUint8(1, 0x20)
    ..setUint16(2, 2000, Endian.little)
    ..setUint32(4, body.length, Endian.little);
  final bytes = head.buffer.asUint8List().toList()..setRange(8, 12, '.FIT'.codeUnits);
  return Uint8List.fromList([...bytes, ...body, 0, 0]);
}

/// 60 seconds of heart rate rising 1 bpm a second from 100, three sets of 10 at
/// 80 kg starting 10, 50 and 90 seconds in, and a session total of 250 kcal.
Uint8List _strengthFile(int startUnix) {
  final t0 = startUnix - _fitEpoch;
  final body = <int>[
    ..._def(0, 20, [(253, 4, 0x86), (3, 1, 0x02)]),
    for (var i = 0; i < 120; i++) ...[0x00, ..._u32(t0 + i), 100 + i],
    ..._def(1, 225, [(6, 4, 0x86), (0, 4, 0x86), (3, 2, 0x84), (4, 2, 0x84), (5, 1, 0x02)]),
    for (final off in [10, 50, 90]) ...[0x01, ..._u32(t0 + off), ..._u32(20000), ..._u16(10), ..._u16(80 * 16), 1],
    ..._def(2, 18, [(2, 4, 0x86), (11, 2, 0x84), (16, 1, 0x02), (17, 1, 0x02)]),
    0x02, ..._u32(t0), ..._u16(250), 150, 219,
  ];
  return _fit(body);
}

LoggedSession _session(int startUnix, {int sets = 3, bool timed = false}) {
  final end = DateTime.fromMillisecondsSinceEpoch((startUnix + 120) * 1000);
  return LoggedSession(end, 120, [
    LoggedExercise(_bench, 'Barbell Bench Press', 'chest', [
      for (var i = 0; i < sets; i++) LoggedSet(10, 80, at: timed ? startUnix + 30 + i * 40 : null),
    ]),
  ]);
}

LoggedSession _old(int daysAgo, double kg, {int reps = 5, int hour = 18}) {
  final end = DateTime.now().subtract(Duration(days: daysAgo)).copyWith(hour: hour, minute: 0, second: 0, millisecond: 0);
  return LoggedSession(end, 3000, [
    LoggedExercise(_bench, 'Barbell Bench Press', 'chest', [for (var i = 0; i < 3; i++) LoggedSet(reps, kg)]),
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

  group('FIT reader', () {
    test('reads heart rate, strength sets and session totals', () {
      final file = parseFit(_strengthFile(1700000000))!;
      expect(file.samples.length, 120);
      expect(file.samples.first[1], 100);
      expect(file.samples.first[0], 1700000000 * 1000);
      expect(file.lifted.length, 3);
      expect(file.lifted.first.reps, 10);
      expect(file.lifted.first.kg, 80);
      expect(file.lifted.first.startMs, (1700000000 + 10) * 1000);
      expect(file.lifted.first.durMs, 20000);
      expect(file.kcal, 250);
      expect(file.hrAvg, 150);
      expect(file.hrMax, 219);
      expect(file.startMs, 1700000000 * 1000);
    });

    test('anything that is not a FIT file gives null and never throws', () {
      expect(parseFit(Uint8List(0)), isNull);
      expect(parseFit(Uint8List.fromList(List.filled(40, 7))), isNull);
      final good = _strengthFile(1700000000);
      expect(() => parseFit(good.sublist(0, 60)), returnsNormally);
      expect(() => parseFit(Uint8List.fromList([...good.sublist(0, 14), 0x41, 0xFF, 1, 2, 3])), returnsNormally);
    });
  });

  group('heart rate on sets', () {
    test('a FIT file gives each set its own heart rate, drop and the reps the watch counted', () {
      final file = parseFit(_strengthFile(1700000000))!;
      final s = _session(1700000000);
      final n = applyHeart(s, file.samples, fitSets: file.lifted);
      expect(n, 3);
      final first = s.exercises.first.sets.first;
      expect(first.hr, inInclusiveRange(119, 121));
      expect(first.hrPeak, 130);
      expect(first.watch, 10);
      expect(s.hrAvg, isNotNull);
      expect(s.hrHist, isNotNull);
      expect(s.hrHist!.reduce((a, b) => a + b), greaterThan(100));
    });

    test('a set ticked live gets heart rate from the 45 seconds before the tick', () {
      final file = parseFit(_strengthFile(1700000000))!;
      final s = _session(1700000000, timed: true);
      expect(applyHeart(s, file.samples), 3);
      final a = s.exercises.first.sets.first;
      expect(a.hr, isNotNull);
      expect(a.hrPeak, 100 + 30);
      expect(s.exercises.first.sets[2].hr!, greaterThan(a.hr!));
    });

    test('fewer than two samples in a set gives nothing, and mismatched set counts are skipped', () {
      final s = _session(1700000000, sets: 12);
      final file = parseFit(_strengthFile(1700000000))!;
      expect(applyHeart(s, file.samples, fitSets: file.lifted), 0);
      expect(heartForWindow(const [], 0, 1000), isNull);
    });

    test('zones come from the histogram and follow the max heart rate', () {
      final hist = List<int>.filled(hrBuckets, 0);
      hist[(150 - 40) ~/ 5] = 60;
      expect(zoneSeconds(hist, 190)[3], 60);
      expect(zoneSeconds(hist, 160)[4], 60);
    });

    test('sets and sessions keep it through a save', () {
      final s = _session(1700000000);
      applyHeart(s, parseFit(_strengthFile(1700000000))!.samples, fitSets: parseFit(_strengthFile(1700000000))!.lifted);
      s.kcal = 250;
      final back = LoggedSession.fromJson(s.toJson());
      expect(back.kcal, 250);
      expect(back.hrHist, s.hrHist);
      expect(back.exercises.first.sets.first.hr, s.exercises.first.sets.first.hr);
      expect(back.exercises.first.sets.first.watch, 10);
    });
  });

  group('Garmin switch', () {
    test('importing a file works only while Garmin is on, and matches the right session', () {
      final bytes = _strengthFile(1700000000);
      fit.sessions.add(_session(1700000000));
      expect(fit.importFit(bytes), contains('on first'));
      fit.loadGarmin({'on': true});
      final line = fit.importFit(bytes);
      expect(line, contains('3 of 3'));
      expect(fit.sessions.first.kcal, 250);
      fit.sessions
        ..clear()
        ..add(_session(1600000000));
      expect(fit.importFit(bytes), contains('No logged session'));
    });

    test('clearing removes what came from the watch and keeps the sessions', () {
      fit.loadGarmin({'on': true});
      fit.sessions.add(_session(1700000000));
      fit.importFit(_strengthFile(1700000000));
      fit.clearGarmin();
      expect(fit.sessions.length, 1);
      expect(fit.sessions.first.kcal, isNull);
      expect(fit.sessions.first.exercises.first.sets.first.hr, isNull);
      expect(fit.garminDays, isEmpty);
    });

    test('the switch and the settings survive a backup', () {
      fit.loadGarmin({'on': true, 'max': 185, 'reps': 12, 'secs': 45});
      final data = fit.toJson();
      fit.resetAllData();
      expect(fit.garminOn, isFalse);
      expect(fit.maxHrSetting, 0);
      fit.applyBackup(data);
      expect(fit.garminOn, isTrue);
      expect(fit.maxHr, 185);
      expect(fit.readyReps, 12);
      expect(fit.readySeconds, 45);
    });

    test('readiness needs Garmin on and at least two signals, and its cards hide when it is off', () {
      final days = <String, Map<String, double>>{'sleep': {}, 'hrv': {}, 'restingHr': {}};
      for (var i = 0; i < 30; i++) {
        final k = HealthMetrics.dayKey(DateTime.now().subtract(Duration(days: i)));
        days['sleep']![k] = 450;
        days['hrv']![k] = 60;
        days['restingHr']![k] = 55;
      }
      fit.loadGarmin({'on': false, 'days': days});
      expect(fit.garminReadiness, isNull);
      expect(StatCards.group('g_before', flat: false), isEmpty);
      fit.loadGarmin({'on': true, 'days': days});
      expect(fit.garminReadiness!.score, inInclusiveRange(86, 90));
      expect(fit.garminSeries('restingHr', 12).whereType<double>().length, 12);
      expect(fit.garminBaseline('hrv'), closeTo(60, 0.001));
      expect(StatCards.group('g_before', flat: false), isNotEmpty);
    });

    test('Garmin cards need their own switch as well', () {
      fit.loadGarmin({'on': true});
      expect(StatCards.one('g_ready', flat: false), isNull, reason: 'no data yet, so hidden');
      expect(kStatCards.where((c) => c.garmin).length, 18);
      fit.setStatOn('g_ready', false);
      expect(StatCards.one('g_ready', flat: false), isNull);
    });
  });

  group('exercise stats', () {
    test('a barbell lift is a loaded exercise with its six stats', () {
      expect(fit.exerciseType(_bench), ExType.loaded);
      expect(kTypeStats[ExType.loaded]!.length, 6);
      for (final type in ExType.values) {
        expect(kTypeStats[type]!.length, 6, reason: type.name);
        for (final id in kTypeStats[type]!) {
          expect(kStatCards.any((c) => c.id == id), isTrue, reason: id);
        }
      }
    });

    test('ready for more compares your reps with the target, and the target is a setting', () {
      for (final d in [21, 14, 7]) {
        fit.sessions.add(_old(d, 80, reps: 8));
      }
      expect(fit.readyFor(_bench)!.hit, 0);
      expect(fit.readyFor(_bench)!.ready, isFalse);
      fit.setReadyReps(8);
      final r = fit.readyFor(_bench)!;
      expect(r.ready, isTrue);
      expect(r.advice, contains('Try'));
    });

    test('PR rhythm, frequency and totals read the history', () {
      for (final (d, kg) in [(42, 80.0), (35, 82.5), (28, 85.0), (21, 87.5), (14, 87.5), (7, 90.0)]) {
        fit.sessions.add(_old(d, kg));
      }
      final rhythm = fit.prRhythm(_bench)!;
      expect(rhythm.first.label, 'Last PR');
      expect(fit.frequencyStats(_bench)!.first.value, contains('7'));
      expect(fit.lifetimeTotals(_bench)!.first.value, '6');
      expect(fit.repMaxes(_bench), isNotNull);
      expect(fit.ladder(_bench), isNull, reason: 'a loaded lift has no milestone ladder');
    });

    test('the deload signal needs enough history and counts the signs that fire', () {
      for (var d = 1; d <= 40; d += 6) {
        fit.sessions.add(_old(d, 80));
      }
      final s = fit.deloadSignal;
      expect(s, isNotNull);
      expect(s!.of, greaterThanOrEqualTo(3));
      expect(s.on, lessThanOrEqualTo(s.of));
    });

    test('rest against reps stays hidden without enough timed sets', () {
      fit.sessions.add(_old(2, 80));
      expect(fit.restVsReps, isNull);
    });
  });

  group('screens', () {
    Future<void> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const GymManeApp());
      await tester.pumpAndSettle();
    }

    void seed() {
      final days = <String, Map<String, double>>{'sleep': {}, 'hrv': {}, 'restingHr': {}, 'totalKcal': {}};
      for (var i = 0; i < 30; i++) {
        final k = HealthMetrics.dayKey(DateTime.now().subtract(Duration(days: i)));
        days['sleep']![k] = 400.0 + i * 3;
        days['hrv']![k] = 55.0 + (i % 5);
        days['restingHr']![k] = 52.0 + (i % 4);
        days['totalKcal']![k] = 2400;
      }
      fit.loadGarmin({'on': true, 'days': days});
      for (var d = 1; d <= 30; d += 3) {
        final s = _old(d, 80 + (30 - d) / 3, reps: 8);
        for (final st in s.exercises.first.sets) {
          st
            ..hr = 120 + d % 7
            ..hrPeak = 140
            ..hrDrop = 20
            ..watch = 8;
        }
        s.hrAvg = 130;
        s.hrMax = 165;
        s.hrHist = List<int>.generate(hrBuckets, (i) => i > 8 && i < 22 ? 30 : 0);
        fit.sessions.add(s);
      }
    }

    testWidgets('main Stats draws the Garmin sections without errors', (tester) async {
      seed();
      fit.setMinimalMode(false);
      await pumpApp(tester);
      fit.goProgress();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('GARMIN · BEFORE YOU LIFT'), 600, scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      expect(find.text('Readiness'), findsWidgets);
    });

    testWidgets('Minimal Stats draws the Garmin and parity cards without errors', (tester) async {
      seed();
      fit.setMinimalMode(true);
      await pumpApp(tester);
      fit.goProgress();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('GARMIN · BEFORE YOU LIFT'), 800, scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Stats cards sheet has the Garmin switch, and its groups open', (tester) async {
      fit.setMinimalMode(false);
      await pumpApp(tester);
      showStatCardsSheet(tester.element(find.byType(Scaffold).first));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('garmin-master')), findsOneWidget);
      expect(find.byKey(const ValueKey('stat-group-g_before')), findsNothing, reason: 'Garmin groups are hidden while it is off');
      expect(find.byKey(const ValueKey('garmin-import')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('garmin-master')));
      await tester.pumpAndSettle();
      expect(fit.garminOn, isTrue);
      expect(find.byKey(const ValueKey('garmin-import')), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('stat-group-g_before')), 300, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.byKey(const ValueKey('stat-group-g_before')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stat-card-g_ready')), findsOneWidget);
    });
  });
}

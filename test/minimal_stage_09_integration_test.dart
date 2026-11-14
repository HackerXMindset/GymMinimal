import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/services/workout_history_xlsx.dart';
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
    fit.setRestSeconds(90);
    fit.startCountdown = false;
    fit.setSessionLayout('list');
    fit.setMinimalMode(true);
    fit.updateMinimalOptions(
      textSize: 'small',
      rowHeight: 'tight',
      showPrevious: false,
      showHowTo: true,
      showNotes: false,
      showExerciseIcons: true,
      showTotals: false,
      showSettingsButton: false,
    );
  });

  tearDown(() {
    if (fit.session != null) fit.saveAndExit();
  });

  test('Minimal workout survives restart, completes into shared stats, and exports real data', () async {
    final exercise = fit.matchExerciseByName('Barbell Bench Press')!;
    final routineId = fit.createRoutine('Stage 9 Push');
    fit.toggleRoutineExercise(routineId, exercise.id);
    final routine = fit.routines.singleWhere((r) => r.id == routineId);

    fit.startRoutine(routine);
    expect(fit.route, 'session');
    expect(fit.session, isNotNull);
    expect(fit.session!.routineId, routineId);

    final workingIndices = [
      for (var i = 0; i < fit.session!.exercises.single.sets.length; i++)
        if (fit.session!.exercises.single.sets[i].counts) i,
    ];
    expect(workingIndices, isNotEmpty);

    final first = workingIndices.first;
    fit.setSessionWeight(0, first, 60);
    fit.setSessionReps(0, first, 8);
    fit.toggleSet(0, first);
    expect(fit.session!.restEndsAt, isNotNull);
    fit.toggleSessionPause();
    expect(fit.sessionPaused, isTrue);
    expect(fit.session!.restFrozen, isNotNull);

    // Simulate an application restart using the same persisted local store.
    fit.persistNow();
    await pumpEventQueue();
    fit.loadFromStore();

    expect(fit.session, isNotNull);
    expect(fit.route, 'session');
    expect(fit.sessionPaused, isTrue);
    expect(fit.session!.exercises.single.sets[first].done, isTrue);
    expect(fit.session!.exercises.single.sets[first].weight, 60);
    expect(fit.session!.exercises.single.sets[first].reps, 8);
    expect(fit.minimalMode, isTrue);
    expect(fit.listLayout, isTrue);
    expect(fit.minimalTextSize, 'small');
    expect(fit.minimalRowHeight, 'tight');
    expect(fit.minimalShowPrevious, isFalse);
    expect(fit.minimalShowHowTo, isTrue);
    expect(fit.minimalShowNotes, isFalse);
    expect(fit.minimalShowExerciseIcons, isTrue);
    expect(fit.minimalShowTotals, isFalse);
    expect(fit.minimalShowSettingsButton, isFalse);

    fit.stepBackIntoSession();
    expect(fit.sessionPaused, isFalse);
    expect(fit.route, 'session');
    expect(fit.session!.restRemaining, isNotNull);

    for (var position = 0; position < workingIndices.length; position++) {
      final index = workingIndices[position];
      final set = fit.session!.exercises.single.sets[index];
      if (set.done) continue;
      fit.setSessionWeight(0, index, 60 + position * 5);
      fit.setSessionReps(0, index, 8 + position);
      fit.toggleSet(0, index);
    }

    fit.finishSession();
    expect(fit.sessions, hasLength(1));
    final logged = fit.sessions.single;
    fit.renameSession(logged, 'Stage 9 Push');

    final loggedExercise = logged.exercises.single;
    final expectedVolume = loggedExercise.volume;
    final expectedSets = logged.setCount;
    final expectedOneRm = loggedExercise.bestOneRm;

    // Exercise list/detail, History, and Stats must use the same saved workout.
    expect(fit.totalSets, expectedSets);
    expect(fit.weekSetCount, expectedSets);
    expect(fit.setsToday, expectedSets);
    expect(fit.totalVolumeKg, closeTo(expectedVolume, 0.001));
    expect(fit.volumeThisWeekKg, closeTo(expectedVolume, 0.001));
    expect(fit.volume30dKg, closeTo(expectedVolume, 0.001));

    final history = fit.exerciseHistory(exercise.id);
    expect(history, isNotEmpty);
    expect(history.first.ex.volume, closeTo(expectedVolume, 0.001));

    final detailRecord = fit.exerciseRecord(exercise.id)!;
    final statsRecord = fit.personalRecords.singleWhere((r) => r.id == exercise.id);
    expect(detailRecord.oneRm, closeTo(expectedOneRm, 0.001));
    expect(statsRecord.oneRm, closeTo(expectedOneRm, 0.001));
    expect(detailRecord.best, closeTo(statsRecord.best, 0.001));

    // Verify the actual XLSX archive and all exported workout rows.
    final xlsx = ZipDecoder().decodeBytes(workoutHistoryXlsx(fit.sessions));
    final sheetFile = xlsx.findFile('xl/worksheets/sheet1.xml');
    expect(sheetFile, isNotNull);
    final sheet = utf8.decode(sheetFile!.readBytes()!);
    final exportedRows = logged.exercises.fold<int>(1, (n, e) => n + e.sets.length);
    expect(sheet, contains('Stage 9 Push'));
    expect(sheet, contains('Barbell Bench Press'));
    expect(sheet, contains('<autoFilter ref="A1:O$exportedRows"/>'));

    // JSON export/import must restore the workout, Minimal settings, and metrics.
    final backup = fit.exportJson();
    final decoded = jsonDecode(backup) as Map<String, dynamic>;
    expect(decoded['sessions'], hasLength(1));
    expect(decoded['minimalMode'], isTrue);

    fit.resetAllData();
    expect(fit.importJson(backup), isTrue);
    expect(fit.sessions, hasLength(1));
    expect(fit.sessions.single.name, 'Stage 9 Push');
    expect(fit.minimalMode, isTrue);
    expect(fit.listLayout, isTrue);
    expect(fit.minimalTextSize, 'small');
    expect(fit.minimalRowHeight, 'tight');
    expect(fit.totalSets, expectedSets);
    expect(fit.totalVolumeKg, closeTo(expectedVolume, 0.001));
    expect(fit.exerciseRecord(exercise.id)!.oneRm, closeTo(expectedOneRm, 0.001));
  });
}

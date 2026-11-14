# Minimal Mode — Sample.html Parity Roadmap

> **Start here for takeover context:** [Complete Project Handoff](MINIMAL_MODE_HANDOFF.md). It explains the product goal, authoritative reference boundary, native code map, exact screen requirements, per-stage implementation contracts, testing, APK release and how to resume from any stage.

**Scope:** Native Android Minimal Mode only. The target is the phone UI inside `#app` in the root `Sample.html`. The browser/demo frame and the prototype's rough Standard-mode mockup are not targets. Standard mode must remain unchanged and fully functional.

**Working method:** One focused stage per branch and pull request. Reuse real Flutter state/models/services; do not copy the HTML prototype's sample data or browser implementation. Run Flutter analysis, relevant tests and the one-APK build on every PR. Only mark a stage complete after its UI and interactions have been checked against the HTML reference. A successful merge to `main` should publish the same tested `GymMinimal.apk` artifact to the rolling GitHub preview release.

**Snapshot:** 2026-11-14. Stage 6 History merged in PR #15 as `b97e1aa2512c84ec9e1037d5911dcd467a648683`; the post-merge main workflow #43534728710 passed analysis, 1,117 tests (3 skipped), one-APK build and preview publishing. Stage 7 Stats Dashboard is being implemented on `feat/minimal-stage-07-stats-dashboard`.

## Overall progress

- [x] Stage 0 — Reference specification and baseline
- [x] Stage 1 — Minimal shell and navigation
- [x] Stage 2 — Today screen
- [x] Stage 3 — Live workout
- [x] Stage 4 — Exercise library
- [x] Stage 5 — Exercise details and per-exercise statistics
- [x] Stage 6 — History (PR #15 merged)
- [ ] Stage 7 — Stats dashboard (in progress, `feat/minimal-stage-07-stats-dashboard`)
- [ ] Stage 8 — Settings
- [ ] Stage 9 — Behaviour, persistence and export parity
- [ ] Stage 10 — Visual and functional QA

**Progress: 6 of 11 stages implemented and merged (55%).** Five stages remain. Final cross-screen visual verification is consolidated in Stage 10.

## Stage details

### Stage 0 — Reference specification and baseline — COMPLETE

- [x] Inspect the complete `Sample.html` and identify the actual `#app` target.
- [x] Inventory screens, navigation, controls, settings, visual tokens and sample states.
- [x] Compare the reference with the current Flutter Minimal implementation.
- [x] Record differences and define Standard mode as out of scope.

### Stage 1 — Minimal shell and navigation — COMPLETE

- [x] Add flat five-destination Minimal navigation: Today, Exercises, History, Stats and Settings.
- [x] Keep existing Standard-mode navigation and presentation conditional on Standard mode.
- [x] Apply reference palette and remove Standard shell chrome from Minimal screens.
- [x] Route the live-workout settings control to Minimal Settings.
- [x] Add navigation regression coverage.
- [x] Merge PR #8.

### Stage 2 — Today screen — COMPLETE (PR #9 merged)

**Primary source:** `lib/screens/home_screen.dart` → `HomeScreen._minimalHome`.  
**Reference:** `Sample.html` → `today()`, `weekStrip()`.

- [x] Match the Today header/date and compact seven-day Monday–Sunday training strip.
- [x] Mark the current day and days containing logged workouts.
- [x] Match the active-workout Resume action and the empty-workout Start action.
- [x] Match compact routine rows with an expand/collapse exercise list and direct Start action.
- [x] Match the compact last-workout summary using real history; show a clean empty state.
- [x] Keep all home-screen changes inside the Minimal branch; Standard home remains on its existing path.
- [x] PR #9 merged on 2026-11-13 (merge commit `f0ed1cf4a5626ee0806cd7bee87c225d361439f9`).
- [x] PR Actions run #43506289411 passed analysis, tests, one-APK build and artifact upload.
- [ ] Include the final phone-viewport screenshot/manual parity check in the consolidated Stage 10 QA pass.

**Implementation is merged. Stage 3 is the next implementation stage; the remaining Today screenshot check is tracked with final visual QA in Stage 10.**

### Stage 3 — Live workout — COMPLETE (PR #11 merged)

**Primary source:** `lib/screens/session_screen.dart`, active-session Minimal branch.  
**Reference:** `Sample.html` → `workoutMin()`, `groupHtml()`, `setRow()`, `noteRow()`, `restHtml()`.

- [x] Match compact toolbar, active timer, pause/resume and Finish actions.
- [x] Match optional duration/volume/completed-total set strip.
- [x] Match one shared set-table header: set number/type, optional Previous, Kg, Reps, Done.
- [x] Match compact, collapsible exercise headers with muscle and completed/total count.
- [x] Match optional How-to, Notes, Add Set, More/Remove and searchable Add Exercise flow.
- [x] Match bottom rest dock with countdown, −15, +15 and Skip.
- [x] Preserve existing session model fields and supported set types; do not flatten underlying workout data.
- [x] Add discard regression coverage; CI run #43515792250 passed analysis, full tests and the single-APK build.
- [ ] Final phone screenshot/manual parity and Standard-mode regression are consolidated in Stage 10.

### Stage 4 — Exercise library — IN PROGRESS (PR #12)

**Primary source:** `lib/screens/exercises_screen.dart`.  
**Reference:** `Sample.html` → `exercises()`, `exList()`.

- [x] Match the Minimal All/muscle filter chips while preserving the existing search field.
- [x] Add the compact Name / Muscle / 1RM table header and aligned rows.
- [x] Calculate 1RM using the existing historical best-lift calculation; show an em dash without history.
- [x] Keep the existing custom-exercise action, search and detail navigation.
- [ ] Verify the 360px phone-width widget test, search/filter interactions and Standard library regression in CI.
- [ ] Complete phone screenshot/manual parity review in Stage 10.

### Stage 5 — Exercise details and per-exercise statistics — IN PROGRESS (PR #14)

**Primary source:** `lib/screens/exercise_detail_screen.dart`.  
**Reference:** `Sample.html` → `exercise()`, `rangeBar()`, `exSessions()`, `lineChart()`, `barsSvg()`.

- [x] Add the ten reference metric slots using logged exercise history: last done, last sets, first done, sessions, total sets, total reps, total volume, heaviest set, best estimated 1RM and last PR.
- [x] Add 4W / 8W / 12W / All controls and earlier/later navigation.
- [x] Add range-filtered estimated 1RM and per-session volume charts.
- [x] Add progressive PR history and a per-session table.
- [ ] Verify empty/sparse history, range navigation, narrow phone layout and Standard detail regression in CI/manual review.
- [ ] Confirm focused tests, formatting, analysis, full tests and one-APK CI build.
- [ ] Complete phone screenshot/manual parity review in Stage 10.

**PR #14 is open. Do not mark Stage 5 complete until CI and visual/interaction review pass.**

### Stage 6 — History — COMPLETE (PR #15 merged)

**Primary source:** `lib/screens/history_screen.dart`; export service `lib/services/workout_history_xlsx.dart`.  
**Reference:** `Sample.html` → `history()`, `tableBody()`, `flat()`.

- [x] Match List / Table switch and Excel export.
- [x] Match latest-40 expandable workout list, newest first.
- [x] Match eight-column table: Date / Exercise / Set / Kg / Reps / Volume / 1RM / Muscle.
- [x] Add search by exercise, muscle or date; sortable columns and active sort direction.
- [x] Bound rendered rows to 200 and report the real result count.
- [x] Verify exports, no-history and no-match states; keep Standard history unchanged. PR #15 merged; main CI passed.

### Stage 7 — Stats dashboard

**Primary source:** `lib/screens/progress_screen.dart`, `lib/state/stats_state.dart`, `lib/widgets/charts.dart`.  
**Reference:** `Sample.html` → `stats()`, `volChart()`, `lineChart()`, `prBars()`, `heat()`, `muscleBars()`.

- [x] Add weekly volume chart with 4W / 8W / 12W / All range selection.
- [x] Keep selected-exercise estimated 1RM trend and show Best / Last PR / Sessions context.
- [x] Add days-since-last-PR chart for exercises with a recorded PR.
- [x] Reuse the existing 16-week training heatmap.
- [x] Reuse the real-data 30-day sets-per-muscle breakdown.
- [ ] Verify real-data calculations, range changes and empty/sparse data states in CI and phone review.

### Stage 8 — Settings

**Primary source:** `lib/screens/settings_screen.dart`, `lib/state/settings_state.dart`.  
**Reference:** `Sample.html` → `settings()`.

- [ ] Match the single compact Minimal Settings page.
- [ ] Match Minimal toggle, text size and row-height controls.
- [ ] Match Previous, How-to, Notes, exercise icons, totals strip and workout-header Settings toggles.
- [ ] Match rest timer adjustment, Excel export, JSON backup and offline/local-data message.
- [ ] Reuse existing persisted Minimal settings fields; do not introduce duplicate prototype/localStorage settings.
- [ ] Verify persistence and Standard preference regression.

### Stage 9 — Behaviour, persistence and export parity

- [ ] Verify full workout journey: start → edit/complete sets → rest → pause/resume → finish → history → exercise detail → stats.
- [ ] Verify active workout restoration after app restart.
- [ ] Verify all Minimal settings persist and affect the correct controls.
- [ ] Verify Excel and JSON exports contain real expected data and supported restore paths work.
- [ ] Verify volume, set counts, 1RM and PR definitions agree across screens.
- [ ] Resolve integration issues and add regression tests.

### Stage 10 — Visual and functional QA

- [ ] Compare each Minimal screen with the corresponding `Sample.html` state at a comparable phone viewport.
- [ ] Check typography, spacing, palette, border, row height, shared table alignment, chart layout and bottom navigation.
- [ ] Exercise every visible button, toggle, tab, filter, timer and export action.
- [ ] Test empty/sparse/large data, long exercise names, small phone width and increased system text size.
- [ ] Switch between Minimal and Standard throughout testing; confirm data is preserved and Standard remains functional.
- [ ] Run formatting, Flutter analysis and the full test suite.
- [ ] Build/install the final single APK and verify launch.
- [ ] Verify the GitHub Release contains exactly one `GymMinimal.apk` asset.

## Native code map

| Destination | Route | Main UI |
|---|---|---|
| Today | `home` | `lib/screens/home_screen.dart` → `_minimalHome` |
| Exercises | `exercises` | `lib/screens/exercises_screen.dart` |
| History | `history` | `lib/screens/history_screen.dart` |
| Stats | `progress` | `lib/screens/progress_screen.dart` → `_MinimalProgressScreen` |
| Settings | `preferences` | `lib/screens/settings_screen.dart` |
| Active workout | `session` | `lib/screens/session_screen.dart` |
| Exercise details | `exercise-detail` | `lib/screens/exercise_detail_screen.dart` |

- App routing/navigation: `lib/app/app_shell.dart`.
- Global state: `lib/state/fit_state.dart` and its state part files.
- Preferences: `lib/state/settings_state.dart`.
- Workout models: `lib/models/live_session.dart`, `lib/models/workout.dart`.
- Persistence: `lib/services/local_store.dart`.
- Excel history export: `lib/services/workout_history_xlsx.dart`.
- Shared theme: `lib/theme/app_colors.dart`, `lib/theme/app_theme.dart`.
- Tests: `test/`; start with the existing test closest to the feature being changed.

## Per-PR quality gate

- [ ] One stage/topic per branch and PR.
- [ ] Dart formatting applied to changed Dart files.
- [ ] `flutter analyze --no-fatal-infos` passes.
- [ ] Relevant focused tests pass.
- [ ] Full `flutter test` suite passes.
- [ ] Workflow builds exactly one APK (no ABI split).
- [ ] Minimal phone screenshot/manual interaction review attached.
- [ ] Standard Mode regression checked.
- [ ] Handoff and roadmap statuses updated truthfully.

## Release pipeline status

The authoritative workflow is the version already merged to `main` by PR #9: `.github/workflows/build-apk.yml`.

- [x] Build one APK (no ABI split) named `GymMinimal.apk`.
- [x] Run Flutter analysis and tests before the APK build.
- [x] Upload one `gymminimal-apk` Actions artifact on PR builds.
- [x] On a push to `main` or manual workflow dispatch, publish the APK produced by that same workflow job; do not run a second Flutter build.
- [x] Main-branch run #43508196293 completed successfully, including the release-publishing steps.
- [x] Verified the rolling GitHub Release contains exactly one APK asset named `GymMinimal.apk`.

**Pipeline design:** the build, test, artifact upload and conditional Release publishing steps are in one job. Release steps run only for main pushes or workflow dispatch; PR runs stop after uploading the artifact. This is the newer `main` implementation and is intentionally retained when resolving PR #10.

**Verified release:** [GymMinimal — Minimal Mode preview](https://github.com/HackerXMindset/GymMinimal/releases/tag/minimal-mode-preview). The asset list contained exactly one APK: `GymMinimal.apk`.

**Signing caveat:** no persistent private release keystore is currently established. Do not promise seamless in-place upgrades across separately built CI APKs until a stable private signing key is configured and tested. Never commit signing credentials.

## Current PR / branch snapshot

| Item | Value |
|---|---|
| PR #8 | Merged — Minimal shell/navigation |
| PR #9 | Merged — Stage 2 Today screen and single-APK workflow |
| PR #10 | Merged — conflict-resolved project handoff/roadmap documentation |
| PR #11 | Merged — Stage 3 Live Workout; Actions run #43515792250 passed |
| PR #10 merge commit | `7fbc49522965e638a110e9988c4fe53b29a11301` |
| PR #10 Actions | Run #43510832870 passed; the newer single-job APK workflow was preserved |
| Current UI stage | Stage 5 — Exercise details (PR #14 in progress); Stage 4 follow-up PR #13 remains open |
| Stage 3 PR | [PR #11](https://github.com/HackerXMindset/GymMinimal/pull/11) — merged |
| Stage 3 merge commit | `7b9a8e3ea4492b56d3391f640c708062991c6297` |
| Stage 3 CI | Actions run #43515792250 passed analysis, full tests and one-APK build |
| Stage 4 branch | `feature/sample-html-parity-stage-4-exercise-library` |
| Stage 4 PR | [PR #12](https://github.com/HackerXMindset/GymMinimal/pull/12) |
| Stage 4 base | `main` at Stage 3 merge commit `7b9a8e3ea4492b56d3391f640c708062991c6297` |
| Stage 4 CI | Pending; verify latest PR run before merge |
| Remaining proof | Phone-sized screenshot/manual interaction review and Standard library regression review |
| Stage 5 PR | [PR #14](https://github.com/HackerXMindset/GymMinimal/pull/14) — open; CI pending |
| Stage 5 branch | `feat/minimal-stage-05-exercise-details` |
| Next action | Review PR #14 CI and phone-width layout; resolve failures before merging Stage 5 |

## Change log

| Date | Change |
|---|---|
| 2026-11-13 | Baseline comparison and staged parity roadmap established. |
| 2026-11-13 | PR #8 merged: Minimal-only shell/navigation parity. |
| 2026-11-14 | PR #10 created: single tested APK release pipeline and roadmap. |
| 2026-11-14 | Expanded handoff guide: source hierarchy, code map, all screen contracts, test/release process and takeover record. |
| 2026-11-14 | PR #9 merged Stage 2 Today and the single-job APK release workflow; Actions run #43506289411 passed. |
| 2026-11-14 | PR #10 conflict resolved and merged as `7fbc49522965e638a110e9988c4fe53b29a11301`; updated PR Actions run #43510832870 passed. |
| 2026-11-14 | Stage 3 Live workout merged in PR #11; Actions run #43515792250 passed analysis, full tests and single-APK build. |
| 2026-11-14 | Main run #43508196293 passed and published the rolling release with exactly one `GymMinimal.apk` asset. |

## How to continue

1. Read [Complete Project Handoff](MINIMAL_MODE_HANDOFF.md).
2. PR #10 is merged and conflict-free; PR #11 Stage 3 is also merged with CI run #43515792250 passing.
3. Stage 4 follow-up PR #13 remains open. Stage 5 implementation is in [PR #14](https://github.com/HackerXMindset/GymMinimal/pull/14) on its own branch from `main`.
4. Review Stage 5 CI and phone-width interactions; do not mark the stage complete until every acceptance check passes.

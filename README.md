# GymMinimal

A minimal, offline gym tracker for Android. Few taps, a quiet screen, and
stats that show you where you are stuck.

GymMinimal is a fork of [GymMane](https://github.com/InlitX/GymMane) by InlitX,
with a **Minimal mode** that turns the whole app into a smaller, calmer version
of itself. Everything GymMane does is still there, and the original look is one
switch away.

- **Offline.** No account, no ads, no analytics, no internet permission.
- **Minimal first.** As few taps as possible, small type, no clutter.
- **Every addition has an on/off switch.** Turn off what you do not use.
- **Stats you can see.** Raw numbers shown as charts, not lectures.

## What GymMinimal adds

### Minimal mode

On by default, with a switch in **Settings**. The Today page matches the
HTML reference in [`docs/design`](docs/design).

- **Today** with one hero card for the workout, no date header, and a **month
  calendar**. Open any day to see its muscles and exercises, and add a workout
  on a past day.
- **Workout** exercises start collapsed. Choose between a **Table** view
  (aligned columns, bands) and the **Cards** view in Settings.
- **Keyboard-first number entry** for weight and reps, remembered between
  sessions, with a small icon to switch back to the scroller.
- **Exercises** open on a **Recent** chip. The exercise page is cleaner, with
  How-to and Settings as popups and no Similar list.
- **History** as a list or a table, with a month calendar on the list. Export a
  single **Excel** file of an exercise's history.
- **Bottom bar** with small icons, and your **wallpaper** shows through.
- **Achievements** are off by default.
- **Compact settings** on one page.

### Stats

- A **Stats** page built from cards you can switch on and off one by one
  (**Settings › Stats cards**), grouped into sections.
- **Per-exercise stats** shaped by the kind of exercise: strength level,
  sets and frequency, records, volume, progression, and more. Nineteen cards in
  all, each with its own switch.
- **Minimal parity cards**: the same stats arranged for the Minimal screen.
- **Rep max per exercise.** Change an exercise's 1RM to any rep max (8RM, for
  example) in its settings, and the chart follows.
- **Swipe through past weeks** on every card that shows one week. Drag left to
  right for the previous week.
- **Chart styles** you pick in Settings: classic, a **TradingView-style**
  chart with a crosshair and tooltip, bars, or dots.

### Garmin and heart rate (optional)

Off until you turn on the **Garmin** switch.

- Reads Garmin data through **Health Connect**, and imports **.fit** files.
- Heart rate, zones, sleep, readiness and hard minutes as cards, plus heart
  rate laid over your sets.
- Max heart rate is typed in or worked out for you.

### Food tracker in Minimal (optional)

A small tracker under the workout card on Today, with a switch. It reads the
same food log and targets as the full Nutrition section (**Settings › Beta**).

- A **Food strip** with bars against your targets, quick-add foods, and a
  Water button.
- A small **Food page** for the day's meals, with a link to the full Nutrition
  section.
- **Everything is a setting**: the numbers shown (calories, protein, carbs, fat,
  water, fiber, sugar, sodium), targets (with a separate set for rest days),
  your meals, the quick-add foods, and which cards show.
- **Twelve food cards** on Stats, such as calories by week, macro split, days on
  target, when you eat and water.
- **Food next to training**: protein on lifting days against rest days, calories
  next to bodyweight, and what eating before you lift does to your load.

## Everything from GymMane

GymMinimal is currently on top of **GymMane 2.4.0**. Body map sessions, rest
timer, supersets, routines, progression and deload weeks, records and strength
curves, 500+ exercises with animations, places, a training journal, twelve
calculators, widgets, an NFC sticker, nutrition (beta), the Wear OS watch app,
imports from Hevy, Strong, Lyfta, Liftosaur, JEFIT, StrongLifts, FitNotes and
openGym, CSV and ZIP backups, Health Connect, and 22 languages. See the
[GymMane README](https://github.com/InlitX/GymMane#readme) for the full list.

## Build

The signed ARM64 APK is built on GitHub Actions
(`.github/workflows/build-minimal-apk.yml`, also runnable by hand from the
**Actions** tab). To build it yourself:

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64
```

The release is signed with the key in `android/keystore`. Replace it with your
own if you publish the app.

## Privacy

There is no internet permission, so your training and food never leave your
phone. The permissions it asks for are for the rest timer, its notification and
the widgets.

## License and credit

Based on GymMane by InlitX. The code is [GPL-3.0](LICENSE), with one
[additional term](ADDITIONAL_TERMS.md) under its section 7(b): works based on
GymMane must credit it as "Based on GymMane by InlitX". The exercise art is
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) and the fonts
use the SIL Open Font License. [CREDITS.md](CREDITS.md) has the details.

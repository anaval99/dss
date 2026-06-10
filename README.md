# Damn Simple Scheduler (dss)

A deliberately minimal scheduler for Android. One screen, one job: **tell it
what's coming up, and it shows you an urgency-sorted list.** No month grid to
navigate, no accounts, no invites or timezones — just capture and glance.

## Why it exists

A calendar's month grid is a *viewer* being misused as an *input*. Apps like
Google/iOS Calendar make you navigate to a date — scroll to the month, tap the
day cell — before you can say what you want to remember. But you already know
the date in your head. DSS inverts this: you state the event as plain data
(title + date), and the home screen sorts itself. You never "go to" a date;
you just tell it one.

## Features

- **Flat, sorted list** — events ordered by how soon they are, not by calendar position.
- **Urgency at a glance** — color-coded rows: red (overdue / today), yellow (within a week), green (later).
- **Flexible schedules** — one-time, weekly (any set of weekdays), monthly by day-of-month, or monthly by nth weekday (e.g. "3rd Friday"). Optional time-of-day, or all-day.
- **Fast capture & edit** — `+` to add, tap to edit, swipe to delete with undo.
- **Local & private** — all data lives on-device (Drift/SQLite). No accounts, no network, no sync.

## Download

Grab the latest APK from the [Releases page](https://github.com/anaval99/dss/releases).
On your phone, open the APK and allow installing from unknown sources when prompted.

## Build & run from source

Requires the Flutter SDK (stable, 3.44+).

```bash
flutter pub get
flutter run                    # run on a connected device/emulator
flutter build apk --release    # build a release APK
```

## Tech

Flutter • Riverpod (state) • Drift (local persistence). Architecture is layered:
`domain/` (pure models + recurrence engine), `data/` (Drift database + repository),
`presentation/` (screens, widgets, providers).

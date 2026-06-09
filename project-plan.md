# Damn Simple Scheduler — Project Plan

> A dead-simple, **offline-only** scheduler. One screen: a date-sorted list of events.
> A `+` button to add them. Fat-finger-friendly **scroller** inputs. Color-coded by urgency.
> No login, no network, no cloud — all data lives on the device.

---

## 1. Product summary

A single-purpose mobile app for tracking upcoming events — both **one-time** and **recurring** —
displayed as one continuous list sorted by date (soonest first). Each row is color-coded by how
soon it is. Adding/editing uses wheel "scroller" pickers so it's comfortable to use without
precise tapping.

### Core principles
- **Damn simple.** One primary screen. No tabs, no accounts, no settings sprawl.
- **Offline-first, local-only.** Zero network code. Data never leaves the device.
- **Forgiving input.** Wheel scrollers for date, time, and AM/PM. Large tap targets.
- **Glanceable urgency.** Color tells you at a glance what's due.

---

## 2. Confirmed requirements & decisions

| Area | Decision |
|------|----------|
| **Platforms** | Android only (code stays cross-platform-clean; only Android is tested/shipped) |
| **Storage** | Local-only, on-device. No sync, no backend, no auth. |
| **Event types** | One-time; Recurring (weekly-by-weekday, monthly-by-day, monthly-by-nth-weekday) |
| **Event fields** | Title (required) + Notes (optional, multi-line) + date/time/recurrence |
| **Time** | Optional on all event types. Entered via wheel scrollers incl. AM/PM (12-hour). |
| **Sorting** | Single list, by effective date ascending (soonest/overdue first). |
| **Color coding** | Overdue **or** today → **red**; 1–6 days → **yellow**; 7+ days → **green**. |
| **Overdue events** | One-time events whose date has passed **stay at the top**, styled overdue (red), until deleted. |
| **Recurring mapping** | Each recurring event shows its **nearest upcoming occurrence** (today counts if it matches). |
| **Recurrence end** | Repeats **forever** (no end date). |
| **Month edge cases** | **Clamp to last valid day**: "31st" → Feb 28/29, Apr 30; "5th Friday" → last Friday. |
| **Manage events** | **Tap a row to edit; swipe to delete.** |
| **Reminders** | **Visual only for v1**, but architected so local notifications can be added later cleanly. |

---

## 3. Tech stack & rationale

| Concern | Choice | Why |
|---------|--------|-----|
| Framework | **Flutter** (stable 3.44.x, Dart 3.12) | Already set up; great for this UI. |
| State management | **Riverpod** (`flutter_riverpod` v2) | Testable, no `BuildContext` plumbing; the derived "sorted + colored occurrence list" is a clean computed provider. |
| Persistence | **Drift** (SQLite) | Type-safe, migration-friendly, durable. Survives the notifications phase (queryable schedule data). `sqflite` was the lighter alternative but Drift's codegen + migrations win for longevity. |
| Date/format | **`intl`** | Locale-aware date/time formatting. |
| Pickers | **`CupertinoDatePicker` / `CupertinoPicker` / `ListWheelScrollView`** | Native wheel "scroller" feel for date, time, AM/PM, day-of-month, weekday, ordinal — exactly the fat-finger UX requested. (Cupertino wheels look/work fine on Android.) |
| IDs | SQLite autoincrement `INTEGER` PK | Simple; no uuid dependency needed. |
| Notifications (later) | `flutter_local_notifications` + `timezone` | Phase 8 only. Not pulled in for v1. |

**Why not just JSON/SharedPreferences?** CRUD + edit/delete + growing event counts are cleaner over a
real table, and Drift gives compile-time-checked queries and a migration path. The recurrence
*occurrences* are computed in-app (we store the **rule**, never materialized dates), so storage stays tiny.

---

## 4. Architecture

Layered, with a **pure-Dart domain core** (no Flutter imports) so the riskiest logic — recurrence math
and color classification — is fully unit-testable in isolation.

```
lib/
├── main.dart                      # bootstrap: init DB, ProviderScope, runApp
├── app.dart                       # MaterialApp, theme, routing
│
├── core/
│   ├── theme/                     # color tokens, text styles, urgency palette
│   ├── date/                      # date-only helpers, "today" provider, day math
│   └── constants.dart
│
├── domain/                        # PURE DART — no Flutter, no Drift
│   ├── models/
│   │   ├── event.dart             # Event entity (sealed by EventSchedule)
│   │   ├── schedule.dart          # sealed: OneTime | Weekly | MonthlyByDay | MonthlyByWeekday
│   │   ├── occurrence.dart        # an Event resolved to its next concrete DateTime
│   │   └── urgency.dart           # enum: overdue, today, soon(yellow), later(green)
│   └── recurrence/
│       ├── recurrence_engine.dart # nextOccurrence(schedule, from) -> DateTime?
│       └── urgency_classifier.dart# classify(occurrenceDate, today) -> Urgency
│
├── data/
│   ├── database/
│   │   ├── app_database.dart      # Drift DB + Events table + migrations
│   │   └── event_dao.dart
│   └── repositories/
│       └── event_repository.dart  # CRUD; maps Drift rows <-> domain Event
│
└── presentation/
    ├── providers/
    │   ├── repository_providers.dart
    │   ├── today_provider.dart        # current date (refreshes at midnight / on resume)
    │   └── event_list_provider.dart   # watch events -> resolve occurrences -> sort -> classify
    ├── screens/
    │   ├── event_list_screen.dart     # the home screen + FAB
    │   └── event_editor_screen.dart   # create/edit form
    └── widgets/
        ├── event_tile.dart            # row: title, when, urgency accent + label
        ├── empty_state.dart
        └── pickers/
            ├── wheel_date_picker.dart
            ├── wheel_time_picker.dart        # hour / minute / AM-PM wheels
            ├── day_of_month_wheel.dart       # 1..31
            ├── weekday_wheel.dart            # Mon..Sun
            └── ordinal_wheel.dart            # 1st..5th
```

### Data flow
1. `EventRepository` exposes a reactive stream of all stored `Event`s (Drift `.watch()`).
2. `eventListProvider` combines that stream with `todayProvider`, and for each event computes its
   **next occurrence** (recurring) or its date (one-time, possibly overdue), then **sorts ascending**
   and tags each with an **`Urgency`**.
3. `EventListScreen` renders the resulting `List<ResolvedEvent>`; `EventTile` paints the urgency color.
4. Edits go back through the repository → Drift → stream re-emits → list rebuilds. Unidirectional.

---

## 5. Domain model details

### Event
```
Event {
  int? id
  String title              // required, non-empty
  String? notes             // optional
  EventSchedule schedule    // sealed (below)
  DateTime createdAt
  DateTime updatedAt
}
```

### EventSchedule (sealed)
All schedules carry an **optional `TimeOfDay? time`** (null = all-day).

| Variant | Fields | Example |
|---------|--------|---------|
| `OneTime` | `DateTime date`, `TimeOfDay? time` | "Dentist on Jun 20, 2:30 PM" |
| `Weekly` | `Set<int> weekdays` (1=Mon…7=Sun), `TimeOfDay? time` | "Every Monday" / "Every Mon & Thu" |
| `MonthlyByDay` | `int dayOfMonth` (1–31), `TimeOfDay? time` | "Every 1st", "Every 31st" |
| `MonthlyByWeekday` | `int ordinal` (1–5), `int weekday` (1–7), `TimeOfDay? time` | "Every 3rd Friday" |

### Recurrence engine — `nextOccurrence(schedule, from: today)`
Returns the **first occurrence on or after `today`** (date granularity; today counts).

- **OneTime** → returns its `date` regardless (may be in the past → overdue). Recurring never returns past.
- **Weekly** → nearest of the chosen weekdays ≥ today. *(today is Tue, rule = Wed ⇒ this coming Wed; rule = Tue ⇒ today.)*
- **MonthlyByDay** → this month's `min(dayOfMonth, lastDayOfMonth)` if ≥ today, else next month's (clamped). *(31st in Feb ⇒ 28th/29th.)*
- **MonthlyByWeekday** → the nth weekday this month; if that month has fewer (e.g. no 5th Friday) **clamp to the last** matching weekday; if it's already past, roll to next month.

> **Clamp rule (global):** whenever a requested day doesn't exist in a month, use the **last valid** day/weekday of that month rather than skipping.

### Urgency classifier — `classify(occurrenceDate, today)`
Computed from **whole-day** difference `d = occurrenceDate - today`:

| Condition | Urgency | Color |
|-----------|---------|-------|
| `d < 0` (overdue, one-time only) | `overdue` | **red** |
| `d == 0` (today) | `today` | **red** |
| `1 ≤ d ≤ 6` | `soon` | **yellow** |
| `d ≥ 7` | `later` | **green** |

Color is **always derived, never stored.** Time-of-day does not change the color (a thing due later
today is still "today/red").

---

## 6. UI / UX design direction

The visual build will use the **`/frontend-design:frontend-design` skill** to keep it distinctive and
production-grade (not generic). Guiding direction:

- **One calm, content-first screen.** Neutral background; events as cards/rows. The only saturated
  colors are the urgency accents, so they pop.
- **Urgency shown three ways (accessibility — never color alone):**
  - a colored **left accent bar / dot**, plus
  - a **tinted** row background, plus
  - a **relative label**: `Overdue 2d` · `Today` · `In 3 days` · `In 2 weeks`.
- **Urgency palette (tokens, tuned in build):** red `#E5484D`, yellow/amber `#F5A623`, green `#30A46C`,
  on a near-white surface with dark text. Dark-mode variants defined as tokens.
- **The list:** overdue/today (red) cluster at the top, flowing down to greens. Each row shows
  **title**, **when** (e.g. "Mon, Jun 16 · 2:30 PM" or "Every 3rd Friday"), and a recurrence glyph.
- **FAB `+`** bottom-right opens the editor.
- **Editor screen:**
  - Title field (autofocus), optional Notes.
  - **Type segmented control:** One-time / Recurring.
  - **One-time:** wheel **date** picker; optional wheel **time** (hour · minute · AM/PM columns).
  - **Recurring:** sub-choice (Weekly / Monthly by day / Monthly by weekday) revealing the matching
    wheel(s): weekday wheel, day-of-month wheel (1–31), or ordinal+weekday wheels. Optional time wheel.
  - A **live "Next: …" preview** line that runs the recurrence engine as you scroll, so the user sees
    exactly when it'll next fire.
  - Save / (on edit) Delete.
- **Interactions:** tap row → editor (prefilled); **swipe row → delete** (with undo snackbar).
- **Empty state:** friendly prompt pointing at the `+`.

---

## 7. Edge cases & rules (locked)

- **Month clamping:** 31st → last day of short months; 5th weekday → last such weekday.
- **Weekly "today counts":** if today matches the rule's weekday, the nearest occurrence is **today** (red).
- **All-day events** (no time) sort before timed events on the same date; render without a time.
- **"Today" boundary** is local **midnight**; the app recomputes urgency on resume and at day rollover
  (`todayProvider` invalidates so colors stay correct without a restart).
- **Overdue** applies only to one-time events (recurring always have a future occurrence).
- **Local time only** — wall-clock times; no timezone conversion in v1 (revisit with notifications).
- **Empty title** blocked at save.

---

## 8. Build phases & milestones

> Phase 0 is already done (Flutter scaffold, `damn.simple.scheduler` app id, git init).
> Each phase is independently runnable/testable.

| Phase | Deliverable | Key tests |
|-------|-------------|-----------|
| **1. Domain core** | `Event`, sealed `EventSchedule`, `recurrence_engine`, `urgency_classifier` — pure Dart | **Extensive unit tests** for every recurrence variant + clamp + boundary days; classifier truth table |
| **2. Persistence** | Drift DB, `Events` table, `EventRepository` CRUD, row↔domain mapping | Repo CRUD tests on in-memory DB; round-trip of every schedule variant |
| **3. State layer** | Riverpod providers; `eventListProvider` (resolve → sort → classify); `todayProvider` | Provider tests with fake repo/clock |
| **4. List screen** | Home screen, `EventTile` with urgency styling, FAB, empty state | Widget test: ordering + colors render |
| **5. Editor + wheel pickers** | Create flow for all types; date/time/AM-PM/day/weekday/ordinal wheels; live "Next:" preview | Widget tests for each picker; create→appears-in-list |
| **6. Edit & delete** | Tap-to-edit (prefilled), swipe-to-delete + undo | Edit persists; delete + undo restores |
| **7. Design polish** | Apply frontend-design pass: theme tokens, dark mode, spacing, motion, accessibility labels | Manual + golden tests (optional) |
| **8. Notifications (later)** | `flutter_local_notifications`: schedule per next occurrence, reschedule on edit/rollover | Scheduling integration tests |

**v1 = Phases 1–7.** Phase 8 is post-v1 (the architecture already isolates the "next occurrence"
computation that notifications will reuse).

---

## 9. Dependencies to add

**v1:**
```
flutter_riverpod        # state
drift                   # persistence (runtime)
sqlite3_flutter_libs    # bundled SQLite for Android
path_provider           # DB file location
path                    # path joining
intl                    # date/time formatting

dev:
drift_dev               # codegen
build_runner            # codegen runner
```
**Phase 8 (later):** `flutter_local_notifications`, `timezone`.

---

## 10. Testing strategy

- **Unit (heaviest):** recurrence engine + urgency classifier are the correctness-critical core —
  table-driven tests across weekdays, month lengths, leap years, clamps, and the today-boundary.
- **Repository:** Drift in-memory DB, full CRUD + schedule round-trips.
- **Provider:** injected fake clock (`todayProvider`) + fake repo to assert ordering/colors deterministically.
- **Widget:** list ordering/colors, each wheel picker, create/edit/delete flows.
- A fixed **injectable "today"** (no direct `DateTime.now()` in domain) keeps every date test deterministic.

---

## 11. Open items / future (post-v1)
- Local notifications & reminders (Phase 8).
- Optional recurrence **end date** (currently forever).
- Search / filter, categories, recurring **end-after-N**, snooze.
- Backup/export (e.g. JSON file share) — still offline, user-initiated.
- iOS build & store packaging.

---

*Decisions captured 2026-06-08. This plan is the source of truth; update it as scope evolves.*

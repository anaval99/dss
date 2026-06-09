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

#### Invariants & defensive handling
These are enforced at construction **and** the persistence boundary must tolerate violations from
malformed stored rows (a single bad row must **never** throw and take down the whole list render):

- **`Weekly.weekdays` is non-empty**, each value in `1..7`. Editor blocks save on an empty set
  (mirrors "empty title blocked"). An empty/invalid stored set ⇒ row is **skipped-and-logged**, not thrown.
- **`MonthlyByDay.dayOfMonth`** is clamped to `1..31` *on read* (`dayOfMonth.clamp(1, 31)`), then
  clamped again to the target month's last day during occurrence computation. (Guards `DateTime(y,m,0)`,
  which silently rolls to the previous month.)
- **`MonthlyByWeekday.ordinal`** in `1..5`, **`weekday`** in `1..7`; out-of-range ⇒ skip-and-logged.
- **Unknown schedule discriminator** (e.g. a type written by a future schema) ⇒ skip-and-logged, never throw.
- The repository mapping returns a `List<Event>` of only the **valid** rows; invalid rows are dropped
  with a logged warning so the list keeps rendering. (A "corrupt event" tile is a post-v1 nicety.)

### Recurrence engine — `nextOccurrence(schedule, from) -> DateTime?`
Returns the **first occurrence whose *date* is on or after `from`** (today counts). Both `from` and the
returned value are normalized to **date-only** (midnight, local) for all comparisons — the engine works
purely in calendar dates. Time-of-day is **not** part of occurrence selection in v1; it is carried
separately for display only (and never moves an occurrence to the next day). Returns `null` only for an
invalid/empty schedule that slipped past validation (caller skips it).

> **Normative comparison rule:** all date comparisons use **date-only** values
> (`d = DateUtils.dateOnly(x)`). Never compare or subtract raw `DateTime`s with a time component.

**Global ordered algorithm for the monthly variants** (this exact order is mandatory — a naive
"compare the raw requested day, then clamp" ordering would wrongly skip an occurrence):

```
nextMonthlyOccurrence(from):
  cursor = first-of-month(from)
  loop:                                 # bounded; resolves within at most a few iterations
    candidate = resolveInMonth(cursor)  # CLAMP happens here, inside the month
    if dateOnly(candidate) >= dateOnly(from):
        return candidate
    cursor = cursor + 1 month           # roll forward
    # loop re-runs resolveInMonth → RE-CLAMPS in the new month
```
The key invariants: **clamp first (inside the month) → then compare to `from` → only then roll → then
re-clamp.** Each `resolveInMonth` is self-contained and always re-clamps; "roll to next month" never
carries a clamped day across the boundary.

Per-variant `resolveInMonth` / selection:

- **OneTime** → returns its `date` verbatim (may be in the past → overdue). Recurring never returns past.
- **Weekly** → smallest date `≥ from` whose weekday ∈ `weekdays` (scan the next 7 days from `from`).
  *(today Tue, rule Wed ⇒ this coming Wed; rule Tue ⇒ today.)* Requires `weekdays` non-empty (invariant).
- **MonthlyByDay** → `day = min(dayOfMonth.clamp(1,31), lastDayOfMonth(cursor))`; candidate =
  `DateTime(cursor.year, cursor.month, day)`. *(31st in Feb ⇒ 28th/29th.)*
- **MonthlyByWeekday** → the `ordinal`-th `weekday` in `cursor`'s month; if the month has fewer
  (e.g. no 5th Friday) **clamp to the last** matching weekday in that month. Then apply the ordered
  algorithm (compare, roll, **re-clamp** next month).

> **Clamp rule (global):** whenever a requested day/weekday-ordinal doesn't exist in a month, use the
> **last valid** one in that month rather than skipping — applied *inside each month*, before comparison.

### Urgency classifier — `classify(occurrenceDate, today)`
`d` is a **calendar-day count**, computed on **date-only** values — *not* `Duration.inDays`:

```
d = dateOnly(occurrenceDate).difference(dateOnly(today)).inDays
```
> ⚠️ **Must not** use `occurrence.difference(today).inDays` on raw timestamps: `inDays` truncates toward
> zero, so a 23:30 occurrence vs midnight `today` yields `0`, an off-by-one across the day boundary.
> Normalizing both to midnight first makes the delta a true calendar-day difference. This boundary case
> has a dedicated test (see §10).

| Condition | Urgency | Color |
|-----------|---------|-------|
| `d < 0` (overdue, one-time only) | `overdue` | **red** |
| `d == 0` (today) | `today` | **red** |
| `1 ≤ d ≤ 6` | `soon` | **yellow** |
| `d ≥ 7` | `later` | **green** |

Color is **always derived, never stored.** Time-of-day does not change the color (a thing due later
today is still "today/red").

### Sort comparator — total & deterministic
`List.sort` in Dart is **not stable**, so equal-key rows would reorder/flicker on every stream re-emit.
The resolved list uses a **total comparator** with a final unique tiebreaker:

```
compareBy(
  1. dateOnly(occurrence)        ascending   # soonest/overdue first
  2. isAllDay ? 0 : 1            ascending   # all-day before timed, same date
  3. time (minutes from midnight) ascending  # earlier time first (timed only)
  4. id                           ascending   # unique final tiebreaker → deterministic
)
```
Because overdue one-time events carry past dates, key #1 naturally clusters them at the very top
(most-overdue first). Same-datetime events keep a stable, repeatable order via `id`.

### Persistence schema (Drift) — `schemaVersion = 1`
The sealed `EventSchedule` (variants with disjoint fields) maps to **one flat table** via a
**discriminator column + nullable per-variant columns**. Computed occurrences are never stored.

`Events` table:

| Column | Type | Notes |
|--------|------|-------|
| `id` | `INTEGER` PK AUTOINCREMENT | unique, stable; used as the sort tiebreaker |
| `title` | `TEXT NOT NULL` | non-empty (validated above the DB) |
| `notes` | `TEXT NULL` | optional |
| `scheduleType` | `TEXT NOT NULL` | discriminator: `oneTime` \| `weekly` \| `monthlyByDay` \| `monthlyByWeekday` |
| `date` | `INTEGER (epoch millis) NULL` | `OneTime` only |
| `weekdaysMask` | `INTEGER NULL` | `Weekly` only — **7-bit mask**, bit `n` = weekday `n+1` (Mon=bit0…Sun=bit6) |
| `dayOfMonth` | `INTEGER NULL` | `MonthlyByDay` only (1–31) |
| `ordinal` | `INTEGER NULL` | `MonthlyByWeekday` only (1–5) |
| `weekday` | `INTEGER NULL` | `MonthlyByWeekday` only (1–7) |
| `timeMinutes` | `INTEGER NULL` | optional time-of-day = minutes from midnight; `NULL` = all-day |
| `createdAt` | `INTEGER (epoch millis) NOT NULL` | |
| `updatedAt` | `INTEGER (epoch millis) NOT NULL` | |

- **`Set<int> weekdays` serialization:** chosen as a **7-bit integer bitmask** (compact, indexable,
  trivially round-trippable) rather than CSV/JSON. The repository converts mask ⇄ `Set<int>` and
  treats `0`/`NULL` as invalid (→ skip-and-log).
- **Migrations:** start at `schemaVersion = 1` with a documented `MigrationStrategy`; every future
  column/variant change bumps the version with an explicit migration step (Drift-checked).
- **Repository mapping is total and non-throwing** (per the invariants above): unknown `scheduleType`
  or out-of-range variant fields drop the row with a logged warning.

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

- **Month clamping:** 31st → last day of short months; 5th weekday → last such weekday. Applied
  *inside each month, before the ≥ comparison*, with **re-clamp after rolling** to the next month
  (see the ordered algorithm in §5).
- **Weekly "today counts":** if today matches the rule's weekday, the nearest occurrence is **today** (red).
- **Date-only comparisons everywhere:** the engine and classifier normalize to midnight; never subtract
  raw timestamps (`Duration.inDays` truncation bug — see §5 classifier).
- **Sorting is total & deterministic:** `(dateOnly, all-day-first, time, id)` with `id` as a unique
  tiebreaker; results are stable across stream re-emits (no row flicker). See §5 comparator.
- **Malformed / unknown stored rows** are **skipped-and-logged** by the repository — a single bad row
  never throws or blanks the list (invariants in §5).
- **"Today" boundary & day rollover (concrete mechanism):** `today` is local **midnight**. A top-level
  `WidgetsBindingObserver` recomputes `today` on **`AppLifecycleState.resumed`** — this is the reliable
  path (an in-process midnight `Timer` is **not** dependable on Android due to Doze/app suspension).
  Optionally, while the app is foregrounded, a `Timer` set to the next local midnight invalidates
  `todayProvider` so an app left open overnight refreshes its colors without a restart. On invalidation,
  the derived list re-resolves occurrences and re-classifies.
- **Overdue** applies only to one-time events (recurring always have a future occurrence).
- **Local time only** — wall-clock times; no timezone conversion in v1 (revisit with notifications).
- **Empty title** blocked at save; **Weekly requires ≥1 weekday** selected before save.

---

## 8. Build phases & milestones

> Phase 0 is already done (Flutter scaffold, `damn.simple.scheduler` app id, git init).
> Each phase is independently runnable/testable.

| Phase | Deliverable | Key tests |
|-------|-------------|-----------|
| **1. Domain core** | `Event`, sealed `EventSchedule` (+ invariants), `recurrence_engine` (ordered algorithm), `urgency_classifier` (date-only delta), sort comparator — pure Dart. **Decide the `weekdaysMask` serialization + table column layout here** (so Phase 2 has a spec, not a gap). | **Extensive unit tests**: every recurrence variant, clamp, roll-then-re-clamp, classifier boundary, sort stability |
| **2. Persistence** | Drift DB (`schemaVersion=1`), `Events` table, `EventRepository` CRUD, **total non-throwing** row↔domain mapping | Repo CRUD on in-memory DB; round-trip every variant (mask ⇄ set); malformed-row tolerance |
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
  Mandatory cases:
  - **Clamp + ordering:** "31st" in Feb (28/29) and Apr (30); "5th Friday" in a 4-Friday month →
    last Friday; **roll-then-re-clamp** (e.g. today late-month, no occurrence this month → next month
    re-clamped, *not* the month after).
  - **Weekly "today counts":** rule weekday == today ⇒ today; multi-weekday picks the nearest.
  - **Classifier day-boundary:** `23:30 today` vs `00:00 tomorrow` ⇒ `d == 1` (regression guard for the
    `Duration.inDays` truncation bug); `d` values at −1, 0, 1, 6, 7.
- **Repository:** Drift in-memory DB, full CRUD + **round-trip of every schedule variant** (incl. the
  `weekdaysMask` ⇄ `Set<int>` conversion). **Malformed-row tolerance:** unknown `scheduleType`, empty
  `weekdaysMask`, out-of-range `dayOfMonth`/`ordinal` ⇒ row dropped, list still returns the valid rows.
- **Provider:** injected fake clock (`todayProvider`) + fake repo to assert ordering/colors deterministically,
  including **sort stability** (two events with identical date+time keep a fixed order across re-emits via `id`).
- **Widget:** list ordering/colors, each wheel picker, create/edit/delete flows; **Weekly save blocked**
  with zero weekdays.
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

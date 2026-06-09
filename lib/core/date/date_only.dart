import 'package:flutter/material.dart' show DateUtils;

/// Pure calendar-date math used across the domain.
///
/// The recurrence engine and urgency classifier compare and subtract dates
/// **only** through these helpers — never raw [DateTime]s with a time
/// component. Subtracting raw timestamps and reading `Duration.inDays`
/// truncates toward zero, which produces an off-by-one across the day
/// boundary (e.g. a 23:30 occurrence vs midnight today would read as 0 days).
/// Normalizing both operands to local midnight first makes every delta a true
/// calendar-day difference.

/// Midnight-local of [date] (drops the time component).
DateTime dateOnly(DateTime date) => DateUtils.dateOnly(date);

/// Last calendar day (28–31) of the given [year]/[month].
///
/// `DateTime(year, month + 1, 0)` rolls back to the final day of [month],
/// correctly handling 30/31-day months and leap-year February.
int lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// First-of-month, [months] away from [date]'s month (date-only, day = 1).
///
/// Used as the recurrence cursor: monthly resolution always starts from the
/// first of the month so day clamping happens cleanly inside each month.
DateTime addMonths(DateTime date, int months) =>
    DateTime(date.year, date.month + months, 1);

/// Whole calendar days from [from] to [to] (negative if [to] is earlier).
///
/// Both operands are normalized to midnight first — this is the only correct
/// way to count day deltas (see the truncation note above).
int daysBetween(DateTime from, DateTime to) =>
    dateOnly(to).difference(dateOnly(from)).inDays;

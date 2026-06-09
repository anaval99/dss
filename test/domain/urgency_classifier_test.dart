import 'package:dss/domain/models/urgency.dart';
import 'package:dss/domain/recurrence/urgency_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 6, 9);

  test('delta -1 is overdue', () {
    expect(classify(DateTime(2026, 6, 8), today), Urgency.overdue);
  });

  test('delta 0 is today', () {
    expect(classify(DateTime(2026, 6, 9), today), Urgency.today);
  });

  test('delta 1 is soon', () {
    expect(classify(DateTime(2026, 6, 10), today), Urgency.soon);
  });

  test('delta 6 is soon', () {
    expect(classify(DateTime(2026, 6, 15), today), Urgency.soon);
  });

  test('delta 7 is later', () {
    expect(classify(DateTime(2026, 6, 16), today), Urgency.later);
  });

  test('23:30 today vs 00:00 tomorrow is d==1 (truncation regression)', () {
    // Raw `difference(...).inDays` would be 0 (30 minutes truncated). The
    // date-only delta must be 1 → soon.
    final occurrence = DateTime(2026, 6, 10, 0, 0);
    final now = DateTime(2026, 6, 9, 23, 30);
    expect(classify(occurrence, now), Urgency.soon);
  });
}

import 'schedule.dart';

/// A user-created event: a title/notes plus a [schedule] describing when it
/// occurs. Pure data — resolution to a concrete occurrence and its urgency
/// lives in the recurrence layer.
///
/// [title] non-emptiness is a save-time UI concern, not enforced here.
class Event {
  const Event({
    this.id,
    required this.title,
    this.notes,
    required this.schedule,
    required this.createdAt,
    required this.updatedAt,
  });

  /// SQLite autoincrement PK; `null` before first persist. Also the unique
  /// final tiebreaker in the resolved-list sort.
  final int? id;
  final String title;
  final String? notes;
  final EventSchedule schedule;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event copyWith({
    int? id,
    String? title,
    String? notes,
    EventSchedule? schedule,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      schedule: schedule ?? this.schedule,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Event &&
      other.id == id &&
      other.title == title &&
      other.notes == notes &&
      other.schedule == schedule &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, title, notes, schedule, createdAt, updatedAt);
}

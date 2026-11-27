import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

/// DAO de "Libre" (v8): contadores de hábitos que se dejan y sus momentos
/// (ganas superadas y reinicios).
class QuitDao {
  QuitDao(this._db);

  final AppDatabase _db;

  static const String eventUrge = 'urge';
  static const String eventReset = 'reset';

  Stream<List<QuitTracker>> watchActive() {
    return (_db.select(_db.quitTrackers)
          ..where((tbl) => tbl.isArchived.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.startedAt)]))
        .watch();
  }

  Stream<QuitTracker?> watchTracker(int id) {
    return (_db.select(_db.quitTrackers)..where((tbl) => tbl.id.equals(id))).watchSingleOrNull();
  }

  Future<QuitTracker?> getTracker(int id) {
    return (_db.select(_db.quitTrackers)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertTracker(QuitTrackersCompanion entry) {
    return _db.into(_db.quitTrackers).insert(entry);
  }

  Future<void> updateTracker(int id, QuitTrackersCompanion patch) {
    return (_db.update(_db.quitTrackers)..where((tbl) => tbl.id.equals(id))).write(patch);
  }

  Future<void> deleteTracker(int id) {
    return (_db.delete(_db.quitTrackers)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<int> insertEvent(QuitEventsCompanion entry) {
    return _db.into(_db.quitEvents).insert(entry);
  }

  Future<void> deleteEvent(int id) {
    return (_db.delete(_db.quitEvents)..where((tbl) => tbl.id.equals(id))).go();
  }

  Stream<List<QuitEvent>> watchEvents(int trackerId) {
    return (_db.select(_db.quitEvents)
          ..where((tbl) => tbl.trackerId.equals(trackerId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.occurredAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Reinicia la racha en una transacción: guarda el evento, suma la racha que
  /// termina al tiempo libre total y actualiza la mejor racha.
  Future<int> resetStreak({required QuitTracker tracker, required DateTime at, String? note}) {
    return _db.transaction(() async {
      final int streak = at.isBefore(tracker.startedAt)
          ? 0
          : at.difference(tracker.startedAt).inSeconds;
      final int eventId = await insertEvent(
        QuitEventsCompanion.insert(
          trackerId: tracker.id,
          kind: eventReset,
          occurredAt: at,
          streakSeconds: Value(streak),
          note: Value(note),
        ),
      );
      await updateTracker(
        tracker.id,
        QuitTrackersCompanion(
          startedAt: Value(at),
          bankedSeconds: Value(tracker.bankedSeconds + streak),
          longestStreakSeconds: Value(
            streak > tracker.longestStreakSeconds ? streak : tracker.longestStreakSeconds,
          ),
          celebratedMilestones: const Value(0),
        ),
      );
      return eventId;
    });
  }

  /// Deshace un reinicio: devuelve el contador al estado guardado en [before].
  Future<void> undoReset({required QuitTracker before, required int eventId}) {
    return _db.transaction(() async {
      await deleteEvent(eventId);
      await updateTracker(
        before.id,
        QuitTrackersCompanion(
          startedAt: Value(before.startedAt),
          bankedSeconds: Value(before.bankedSeconds),
          longestStreakSeconds: Value(before.longestStreakSeconds),
          celebratedMilestones: Value(before.celebratedMilestones),
        ),
      );
    });
  }
}

final quitDaoProvider = Provider<QuitDao>((Ref ref) {
  return QuitDao(ref.watch(appDatabaseProvider));
});

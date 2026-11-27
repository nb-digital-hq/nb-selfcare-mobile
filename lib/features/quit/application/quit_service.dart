import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/quit_dao.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../../pet_gamification/domain/reward_policy.dart';
import '../domain/quit_catalog.dart';
import '../domain/quit_progress.dart';

/// Datos del formulario de un contador (crear o editar).
class QuitDraft {
  const QuitDraft({
    required this.presetKey,
    required this.startedAt,
    this.customName,
    this.dailyCost,
    this.dailyUnits,
    this.dailyMinutes,
    this.motivation,
  });

  final String presetKey;
  final String? customName;
  final DateTime startedAt;
  final double? dailyCost;
  final double? dailyUnits;
  final int? dailyMinutes;
  final String? motivation;
}

/// Casos de uso de "Libre": crear y editar contadores, reiniciar sin culpa,
/// registrar ganas superadas y celebrar hitos.
class QuitService {
  QuitService(this._dao, this._rewards, this._clock);

  final QuitDao _dao;
  final RewardService _rewards;
  final Clock _clock;

  static const int maxNameLength = 40;

  /// Tipos de momento del historial (para contar en la presentación).
  static const String eventUrge = QuitDao.eventUrge;
  static const String eventReset = QuitDao.eventReset;

  static const int maxTextLength = 200;

  static String? _clean(String? raw, int max) {
    final String t = (raw ?? '').trim();
    if (t.isEmpty) return null;
    return t.length > max ? t.substring(0, max) : t;
  }

  static double? _positive(double? v) => v == null || v.isNaN || v <= 0 ? null : v;

  /// Crea un contador. Un hábito propio sin nombre no se guarda (devuelve `null`).
  Future<int?> add(QuitDraft d) async {
    final bool isCustom = QuitPreset.byKey(d.presetKey).key == QuitPreset.customKey;
    final String? name = _clean(d.customName, maxNameLength);
    if (isCustom && name == null) return null;
    final DateTime now = _clock.now();
    final DateTime start = d.startedAt.isAfter(now) ? now : d.startedAt;
    return _dao.insertTracker(
      QuitTrackersCompanion.insert(
        presetKey: isCustom ? QuitPreset.customKey : d.presetKey,
        customName: Value(isCustom ? name : null),
        startedAt: start,
        firstStartedAt: start,
        dailyCost: Value(_positive(d.dailyCost)),
        dailyUnits: Value(_positive(d.dailyUnits)),
        dailyMinutes: Value(d.dailyMinutes == null || d.dailyMinutes! <= 0 ? null : d.dailyMinutes),
        motivation: Value(_clean(d.motivation, maxTextLength)),
        // Quien empieza con días ya ganados no recibe de golpe las celebraciones
        // de lo anterior: se celebra desde el próximo hito.
        celebratedMilestones: Value(QuitMilestones.reachedCount(now.difference(start))),
        createdAt: now,
      ),
    );
  }

  /// Edita un contador. Cambiar la fecha de inicio corrige la racha actual.
  Future<void> update(QuitTracker t, QuitDraft d) async {
    final bool isCustom = t.presetKey == QuitPreset.customKey;
    final String? name = _clean(d.customName, maxNameLength);
    final DateTime now = _clock.now();
    final DateTime start = d.startedAt.isAfter(now) ? now : d.startedAt;
    final bool startChanged = !start.isAtSameMomentAs(t.startedAt);
    await _dao.updateTracker(
      t.id,
      QuitTrackersCompanion(
        customName: isCustom && name != null ? Value(name) : const Value.absent(),
        startedAt: Value(start),
        firstStartedAt: start.isBefore(t.firstStartedAt) ? Value(start) : const Value.absent(),
        dailyCost: Value(_positive(d.dailyCost)),
        dailyUnits: Value(_positive(d.dailyUnits)),
        dailyMinutes: Value(d.dailyMinutes == null || d.dailyMinutes! <= 0 ? null : d.dailyMinutes),
        motivation: Value(_clean(d.motivation, maxTextLength)),
        celebratedMilestones: startChanged
            ? Value(QuitMilestones.reachedCount(now.difference(start)))
            : const Value.absent(),
      ),
    );
  }

  /// Reinicia la racha. Lo ganado se conserva en el tiempo total y en la mejor
  /// racha. Devuelve el contador previo y el id del evento para deshacer.
  Future<({QuitTracker before, int eventId})?> reset(int id, {String? note}) async {
    final QuitTracker? before = await _dao.getTracker(id);
    if (before == null) return null;
    final int eventId = await _dao.resetStreak(
      tracker: before,
      at: _clock.now(),
      note: _clean(note, maxTextLength),
    );
    return (before: before, eventId: eventId);
  }

  Future<void> undoReset(QuitTracker before, int eventId) =>
      _dao.undoReset(before: before, eventId: eventId);

  /// Unas ganas que pasaron sin ceder: se guardan y dan monedas (una vez al día).
  Future<RewardGrant> urgeSurfed(int id, {String? note}) async {
    final DateTime now = _clock.now();
    await _dao.insertEvent(
      QuitEventsCompanion.insert(
        trackerId: id,
        kind: QuitDao.eventUrge,
        occurredAt: now,
        note: Value(_clean(note, maxTextLength)),
      ),
    );
    return _rewards.grant(RewardAction.urgeSurfed, dateKey: now.dateKey);
  }

  /// Si la racha alcanzó un hito aún sin celebrar, lo marca y devuelve el
  /// hito (con las monedas); si no, `null`.
  Future<({Duration milestone, RewardGrant grant})?> celebrateIfDue(QuitTracker t) async {
    final DateTime now = _clock.now();
    final int reached = QuitProgress.compute(startedAt: t.startedAt, now: now).milestonesReached;
    if (reached <= t.celebratedMilestones) return null;
    await _dao.updateTracker(t.id, QuitTrackersCompanion(celebratedMilestones: Value(reached)));
    final RewardGrant grant = await _rewards.grant(
      RewardAction.quitMilestone,
      dateKey: now.dateKey,
    );
    return (milestone: QuitMilestones.all[reached - 1], grant: grant);
  }

  Future<void> archive(int id) =>
      _dao.updateTracker(id, const QuitTrackersCompanion(isArchived: Value(true)));

  Future<void> unarchive(int id) =>
      _dao.updateTracker(id, const QuitTrackersCompanion(isArchived: Value(false)));

  Future<void> delete(int id) => _dao.deleteTracker(id);
}

final quitServiceProvider = Provider<QuitService>((Ref ref) {
  return QuitService(
    ref.watch(quitDaoProvider),
    ref.watch(rewardServiceProvider),
    ref.watch(clockProvider),
  );
});

/// Contadores activos.
final quitTrackersProvider = StreamProvider<List<QuitTracker>>((Ref ref) {
  return ref.watch(quitDaoProvider).watchActive();
});

final quitTrackerProvider = StreamProvider.family<QuitTracker?, int>((Ref ref, int id) {
  return ref.watch(quitDaoProvider).watchTracker(id);
});

final quitEventsProvider = StreamProvider.family<List<QuitEvent>, int>((Ref ref, int id) {
  return ref.watch(quitDaoProvider).watchEvents(id);
});

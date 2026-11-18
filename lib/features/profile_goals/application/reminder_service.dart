import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/reminders_dao.dart';
import '../../../core/database/daos/supplement_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/domain/care_enums.dart';
import '../../../core/domain/enums.dart';
import '../../../core/l10n/idioma.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/platform/native_call.dart';
import '../../../core/platform/notification_gateway.dart';
import '../../care/domain/treatment_schedule.dart';

/// Recordatorios de hábitos (docs/07 §1.2): la tabla `reminders` es la fuente de
/// verdad y cada cambio reprograma las alarmas locales del sistema.
class ReminderService {
  ReminderService(
    this._remindersDao,
    this._profileDao,
    this._supplementDao,
    this._notifications,
    this._l10n,
  );

  /// Los avisos se programan con el idioma activo en ese momento; al cambiar
  /// de idioma se reprograman (ver Ajustes).
  final AppLocalizations Function() _l10n;

  final RemindersDao _remindersDao;
  final UserProfileDao _profileDao;
  final SupplementDao _supplementDao;
  final NotificationGateway _notifications;

  /// Los avisos de tomas usan ids a partir de aquí (los de la tabla son pequeños).
  static const int treatmentIdBase = 100000;

  /// Clave de la acción "Hecho" de una toma: `dose:<tratamiento>:<minutos|->`.
  static String doseActionKey(int treatmentId, int? slotMinutes) =>
      'dose:$treatmentId:${slotMinutes ?? '-'}';

  static ({int treatmentId, int? slotMinutes})? parseDoseAction(String key) {
    final List<String> parts = key.split(':');
    if (parts.length != 3 || parts[0] != 'dose') return null;
    final int? id = int.tryParse(parts[1]);
    if (id == null) return null;
    return (treatmentId: id, slotMinutes: parts[2] == '-' ? null : int.tryParse(parts[2]));
  }

  static String _hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  /// Textos en positivo: invitan, nunca reprochan (ADR-08).
  static ({String title, String body}) copyFor(AppLocalizations l10n, ReminderType type) =>
      switch (type) {
        ReminderType.morningWeighIn => (
          title: l10n.reminderPesajeMatutino,
          body: l10n.reminderEnAyunasYDescalzo15,
        ),
        ReminderType.hydration => (
          title: l10n.reminderUnVasoDeAgua,
          body: l10n.reminderTuCuerpoLoAgradeceRegistralo,
        ),
        ReminderType.fastingOpen => (
          title: l10n.reminderSeAbreTuVentanaDe,
          body: l10n.reminderEmpiezaSuaveProteinaVerdurasY,
        ),
        ReminderType.fastingClose => (
          title: l10n.reminderCierraTuVentanaDeComida,
          body: l10n.reminderBuenMomentoParaLaUltima,
        ),
        ReminderType.tapeMeasure => (
          title: l10n.reminderValidacionConCintaMetrica,
          body: l10n.reminderCinturaYCuelloYCadera,
        ),
        ReminderType.journal => (
          title: l10n.reminderUnMomentoParaTi,
          body: l10n.reminderComoTeSentisteHoyUnas,
        ),
        ReminderType.windDown => (
          title: l10n.reminderHoraDeIrBajandoEl,
          body: l10n.reminderLucesSuavesYMenosPantalla,
        ),
        // Siempre discreto: se ve en la pantalla de bloqueo.
        ReminderType.pelvicFloor => (
          title: l10n.reminderTuMomentoDe3Minutos,
          body: l10n.reminderCuandoPuedasAbreNbSelfcare,
        ),
        ReminderType.eyeRest => (
          title: l10n.reminderDescansaLaVista,
          body: l10n.reminderMiraAlgoLejanoDurante20,
        ),
      };

  /// Texto del aviso de una toma: discreto por defecto (sin el nombre del medicamento).
  static ({String title, String body}) doseCopy(
    AppLocalizations l10n, {
    required bool discreet,
    required String name,
    required String dosage,
    required int? slotMinutes,
  }) {
    if (discreet) {
      return (title: l10n.reminderUnMomentoParaTi, body: l10n.reminderTienesUnaTomaPendiente);
    }
    return (
      title: slotMinutes == null
          ? l10n.reminderTuTomaDeHoy
          : l10n.reminderTuTomaDeLas(_hhmm(slotMinutes).toString()),
      body: dosage.isEmpty ? name : '$name · $dosage',
    );
  }

  Future<void> seedDefaults() async {
    await _remindersDao.seedDefaultRemindersIfEmpty();
    await _remindersDao.ensureReminderTypes();
    await syncSchedules();
  }

  Future<void> setEnabled(int id, bool enabled) async {
    await _remindersDao.toggleReminder(id, enabled);
    await syncSchedules();
  }

  Future<void> setTime(int id, int minutesOfDay) async {
    await _remindersDao.updateReminderTime(id, minutesOfDay);
    await syncSchedules();
  }

  /// Reprograma todos los recordatorios activos. Los de la ventana de ayuno se
  /// omiten si el usuario desactivó el módulo de ayuno (modos contextuales); los
  /// de tomas, si el módulo de tratamientos está oculto.
  Future<void> syncSchedules() async {
    final AppLocalizations l10n = _l10n();
    final UserProfile? profile = await _profileDao.getProfile();
    final bool fastingEnabled = profile?.isFastingEnabled ?? true;
    final bool discreet = profile?.discreetNotifications ?? true;
    final Set<CareModule> modules = profile == null
        ? CareModule.defaults
        : ProfileSets.careModules(profile.careModulesJson);
    final List<Reminder> reminders = await _remindersDao.getEnabledReminders();
    final List<SupplementsTrackerData> treatments = modules.contains(CareModule.treatments)
        ? await _supplementDao.getActiveSupplements()
        : const <SupplementsTrackerData>[];

    await bestEffort(
      () => _notifications.setReminders(<ScheduledReminder>[
        for (final Reminder r in reminders)
          if (_isVisible(r.reminderType, fastingEnabled: fastingEnabled, modules: modules))
            ScheduledReminder(
              id: r.id,
              title: copyFor(l10n, r.reminderType).title,
              body: copyFor(l10n, r.reminderType).body,
              minutesOfDay: r.timeOfDayMinutes,
              daysMask: r.daysOfWeekBitmask,
              intervalMinutes: r.intervalMinutes,
              windowEndMinutes: r.reminderType == ReminderType.eyeRest ? 18 * 60 + 30 : 21 * 60,
            ),
        for (final SupplementsTrackerData t in treatments)
          if (t.remindersEnabled)
            for (final (int index, int slot) in TreatmentSchedule.decodeTimes(
              t.scheduleJson,
            ).indexed)
              ScheduledReminder(
                id: treatmentIdBase + t.id * 16 + index,
                title: doseCopy(
                  l10n,
                  discreet: discreet,
                  name: t.name,
                  dosage: t.dosage,
                  slotMinutes: slot,
                ).title,
                body: doseCopy(
                  l10n,
                  discreet: discreet,
                  name: t.name,
                  dosage: t.dosage,
                  slotMinutes: slot,
                ).body,
                minutesOfDay: slot,
                daysMask: t.daysOfWeekBitmask,
                actionKey: doseActionKey(t.id, slot),
                actionLabel: l10n.reminderHecho,
              ),
      ]),
      null,
    );
  }

  static bool _isVisible(
    ReminderType type, {
    required bool fastingEnabled,
    required Set<CareModule> modules,
  }) => switch (type) {
    ReminderType.fastingOpen || ReminderType.fastingClose => fastingEnabled,
    ReminderType.pelvicFloor => modules.contains(CareModule.pelvicFloor),
    ReminderType.eyeRest => modules.contains(CareModule.activeBreaks),
    _ => true,
  };
}

final reminderServiceProvider = Provider<ReminderService>((Ref ref) {
  return ReminderService(
    ref.watch(remindersDaoProvider),
    ref.watch(userProfileDaoProvider),
    ref.watch(supplementDaoProvider),
    ref.watch(notificationGatewayProvider),
    () => ref.read(l10nProvider),
  );
});

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/daos/pet_dao.dart';
import 'package:nb_selfcare/core/database/daos/quit_dao.dart';
import 'package:nb_selfcare/core/database/daos/user_profile_dao.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/core/l10n/generated/app_localizations_es.dart';
import 'package:nb_selfcare/features/pet_gamification/application/reward_service.dart';
import 'package:nb_selfcare/features/quit/application/quit_service.dart';
import 'package:nb_selfcare/features/quit/domain/quit_catalog.dart';
import 'package:nb_selfcare/features/quit/domain/quit_progress.dart';
import 'package:nb_selfcare/features/quit/presentation/quit_l10n.dart';

import '../support/test_container.dart';

void main() {
  group('QuitProgress', () {
    final DateTime start = DateTime(2026, 11, 1, 8);

    test('racha, dinero, unidades y tiempo crecen con los días libres', () {
      final QuitProgress p = QuitProgress.compute(
        startedAt: start,
        now: start.add(const Duration(days: 10)),
        dailyCost: 12000,
        dailyUnits: 10,
        dailyMinutes: 90,
      );
      expect(p.streak, const Duration(days: 10));
      expect(p.moneySaved, closeTo(120000, 0.01));
      expect(p.unitsAvoided, closeTo(100, 0.01));
      expect(p.minutesReclaimed, 900);
      // 1, 3 y 7 días alcanzados; el siguiente es a las 2 semanas.
      expect(p.milestonesReached, 3);
      expect(p.nextMilestone, const Duration(days: 14));
      expect(p.milestoneFraction, closeTo(3 / 7, 0.001));
    });

    test('un reinicio no borra lo ganado: se suma al tiempo libre total', () {
      final QuitProgress p = QuitProgress.compute(
        startedAt: start,
        now: start.add(const Duration(days: 2)),
        bankedSeconds: const Duration(days: 5).inSeconds,
        longestStreakSeconds: const Duration(days: 5).inSeconds,
        dailyCost: 1000,
      );
      expect(p.cleanTime, const Duration(days: 7));
      expect(p.moneySaved, closeTo(7000, 0.01));
      expect(p.longest, const Duration(days: 5));
      expect(p.isPersonalBest, isFalse);
    });

    test('un inicio en el futuro (reloj cambiado) cuenta como cero', () {
      final QuitProgress p = QuitProgress.compute(
        startedAt: start,
        now: start.subtract(const Duration(hours: 3)),
      );
      expect(p.streak, Duration.zero);
      expect(p.milestonesReached, 0);
      expect(p.moneySaved, isNull);
    });

    test('superados todos los hitos, el anillo queda lleno', () {
      final QuitProgress p = QuitProgress.compute(
        startedAt: start,
        now: start.add(const Duration(days: 1000)),
      );
      expect(p.nextMilestone, isNull);
      expect(p.milestoneFraction, 1.0);
      expect(p.milestonesReached, QuitMilestones.all.length);
    });

    test('beneficios del tabaco en orden y el siguiente por llegar', () {
      final QuitProgress p = QuitProgress.compute(
        startedAt: start,
        now: start.add(const Duration(hours: 13)),
      );
      expect(p.reachedBenefits(QuitPreset.tobacco).map((QuitBenefit b) => b.key), <String>[
        'tobacco_20m',
        'tobacco_12h',
      ]);
      expect(p.nextBenefit(QuitPreset.tobacco)?.key, 'tobacco_2d');
    });
  });

  group('Catálogo', () {
    final AppLocalizationsEs l10n = AppLocalizationsEs();

    test('cada preset y cada beneficio tiene texto y los beneficios van en orden', () {
      for (final QuitPreset p in QuitPreset.all) {
        expect(QuitText.preset(l10n, p.key), isNotEmpty);
        for (int i = 0; i < p.benefits.length; i++) {
          expect(QuitText.benefit(l10n, p.benefits[i].key), isNotEmpty, reason: p.benefits[i].key);
          if (i > 0) expect(p.benefits[i].after > p.benefits[i - 1].after, isTrue);
        }
      }
      expect(QuitPreset.byKey('desconocido').key, QuitPreset.customKey);
    });

    test('duraciones legibles', () {
      expect(QuitText.span(l10n, const Duration(minutes: 20)), '20 min');
      expect(QuitText.span(l10n, const Duration(days: 1)), '1 día');
      expect(QuitText.span(l10n, const Duration(days: 14)), '2 semanas');
      expect(QuitText.span(l10n, const Duration(days: 30)), '1 mes');
      expect(QuitText.span(l10n, const Duration(days: 66)), '66 días');
      expect(QuitText.span(l10n, const Duration(days: 730)), '2 años');
      expect(QuitText.compact(l10n, const Duration(days: 3, hours: 4)), '3 d 4 h');
      expect(QuitText.money(l10n, 125000.7), r'$ 125.000');
    });
  });

  group('QuitService', () {
    late AppDatabase db;
    final DateTime now = DateTime(2026, 11, 14, 10);

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await UserProfileDao(db).createProfile(
        UserProfilesCompanion.insert(
          name: 'Ana',
          birthDate: DateTime(1990, 3, 10),
          biologicalSex: BiologicalSex.female,
          heightCm: 165,
          targetWeightKg: 60,
        ),
      );
      await db.into(db.petStatus).insert(const PetStatusCompanion(coinsBalance: Value(0)));
    });

    tearDown(() => db.close());

    Future<int> coins() async => (await PetDao(db).getPetStatus())!.coinsBalance;

    test('un hábito propio sin nombre no se guarda; uno del catálogo sí', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final QuitService s = c.read(quitServiceProvider);
      expect(await s.add(QuitDraft(presetKey: 'custom', customName: '  ', startedAt: now)), isNull);
      final int? id = await s.add(
        QuitDraft(
          presetKey: 'tobacco',
          startedAt: now.add(const Duration(days: 2)), // futuro: se recorta a ahora
          dailyCost: 8000,
          dailyUnits: 12,
          dailyMinutes: 30, // no aplica al tabaco, pero no rompe nada
          motivation: '  Respirar mejor  ',
        ),
      );
      final QuitTracker t = (await QuitDao(db).getTracker(id!))!;
      expect(t.startedAt, now);
      expect(t.motivation, 'Respirar mejor');
      expect(t.customName, isNull);
    });

    test('empezar con días ya ganados no regala las celebraciones pasadas', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final QuitService s = c.read(quitServiceProvider);
      final int id = (await s.add(
        QuitDraft(presetKey: 'alcohol', startedAt: now.subtract(const Duration(days: 8))),
      ))!;
      final QuitTracker t = (await QuitDao(db).getTracker(id))!;
      expect(t.celebratedMilestones, 3);
      expect(await s.celebrateIfDue(t), isNull);
    });

    test('un hito nuevo se celebra una sola vez y da monedas', () async {
      final ProviderContainer start = createTestContainer(db, now: now);
      final int id = (await start
          .read(quitServiceProvider)
          .add(QuitDraft(presetKey: 'sugar', startedAt: now)))!;
      start.dispose();

      final ProviderContainer later = createTestContainer(
        db,
        now: now.add(const Duration(days: 1, hours: 1)),
      );
      addTearDown(later.dispose);
      final QuitService s = later.read(quitServiceProvider);
      final ({Duration milestone, RewardGrant grant})? r = await s.celebrateIfDue(
        (await QuitDao(db).getTracker(id))!,
      );
      expect(r?.milestone, const Duration(days: 1));
      expect(r?.grant.granted, isTrue);
      expect(await coins(), greaterThan(0));
      expect(await s.celebrateIfDue((await QuitDao(db).getTracker(id))!), isNull);
    });

    test('reiniciar guarda la racha en el total y se puede deshacer', () async {
      final ProviderContainer start = createTestContainer(db, now: now);
      final int id = (await start
          .read(quitServiceProvider)
          .add(QuitDraft(presetKey: 'vape', startedAt: now.subtract(const Duration(days: 4)))))!;
      start.dispose();
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final QuitService s = c.read(quitServiceProvider);

      final ({QuitTracker before, int eventId})? r = await s.reset(id, note: 'Una fiesta');
      QuitTracker t = (await QuitDao(db).getTracker(id))!;
      expect(t.startedAt, now);
      expect(t.bankedSeconds, const Duration(days: 4).inSeconds);
      expect(t.longestStreakSeconds, const Duration(days: 4).inSeconds);
      expect(t.celebratedMilestones, 0);
      final List<QuitEvent> events = await QuitDao(db).watchEvents(id).first;
      expect(events.single.kind, QuitDao.eventReset);
      expect(events.single.note, 'Una fiesta');

      await s.undoReset(r!.before, r.eventId);
      t = (await QuitDao(db).getTracker(id))!;
      expect(t.startedAt, now.subtract(const Duration(days: 4)));
      expect(t.bankedSeconds, 0);
      expect(await QuitDao(db).watchEvents(id).first, isEmpty);
    });

    test('ganas superadas: se registran y dan monedas una vez al día', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final QuitService s = c.read(quitServiceProvider);
      final int id = (await s.add(QuitDraft(presetKey: 'caffeine', startedAt: now)))!;
      expect((await s.urgeSurfed(id)).granted, isTrue);
      expect((await s.urgeSurfed(id)).granted, isFalse);
      expect((await QuitDao(db).watchEvents(id).first).length, 2);
    });

    test('borrar un contador borra su historial', () async {
      final ProviderContainer c = createTestContainer(db, now: now);
      addTearDown(c.dispose);
      final QuitService s = c.read(quitServiceProvider);
      final int id = (await s.add(QuitDraft(presetKey: 'gaming', startedAt: now)))!;
      await s.urgeSurfed(id);
      await s.delete(id);
      expect(await QuitDao(db).getTracker(id), isNull);
      expect(await db.select(db.quitEvents).get(), isEmpty);
    });
  });
}

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/health_sync_dao.dart';
import '../../../core/database/seeder/database_seeder.dart';
import '../../../core/domain/care_enums.dart';
import '../../../core/domain/enums.dart';
import '../../../core/l10n/idioma.dart';
import '../../../shared/utils/date_time_extensions.dart';
import '../../body_metrics/application/weigh_in_service.dart';
import '../../care/application/checkup_service.dart';
import '../../care/application/habit_service.dart';
import '../../care/application/health_log_services.dart';
import '../../care/application/treatment_service.dart';
import '../../fasting/application/fasting_service.dart';
import '../../journal/application/journal_service.dart';
import '../../nutrition_hydration/application/food_logging_service.dart';
import '../../nutrition_hydration/application/hydration_service.dart';
import 'onboarding_service.dart';

/// Textos de la demostración en cada idioma. Son datos de ejemplo, no
/// interfaz: se escriben en la base como lo haría la persona.
class _TextosDemo {
  const _TextosDemo({
    required this.alimentos,
    required this.diario,
    required this.medicamento,
    required this.suplemento,
    required this.habitos,
  });

  /// Fragmentos de los nombres de la semilla: avena, huevo, pollo, arroz, aguacate.
  final List<String> alimentos;
  final String diario;
  final String medicamento;
  final String suplemento;
  final List<String> habitos;
}

const Map<String, _TextosDemo> _textos = <String, _TextosDemo>{
  'es': _TextosDemo(
    alimentos: <String>[
      'Avena en hojuelas',
      'Huevo entero',
      'Pechuga de pollo a la plancha',
      'Arroz blanco',
      'Aguacate',
    ],
    diario: 'Dormí bien y entrené fuerza por la mañana. Mucha energía.',
    medicamento: 'Losartán',
    suplemento: 'Creatina',
    habitos: <String>['Hilo dental', 'Protector solar'],
  ),
  'en': _TextosDemo(
    alimentos: <String>[
      'Rolled oats',
      'Whole egg',
      'Grilled chicken breast',
      'Cooked white rice',
      'avocado',
    ],
    diario: 'Slept well and did strength training in the morning. Lots of energy.',
    medicamento: 'Losartan',
    suplemento: 'Creatine',
    habitos: <String>['Floss', 'Sunscreen'],
  ),
  'pt': _TextosDemo(
    alimentos: <String>[
      'Aveia em flocos',
      'Ovo inteiro',
      'Peito de frango grelhado',
      'Arroz branco',
      'Abacate',
    ],
    diario: 'Dormi bem e treinei força pela manhã. Muita energia.',
    medicamento: 'Losartana',
    suplemento: 'Creatina',
    habitos: <String>['Fio dental', 'Protetor solar'],
  ),
};

/// Siembra el perfil ficticio "Alex" con 30 días de pesajes, sueño y pasos y
/// un día completo de comidas, agua, ayuno, diario, tomas, hábitos, síntomas y
/// signos vitales. Lo usan las capturas de la documentación y la edición de
/// demostración (`--dart-define=NB_DEMO=true`); nunca se mezcla con datos
/// reales porque solo actúa sobre una base sin perfil.
Future<void> sembrarDemo(
  AppDatabase db, {
  required DateTime ahora,
  required String idioma,
  String themeKey = 'samsung_dark',
}) async {
  if (await db.select(db.userProfiles).getSingleOrNull() != null) return;
  final _TextosDemo t = _textos[idioma] ?? _textos['es']!;
  await DatabaseSeeder.seedIfEmpty(db, idioma: idioma);

  ProviderContainer en(DateTime momento) => ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(Clock.fixed(momento)),
      localeActivoProvider.overrideWithValue(localeDe(idiomaDeClave(idioma))),
    ],
  );

  final DateTime inicio = ahora.subtract(const Duration(days: 29));
  final ProviderContainer primero = en(DateTime(inicio.year, inicio.month, inicio.day, 7));
  await primero
      .read(onboardingServiceProvider)
      .complete(
        OnboardingAnswers(
          name: 'Alex',
          birthDate: DateTime(1996, 5, 20),
          sex: BiologicalSex.male,
          heightCm: 178,
          currentWeightKg: 84.6,
          targetWeightKg: 76,
          weeklyGoalRateKg: -0.5,
          dailyWaterGoalMl: 2500,
          dailyStepsGoal: 8000,
          dailySleepGoalHours: 7.5,
          themeKey: themeKey,
          hasSmartScale: true,
          vitalDevices: <VitalKind>{VitalKind.bloodPressure, VitalKind.glucose},
        ),
      );
  primero.dispose();

  // Tendencia a la baja con el ruido diario del agua.
  const List<double> ruido = <double>[0.3, -0.2, 0.5, -0.4, 0.1, 0.6, -0.3, 0.2, -0.1, 0.4];
  for (int dia = 1; dia < 30; dia++) {
    final DateTime manana = DateTime(inicio.year, inicio.month, inicio.day + dia, 7, 10);
    final ProviderContainer c = en(manana);
    await c
        .read(weighInServiceProvider)
        .record(
          weightKg: double.parse(
            (84.6 - dia * 0.08 + ruido[dia % ruido.length]).toStringAsFixed(1),
          ),
          impedanceOhms: 480 + (dia % 7) * 6,
          source: MeasurementSource.miScale2Ble,
        );
    await HealthSyncDao(db).upsertDailySummary(
      DailySummariesCompanion(
        dateKey: Value(manana.dateKey),
        stepsCount: Value(5200 + (dia % 6) * 900),
        sleepDurationMinutes: Value(400 + (dia % 5) * 20),
        sleepDeepMinutes: Value(55 + (dia % 3) * 10),
        sleepRemMinutes: Value(70 + (dia % 4) * 8),
        restingHeartRateBpm: Value(56 + dia % 5),
      ),
    );
    c.dispose();
  }

  final ProviderContainer hoy = en(ahora);
  final String clave = ahora.dateKey;
  final List<FoodItem> catalogo = await db.select(db.foodItems).get();
  FoodItem alimento(String fragmento) =>
      catalogo.firstWhere((FoodItem f) => f.name.toLowerCase().contains(fragmento.toLowerCase()));
  final FoodLoggingService comidas = hoy.read(foodLoggingServiceProvider);
  final List<(int, double, MealType)> platos = <(int, double, MealType)>[
    (0, 60, MealType.breakfast),
    (1, 120, MealType.breakfast),
    (2, 180, MealType.lunch),
    (3, 150, MealType.lunch),
    (4, 70, MealType.lunch),
  ];
  for (final (int i, double gramos, MealType comida) in platos) {
    await comidas.logPortion(
      food: alimento(t.alimentos[i]),
      grams: gramos,
      mealType: comida,
      dateKey: clave,
    );
  }
  for (int i = 0; i < 4; i++) {
    await hoy.read(hydrationServiceProvider).logGlass(dateKey: clave, volumeMl: 250);
  }
  await hoy
      .read(fastingServiceProvider)
      .start(
        protocolName: '16:8',
        targetHours: 16,
        startedAt: ahora.subtract(const Duration(hours: 14, minutes: 20)),
      );
  await hoy
      .read(journalServiceProvider)
      .save(
        JournalEntriesCompanion.insert(
          dateKey: clave,
          content: t.diario,
          moodScore: const Value(4),
          energyLevel: const Value(5),
          stressLevel: const Value(2),
        ),
      );
  final TreatmentService tratamientos = hoy.read(treatmentServiceProvider);
  final int? medicamento = await tratamientos.save(
    TreatmentDraft(
      name: t.medicamento,
      dosage: '50 mg',
      kind: TreatmentKind.medication,
      times: const <int>[480, 1200],
      stockUnits: 9,
      remindersEnabled: true,
    ),
  );
  await tratamientos.save(
    TreatmentDraft(
      name: t.suplemento,
      dosage: '5 g',
      kind: TreatmentKind.supplement,
      times: const <int>[780],
    ),
  );
  if (medicamento != null) {
    await tratamientos.markDose(
      dateKey: clave,
      treatmentId: medicamento,
      slotMinutes: 480,
      taken: true,
    );
  }
  final HabitService habitos = hoy.read(habitServiceProvider);
  final int? primerHabito = await habitos.add(name: t.habitos[0], iconKey: 'tooth');
  await habitos.add(name: t.habitos[1], iconKey: 'sun');
  if (primerHabito != null) {
    await habitos.setDone(habitId: primerHabito, dateKey: clave, done: true);
  }
  await hoy.read(symptomServiceProvider).log(symptom: 'headache', intensity: 2);
  await hoy
      .read(vitalServiceProvider)
      .addManual(kind: VitalKind.bloodPressure, primary: 124, secondary: 79);
  await hoy
      .read(vitalServiceProvider)
      .addManual(kind: VitalKind.glucose, primary: 92, context: 'fasting');
  await hoy.read(checkupServiceProvider).seedIfEmpty();
  hoy.dispose();
}

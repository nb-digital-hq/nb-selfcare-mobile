import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../l10n/l10n.dart';

/// Resultado estructurado de una correlación cruzada empírica.
class CrossCorrelationInsight {
  const CrossCorrelationInsight({
    required this.title,
    required this.description,
    required this.correlationR,
    required this.sampleSize,
    required this.domain,
  });

  final String title;
  final String description;
  final double correlationR;
  final int sampleSize;
  final String domain;

  /// Intensidad descriptiva de la correlación.
  String strengthLabel(AppLocalizations l10n) {
    final abs = correlationR.abs();
    if (abs >= 0.7) return l10n.insightCorrelacionFuerte;
    if (abs >= 0.4) return l10n.insightCorrelacionModerada;
    if (abs >= 0.2) return l10n.insightCorrelacionLeve;
    return l10n.insightSinRelacionLinealSignificativa;
  }
}

/// Estado de preparación de datos para activar correlaciones de Pearson (mínimo 10 días emparejados).
class AnalyticsReadinessStats {
  const AnalyticsReadinessStats({
    required this.journalDays,
    required this.foodDays,
    required this.sleepDays,
    required this.fastingDays,
  });

  final int journalDays;
  final int foodDays;
  final int sleepDays;
  final int fastingDays;

  int get maxPairedProgress => math.min(10, math.max(journalDays, fastingDays));
}

/// Motor estadístico de correlaciones cruzadas (Pearson) entre variables biométricas y conductuales.
class CrossAnalyticsEngine {
  CrossAnalyticsEngine(this._db);

  final AppDatabase _db;

  /// Calcula el coeficiente de correlación de Pearson r entre dos series numéricas.
  static double calculatePearsonR(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 2) return 0.0;

    final int n = x.length;
    final double meanX = x.reduce((a, b) => a + b) / n;
    final double meanY = y.reduce((a, b) => a + b) / n;

    double numerator = 0.0;
    double sumSqDiffX = 0.0;
    double sumSqDiffY = 0.0;

    for (int i = 0; i < n; i++) {
      final double diffX = x[i] - meanX;
      final double diffY = y[i] - meanY;
      numerator += diffX * diffY;
      sumSqDiffX += diffX * diffX;
      sumSqDiffY += diffY * diffY;
    }

    final double denominator = math.sqrt(sumSqDiffX * sumSqDiffY);
    if (denominator == 0.0) return 0.0;

    final double r = numerator / denominator;
    return double.parse(r.clamp(-1.0, 1.0).toStringAsFixed(2));
  }

  /// Obtiene el conteo de días únicos registrados por dominio para informar progreso en la UI.
  Future<AnalyticsReadinessStats> getReadinessStats() async {
    final jRow = await _db
        .customSelect(
          'SELECT COUNT(DISTINCT date_key) AS cnt FROM journal_entries',
          readsFrom: {_db.journalEntries},
        )
        .getSingle();
    final fRow = await _db
        .customSelect(
          'SELECT COUNT(DISTINCT date_key) AS cnt FROM food_logs',
          readsFrom: {_db.foodLogs},
        )
        .getSingle();
    final sRow = await _db
        .customSelect(
          'SELECT COUNT(DISTINCT date_key) AS cnt FROM daily_summaries WHERE sleep_duration_minutes > 0',
          readsFrom: {_db.dailySummaries},
        )
        .getSingle();
    final fastRow = await _db
        .customSelect(
          'SELECT COUNT(DISTINCT substr(started_at, 1, 10)) AS cnt FROM fasting_sessions WHERE actual_ended_at IS NOT NULL',
          readsFrom: {_db.fastingSessions},
        )
        .getSingle();

    return AnalyticsReadinessStats(
      journalDays: jRow.read<int>('cnt'),
      foodDays: fRow.read<int>('cnt'),
      sleepDays: sRow.read<int>('cnt'),
      fastingDays: fastRow.read<int>('cnt'),
    );
  }

  /// Ejecuta el análisis cruzado sobre subconsultas diarias pre-agregadas (sin inflación cartesiana)
  /// y retorna únicamente los hallazgos con relación lineal significativa (|r| >= 0.30 y n >= 10).
  Future<List<CrossCorrelationInsight>> computeInsights(AppLocalizations l10n) async {
    final List<CrossCorrelationInsight> insights = [];

    // 1. Estrés Diario vs Consumo de Carbohidratos (subconsultas diarias 1:1)
    final stressCarbQuery = await _db
        .customSelect(
          '''
      SELECT j.avg_stress AS stress_val, f.daily_carbs AS carbs_val
      FROM (
        SELECT date_key, AVG(stress_level) AS avg_stress
        FROM journal_entries
        WHERE stress_level IS NOT NULL
        GROUP BY date_key
      ) j
      JOIN (
        SELECT date_key, SUM(total_carbs_g) AS daily_carbs
        FROM food_logs
        GROUP BY date_key
        HAVING daily_carbs > 0
      ) f ON j.date_key = f.date_key
      ORDER BY j.date_key ASC
      ''',
          readsFrom: {_db.journalEntries, _db.foodLogs},
        )
        .get();

    if (stressCarbQuery.length >= 10) {
      final List<double> stressLevels = stressCarbQuery
          .map((row) => row.read<double>('stress_val'))
          .toList();
      final List<double> carbsGrams = stressCarbQuery
          .map((row) => row.read<double>('carbs_val'))
          .toList();

      final double r = calculatePearsonR(stressLevels, carbsGrams);
      if (r.abs() >= 0.30) {
        insights.add(
          CrossCorrelationInsight(
            title: l10n.insightEstresYConsumoDeCarbohidratos,
            description: r > 0 ? l10n.insightEnLosDiasConMayor : l10n.insightEnLosDiasDeMayor,
            correlationR: r,
            sampleSize: stressCarbQuery.length,
            domain: 'stress_vs_carbs',
          ),
        );
      }
    }

    // 2. Duración Real del Ayuno vs Ingesta Calórica Total del Día
    final fastCalQuery = await _db
        .customSelect(
          '''
      SELECT s.fast_hours AS hours_val, f.daily_kcal AS kcal_val
      FROM (
        SELECT substr(started_at, 1, 10) AS date_key,
               AVG((julianday(actual_ended_at) - julianday(started_at)) * 24.0) AS fast_hours
        FROM fasting_sessions
        WHERE actual_ended_at IS NOT NULL
        GROUP BY substr(started_at, 1, 10)
      ) s
      JOIN (
        SELECT date_key, SUM(total_kcal) AS daily_kcal
        FROM food_logs
        GROUP BY date_key
        HAVING daily_kcal > 0
      ) f ON s.date_key = f.date_key
      WHERE s.fast_hours > 0
      ORDER BY s.date_key ASC
      ''',
          readsFrom: {_db.fastingSessions, _db.foodLogs},
        )
        .get();

    if (fastCalQuery.length >= 10) {
      final List<double> fastHours = fastCalQuery
          .map((row) => row.read<double>('hours_val'))
          .toList();
      final List<double> totalKcals = fastCalQuery
          .map((row) => row.read<double>('kcal_val'))
          .toList();

      final double r = calculatePearsonR(fastHours, totalKcals);
      if (r.abs() >= 0.30) {
        insights.add(
          CrossCorrelationInsight(
            title: l10n.insightDuracionDelAyunoVsIngesta,
            description: r < 0
                ? l10n.insightTusVentanasDeAyunoMas
                : l10n.insightEnDiasDeAyunoProlongado,
            correlationR: r,
            sampleSize: fastCalQuery.length,
            domain: 'fasting_vs_calories',
          ),
        );
      }
    }

    // 3. Horas de Sueño vs Nivel de Energía Percibida
    final sleepEnergyQuery = await _db
        .customSelect(
          '''
      SELECT (d.sleep_duration_minutes / 60.0) AS sleep_h, j.avg_energy AS energy_val
      FROM daily_summaries d
      JOIN (
        SELECT date_key, AVG(energy_level) AS avg_energy
        FROM journal_entries
        WHERE energy_level IS NOT NULL
        GROUP BY date_key
      ) j ON d.date_key = j.date_key
      WHERE d.sleep_duration_minutes > 0
      ORDER BY d.date_key ASC
      ''',
          readsFrom: {_db.dailySummaries, _db.journalEntries},
        )
        .get();

    if (sleepEnergyQuery.length >= 10) {
      final List<double> sleepHours = sleepEnergyQuery
          .map((row) => row.read<double>('sleep_h'))
          .toList();
      final List<double> energyLevels = sleepEnergyQuery
          .map((row) => row.read<double>('energy_val'))
          .toList();

      final double r = calculatePearsonR(sleepHours, energyLevels);
      if (r.abs() >= 0.30) {
        insights.add(
          CrossCorrelationInsight(
            title: l10n.insightSuenoReparadorVsVitalidadDiaria,
            description: r > 0
                ? l10n.insightDormirMasHorasImpulsaDirectamente
                : l10n.insightTuEnergiaPercibidaVariaDe,
            correlationR: r,
            sampleSize: sleepEnergyQuery.length,
            domain: 'sleep_vs_energy',
          ),
        );
      }
    }

    // 4. Hidratación Diaria vs Nivel de Energía
    final waterEnergyQuery = await _db
        .customSelect(
          '''
      SELECT h.daily_ml AS water_val, j.avg_energy AS energy_val
      FROM (
        SELECT date_key, SUM(volume_ml) AS daily_ml
        FROM hydration_logs
        GROUP BY date_key
        HAVING daily_ml > 0
      ) h
      JOIN (
        SELECT date_key, AVG(energy_level) AS avg_energy
        FROM journal_entries
        WHERE energy_level IS NOT NULL
        GROUP BY date_key
      ) j ON h.date_key = j.date_key
      ORDER BY h.date_key ASC
      ''',
          readsFrom: {_db.hydrationLogs, _db.journalEntries},
        )
        .get();

    if (waterEnergyQuery.length >= 10) {
      final List<double> waterMl = waterEnergyQuery
          .map((row) => row.read<double>('water_val'))
          .toList();
      final List<double> energyVals = waterEnergyQuery
          .map((row) => row.read<double>('energy_val'))
          .toList();

      final double r = calculatePearsonR(waterMl, energyVals);
      if (r.abs() >= 0.30) {
        insights.add(
          CrossCorrelationInsight(
            title: l10n.insightHidratacionVsClaridadYEnergia,
            description: r > 0
                ? l10n.insightLosDiasMejorHidratadosCoinciden
                : l10n.insightEnDiasDeMenorEnergia,
            correlationR: r,
            sampleSize: waterEnergyQuery.length,
            domain: 'hydration_vs_energy',
          ),
        );
      }
    }

    // 5. Horas de sueño vs intensidad de los síntomas del día (incluye días sin síntomas = 0)
    final sleepSymptomQuery = await _db
        .customSelect(
          '''
      SELECT (d.sleep_duration_minutes / 60.0) AS sleep_h,
             COALESCE(s.total_intensity, 0) AS symptom_val
      FROM daily_summaries d
      LEFT JOIN (
        SELECT date_key, SUM(intensity) AS total_intensity
        FROM symptom_logs
        GROUP BY date_key
      ) s ON d.date_key = s.date_key
      WHERE d.sleep_duration_minutes > 0
      ORDER BY d.date_key ASC
      ''',
          readsFrom: {_db.dailySummaries, _db.symptomLogs},
        )
        .get();

    final int symptomDays = sleepSymptomQuery
        .where((row) => row.read<int>('symptom_val') > 0)
        .length;
    if (sleepSymptomQuery.length >= 14 && symptomDays >= 3) {
      final double r = calculatePearsonR(
        sleepSymptomQuery.map((row) => row.read<double>('sleep_h')).toList(),
        sleepSymptomQuery.map((row) => row.read<int>('symptom_val').toDouble()).toList(),
      );
      if (r.abs() >= 0.30) {
        insights.add(
          CrossCorrelationInsight(
            title: l10n.insightSuenoYSintomas,
            description: r < 0
                ? l10n.insightTusSintomasSonMasLeves
                : l10n.insightTusSintomasAparecenInclusoTras,
            correlationR: r,
            sampleSize: sleepSymptomQuery.length,
            domain: 'sleep_vs_symptoms',
          ),
        );
      }
    }

    // 6. Alcohol del día vs sueño de esa noche (que termina al día siguiente)
    final alcoholSleepQuery = await _db
        .customSelect(
          '''
      SELECT COALESCE(a.drinks, 0) AS drinks_val, (d.sleep_duration_minutes / 60.0) AS sleep_h
      FROM daily_summaries d
      LEFT JOIN (
        SELECT date_key, SUM(standard_drinks) AS drinks
        FROM substance_logs
        WHERE kind = 'alcohol'
        GROUP BY date_key
      ) a ON date(d.date_key, '-1 day') = a.date_key
      WHERE d.sleep_duration_minutes > 0
      ORDER BY d.date_key ASC
      ''',
          readsFrom: {_db.dailySummaries, _db.substanceLogs},
        )
        .get();

    final int drinkingDays = alcoholSleepQuery
        .where((row) => row.read<double>('drinks_val') > 0)
        .length;
    if (alcoholSleepQuery.length >= 14 && drinkingDays >= 3) {
      final double r = calculatePearsonR(
        alcoholSleepQuery.map((row) => row.read<double>('drinks_val')).toList(),
        alcoholSleepQuery.map((row) => row.read<double>('sleep_h')).toList(),
      );
      if (r.abs() >= 0.30) {
        insights.add(
          CrossCorrelationInsight(
            title: l10n.insightAlcoholYSueno,
            description: r < 0
                ? l10n.insightLasNochesDespuesDeBeber
                : l10n.insightTusNochesTrasBeberNo,
            correlationR: r,
            sampleSize: alcoholSleepQuery.length,
            domain: 'alcohol_vs_sleep',
          ),
        );
      }
    }

    return insights;
  }
}

/// Provider de Riverpod para inyectar CrossAnalyticsEngine.
final crossAnalyticsEngineProvider = Provider<CrossAnalyticsEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CrossAnalyticsEngine(db);
});

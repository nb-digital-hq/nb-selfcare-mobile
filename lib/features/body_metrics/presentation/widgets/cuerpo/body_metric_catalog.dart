import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/utils/biometric_formulas.dart';
import '../../../../../shared/utils/number_formats.dart';
import '../../../../../shared/widgets/app_icons.dart';

// Etiquetas cortas desde el ARB; las explicaciones largas ("¿qué representa?",
// guía y fórmula) son contenido editorial con sus referencias.

/// Identificadores de las 13 métricas fisiológicas + validación antropométrica.
enum BiometricMetricKind {
  bodyFat,
  validatedNavyFat,
  muscleMass,
  leanBodyMass,
  water,
  protein,
  visceralFat,
  boneMass,
  bmr,
  metabolicAge,
  bmi,
  bodyScore,
  somatotype,
}

/// Estado orientativo positivo (sin lenguaje alarmista ni punitivo).
enum MetricStatusTone { optimal, balanced, gentleAttention, neutral }

/// Información estructurada para presentar y explicar cada métrica fisiológica.
class BiometricMetricSpec {
  const BiometricMetricSpec({
    required this.kind,
    required this.title,
    required this.valueLabel,
    required this.subtitle,
    required this.statusLabel,
    required this.tone,
    required this.icon,
    required this.whatItMeans,
    required this.referenceGuide,
    required this.formulaNote,
    this.progressFraction,
  });

  final BiometricMetricKind kind;
  final String title;
  final String valueLabel;
  final String subtitle;
  final String statusLabel;
  final MetricStatusTone tone;
  final IconData icon;
  final String whatItMeans;
  final String referenceGuide;
  final String formulaNote;
  final double? progressFraction;
}

/// Constructor determinista de especificaciones educativas para las 13 métricas.
abstract final class BiometricMetricCatalog {
  static String translateSomatotype(AppLocalizations l10n, String? code) {
    return switch (code) {
      'balanced' => l10n.bodySomatoBalanced,
      'balanced_muscular' => l10n.bodySomatoBalancedMuscular,
      'skinny_muscular' => l10n.bodySomatoSkinnyMuscular,
      'balanced_skinny' => l10n.bodySomatoBalancedSkinny,
      'skinny' => l10n.bodySomatoSkinny,
      'thick_set' => l10n.bodySomatoThickSet,
      'lack_exercise' => l10n.bodySomatoLackExercise,
      'overweight' => l10n.bodySomatoOverweight,
      'obese' => l10n.bodySomatoObese,
      _ => l10n.bodySomatoPending,
    };
  }

  static Color toneColor(ScColors c, MetricStatusTone tone) {
    return switch (tone) {
      MetricStatusTone.optimal => c.success,
      MetricStatusTone.balanced => c.accent,
      MetricStatusTone.gentleAttention => c.warning,
      MetricStatusTone.neutral => c.text3,
    };
  }

  static List<BiometricMetricSpec> buildAll(
    AppLocalizations l10n, {
    required UserProfile profile,
    required BodyMeasurement? latest,
    required DateTime referenceDate,
  }) {
    final bool isMale = profile.biologicalSex == BiologicalSex.male;
    final double ageYears = BiometricFormulas.calculateDynamicAge(profile.birthDate, referenceDate);
    final bool hasBia = latest?.impedanceOhms != null && latest!.impedanceOhms! >= 100;
    final String sourceHint = hasBia
        ? l10n.bodySourceBia
        : (latest != null ? l10n.bodySourceEstimate : l10n.bodySourceNone);

    // 1. Grasa Corporal (%)
    final double? bf = latest?.bodyFatPercentage;
    final double bfOptLow = isMale ? 10.0 : 18.0;
    final double bfOptHigh = isMale ? 20.0 : 28.0;
    final MetricStatusTone bfTone = bf == null
        ? MetricStatusTone.neutral
        : (bf >= bfOptLow && bf <= bfOptHigh
              ? MetricStatusTone.optimal
              : (bf < bfOptLow - 3 || bf > bfOptHigh + 5
                    ? MetricStatusTone.gentleAttention
                    : MetricStatusTone.balanced));
    final String bfStatus = bf == null
        ? l10n.bodyNoData
        : (bf >= bfOptLow && bf <= bfOptHigh
              ? l10n.bodyStatusHealthyRange
              : (bf < bfOptLow ? l10n.bodyStatusLowReserve : l10n.bodyStatusAboveRange));

    // 2. Grasa Validada US Navy (%)
    final double? valFat = latest?.validatedBodyFatPercentage;
    final MetricStatusTone valTone = valFat == null
        ? MetricStatusTone.neutral
        : (valFat >= bfOptLow && valFat <= bfOptHigh
              ? MetricStatusTone.optimal
              : MetricStatusTone.balanced);

    // 3. Masa Muscular (kg)
    final double? muscle = latest?.muscleMassKg;
    final double? weight = latest?.weightKg;
    final double? musclePct = (muscle != null && weight != null && weight > 0)
        ? (muscle / weight) * 100.0
        : null;
    final double minMusclePct = isMale ? 40.0 : 32.0;
    final MetricStatusTone muscleTone = musclePct == null
        ? MetricStatusTone.neutral
        : (musclePct >= minMusclePct ? MetricStatusTone.optimal : MetricStatusTone.balanced);

    // 4. Masa Libre de Grasa / LBM (kg)
    final double? lbm = latest?.leanBodyMassKg;

    // 5. Agua Corporal (%)
    final double? water = latest?.waterPercentage;
    final double waterMin = isMale ? 50.0 : 45.0;
    final double waterMax = isMale ? 65.0 : 60.0;
    final MetricStatusTone waterTone = water == null
        ? MetricStatusTone.neutral
        : (water >= waterMin && water <= waterMax
              ? MetricStatusTone.optimal
              : MetricStatusTone.gentleAttention);

    // 6. Proteína Corporal (%)
    final double? prot = latest?.proteinPercentage;
    final MetricStatusTone protTone = prot == null
        ? MetricStatusTone.neutral
        : (prot >= 16.0
              ? MetricStatusTone.optimal
              : (prot >= 14.0 ? MetricStatusTone.balanced : MetricStatusTone.gentleAttention));

    // 7. Grasa Visceral (1-30)
    final int? visc = latest?.visceralFatIndex;
    final MetricStatusTone viscTone = visc == null
        ? MetricStatusTone.neutral
        : (visc <= 9
              ? MetricStatusTone.optimal
              : (visc <= 14 ? MetricStatusTone.balanced : MetricStatusTone.gentleAttention));

    // 8. Masa Ósea (kg)
    final double? bone = latest?.boneMassKg;
    final double boneRef = isMale ? 2.8 : 2.2;
    final MetricStatusTone boneTone = bone == null
        ? MetricStatusTone.neutral
        : (bone >= boneRef * 0.85 ? MetricStatusTone.optimal : MetricStatusTone.balanced);

    // 9. Metabolismo Basal BMR (kcal)
    final int? bmr = latest?.basalMetabolicRateKcal;

    // 10. Edad Metabólica (años)
    final int? metAge = latest?.metabolicAge;
    final int chronoAge = ageYears.floor();
    final MetricStatusTone metAgeTone = metAge == null
        ? MetricStatusTone.neutral
        : (metAge <= chronoAge
              ? MetricStatusTone.optimal
              : (metAge <= chronoAge + 3
                    ? MetricStatusTone.balanced
                    : MetricStatusTone.gentleAttention));

    // 11. IMC (kg/m²)
    final double? bmi = latest?.bmi;
    final MetricStatusTone bmiTone = bmi == null
        ? MetricStatusTone.neutral
        : (bmi >= 18.5 && bmi < 25.0 ? MetricStatusTone.optimal : MetricStatusTone.balanced);

    // 12. Puntuación Corporal (0-100)
    final int? score = latest?.bodyScore;
    final MetricStatusTone scoreTone = score == null
        ? MetricStatusTone.neutral
        : (score >= 75
              ? MetricStatusTone.optimal
              : (score >= 60 ? MetricStatusTone.balanced : MetricStatusTone.gentleAttention));

    // 13. Somatotipo
    final String? somato = latest?.somatotype;

    return <BiometricMetricSpec>[
      BiometricMetricSpec(
        kind: BiometricMetricKind.bodyFat,
        title: l10n.bodyMetricFat,
        valueLabel: bf != null ? '${_fmt(bf, l10n, 1)}%' : '-- %',
        subtitle: sourceHint,
        statusLabel: bfStatus,
        tone: bfTone,
        icon: AppIcons.corazon,
        progressFraction: bf != null ? (bf / 45.0).clamp(0.05, 1.0) : null,
        whatItMeans: l10n.bodyCatRepresentaLaProporcionDeTejido,
        referenceGuide: isMale
            ? l10n.bodyCatReferenciaGeneralAdultaHombre10
            : l10n.bodyCatReferenciaGeneralAdultaMujer18,
        formulaNote: hasBia
            ? l10n.bodyCatDerivadaDeLaImpedanciaBioelectrica(latest.impedanceOhms.toString())
            : l10n.bodyCatEstimadaMedianteEcuacionAntropometricaDe,
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.validatedNavyFat,
        title: l10n.bodyMetricTapeFat,
        valueLabel: valFat != null ? '${_fmt(valFat, l10n, 1)}%' : l10n.bodyTapeMeasure,
        subtitle: latest?.waistCm != null
            ? l10n.bodyTapeWaist(_fmt(latest!.waistCm!, l10n, 1))
            : l10n.bodyTapeHint,
        statusLabel: valFat != null ? l10n.bodyTapeValidated : l10n.bodyTapeEvery2Weeks,
        tone: valTone,
        icon: AppIcons.tape,
        progressFraction: valFat != null ? (valFat / 45.0).clamp(0.05, 1.0) : null,
        whatItMeans: l10n.bodyCatCombinaLaBioimpedanciaConLos,
        referenceGuide: l10n.bodyCatUsalaCada2SemanasEn,
        formulaNote: l10n.bodyCatFusionPonderada060Grasa,
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.muscleMass,
        title: l10n.bodyMetricMuscle,
        valueLabel: muscle != null ? '${_fmt(muscle, l10n, 1)} kg' : l10n.bodyCatKg,
        subtitle: musclePct != null
            ? l10n.bodyPctOfWeight(_fmt(musclePct, l10n, 1))
            : l10n.bodyMuscleTotal,
        statusLabel: musclePct == null
            ? l10n.bodyNoData
            : (musclePct >= minMusclePct ? l10n.bodyStatusSolid : l10n.bodyStatusBuilding),
        tone: muscleTone,
        icon: AppIcons.pesa,
        progressFraction: musclePct != null ? (musclePct / 60.0).clamp(0.1, 1.0) : null,
        whatItMeans: l10n.bodyCatIncluyeElMusculoEsqueleticoLiso,
        referenceGuide: isMale
            ? l10n.bodyCatReferenciaOrientativaHombre40Del
            : l10n.bodyCatReferenciaOrientativaMujer32Del,
        formulaNote: l10n.bodyCatMasaMuscularPesoTotalMasa,
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.leanBodyMass,
        title: l10n.bodyMetricLean,
        valueLabel: lbm != null ? '${_fmt(lbm, l10n, 1)} kg' : l10n.bodyCatKg,
        subtitle: l10n.bodyLeanSubtitle,
        statusLabel: lbm != null ? l10n.bodyLeanStatus : l10n.bodyNoData,
        tone: lbm != null ? MetricStatusTone.balanced : MetricStatusTone.neutral,
        icon: Icons.accessibility_new_rounded,
        progressFraction: (lbm != null && weight != null && weight > 0)
            ? (lbm / weight).clamp(0.2, 0.98)
            : null,
        whatItMeans: l10n.bodyCatEsTodoElPesoDe,
        referenceGuide: l10n.bodyCatEnEtapasDePerdidaDe,
        formulaNote: l10n.bodyCatLbmPeso1GrasaCorporal,
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.water,
        title: l10n.bodyMetricWater,
        valueLabel: water != null ? '${_fmt(water, l10n, 1)}%' : '-- %',
        subtitle: l10n.bodyWaterSubtitle,
        statusLabel: water == null
            ? l10n.bodyNoData
            : (water >= waterMin ? l10n.bodyStatusHydrated : l10n.bodyStatusDrinkMore),
        tone: waterTone,
        icon: AppIcons.gota,
        progressFraction: water != null ? (water / 75.0).clamp(0.1, 1.0) : null,
        whatItMeans: l10n.bodyCatPorcentajeDeAguaTotalIntracelular,
        referenceGuide: isMale
            ? l10n.bodyCatRangoHabitualHombre5065
            : l10n.bodyCatRangoHabitualMujer4560,
        formulaNote: l10n.bodyCatDerivadaDeLaConductividadElectrica,
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.protein,
        title: l10n.bodyMetricProtein,
        valueLabel: prot != null ? '${_fmt(prot, l10n, 1)}%' : '-- %',
        subtitle: l10n.bodyProteinSubtitle,
        statusLabel: prot == null
            ? l10n.bodyNoData
            : (prot >= 16.0 ? l10n.bodyStatusOptimal : l10n.bodyStatusStable),
        tone: protTone,
        icon: Icons.egg_alt_rounded,
        progressFraction: prot != null ? (prot / 26.0).clamp(0.1, 1.0) : null,
        whatItMeans: l10n.bodyCatEstimaLaFraccionSolidaProteica,
        referenceGuide: l10n.bodyCatRangoSaludableOrientativo1620,
        formulaNote: l10n.bodyCatDerivadaDeLaProporcionMuscular,
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.visceralFat,
        title: l10n.bodyMetricVisceral,
        valueLabel: l10n.bodyVisceralLevel(visc?.toString() ?? '--'),
        subtitle: l10n.bodyVisceralSubtitle,
        statusLabel: visc == null
            ? l10n.bodyNoData
            : (visc <= 9
                  ? l10n.bodyStatusHealthy
                  : (visc <= 14 ? l10n.bodyStatusModerate : l10n.bodyStatusMoveMore)),
        tone: viscTone,
        icon: AppIcons.fuego,
        progressFraction: visc != null ? (1.0 - ((visc - 1) / 25.0)).clamp(0.1, 1.0) : null,
        whatItMeans: l10n.bodyCatIndiceEstimativoDeLaGrasa,
        referenceGuide: l10n.bodyCatNiveles19Optimo10,
        formulaNote: l10n.bodyCatIndiceAntropometricoImpedanciometricoAcotadoEn,
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.boneMass,
        title: l10n.bodyMetricBone,
        valueLabel: bone != null ? '${_fmt(bone, l10n, 2)} kg' : l10n.bodyCatKg,
        subtitle: l10n.bodyBoneSubtitle,
        statusLabel: bone != null ? l10n.bodyStatusStable : l10n.bodyNoData,
        tone: boneTone,
        icon: Icons.shield_outlined,
        progressFraction: bone != null ? (bone / 4.2).clamp(0.15, 1.0) : null,
        whatItMeans: l10n.bodyCatEstimaElPesoDelMineral,
        referenceGuide: isMale
            ? l10n.bodyCatPromedioOrientativoHombreAdulto2
            : l10n.bodyCatPromedioOrientativoMujerAdulta1,
        formulaNote: l10n.bodyCatEstimacionLinealDerivadaDeLa,
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.bmr,
        title: l10n.bodyMetricBmr,
        valueLabel: bmr != null ? '${NumberFormats.group(bmr)} kcal' : l10n.bodyCatKcal,
        subtitle: l10n.bodyBmrSubtitle,
        statusLabel: bmr != null ? l10n.bodyBmrStatus : l10n.bodyNoData,
        tone: bmr != null ? MetricStatusTone.optimal : MetricStatusTone.neutral,
        icon: AppIcons.bolt,
        progressFraction: bmr != null ? (bmr / 2500.0).clamp(0.2, 1.0) : null,
        whatItMeans: l10n.bodyCatEnergiaMinimaDiariaQueTu,
        referenceGuide: l10n.bodyCatAMayorMasaLibreDe,
        formulaNote: l10n.bodyCatEcuacionKatchMcardleTmb370,
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.metabolicAge,
        title: l10n.bodyMetricMetabolicAge,
        valueLabel: l10n.bodyYears(metAge?.toString() ?? '--'),
        subtitle: l10n.bodyCurrentAge(chronoAge),
        statusLabel: metAge == null
            ? l10n.bodyNoData
            : (metAge <= chronoAge ? l10n.bodyStatusYoung : l10n.bodyStatusRoomToImprove),
        tone: metAgeTone,
        icon: Icons.cake_rounded,
        progressFraction: metAge != null
            ? (chronoAge / (metAge > 0 ? metAge : chronoAge)).clamp(0.25, 1.0)
            : null,
        whatItMeans: l10n.bodyCatComparaTuTasaMetabolicaBasal,
        referenceGuide: l10n.bodyCatEntrenarFuerza24VecesPor,
        formulaNote: l10n.bodyCatRelacionEntreTuTmbKatch(
          NumberFormats.fixed(ageYears, 1).toString(),
        ),
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.bmi,
        title: l10n.bodyMetricBmi,
        valueLabel: bmi != null ? _fmt(bmi, l10n, 1) : '--',
        subtitle: l10n.bodyBmiSubtitle,
        statusLabel: bmi == null
            ? l10n.bodyNoData
            : (bmi >= 18.5 && bmi < 25.0 ? l10n.bodyStatusStandard : l10n.bodyStatusBmiContext),
        tone: bmiTone,
        icon: Icons.speed_rounded,
        progressFraction: bmi != null ? (bmi / 35.0).clamp(0.15, 1.0) : null,
        whatItMeans: l10n.bodyCatElIndiceDeMasaCorporal,
        referenceGuide: l10n.bodyCatRangoPoblacionalOms185,
        formulaNote: l10n.bodyCatImcPesoKgM2(
          (weight == null ? '--' : NumberFormats.fixed(weight, 1)).toString(),
          NumberFormats.fixed(profile.heightCm / 100.0, 2).toString(),
        ),
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.bodyScore,
        title: l10n.bodyMetricScore,
        valueLabel: score != null ? '$score/100' : '--/100',
        subtitle: l10n.bodyScoreSubtitle,
        statusLabel: score == null
            ? l10n.bodyNoData
            : (score >= 80
                  ? l10n.bodyStatusExcellent
                  : (score >= 65 ? l10n.bodyStatusBalanced : l10n.bodyStatusInProgress)),
        tone: scoreTone,
        icon: AppIcons.starFilled,
        progressFraction: score != null ? (score / 100.0).clamp(0.1, 1.0) : null,
        whatItMeans: l10n.bodyCatResumenIntegradorDe10A,
        referenceGuide: l10n.bodyCatMasQueUnNumeroAislado,
        formulaNote: l10n.bodyCatPonderacionCompuestaDeBalanceAdiposo,
      ),
      BiometricMetricSpec(
        kind: BiometricMetricKind.somatotype,
        title: l10n.bodyMetricSomatotype,
        valueLabel: translateSomatotype(l10n, somato),
        subtitle: l10n.bodySomatoSubtitle,
        statusLabel: somato != null ? l10n.bodySomatoStatus : l10n.bodySomatoStatusPending,
        tone: somato != null ? MetricStatusTone.optimal : MetricStatusTone.neutral,
        icon: AppIcons.perfil,
        whatItMeans: l10n.bodyCatClasificaDeFormaDescriptivaY,
        referenceGuide: l10n.bodyCatTuFenotipoEsDinamicoSe,
        formulaNote: l10n.bodyCatMatrizBidimensionalGrasaCorporalProporcion,
      ),
    ];
  }
}

/// Cifra con los decimales del idioma ("25,5" en español).
String _fmt(double value, AppLocalizations l10n, int decimals) => decimals == 1
    ? NumberFormats.oneDecimal(value, l10n.localeName)
    : NumberFormat.decimalPatternDigits(
        locale: l10n.localeName,
        decimalDigits: decimals,
      ).format(value);

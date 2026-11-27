import '../../shared/utils/number_formats.dart';
import '../database/app_database.dart';
import '../l10n/l10n.dart';

/// Veredicto de seguridad metabólica para un protocolo de ayuno propuesto.
class FastingSafetyVerdict {
  const FastingSafetyVerdict._({
    required this.isSafe,
    this.warningTitle,
    this.warningBody,
    this.recommendedAlternativeHours,
  });

  factory FastingSafetyVerdict.safe() {
    return const FastingSafetyVerdict._(isSafe: true);
  }

  factory FastingSafetyVerdict.warning({
    required String title,
    required String body,
    int? recommendedAlternativeHours,
  }) {
    return FastingSafetyVerdict._(
      isSafe: false,
      warningTitle: title,
      warningBody: body,
      recommendedAlternativeHours: recommendedAlternativeHours,
    );
  }

  final bool isSafe;
  final String? warningTitle;
  final String? warningBody;
  final int? recommendedAlternativeHours;
}

/// Etapa de reintroducción de alimentos para romper el ayuno de forma segura.
class FastBreakStage {
  const FastBreakStage({
    required this.phaseNumber,
    required this.timing,
    required this.title,
    required this.description,
    required this.recommendedFoods,
    required this.foodsToAvoid,
  });

  final int phaseNumber;
  final String timing;
  final String title;
  final String description;
  final List<String> recommendedFoods;
  final List<String> foodsToAvoid;
}

/// Asesor clínico y preventivo de dosificación segura del ayuno intermitente.
class FastingDosageAdvisor {
  /// Duración máxima por defecto con historial de trastornos de la conducta alimentaria (docs/01 §5).
  static const int maxHoursWithEdHistory = 16;

  /// Avisos derivados de las respuestas de seguridad del onboarding. Tienen
  /// prioridad sobre la dosificación semanal porque dependen de la persona.
  static FastingSafetyVerdict evaluatePersonalSafety({
    required AppLocalizations l10n,
    required int proposedTargetHours,
    required bool hasEatingDisorderHistory,
    required bool takesHypoglycemicMedication,
  }) {
    if (hasEatingDisorderHistory && proposedTargetHours > maxHoursWithEdHistory) {
      return FastingSafetyVerdict.warning(
        title: l10n.fastAdvAyunosLargosDesactivadosPorDefecto,
        body: l10n.fastAdvIndicasteAntecedentesDeTrastornosDe(maxHoursWithEdHistory.toString()),
        recommendedAlternativeHours: maxHoursWithEdHistory,
      );
    }
    if (takesHypoglycemicMedication) {
      return FastingSafetyVerdict.warning(
        title: l10n.fastAdvAntesDeAyunarConsultaTu,
        body: l10n.fastAdvLosMedicamentosQueBajanLa,
      );
    }
    return FastingSafetyVerdict.safe();
  }

  /// Evalúa si el protocolo propuesto es seguro respecto al historial de los últimos 7 días.
  static FastingSafetyVerdict evaluateProtocolSafety({
    required AppLocalizations l10n,
    required int proposedTargetHours,
    required List<FastingSession> recentSessions,
    required DateTime now,
  }) {
    // Protocolos suaves o moderados (hasta 18h) son fisiológicamente seguros a diario
    if (proposedTargetHours < 20) {
      return FastingSafetyVerdict.safe();
    }

    final DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));

    // Filtrar sesiones completadas en los últimos 7 días con duración real ≥ 20 horas
    final List<FastingSession> prolongedSessions = recentSessions.where((s) {
      if (s.actualEndedAt == null) return false;
      final bool within7Days = s.actualEndedAt!.isAfter(sevenDaysAgo);
      final double hours = s.actualEndedAt!.difference(s.startedAt).inMinutes / 60.0;
      return within7Days && hours >= 19.5;
    }).toList();

    // 1. Regla de Días Consecutivos: No encadenar dos ayunos de 20h+ seguidos
    if (recentSessions.isNotEmpty) {
      final FastingSession lastSession = recentSessions.first;
      if (lastSession.actualEndedAt != null) {
        final double lastHours =
            lastSession.actualEndedAt!.difference(lastSession.startedAt).inMinutes / 60.0;
        final int hoursSinceLastEnded = now.difference(lastSession.actualEndedAt!).inHours;

        if (lastHours >= 19.5 && hoursSinceLastEnded < 36) {
          return FastingSafetyVerdict.warning(
            title: l10n.fastAdvRecuperacionMetabolicaRecomendada,
            body: l10n.fastAdvCompletasteUnAyunoProlongadoH(
              NumberFormats.fixed(lastHours, 1).toString(),
            ),
            recommendedAlternativeHours: 16,
          );
        }
      }
    }

    // 2. Regla Semanal: Máximo 2 ayunos de 20h+ por semana
    if (prolongedSessions.length >= 2) {
      return FastingSafetyVerdict.warning(
        title: l10n.fastAdvLimiteSemanalDeAyunoProlongado,
        body: l10n.fastAdvYaHasRealizadoAyunosProlongados(prolongedSessions.length.toString()),
        recommendedAlternativeHours: 16,
      );
    }

    return FastingSafetyVerdict.safe();
  }

  /// Retorna las 3 etapas clínicas de realimentación cuando el ayuno supera 18 horas.
  static List<FastBreakStage> getRefeedingGuidance(AppLocalizations l10n, double actualHoursFast) {
    if (actualHoursFast < 18.0) {
      return <FastBreakStage>[
        FastBreakStage(
          phaseNumber: 1,
          timing: l10n.fastAdvInmediato,
          title: l10n.fastAdvAperturaSuave,
          description: l10n.fastAdvParaAyunosModerados18hComienza,
          recommendedFoods: <String>[
            l10n.fastAdvAguaConElectrolitos,
            l10n.fastAdvComidaEstandar,
            l10n.fastAdvProteinaMagra,
          ],
          foodsToAvoid: <String>[l10n.fastAdvExcesoDeFriturasOUltraprocesados],
        ),
      ];
    }

    return <FastBreakStage>[
      FastBreakStage(
        phaseNumber: 1,
        timing: l10n.fastAdvMinuto0,
        title: l10n.fastAdvDespertarDigestivoElectrolitos,
        description: l10n.fastAdvTuSistemaDigestivoHaEstado,
        recommendedFoods: <String>[
          l10n.fastAdvCaldoDeHuesosOCaldo,
          l10n.fastAdvVasoDeAguaConUna,
          l10n.fastAdvTeDeManzanillaOJengibre,
        ],
        foodsToAvoid: <String>[
          l10n.fastAdvBebidasAzucaradasOZumosDe,
          l10n.fastAdvCafeSoloFuerteEnEstomago,
          l10n.fastAdvBebidasHeladas,
        ],
      ),
      FastBreakStage(
        phaseNumber: 2,
        timing: l10n.fastAdv30A45MinutosDespues,
        title: l10n.fastAdvGrasasSuavesProteinasFaciles,
        description: l10n.fastAdvAportaNutrientesDeLentaAbsorcion,
        recommendedFoods: <String>[
          l10n.fastAdvMedioAguacateConSalY,
          l10n.fastAdv1O2HuevosRevueltos,
          l10n.fastAdvYogurtGriegoNaturalOKefir,
          l10n.fastAdvPunadoPequenoDeAlmendrasRemojadas,
        ],
        foodsToAvoid: <String>[
          l10n.fastAdvPanBlancoGalletasOHarinas,
          l10n.fastAdvCarnesRojasMuyGrasasO,
          l10n.fastAdvLegumbresConPielDuraPueden,
        ],
      ),
      FastBreakStage(
        phaseNumber: 3,
        timing: l10n.fastAdv2HorasDespues,
        title: l10n.fastAdvComidaPrincipalCompleta,
        description: l10n.fastAdvTuTractoGastrointestinalYaEsta,
        recommendedFoods: <String>[
          l10n.fastAdvPechugaDePolloPescadoO,
          l10n.fastAdvArrozIntegralOBatataAsada,
          l10n.fastAdvEnsaladaFrescaConSemillasDe,
        ],
        foodsToAvoid: <String>[
          l10n.fastAdvComilonasMasivasSinMasticarPausadamente,
          l10n.fastAdvAlimentosUltraprocesadosDensosEnSodio,
        ],
      ),
    ];
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/science_on_demand_sheet.dart';

// Fichas divulgativas de "Ciencia a demanda" del perfil (contenido editorial).

void showTdeeScience(BuildContext context) {
  unawaited(
    ScienceOnDemandSheet.show(
      context,
      ScienceSpec(
        title: context.l10n.sciGastoEnergeticoDiarioTdee,
        badgeLabel: context.l10n.sciMetabolismoBasalActividad,
        icon: AppIcons.fuego,
        quickTake: context.l10n.sciTuTdeeEsLaEnergia,
        howItWorks: context.l10n.sciADiferenciaDeLasFormulas,
        formula: context.l10n.sciTdeeIngestaDiariaKcalPeso,
        scientificReferences: <String>[
          'Hall, K. D. et al. (2011). Quantification of the effect of energy imbalance on bodyweight. The Lancet.',
          'Mifflin, M. D. et al. (1990). A new predictive equation for resting energy expenditure.',
        ],
        actionableAdvice: context.l10n.sciRegistraTusComidasYPesate,
      ),
    ),
  );
}

void showWeightTrendScience(BuildContext context) {
  unawaited(
    ScienceOnDemandSheet.show(
      context,
      ScienceSpec(
        title: context.l10n.sciTendenciaDePesoYFluctuaciones,
        badgeLabel: context.l10n.sciMasaGrasaVsAguaTransitoria,
        icon: AppIcons.cuerpo,
        quickTake: context.l10n.sciLasSubidasOBajadasBruscas,
        howItWorks: context.l10n.sciAlmacenar1GramoDeGlucogeno,
        formula: context.l10n.sci1gGlucogeno35gH2o,
        scientificReferences: <String>[
          'Fernández-Elías, V. E. et al. (2015). Relationship between muscle water and glycogen recovery.',
          'Davy, K. P. & Hall, J. E. (2004). Weight gain and hormonal fluid retention.',
        ],
        actionableAdvice: context.l10n.sciNoTeAlarmesPorPicos,
      ),
    ),
  );
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/science_on_demand_sheet.dart';

// Fichas divulgativas de "Ciencia a demanda" para electrolitos y fibra.
// Son contenido editorial (con sus referencias), no textos de interfaz.

void showSodiumScience(BuildContext context) {
  unawaited(
    ScienceOnDemandSheet.show(
      context,
      ScienceSpec(
        title: context.l10n.sciSodioNaYRetencionHidrica,
        badgeLabel: context.l10n.sciElectrolitoExtracelularUl2300,
        icon: AppIcons.bolt,
        quickTake: context.l10n.sciElSodioRegulaElVolumen,
        howItWorks: context.l10n.sciConsumirMasDe2300,
        formula: context.l10n.sciUlSodio2300Mg,
        scientificReferences: <String>[
          'World Health Organization (WHO). Guideline: Sodium intake for adults and children.',
          'He, F. J. & MacGregor, G. A. (2002). Effect of modest salt reduction on blood pressure.',
        ],
        actionableAdvice: context.l10n.sciSiTuPesoSubeTras,
      ),
    ),
  );
}

void showPotassiumScience(BuildContext context) {
  unawaited(
    ScienceOnDemandSheet.show(
      context,
      ScienceSpec(
        title: context.l10n.sciPotasioKYBalanceCelular,
        badgeLabel: context.l10n.sciElectrolitoIntracelularMeta3500,
        icon: AppIcons.bolt,
        quickTake: context.l10n.sciElPotasioContrarrestaLosEfectos,
        howItWorks: context.l10n.sciLaBombaNaKAtpasa,
        formula: context.l10n.sciRelacionKNaOptima2,
        scientificReferences: <String>[
          context.l10n.sciNasemDietaryReferenceIntakesFor,
          'Whelton, P. K. et al. (1997). Effects of oral potassium on blood pressure.',
        ],
        actionableAdvice: context.l10n.sciPriorizaFrutasVerdurasAguacatesY,
      ),
    ),
  );
}

void showMagnesiumScience(BuildContext context) {
  unawaited(
    ScienceOnDemandSheet.show(
      context,
      ScienceSpec(
        title: context.l10n.sciMagnesioMgYToleranciaSuplementaria,
        badgeLabel: context.l10n.sciCofactorEnzimaticoUlSuplementario350,
        icon: AppIcons.bolt,
        quickTake: context.l10n.sciEsencialParaProduccionDeAtp,
        howItWorks: context.l10n.sciElMagnesioDieteticoNoTiene,
        formula: context.l10n.sciUlSuplementario350MgDia,
        scientificReferences: <String>[
          context.l10n.sciInstituteOfMedicineUsDietary,
          'Nielsen, F. H. (2010). Magnesium, inflammation, and obesity in humans.',
        ],
        actionableAdvice: context.l10n.sciTomaSuplementosDeMagnesioBisglicinato,
      ),
    ),
  );
}

void showFiberScience(BuildContext context) {
  unawaited(
    ScienceOnDemandSheet.show(
      context,
      ScienceSpec(
        title: context.l10n.sciFibraDieteticaYMicrobiota,
        badgeLabel: context.l10n.sciSaludIntestinalYSaciedadMeta,
        icon: Icons.grain_rounded,
        quickTake: context.l10n.sciLaFibraDieteticaModulaLa,
        howItWorks: context.l10n.sciLaFibraSolubleRetrasaEl,
        formula: context.l10n.sciMetaDiaria14GDe,
        scientificReferences: <String>[
          'Dahl, W. J. & Stewart, M. L. (2015). Health Implications of Dietary Fiber.',
          'Sonnenburg, E. D. & Sonnenburg, J. L. (2014). Starving our microbial self.',
        ],
        actionableAdvice: context.l10n.sciAumentaLaFibraDeManera,
      ),
    ),
  );
}

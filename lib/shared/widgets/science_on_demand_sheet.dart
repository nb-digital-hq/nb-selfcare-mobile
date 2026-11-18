import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../theme/sc_colors.dart';
import '../theme/sc_theme.dart';
import '../utils/number_formats.dart';
import 'app_icons.dart';
import 'sheet.dart';

/// Especificación de contenido para una tarjeta o concepto científico en la aplicación.
class ScienceSpec {
  const ScienceSpec({
    required this.title,
    required this.badgeLabel,
    this.icon = AppIcons.hoy,
    required this.quickTake,
    required this.howItWorks,
    this.formula,
    this.scientificReferences = const <String>[],
    required this.actionableAdvice,
  });

  final String title;
  final String badgeLabel;
  final IconData icon;
  final String quickTake;
  final String howItWorks;
  final String? formula;
  final List<String> scientificReferences;
  final String actionableAdvice;

  factory ScienceSpec.caffeineDecay(
    AppLocalizations l10n, {
    required double halfLifeHours,
    required String bedtimeCurfewTime,
    required double residualAtBedtimeMg,
  }) {
    return ScienceSpec(
      title: l10n.sciDecaimientoDeLaCafeina,
      badgeLabel: l10n.sciCronobiologiaSuenoN3,
      icon: Icons.coffee_rounded,
      quickTake: l10n.sciLaCafeinaTieneUnaSemivida(halfLifeHours.toString()),
      howItWorks: l10n.sciLaAdenosinaEsElNeurotransmisor,
      formula: 'C(t) = C₀ · (0.5)^(Δt / $halfLifeHours)',
      scientificReferences: const <String>[
        'Drake et al. (2013). Caffeine effects on sleep taken 0, 3, or 6 hours before going to bed. J Clin Sleep Med.',
        'EFSA NDA Panel (2015). Scientific Opinion on the safety of caffeine. EFSA Journal.',
      ],
      actionableAdvice: l10n.sciTuHoraDeCorteAconsejada(
        bedtimeCurfewTime.toString(),
        NumberFormats.fixed(residualAtBedtimeMg, 1).toString(),
      ),
    );
  }

  factory ScienceSpec.novaClassification(AppLocalizations l10n) {
    return ScienceSpec(
      title: l10n.sciSistemaDeClasificacionNova,
      badgeLabel: l10n.sciProcesamientoAlimentario,
      icon: Icons.eco_rounded,
      quickTake: l10n.sciElSistemaNovaClasificaLos,
      howItWorks: l10n.sciGrupo1AlimentosSinProcesar,
      scientificReferences: <String>[
        'Monteiro CA et al. (2019). Ultra-processed foods: what they are and how to identify them. Public Health Nutr.',
        'FAO / OMS (2019). Ultra-processed foods, diet quality, and health using the NOVA classification system.',
      ],
      actionableAdvice: l10n.sciApuntaAQueMasDel,
    );
  }
}

/// Hoja modal pedagógica reutilizable para el principio "Action-First, Science-on-Demand".
/// Permite que la interfaz principal se mantenga limpia de fórmulas complejas, ofreciendo
/// la explicación científica profunda a demanda con solo un toque del usuario.
class ScienceOnDemandSheet extends StatelessWidget {
  const ScienceOnDemandSheet({super.key, required this.spec});

  final ScienceSpec spec;

  /// Presenta la hoja pedagógica con el diseño responsivo del sistema.
  static Future<void> show(BuildContext context, ScienceSpec spec) {
    return mostrarHojaMenu<void>(context, builder: (_) => ScienceOnDemandSheet(spec: spec));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ScColors c = context.sc;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Encabezado con Icono y Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                ),
                child: Icon(spec.icon, color: c.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.soft,
                        borderRadius: BorderRadius.circular(6),
                        border: c.isFlat ? Border.all(color: c.line2) : null,
                      ),
                      child: Text(
                        spec.badgeLabel.toUpperCase(),
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: c.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spec.title,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(AppIcons.close, color: c.text2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // En Resumen (Takeaway ejecutivo)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.soft,
              borderRadius: BorderRadius.circular(12),
              border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : Border.all(color: c.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(AppIcons.check, color: c.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    spec.quickTake,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ¿Cómo funciona en tu cuerpo? (Fisiología)
          Text(
            l10n.sciComoFuncionaEnTuCuerpo,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            spec.howItWorks,
            style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13, color: c.text2, height: 1.4),
          ),
          const SizedBox(height: 14),

          // Fórmula Matemática (Opcional)
          if (spec.formula != null) ...[
            Text(
              l10n.sciLaMatematicaAplicada,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: c.text,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.isFlat ? c.line2 : c.line),
              ),
              child: Text(
                spec.formula!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.accent,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Qué debes hacer tú (Acción clara)
          Text(
            l10n.sciTuAccionRecomendada,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            spec.actionableAdvice,
            style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13, color: c.text, height: 1.4),
          ),
          const SizedBox(height: 16),

          // Referencias Científicas (Opcional)
          if (spec.scientificReferences.isNotEmpty) ...[
            Text(
              l10n.sciEvidenciaYLiteratura,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.text3,
              ),
            ),
            const SizedBox(height: 4),
            for (final ref in spec.scientificReferences)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $ref',
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11,
                    color: c.text3,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],

          // Botón Entendido
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.sciEntendido, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

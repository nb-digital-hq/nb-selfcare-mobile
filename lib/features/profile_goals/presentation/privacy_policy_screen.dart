import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/widgets/health_card.dart';

/// Política de privacidad (exigida por Health Connect al conceder permisos).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static List<({String title, String body})> _sections(AppLocalizations l10n) =>
      <({String title, String body})>[
        (title: l10n.privacyTodoSeQuedaEnTu, body: l10n.privacyNbSelfcareNoTieneCuentas),
        (title: l10n.privacyQueLeemosDeHealthConnect, body: l10n.privacyPasosSuenoConSusFases),
        (title: l10n.privacyQueEscribimosEnHealthConnect, body: l10n.privacyLosPesajesDeTuBascula),
        (title: l10n.privacyLecturaEnSegundoPlano, body: l10n.privacySoloSiActivasPausasActivas),
        (title: l10n.privacyCamaraYMicrofono, body: l10n.privacyElEscanerDeCodigosDe),
        (title: l10n.privacyLasDosUnicasSalidasA, body: l10n.privacyAlEscanearUnCodigoQue),
        (
          title: l10n.privacyMedicamentosYAvisos,
          body: l10n.privacyTusMedicamentosSintomasSignosVitales,
        ),
        (title: l10n.privacyTuDecides, body: l10n.privacyPuedesRetirarCualquierPermisoDesde),
      ];

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<({String title, String body})> sections = _sections(l10n);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final ({String title, String body}) section = sections[index];
          return HealthCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  section.title,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  section.body,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 13,
                    height: 1.4,
                    color: c.text2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

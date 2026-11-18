import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/domain/metabolic_phase.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../fasting/presentation/metabolic_phase_l10n.dart';
import '../../../../pet_gamification/domain/pet_catalog.dart';
import '../../../../pet_gamification/presentation/nibi/nibi_view.dart';
import '../../../domain/hoy_widget_config.dart';

// ============================================================================
// Compañero Nibi en Inicio (4×2 o 2×2)
// ============================================================================
class HoyNibiBentoCard extends StatelessWidget {
  const HoyNibiBentoCard({
    super.key,
    required this.size,
    required this.petName,
    required this.coinsBalance,
    required this.streakDays,
    required this.aiGreeting,
    required this.fastingPhase,
    required this.hasSleepBonus,
    required this.onRefreshGreeting,
    this.look = const NibiLook(),
  });

  /// Sombrero que lleva puesto en la pestaña de Nibi.
  final NibiLook look;

  final HoyWidgetSize size;
  final String petName;
  final int coinsBalance;
  final int streakDays;
  final String aiGreeting;

  /// Fase del ayuno en curso; la etiqueta aparece desde la quema de grasa (12 h).
  final MetabolicPhase? fastingPhase;

  bool get _showsFastingTag =>
      fastingPhase != null && fastingPhase!.startsAtHour >= MetabolicPhase.fatBurning.startsAtHour;
  final bool hasSleepBonus;
  final VoidCallback onRefreshGreeting;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final bool compact = size.isHalfWidth;

    // Nibi en Inicio es una fila de compañía, no un panel: el santuario, la
    // tienda y las acciones viven en su pestaña. Aquí solo su voz y un dato.
    final List<String> estado = <String>[
      l10n.todayNibiCoins(coinsBalance),
      if (streakDays > 0) l10n.todayNibiStreak(streakDays),
      if (_showsFastingTag) fastingPhase!.label(l10n),
      if (hasSleepBonus) l10n.todayBonoSuenoX15,
    ];

    final Widget saludo = Text(
      aiGreeting,
      maxLines: compact ? 4 : 3,
      overflow: TextOverflow.ellipsis,
      style: context.type.body.copyWith(color: c.text, fontSize: compact ? 13 : 14),
    );

    final Widget meta = Text(
      estado.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.type.caption.copyWith(color: c.text3),
    );

    final Widget refrescar = IconButton(
      tooltip: l10n.todayNuevoPensamientoDe(petName),
      onPressed: onRefreshGreeting,
      icon: Icon(AppIcons.chispa, size: 18, color: c.text3),
    );

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      onTap: () => context.go('/nibi'),
      child: Semantics(
        label: l10n.todayOpenPet(petName),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      NibiAvatar(size: 44, look: look),
                      const Spacer(),
                      refrescar,
                    ],
                  ),
                  const SizedBox(height: ScSpace.s),
                  saludo,
                  const SizedBox(height: ScSpace.s),
                  meta,
                ],
              )
            : Row(
                children: <Widget>[
                  NibiAvatar(size: 52, look: look),
                  const SizedBox(width: ScSpace.m + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(petName, style: context.type.label),
                        const SizedBox(height: ScSpace.xs),
                        saludo,
                        const SizedBox(height: ScSpace.xs + 2),
                        meta,
                      ],
                    ),
                  ),
                  refrescar,
                ],
              ),
      ),
    );
  }
}

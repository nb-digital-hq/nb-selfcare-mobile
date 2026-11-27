import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/card_header.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/progress_ring.dart';
import '../../application/quit_service.dart';
import '../../domain/quit_progress.dart';
import '../quit_l10n.dart';
import 'quit_clock.dart';
import 'quit_editor_sheet.dart';

/// Tarjeta de "Libre" en Cuidado: cada hábito que se deja con su racha viva.
class QuitCard extends ConsumerWidget {
  const QuitCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<QuitTracker> trackers =
        ref.watch(quitTrackersProvider).value ?? const <QuitTracker>[];
    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CardHeader(
            icon: Icons.self_improvement_rounded,
            tone: c.success,
            title: l10n.quitTitle,
            subtitle: trackers.isEmpty ? l10n.quitCardEmpty : l10n.quitCardSubtitle,
            trailing: trackers.isEmpty
                ? null
                : TextButton(
                    onPressed: () => unawaited(context.push('/libre')),
                    child: Text(l10n.quitSeeAll),
                  ),
          ),
          const SizedBox(height: ScSpace.m),
          if (trackers.isEmpty)
            FilledButton.icon(
              onPressed: () => unawaited(showQuitEditor(context)),
              icon: const Icon(AppIcons.add),
              label: Text(l10n.quitStart),
            )
          else
            QuitClockBuilder(
              builder: (BuildContext context, DateTime now) => Column(
                children: <Widget>[
                  for (final QuitTracker t in trackers.take(4)) QuitRow(tracker: t, now: now),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Fila compacta de un contador: icono con el avance al próximo hito, nombre
/// y racha. Abre el detalle.
class QuitRow extends StatelessWidget {
  const QuitRow({super.key, required this.tracker, required this.now});

  final QuitTracker tracker;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final QuitProgress p = QuitProgress.compute(
      startedAt: tracker.startedAt,
      now: now,
      bankedSeconds: tracker.bankedSeconds,
      longestStreakSeconds: tracker.longestStreakSeconds,
      dailyCost: tracker.dailyCost,
    );
    final String name = QuitText.name(l10n, tracker);
    final Duration? next = p.nextMilestone;
    return InkWell(
      borderRadius: BorderRadius.circular(ScRadius.controlOf(c)),
      onTap: () => unawaited(context.push('/libre/${tracker.id}')),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ScSpace.s),
        child: Row(
          children: <Widget>[
            ScProgressRing(
              value: p.milestoneFraction,
              size: 46,
              stroke: 4,
              color: c.success,
              animateChanges: false,
              child: Icon(
                QuitText.icon(tracker.presetKey),
                size: 20,
                color: c.isFlat ? c.text : c.success,
              ),
            ),
            const SizedBox(width: ScSpace.m),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    next == null
                        ? l10n.quitAllMilestones
                        : l10n.quitNextMilestone(QuitText.span(l10n, next)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: ScSpace.s),
            Flexible(
              flex: 4,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(QuitText.compact(l10n, p.streak), style: context.type.metricM),
                    if (p.moneySaved != null)
                      Text(
                        QuitText.money(l10n, p.moneySaved!),
                        style: context.type.caption.copyWith(color: c.isFlat ? c.text : c.success),
                      ),
                  ],
                ),
              ),
            ),
            Icon(AppIcons.chevronRight, color: c.text3),
          ],
        ),
      ),
    );
  }
}

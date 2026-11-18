import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/top_bar.dart';
import '../application/quit_service.dart';
import 'widgets/quit_card.dart';
import 'widgets/quit_clock.dart';
import 'widgets/quit_editor_sheet.dart';

/// "Libre": todos los hábitos que la persona está dejando, como contadores
/// de ayuno que nunca se "rompen": un reinicio conserva lo ganado.
class QuitScreen extends ConsumerWidget {
  const QuitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<QuitTracker> trackers =
        ref.watch(quitTrackersProvider).value ?? const <QuitTracker>[];
    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: trackers.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => unawaited(showQuitEditor(context)),
              icon: const Icon(AppIcons.add),
              label: Text(l10n.quitAdd),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: <Widget>[
            TopBar(
              title: l10n.quitTitle,
              subtitle: l10n.quitScreenSubtitle,
              leading: BackButton(color: c.text),
            ),
            if (trackers.isEmpty)
              HealthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Icon(
                      Icons.self_improvement_rounded,
                      size: 48,
                      color: c.isFlat ? c.text : c.success,
                    ),
                    const SizedBox(height: ScSpace.m),
                    Text(
                      l10n.quitEmptyTitle,
                      style: context.text.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: ScSpace.xs),
                    Text(
                      l10n.quitEmptyBody,
                      style: context.text.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: ScSpace.l),
                    FilledButton.icon(
                      onPressed: () => unawaited(showQuitEditor(context)),
                      icon: const Icon(AppIcons.add),
                      label: Text(l10n.quitStart),
                    ),
                  ],
                ),
              )
            else
              HealthCard(
                child: QuitClockBuilder(
                  builder: (BuildContext context, DateTime now) => Column(
                    children: <Widget>[
                      for (final QuitTracker t in trackers) QuitRow(tracker: t, now: now),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(ScSpace.gutter, ScSpace.m, ScSpace.gutter, 0),
              child: Text(l10n.quitPrivacyNote, style: context.type.caption),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../pet_gamification/application/reward_service.dart';
import '../../application/quit_service.dart';
import '../quit_l10n.dart';

/// "Tengo ganas": surfear la ola. Las ganas suben, llegan a su punto más alto
/// y bajan en pocos minutos; respirar despacio mientras pasan ayuda a no ceder.
Future<void> showUrgeSheet(BuildContext context, QuitTracker tracker) async {
  final RewardGrant? grant = await mostrarHojaMenu<RewardGrant>(
    context,
    builder: (BuildContext _) => UrgeSheet(tracker: tracker),
  );
  if (grant == null || !context.mounted) return;
  final AppLocalizations l10n = context.l10n;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(grant.granted ? l10n.quitUrgeWonCoins(grant.coins) : l10n.quitUrgeWon),
      ),
    );
}

class UrgeSheet extends ConsumerStatefulWidget {
  const UrgeSheet({super.key, required this.tracker});

  final QuitTracker tracker;

  /// Duración de la ola guiada.
  static const int totalSeconds = 180;

  /// Ritmo de respiración: 4 s inhalar, 6 s exhalar (exhalación larga, calma).
  static const int inhaleSeconds = 4;
  static const int exhaleSeconds = 6;

  @override
  ConsumerState<UrgeSheet> createState() => _UrgeSheetState();
}

class _UrgeSheetState extends ConsumerState<UrgeSheet> {
  Timer? _timer;
  int _elapsed = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = math.min(_elapsed + 1, UrgeSheet.totalSeconds));
      if (_elapsed >= UrgeSheet.totalSeconds) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _won() async {
    if (_saving) return;
    setState(() => _saving = true);
    unawaited(HapticFeedback.mediumImpact());
    final RewardGrant grant = await ref.read(quitServiceProvider).urgeSurfed(widget.tracker.id);
    if (mounted) Navigator.of(context).pop(grant);
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    const int cycle = UrgeSheet.inhaleSeconds + UrgeSheet.exhaleSeconds;
    final int inCycle = _elapsed % cycle;
    final bool inhaling = inCycle < UrgeSheet.inhaleSeconds;
    // Tamaño del círculo: crece al inhalar y se encoge al exhalar. En papel,
    // tamaño fijo y solo cambia la palabra.
    final double t = inhaling
        ? (inCycle + 1) / UrgeSheet.inhaleSeconds
        : 1 - (inCycle - UrgeSheet.inhaleSeconds + 1) / UrgeSheet.exhaleSeconds;
    final double size = c.isFlat ? 150 : 110 + 70 * t;
    final int left = UrgeSheet.totalSeconds - _elapsed;
    final bool done = left == 0;
    final String? why = widget.tracker.motivation;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ScSpace.gutter, 0, ScSpace.gutter, ScSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.quitUrgeTitle, style: context.text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: ScSpace.xs),
          Text(l10n.quitUrgeBody, style: context.text.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: ScSpace.l),
          SizedBox(
            height: 200,
            child: Center(
              child: AnimatedContainer(
                duration: ScMotion.of(context, const Duration(milliseconds: 950)),
                curve: Curves.easeInOut,
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.isFlat ? c.bg3 : c.success.withValues(alpha: 0.18),
                  border: Border.all(
                    color: c.isFlat ? c.text : c.success,
                    width: c.isFlat ? 1.5 : 2,
                  ),
                ),
                child: Text(
                  done ? l10n.quitUrgeDone : (inhaling ? l10n.quitUrgeInhale : l10n.quitUrgeExhale),
                  style: context.text.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: ScSpace.s),
          Text(
            '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
            textAlign: TextAlign.center,
            style: context.type.metricL,
          ),
          if (why != null && why.isNotEmpty) ...<Widget>[
            const SizedBox(height: ScSpace.m),
            Text(l10n.quitYourWhy, style: context.type.overline, textAlign: TextAlign.center),
            const SizedBox(height: ScSpace.xxs),
            Text('“$why”', style: context.text.bodyLarge, textAlign: TextAlign.center),
          ],
          const SizedBox(height: ScSpace.m),
          Text(
            l10n.quitUrgeTip(QuitText.name(l10n, widget.tracker).toLowerCase()),
            style: context.type.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ScSpace.l),
          FilledButton.icon(
            onPressed: _saving ? null : _won,
            icon: const Icon(Icons.waves_rounded),
            label: Text(l10n.quitUrgeWonButton),
          ),
          const SizedBox(height: ScSpace.xs),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.quitUrgeLater)),
        ],
      ),
    );
  }
}

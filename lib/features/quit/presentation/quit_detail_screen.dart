import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/utils/date_formats.dart';
import '../../../shared/utils/number_formats.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/card_header.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/quick_action_button.dart';
import '../../../shared/widgets/tonal_badge.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../../shared/widgets/undo_snackbar.dart';
import '../../pet_gamification/application/reward_service.dart';
import '../application/quit_service.dart';
import '../domain/quit_catalog.dart';
import '../domain/quit_progress.dart';
import 'quit_l10n.dart';
import 'widgets/quit_clock.dart';
import 'widgets/quit_editor_sheet.dart';
import 'widgets/urge_sheet.dart';

/// Detalle de un contador de "Libre": la racha viva al estilo del ayuno, lo
/// ganado (dinero, unidades, tiempo), lo que recupera el cuerpo y los hitos.
class QuitDetailScreen extends ConsumerStatefulWidget {
  const QuitDetailScreen({super.key, required this.trackerId});

  final int trackerId;

  @override
  ConsumerState<QuitDetailScreen> createState() => _QuitDetailScreenState();
}

class _QuitDetailScreenState extends ConsumerState<QuitDetailScreen> {
  bool _celebrating = false;

  /// Celebra el hito alcanzado (una vez por hito y racha).
  Future<void> _maybeCelebrate(QuitTracker t) async {
    if (_celebrating) return;
    _celebrating = true;
    final ({Duration milestone, RewardGrant grant})? r = await ref
        .read(quitServiceProvider)
        .celebrateIfDue(t);
    if (r != null && mounted) {
      unawaited(HapticFeedback.heavyImpact());
      final AppLocalizations l10n = context.l10n;
      final int index = QuitMilestones.all.indexOf(r.milestone);
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          icon: const Icon(Icons.emoji_events_outlined, size: 40),
          title: Text(l10n.quitMilestoneTitle(QuitText.span(l10n, r.milestone))),
          content: Text(
            r.grant.granted
                ? '${QuitText.milestoneCheer(l10n, index, QuitText.name(l10n, t))}\n\n'
                      '${l10n.quitMilestoneCoins(r.grant.coins)}'
                : QuitText.milestoneCheer(l10n, index, QuitText.name(l10n, t)),
          ),
          actions: <Widget>[
            FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.quitThanks)),
          ],
        ),
      );
    }
    _celebrating = false;
  }

  Future<void> _reset(QuitTracker t) async {
    final AppLocalizations l10n = context.l10n;
    final TextEditingController note = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.quitResetTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.quitResetBody),
            const SizedBox(height: ScSpace.m),
            TextField(
              controller: note,
              maxLength: QuitService.maxTextLength,
              maxLines: 2,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.quitResetNote,
                hintText: l10n.quitResetNoteHint,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.quitResetConfirm),
          ),
        ],
      ),
    );
    final String text = note.text;
    note.dispose();
    if (confirmed != true || !mounted) return;
    final QuitService service = ref.read(quitServiceProvider);
    final ({QuitTracker before, int eventId})? r = await service.reset(t.id, note: text);
    if (r == null || !mounted) return;
    showUndoSnackBar(
      context,
      message: l10n.quitResetDone,
      onUndo: () => unawaited(service.undoReset(r.before, r.eventId)),
    );
  }

  Future<void> _menu(QuitTracker t, String action) async {
    final AppLocalizations l10n = context.l10n;
    final QuitService service = ref.read(quitServiceProvider);
    switch (action) {
      case 'edit':
        await showQuitEditor(context, tracker: t);
      case 'archive':
        await service.archive(t.id);
        if (!mounted) return;
        Navigator.of(context).pop();
        showUndoSnackBar(
          context,
          message: l10n.quitArchived,
          onUndo: () => unawaited(service.unarchive(t.id)),
        );
      case 'delete':
        final bool? ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: Text(l10n.quitDeleteTitle),
            content: Text(l10n.quitDeleteBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.commonDelete),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await service.delete(t.id);
        if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<QuitTracker?> async = ref.watch(quitTrackerProvider(widget.trackerId));
    final QuitTracker? t = async.value;
    final List<QuitEvent> events =
        ref.watch(quitEventsProvider(widget.trackerId)).value ?? const <QuitEvent>[];

    if (t == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              TopBar(
                title: l10n.quitTitle,
                leading: BackButton(color: c.text),
              ),
              if (!async.isLoading)
                Padding(
                  padding: const EdgeInsets.all(ScSpace.gutter),
                  child: Text(l10n.quitNotFound, style: context.text.bodyMedium),
                ),
            ],
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_maybeCelebrate(t));
    });

    final QuitPreset preset = QuitPreset.byKey(t.presetKey);
    final String name = QuitText.name(l10n, t);
    final int urges = events.where((QuitEvent e) => e.kind == QuitService.eventUrge).length;
    final int resets = events.where((QuitEvent e) => e.kind == QuitService.eventReset).length;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: QuitClockBuilder(
          seconds: true,
          builder: (BuildContext context, DateTime now) {
            final QuitProgress p = QuitProgress.compute(
              startedAt: t.startedAt,
              now: now,
              bankedSeconds: t.bankedSeconds,
              longestStreakSeconds: t.longestStreakSeconds,
              dailyCost: t.dailyCost,
              dailyUnits: t.dailyUnits,
              dailyMinutes: t.dailyMinutes,
            );
            return ListView(
              padding: const EdgeInsets.only(bottom: ScSpace.xl),
              children: <Widget>[
                TopBar(
                  title: name,
                  subtitle: l10n.quitSinceDate(DateFormats.shortDate(t.startedAt, l10n.localeName)),
                  leading: BackButton(color: c.text),
                  trailing: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: c.text),
                    onSelected: (String a) => unawaited(_menu(t, a)),
                    itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(value: 'edit', child: Text(l10n.commonEdit)),
                      PopupMenuItem<String>(value: 'archive', child: Text(l10n.quitArchive)),
                      PopupMenuItem<String>(value: 'delete', child: Text(l10n.commonDelete)),
                    ],
                  ),
                ),
                _StreakCard(
                  progress: p,
                  onUrge: () => unawaited(showUrgeSheet(context, t)),
                  onReset: () => unawaited(_reset(t)),
                ),
                _GainsCard(tracker: t, progress: p, urges: urges, resets: resets),
                if ((t.motivation ?? '').isNotEmpty)
                  HealthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l10n.quitYourWhy, style: context.type.overline),
                        const SizedBox(height: ScSpace.xs),
                        Text('“${t.motivation}”', style: context.text.bodyLarge),
                      ],
                    ),
                  ),
                if (preset.benefits.isNotEmpty) _BenefitsCard(preset: preset, progress: p),
                _MilestonesCard(progress: p),
                if (preset.medicalNote)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ScSpace.gutter,
                      ScSpace.s,
                      ScSpace.gutter,
                      0,
                    ),
                    child: Text(l10n.quitAlcoholSafety, style: context.type.caption),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(ScSpace.gutter, ScSpace.m, ScSpace.gutter, 0),
                  child: Text(l10n.quitSourcesNote, style: context.type.caption),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.progress, required this.onUrge, required this.onReset});

  final QuitProgress progress;
  final VoidCallback onUrge;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final DurationParts d = DurationParts.of(progress.streak);
    final String hms = c.isFlat
        ? '${d.hours} h ${d.minutes.toString().padLeft(2, '0')} min'
        : '${d.hours.toString().padLeft(2, '0')}:${d.minutes.toString().padLeft(2, '0')}:'
              '${d.seconds.toString().padLeft(2, '0')}';
    final Duration? next = progress.nextMilestone;
    return HealthCard(
      padding: const EdgeInsets.fromLTRB(ScSpace.l + 4, ScSpace.xl, ScSpace.l + 4, ScSpace.l + 4),
      child: Column(
        children: <Widget>[
          Semantics(
            label: l10n.quitStreakSemantics(d.days, d.hours, d.minutes),
            excludeSemantics: true,
            child: ScProgressRing(
              value: progress.milestoneFraction,
              size: 236,
              stroke: 16,
              color: c.success,
              animateChanges: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TonalBadge(
                    label: progress.isPersonalBest ? l10n.quitBestStreak : l10n.quitFree,
                    tone: c.success,
                    icon: progress.isPersonalBest ? Icons.emoji_events_outlined : null,
                  ),
                  const SizedBox(height: ScSpace.s),
                  Text('${d.days}', style: context.type.metricXL.copyWith(fontSize: 56, height: 1)),
                  Text(l10n.quitDaysLabel(d.days), style: context.type.label),
                  const SizedBox(height: ScSpace.xs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(hms, style: context.type.metricS),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ScSpace.m),
          Text(
            next == null
                ? l10n.quitAllMilestones
                : l10n.quitNextMilestoneIn(
                    QuitText.span(context.l10n, next),
                    QuitText.compact(l10n, next - progress.streak),
                  ),
            style: context.type.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ScSpace.l),
          QuickActionButton(
            label: l10n.quitUrgeButton,
            icon: Icons.waves_rounded,
            emphasized: true,
            onPressed: onUrge,
          ),
          const SizedBox(height: ScSpace.s),
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(AppIcons.refresh, size: 18),
            label: Text(l10n.quitResetButton),
          ),
        ],
      ),
    );
  }
}

class _GainsCard extends StatelessWidget {
  const _GainsCard({
    required this.tracker,
    required this.progress,
    required this.urges,
    required this.resets,
  });

  final QuitTracker tracker;
  final QuitProgress progress;
  final int urges;
  final int resets;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<(IconData, String, String)> cells = <(IconData, String, String)>[
      if (progress.moneySaved != null)
        (Icons.savings_outlined, l10n.quitGainMoney, QuitText.money(l10n, progress.moneySaved!)),
      if (progress.unitsAvoided != null)
        (
          Icons.block_rounded,
          l10n.quitGainAvoided,
          QuitText.unitsAvoided(l10n, tracker.presetKey, progress.unitsAvoided!),
        ),
      if (progress.minutesReclaimed != null)
        (
          Icons.schedule_rounded,
          l10n.quitGainTime,
          QuitText.reclaimed(l10n, progress.minutesReclaimed!),
        ),
      (Icons.emoji_events_outlined, l10n.quitGainBest, QuitText.compact(l10n, progress.longest)),
      if (resets > 0)
        (
          Icons.all_inclusive_rounded,
          l10n.quitGainTotal,
          QuitText.compact(l10n, progress.cleanTime),
        ),
      (Icons.waves_rounded, l10n.quitGainUrges, NumberFormats.group(urges)),
    ];
    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CardHeader(icon: Icons.trending_up_rounded, tone: c.success, title: l10n.quitGainsTitle),
          const SizedBox(height: ScSpace.m),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final double w = (box.maxWidth - ScSpace.s) / 2;
              return Wrap(
                spacing: ScSpace.s,
                runSpacing: ScSpace.s,
                children: <Widget>[
                  for (final (IconData icon, String label, String value) in cells)
                    Container(
                      width: w,
                      padding: const EdgeInsets.all(ScSpace.m),
                      decoration: BoxDecoration(
                        color: c.isFlat ? c.bg2 : c.bg3,
                        borderRadius: BorderRadius.circular(ScRadius.tileOf(c)),
                        border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(icon, size: 18, color: c.isFlat ? c.text : c.success),
                          const SizedBox(height: ScSpace.xs),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(value, style: context.type.metricS),
                          ),
                          Text(label, style: context.type.caption, maxLines: 2),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard({required this.preset, required this.progress});

  final QuitPreset preset;
  final QuitProgress progress;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final QuitBenefit? next = progress.nextBenefit(preset);
    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CardHeader(
            icon: Icons.favorite_border_rounded,
            tone: c.success,
            title: l10n.quitBenefitsTitle,
            subtitle: l10n.quitBenefitsSubtitle,
          ),
          const SizedBox(height: ScSpace.m),
          for (final QuitBenefit b in preset.benefits)
            _TimelineRow(
              done: progress.streak >= b.after,
              current: identical(b, next),
              when: QuitText.span(l10n, b.after),
              text: QuitText.benefit(l10n, b.key),
              fraction: identical(b, next)
                  ? (progress.streak.inSeconds / b.after.inSeconds).clamp(0.0, 1.0)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.done,
    required this.current,
    required this.when,
    required this.text,
    this.fraction,
  });

  final bool done;
  final bool current;
  final String when;
  final String text;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final Color tone = c.isFlat ? c.text : c.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ScSpace.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: done ? tone : c.text3,
          ),
          const SizedBox(width: ScSpace.s + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  when.toUpperCase(),
                  style: context.type.overline.copyWith(color: done || current ? tone : c.text3),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: context.text.bodyMedium?.copyWith(
                    color: done || current ? c.text : c.text2,
                  ),
                ),
                if (fraction != null) ...<Widget>[
                  const SizedBox(height: ScSpace.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 5,
                      color: tone,
                      backgroundColor: c.isFlat ? c.line2 : c.success.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestonesCard extends StatelessWidget {
  const _MilestonesCard({required this.progress});

  final QuitProgress progress;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CardHeader(
            icon: Icons.military_tech_outlined,
            tone: c.success,
            title: l10n.quitMilestonesTitle,
            subtitle: l10n.quitMilestonesSubtitle(
              progress.milestonesReached,
              QuitMilestones.all.length,
            ),
          ),
          const SizedBox(height: ScSpace.m),
          Wrap(
            spacing: ScSpace.s,
            runSpacing: ScSpace.s,
            children: <Widget>[
              for (final (int i, Duration m) in QuitMilestones.all.indexed)
                Chip(
                  avatar: Icon(
                    i < progress.milestonesReached ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 18,
                    color: i < progress.milestonesReached
                        ? (c.isFlat ? c.text : c.success)
                        : c.text3,
                  ),
                  label: Text(QuitText.span(l10n, m)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

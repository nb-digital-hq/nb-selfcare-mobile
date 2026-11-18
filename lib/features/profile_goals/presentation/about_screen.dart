import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/network/update_service.dart';
import '../../../core/platform/plataforma.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/widgets/card_header.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/top_bar.dart';
import '../application/update_controller.dart';
import 'widgets/app_logo.dart';

/// Ajustes › Acerca de: logo, versión instalada y actualizaciones desde GitHub.
/// Nunca busca sola: el botón es el consentimiento (ADR-18).
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static String failureText(AppLocalizations l10n, UpdateFailure f) => switch (f) {
    UpdateFailure.sinPublicaciones => l10n.updateNoReleases,
    UpdateFailure.limiteGithub => l10n.updateRateLimited,
    UpdateFailure.sinConexion => l10n.updateNoConnection,
    UpdateFailure.sinApk => l10n.updateNoApk,
    UpdateFailure.descargaFallida => l10n.updateDownloadFailed,
    UpdateFailure.descargaIncompleta => l10n.updateDownloadIncomplete,
    UpdateFailure.huellaDistinta => l10n.updateChecksumMismatch,
    UpdateFailure.instalacionFallida => l10n.updateInstallFailed,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final UpdateState s = ref.watch(updateControllerProvider);
    final UpdateController ctrl = ref.read(updateControllerProvider.notifier);
    final String? message = switch (s) {
      UpdateState(needsPermission: true) => l10n.updateNeedsPermission,
      UpdateState(failure: final UpdateFailure f) => failureText(l10n, f),
      UpdateState(phase: UpdatePhase.checking) => l10n.updateChecking,
      UpdateState(phase: UpdatePhase.upToDate) => l10n.updateUpToDate,
      UpdateState(phase: UpdatePhase.available) => l10n.updateAvailable(s.release?.version ?? ''),
      UpdateState(phase: UpdatePhase.ready) => l10n.updateConfirm,
      _ => null,
    };

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: ScSpace.xl),
          children: <Widget>[
            TopBar(
              title: l10n.aboutTitle,
              leading: BackButton(color: c.text),
            ),
            const SizedBox(height: ScSpace.m),
            Center(
              child: Semantics(
                button: true,
                label: l10n.appIconTitle,
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: funcionesAndroid ? () => unawaited(context.push('/ajustes/icono')) : null,
                  child: const AppLogo(size: 112),
                ),
              ),
            ),
            const SizedBox(height: ScSpace.m),
            Text(
              AppConstants.appName,
              textAlign: TextAlign.center,
              style: context.text.headlineSmall,
            ),
            const SizedBox(height: ScSpace.xxs),
            Text(
              s.installedVersion.isEmpty
                  ? l10n.aboutVersionUnknown
                  : l10n.aboutVersion(s.installedVersion),
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: ScSpace.xxs),
            Text(l10n.aboutEcosystem, textAlign: TextAlign.center, style: context.type.caption),
            const SizedBox(height: ScSpace.l),
            if (funcionesAndroid) ...<Widget>[
              HealthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    CardHeader(
                      icon: Icons.system_update_alt_rounded,
                      title: l10n.updateTitle,
                      subtitle: l10n.updateSubtitle,
                    ),
                    const SizedBox(height: ScSpace.m),
                    if (s.phase == UpdatePhase.downloading) ...<Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: s.progress > 0 ? s.progress : null,
                          minHeight: 6,
                          color: c.isFlat ? c.text : c.accent,
                          backgroundColor: c.line2,
                        ),
                      ),
                      const SizedBox(height: ScSpace.s),
                    ],
                    if (s.hasNewVersion)
                      FilledButton.icon(
                        onPressed: s.busy ? null : () => unawaited(ctrl.install()),
                        icon: const Icon(Icons.download_rounded),
                        label: Text(
                          s.phase == UpdatePhase.downloading
                              ? l10n.updateDownloading((s.progress * 100).round())
                              : l10n.updateInstall(s.release?.version ?? ''),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: s.busy ? null : () => unawaited(ctrl.check()),
                        icon: s.phase == UpdatePhase.checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: Text(l10n.updateCheck),
                      ),
                    if (message != null) ...<Widget>[
                      const SizedBox(height: ScSpace.s),
                      Text(message, style: context.text.bodyMedium),
                    ],
                    if (s.hasNewVersion && (s.release?.notas.isNotEmpty ?? false)) ...<Widget>[
                      const SizedBox(height: ScSpace.m),
                      Text(l10n.updateWhatsNew, style: context.text.titleSmall),
                      const SizedBox(height: ScSpace.xs),
                      Text(s.release!.notas, style: context.text.bodySmall),
                    ],
                    const SizedBox(height: ScSpace.s),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: ctrl.openRepo,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(l10n.updateOpenGithub),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(ScSpace.gutter, ScSpace.m, ScSpace.gutter, 0),
                child: Text(l10n.updatePrivacyNote, style: context.type.caption),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

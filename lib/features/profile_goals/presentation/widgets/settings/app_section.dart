import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/l10n/idioma.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/platform/plataforma.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_tokens.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../application/reminder_service.dart';
import '../../../application/update_controller.dart';
import '../app_logo.dart';

/// Cabecera de Ajustes: el logo de la app (con el ícono elegido), la versión
/// y los accesos a "Ícono de la app" y "Acerca de y actualizaciones".
class AppSection extends ConsumerWidget {
  const AppSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final String version = ref.watch(
      updateControllerProvider.select((UpdateState s) => s.installedVersion),
    );
    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(ScSpace.l),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Semantics(
                button: true,
                label: l10n.appIconTitle,
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: funcionesAndroid ? () => unawaited(context.push('/ajustes/icono')) : null,
                  child: const AppLogo(size: 64),
                ),
              ),
              const SizedBox(width: ScSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(AppConstants.appName, style: context.text.titleLarge),
                    Text(
                      version.isEmpty ? l10n.aboutVersionUnknown : l10n.aboutVersion(version),
                      style: context.type.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ScSpace.s),
          if (funcionesAndroid)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.appIconTitle),
              subtitle: Text(l10n.appIconTileHint),
              trailing: Icon(AppIcons.chevronRight, color: c.text3),
              onTap: () => unawaited(context.push('/ajustes/icono')),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.translate_rounded),
            title: Text(l10n.settingsLanguage),
            subtitle: Text(_nombreIdioma(l10n, ref.watch(idiomaControllerProvider))),
            trailing: Icon(AppIcons.chevronRight, color: c.text3),
            onTap: () => unawaited(_elegirIdioma(context, ref)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.system_update_alt_rounded),
            title: Text(l10n.aboutTileTitle),
            subtitle: Text(l10n.aboutTileHint),
            trailing: Icon(AppIcons.chevronRight, color: c.text3),
            onTap: () => unawaited(context.push('/ajustes/acerca')),
          ),
        ],
      ),
    );
  }
}

/// Nombre de cada idioma en su propia lengua, salvo "el del sistema".
String _nombreIdioma(AppLocalizations l10n, Idioma idioma) => switch (idioma) {
  Idioma.sistema => l10n.settingsLanguageSystem,
  Idioma.es => 'Español',
  Idioma.en => 'English',
  Idioma.pt => 'Português',
};

Future<void> _elegirIdioma(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final Idioma actual = ref.read(idiomaControllerProvider);
  final Idioma? elegido = await showDialog<Idioma>(
    context: context,
    builder: (BuildContext ctx) => SimpleDialog(
      title: Text(l10n.settingsLanguage),
      children: <Widget>[
        RadioGroup<Idioma>(
          groupValue: actual,
          onChanged: (Idioma? v) => Navigator.of(ctx).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final Idioma i in Idioma.values)
                RadioListTile<Idioma>(value: i, title: Text(_nombreIdioma(l10n, i))),
            ],
          ),
        ),
      ],
    ),
  );
  if (elegido == null || elegido == actual) return;
  await ref.read(idiomaControllerProvider.notifier).elegir(elegido);
  // Los avisos programados llevan su texto: se reescriben en el idioma nuevo.
  await ref.read(reminderServiceProvider).syncSchedules();
}

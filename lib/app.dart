import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/l10n/idioma.dart';
import 'shared/theme/sc_theme.dart';
import 'shared/theme/theme_controller.dart';

/// Widget raíz: enrutador, idioma elegido (o el del sistema) y tema activo.
class NbSelfcareApp extends ConsumerWidget {
  const NbSelfcareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String activeThemeKey = ref.watch(themeControllerProvider);
    final router = ref.watch(appRouterProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? light, ColorScheme? dark) {
        final bool dynamicTheme =
            activeThemeKey == kDynamicThemeKey && light != null && dark != null;
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: dynamicTheme
              ? ScTheme.build(activeThemeKey, override: dynamicThemeDef(light))
              : ScTheme.build(activeThemeKey),
          darkTheme: dynamicTheme
              ? ScTheme.build(activeThemeKey, override: dynamicThemeDef(dark))
              : null,
          themeMode: dynamicTheme ? ThemeMode.system : ThemeMode.light,
          // En papel el cambio de tema se dibuja de una vez (un fundido de
          // colores dejaría estelas en la pantalla de tinta).
          themeAnimationDuration: scThemeByKey(activeThemeKey).colors.isFlat
              ? Duration.zero
              : kThemeAnimationDuration,
          locale: ref.watch(localeActivoProvider),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          // Horas siempre en 24 h, como en el resto de la app ("22:30"). Con el
          // formato de 12 h del sistema, el selector en modo texto rechazaba
          // las horas de la tarde porque no mostraba AM/PM.
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

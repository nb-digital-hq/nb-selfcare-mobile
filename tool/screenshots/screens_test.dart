// Arnés de capturas de pantalla para revisar la UI sin dispositivo.
//
//   flutter test tool/screenshots --update-goldens
//
// Genera PNG en tool/screenshots/goldens/ con datos realistas sembrados.
// Con --dart-define=FULL_PAGE=true captura la página completa (alto 3200).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/app.dart';
import 'package:nb_selfcare/app/router/app_router.dart';
import 'package:nb_selfcare/core/clock/clock.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/seeder/database_seeder.dart';
import 'package:nb_selfcare/core/l10n/idioma.dart';
import 'package:nb_selfcare/core/l10n/l10n.dart';
import 'package:nb_selfcare/features/profile_goals/application/demo_seeder.dart';
import 'package:nb_selfcare/shared/theme/theme_controller.dart';

final DateTime _now = DateTime(2026, 10, 26, 13, 30);

Future<void> _seed(AppDatabase db, String themeKey) =>
    sembrarDemo(db, ahora: _now, idioma: _idioma, themeKey: themeKey);

/// Idioma de las capturas: `--dart-define=LANG=en` o `pt`; español por defecto.
const String _idioma = String.fromEnvironment('LANG', defaultValue: 'es');

final AppLocalizations _l10n = lookupAppLocalizations(const Locale(_idioma));

void main() {
  const bool fullPage = bool.fromEnvironment('FULL_PAGE');
  const Size phone = Size(393, fullPage ? 3200 : 873);

  for (final String themeKey in <String>[
    'samsung_dark',
    'nxtpaper_eink_light',
    'nxtpaper_sepia',
    'salvia_lino',
  ]) {
    for (final String route in <String>[
      '/hoy',
      '/comer',
      '/cuerpo',
      '/cuidado',
      '/nibi',
      '/nibi#respirar',
      '/nibi#sesion',
      '/nibi#tienda',
      '/perfil',
      '/ayuno',
      '/ajustes',
      '/protocolo',
      '/onboarding',
    ]) {
      testWidgets('$themeKey $route', (WidgetTester tester) async {
        tester.view.physicalSize = phone * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        final AppDatabase db = AppDatabase(NativeDatabase.memory());
        await tester.runAsync(
          () => route == '/onboarding'
              ? DatabaseSeeder.seedIfEmpty(db, idioma: _idioma)
              : _seed(db, themeKey),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              clockProvider.overrideWithValue(Clock.fixed(_now)),
              localeActivoProvider.overrideWithValue(const Locale(_idioma)),
            ],
            child: const NbSelfcareApp(),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        final ProviderContainer container = ProviderScope.containerOf(
          tester.element(find.byType(NbSelfcareApp)),
        );
        await tester.runAsync(
          () => container.read(themeControllerProvider.notifier).selectTheme(themeKey),
        );
        final List<String> parts = route.split('#');
        container.read(appRouterProvider).go(parts.first);
        for (int i = 0; i < 8; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
          await tester.pump(const Duration(milliseconds: 250));
        }
        await tester.runAsync(() async {
          for (final Element e in find.byType(Image).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
        });
        await tester.pump(const Duration(milliseconds: 300));

        // Estados de la pestaña Nibi a los que se llega tocando.
        Future<void> tapText(String text) async {
          await tester.ensureVisible(find.text(text).last);
          await tester.pump(const Duration(milliseconds: 250));
          await tester.tap(find.text(text).last, warnIfMissed: false);
          for (int i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
        }

        switch (parts.length > 1 ? parts[1] : '') {
          case 'respirar':
            await tapText(_l10n.nibiCareBreathe);
          case 'sesion':
            await tapText(_l10n.nibiCareBreathe);
            await tapText(_l10n.breathStart);
            await tester.pump(const Duration(milliseconds: 1500));
          case 'tienda':
            await tapText(_l10n.nibiShop);
        }

        final String name =
            '${themeKey}_${route.substring(1).replaceAll('#', '_')}${fullPage ? '_full' : ''}';
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$_idioma/$name.png'),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(db.close);
      });
    }
  }
}

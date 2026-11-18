import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/features/quit/application/quit_service.dart';

import '../support/app_harness.dart';
import '../support/layout_probe.dart';
import '../support/test_container.dart';

/// Las pantallas nuevas (Libre, Ícono de la app, Acerca de) se dibujan sin
/// desbordes en color y en papel, en un teléfono estrecho y con letra grande.
void main() {
  const List<String> routes = <String>[
    '/cuidado',
    '/libre',
    '/libre/1',
    '/ajustes',
    '/ajustes/icono',
    '/ajustes/acerca',
  ];

  for (final String theme in <String>['samsung_dark', 'nxtpaper_eink_light']) {
    for (final (Size size, double scale) in <(Size, double)>[
      (const Size(393, 873), 1),
      (const Size(320, 640), 1.3),
    ]) {
      for (final String route in routes) {
        testWidgets('$theme $route ${size.width.toInt()} dp ×$scale', (WidgetTester tester) async {
          final AppDatabase db = harnessDatabase();
          await tester.runAsync(() async {
            await seedHarness(db, SeedProfile.typical, theme);
            final ProviderContainer c = createTestContainer(db, now: harnessNow);
            await c
                .read(quitServiceProvider)
                .add(
                  QuitDraft(
                    presetKey: 'tobacco',
                    startedAt: harnessNow.subtract(const Duration(days: 12, hours: 5)),
                    dailyCost: 9500,
                    dailyUnits: 14,
                    motivation: 'Subir la montaña con mi familia sin ahogarme',
                  ),
                );
            await c
                .read(quitServiceProvider)
                .add(
                  QuitDraft(
                    presetKey: 'social_media',
                    startedAt: harnessNow.subtract(const Duration(hours: 3)),
                    dailyMinutes: 150,
                  ),
                );
            c.dispose();
          });
          await pumpHarness(
            tester,
            db: db,
            themeKey: theme,
            route: route,
            size: size,
            textScale: scale,
          );
          final String overflows = describeOverflows(tester);
          expect(tester.takeException(), isNull, reason: '$route\n$overflows');
          expect(overflows, isEmpty, reason: route);
          await unmountHarness(tester, db);
        });
      }
    }
  }
}

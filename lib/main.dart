import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/clock/clock.dart';
import 'core/database/app_database.dart';
import 'core/l10n/idioma.dart';
import 'features/profile_goals/application/demo_seeder.dart';
import 'features/profile_goals/application/enlace_pc.dart';

/// Con `--dart-define=NB_DEMO=true` la app arranca con el perfil ficticio de
/// la documentación (solo si la base aún no tiene perfil).
const bool _demo = bool.fromEnvironment('NB_DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_demo) {
    final AppDatabase db = AppDatabase();
    await sembrarDemo(
      db,
      ahora: const Clock().now(),
      idioma: localeDe(Idioma.sistema).languageCode,
    );
    await db.close();
  }
  final ProviderContainer contenedor = ProviderContainer();
  // La sincronización con el ordenador vinculado vive fuera del árbol de widgets:
  // solo actúa si la persona vinculó un equipo, y nunca en segundo plano.
  contenedor.read(sincronizacionAutomaticaProvider);
  runApp(UncontrolledProviderScope(container: contenedor, child: const NbSelfcareApp()));
}

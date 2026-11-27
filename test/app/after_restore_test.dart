import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/app/app_sync_coordinator.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/l10n/idioma.dart';

import '../support/fake_platform.dart';
import '../support/test_container.dart';

void main() {
  test('tras restaurar sin ayuno activo se retira el aviso del cronometro', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final FakeNotificationGateway avisos = FakeNotificationGateway()
      ..fastingTimer = (startedAt: DateTime(2026, 10, 23, 8), targetHours: 16, protocol: '16:8');
    final container = createTestContainer(db, notifications: avisos);
    addTearDown(container.dispose);

    await container.read(appSyncCoordinatorProvider).afterRestore();

    expect(avisos.fastingTimer, isNull);
  });

  test('tras restaurar el idioma sigue la preferencia de la base restaurada', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = createTestContainer(db);
    addTearDown(container.dispose);

    await container.read(idiomaControllerProvider.notifier).elegir(Idioma.en);
    // La restauración reemplaza las preferencias por las del respaldo.
    await db.writeUiPreference(kIdiomaPrefKey, Idioma.es.name);

    await container.read(appSyncCoordinatorProvider).afterRestore();
    container.read(idiomaControllerProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(idiomaControllerProvider), Idioma.es);
  });
}

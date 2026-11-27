import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/respaldo_de_migracion.dart';
import 'package:sqlite3/sqlite3.dart';

import '../drift/app_database/generated/schema.dart';

void main() {
  late Directory carpeta;
  setUp(() {
    carpeta = Directory.systemTemp.createTempSync('nb-selfcare-qa-migracion-');
  });
  tearDown(() {
    carpeta.deleteSync(recursive: true);
  });

  test('el respaldo incluye escrituras confirmadas en WAL y no cambia el original', () {
    final archivo = File('${carpeta.path}/base.sqlite');
    final base = sqlite3.open(archivo.path);
    addTearDown(base.close);
    base
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA wal_autocheckpoint = 0')
      ..execute('CREATE TABLE sintetica (valor TEXT NOT NULL)')
      ..execute('PRAGMA user_version = 7')
      ..execute("INSERT INTO sintetica VALUES ('dato sintético')");
    expect(File('${archivo.path}-wal').lengthSync(), greaterThan(0));
    final respaldo = respaldarAntesDeMigrar(base, versionDestino: 8)!;
    final copia = sqlite3.open(respaldo.path, mode: OpenMode.readOnly);
    addTearDown(copia.close);
    expect(copia.select('PRAGMA user_version').single.values.single, 7);
    expect(copia.select('SELECT valor FROM sintetica').single['valor'], 'dato sintético');
    base.execute("UPDATE sintetica SET valor = 'edición posterior'");
    expect(copia.select('SELECT valor FROM sintetica').single['valor'], 'dato sintético');
    expect(base.select('PRAGMA user_version').single.values.single, 7);
  });

  test('los reintentos conservan todos los respaldos anteriores', () {
    final base = sqlite3.open('${carpeta.path}/base.sqlite');
    addTearDown(base.close);
    base
      ..execute('CREATE TABLE sintetica (valor INTEGER)')
      ..execute('PRAGMA user_version = 7');
    final primero = respaldarAntesDeMigrar(base, versionDestino: 8)!;
    final segundo = respaldarAntesDeMigrar(base, versionDestino: 8)!;
    expect(primero.path, isNot(segundo.path));
    expect(primero.existsSync(), isTrue);
    expect(segundo.existsSync(), isTrue);
  });

  test('una base nueva, actual, futura o en memoria no crea respaldo', () {
    final base = sqlite3.open('${carpeta.path}/base.sqlite');
    final memoria = sqlite3.openInMemory();
    addTearDown(base.close);
    addTearDown(memoria.close);
    for (final version in [0, 8, 9]) {
      base.execute('PRAGMA user_version = $version');
      expect(respaldarAntesDeMigrar(base, versionDestino: 8), isNull);
    }
    memoria.execute('PRAGMA user_version = 7');
    expect(respaldarAntesDeMigrar(memoria, versionDestino: 8), isNull);
    expect(carpeta.listSync().whereType<Directory>(), isEmpty);
  });

  test('un fallo de copia bloquea la apertura sin borrar el original ni filtrar rutas', () {
    final archivo = File('${carpeta.path}/base.sqlite');
    final base = sqlite3.open(archivo.path);
    addTearDown(base.close);
    base
      ..execute('CREATE TABLE sintetica (valor INTEGER)')
      ..execute('PRAGMA user_version = 7')
      ..execute('BEGIN IMMEDIATE');
    expect(
      () => respaldarAntesDeMigrar(base, versionDestino: 8),
      throwsA(isA<StateError>().having((e) => e.message, 'código', 'MIGRATION_BACKUP_FAILED')),
    );
    base.execute('ROLLBACK');
    expect(archivo.existsSync(), isTrue);
    expect(base.select('PRAGMA user_version').single.values.single, 7);
    expect(carpeta.listSync().whereType<Directory>(), isEmpty);
  });

  test('Drift conserva el archivo v7 antes de migrar y no repite la copia al reabrir la versión actual', () async {
    final archivo = File('${carpeta.path}/base.sqlite');
    final anterior = GeneratedHelper().databaseForVersion(NativeDatabase(archivo), 7);
    await anterior.customStatement("INSERT INTO ui_preferences VALUES ('sintetica', 'conservada')");
    await anterior.close();
    final actual = AppDatabase(NativeDatabase(archivo, setup: AppDatabase.prepararMigracion));
    try {
      expect(await actual.readUiPreference('sintetica'), 'conservada');
      final version = await actual.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), AppDatabase.versionDelEsquema);
    } finally {
      await actual.close();
    }
    final respaldos = carpeta.listSync().whereType<Directory>().toList();
    expect(respaldos, hasLength(1));
    final copia = sqlite3.open('${respaldos.single.path}/respaldo.sqlite', mode: OpenMode.readOnly);
    try {
      expect(copia.select('PRAGMA user_version').single.values.single, 7);
      expect(
        copia.select('SELECT pref_value FROM ui_preferences').single['pref_value'],
        'conservada',
      );
      expect(copia.select("SELECT name FROM sqlite_master WHERE name = 'quit_trackers'"), isEmpty);
    } finally {
      copia.close();
    }
    final reabierta = AppDatabase(NativeDatabase(archivo, setup: AppDatabase.prepararMigracion));
    try {
      expect(await reabierta.readUiPreference('sintetica'), 'conservada');
    } finally {
      await reabierta.close();
    }
    expect(carpeta.listSync().whereType<Directory>(), hasLength(1));
  });
}

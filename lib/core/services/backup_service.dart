import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../clock/clock.dart';
import '../database/app_database.dart';

/// Resultado de inspeccionar un archivo `.sqlite` externo antes de restaurarlo.
class BackupInspection {
  const BackupInspection({required this.isValid, this.schemaVersion});

  const BackupInspection.invalid() : this(isValid: false);

  final bool isValid;

  /// `PRAGMA user_version` del respaldo (versión de esquema de Drift).
  final int? schemaVersion;
}

/// Servicio de respaldo atómico y portabilidad total (.sqlite).
///
/// Exporta en caliente con `VACUUM INTO` sobre un directorio temporal seguro
/// (`AGENTS.md` §1.4). Restaura todas las tablas del esquema actual: si el
/// respaldo es de una versión anterior, primero se migra una copia temporal con
/// la misma `MigrationStrategy` de la app y luego se copia columna a columna.
class BackupService {
  BackupService(
    this._db, {
    Future<Directory> Function()? temporaryDirectory,
    this._clock = const Clock(),
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final AppDatabase _db;
  final Clock _clock;
  final Future<Directory> Function() _temporaryDirectory;

  static const String _attachedAlias = 'ext_backup';

  /// Tablas que deben existir en cualquier respaldo legítimo de NB SelfCare.
  static const List<String> _requiredTables = <String>['user_profiles', 'food_items', 'pet_status'];

  /// Tablas de datos en orden compatible con las claves foráneas
  /// (el orden de declaración en `@DriftDatabase` respeta las dependencias).
  List<String> get _dataTables =>
      _db.allTables.map((TableInfo<Table, Object?> t) => t.actualTableName).toList();

  /// Exporta la base de datos a un archivo `.sqlite` limpio en el directorio temporal seguro.
  Future<File> exportDatabase() async {
    final Directory tempDir = await _temporaryDirectory();
    final Directory backupDirectory = Directory(p.join(tempDir.path, 'nb_backups'));
    if (!backupDirectory.existsSync()) {
      backupDirectory.createSync(recursive: true);
    }

    return _db.exportCleanDatabaseBackup(backupDirectory.path, stamp: _clock.now());
  }

  /// Exporta y comparte el archivo `.sqlite` mediante el diálogo nativo del sistema.
  Future<void> shareDatabaseBackup({required String subject}) async {
    final File backupFile = await exportDatabase();
    await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(backupFile.path)], subject: subject),
    );
  }

  /// Verifica integridad física, tablas mínimas y versión de esquema compatible.
  BackupInspection inspectBackup(String filePath) {
    final File file = File(filePath);
    if (!file.existsSync() || file.lengthSync() < 4096) {
      return const BackupInspection.invalid();
    }

    sqlite.Database? rawDb;
    try {
      rawDb = sqlite.sqlite3.open(filePath, mode: sqlite.OpenMode.readOnly);
      final sqlite.ResultSet integrity = rawDb.select('PRAGMA integrity_check;');
      if (integrity.isEmpty || integrity.first['integrity_check'] != 'ok') {
        return const BackupInspection.invalid();
      }

      final sqlite.ResultSet tables = rawDb.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN "
        "(${_requiredTables.map((_) => '?').join(', ')});",
        _requiredTables,
      );
      if (tables.length != _requiredTables.length) {
        return const BackupInspection.invalid();
      }

      final int version = rawDb.select('PRAGMA user_version;').first.values.first as int;
      if (version < 1 || version > _db.schemaVersion) {
        return BackupInspection(isValid: false, schemaVersion: version);
      }
      if (rawDb.select('PRAGMA foreign_key_check').isNotEmpty) {
        return const BackupInspection.invalid();
      }
      return BackupInspection(isValid: true, schemaVersion: version);
    } on Object {
      // SqliteException, pero también FormatException: con páginas corrompidas
      // el mensaje de error de SQLite puede no ser UTF-8 válido.
      return const BackupInspection.invalid();
    } finally {
      rawDb?.close();
    }
  }

  /// Atajo booleano de [inspectBackup].
  Future<bool> verifyBackupIntegrity(String filePath) async => inspectBackup(filePath).isValid;

  /// Restaura de forma atómica todas las tablas desde un respaldo `.sqlite` verificado,
  /// reconstruye el índice FTS5 y notifica a todos los streams de Drift.
  Future<bool> restoreDatabaseFromFile(String externalFilePath) async {
    final BackupInspection inspection = inspectBackup(externalFilePath);
    if (!inspection.isValid) return false;

    final Directory stagingDir = (await _temporaryDirectory()).createTempSync('nb_restore_');
    final File staging = File(p.join(stagingDir.path, 'staging.sqlite'));

    try {
      final destino = staging.path;
      await _copiarEnSegundoPlano(externalFilePath, destino);
      final instantanea = inspectBackup(staging.path);
      if (!instantanea.isValid) return false;
      if (instantanea.schemaVersion! < _db.schemaVersion) {
        await _migrateStagingCopy(staging);
      }
      return await _db.exclusively(() async {
        await _respaldarAntesDeRestaurar();
        return _copyFromStaging(staging.path);
      });
    } on Exception {
      return false;
    } finally {
      if (stagingDir.existsSync()) {
        stagingDir.deleteSync(recursive: true);
      }
    }
  }

  static void _copiarOrigenCoherente(String origen, String destino) {
    final base = sqlite.sqlite3.open(origen, mode: sqlite.OpenMode.readOnly);
    try {
      base.execute('VACUUM INTO ?', [destino]);
    } finally {
      base.close();
    }
  }

  // Este cierre solo captura rutas. Crearlo en el método de restauración puede
  // capturar también su contexto de Drift, que contiene objetos FFI no enviables.
  static Future<void> _copiarEnSegundoPlano(String origen, String destino) =>
      Isolate.run(() => _copiarOrigenCoherente(origen, destino));

  static Future<bool> _verificarEnSegundoPlano(String ruta, int version) =>
      Isolate.run(() => _respaldoIntegro(ruta, version));

  /// Abre la copia temporal con la estrategia de migración de la app para llevarla
  /// al esquema actual sin tocar el archivo original del usuario.
  Future<void> _migrateStagingCopy(File staging) async {
    final AppDatabase legacy = AppDatabase(NativeDatabase(staging));
    try {
      await legacy.customSelect('SELECT 1').get();
      await legacy.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
    } finally {
      await legacy.close();
    }
  }

  Future<void> _respaldarAntesDeRestaurar() async {
    final principal = (await _db.customSelect('PRAGMA database_list').get()).singleWhere(
      (fila) => fila.read<String>('name') == 'main',
    );
    final ruta = principal.read<String>('file');
    final directorio = ruta.isEmpty ? await _temporaryDirectory() : File(ruta).parent;
    final carpeta = await directorio.createTemp('.nb-selfcare-restauracion-');
    final respaldo = p.join(carpeta.path, 'respaldo.sqlite');
    final version = _db.schemaVersion;
    try {
      await _db.customStatement('VACUUM INTO ?', [respaldo]);
      final integro = await _verificarEnSegundoPlano(respaldo, version);
      if (!integro) throw const FormatException('RESTORE_BACKUP_INVALID');
    } catch (_) {
      try {
        await carpeta.delete(recursive: true);
      } catch (_) {
        // Un resto parcial no se utiliza para restaurar ni sale del directorio privado.
      }
      rethrow;
    }
  }

  static bool _respaldoIntegro(String ruta, int version) {
    sqlite.Database? copia;
    try {
      copia = sqlite.sqlite3.open(ruta, mode: sqlite.OpenMode.readOnly);
      final resultado = copia.select('PRAGMA integrity_check');
      return resultado.length == 1 &&
          resultado.single.values.single == 'ok' &&
          copia.select('PRAGMA user_version').single.values.single == version;
    } finally {
      copia?.close();
    }
  }

  Future<bool> _copyFromStaging(String stagingPath) async {
    await _db.customStatement('PRAGMA foreign_keys = OFF;');
    var adjunta = false;
    try {
      await _db.customStatement('ATTACH DATABASE ? AS $_attachedAlias;', <Object>[stagingPath]);
      adjunta = true;
      for (final tabla in _dataTables) {
        if (!await _attachedTableExists(tabla)) {
          throw const FormatException('RESTORE_SCHEMA_INVALID');
        }
      }
      await _db.customStatement('BEGIN IMMEDIATE');
      try {
        // Los disparadores de sincronización no marcan revisiones al restaurar; las
        // identidades salen de la copia (siempre migrada al esquema 9).
        await _db.customStatement(
          'UPDATE sc_sync_control SET aplicando = 1, origen = NULL, registro = NULL WHERE id = 1;',
        );
        final List<String> tables = _dataTables;
        for (final String table in tables.reversed) {
          await _db.customStatement('DELETE FROM main."$table";');
        }

        for (final String table in tables) {
          final List<String> columns = await _sharedColumns(table);
          if (columns.isEmpty) continue;
          final String columnList = columns.map((String c) => '"$c"').join(', ');
          await _db.customStatement(
            'INSERT INTO main."$table" ($columnList) '
            'SELECT $columnList FROM $_attachedAlias."$table";',
          );
        }

        if (await _attachedTableExists('ui_preferences')) {
          await _db.customStatement('DELETE FROM main.ui_preferences;');
          await _db.customStatement(
            'INSERT INTO main.ui_preferences (pref_key, pref_value) '
            'SELECT pref_key, pref_value FROM $_attachedAlias.ui_preferences;',
          );
        }

        await _db.customStatement("INSERT INTO food_items_fts(food_items_fts) VALUES('rebuild');");
        await _restaurarIdentidades();
        if ((await _db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
          throw const FormatException('RESTORE_REFERENCES_INVALID');
        }
        await _db.customStatement('COMMIT');
      } catch (_) {
        await _db.customStatement('ROLLBACK');
        rethrow;
      }

      _db.markTablesUpdated(_db.allTables);
      return true;
    } finally {
      try {
        if (adjunta) await _db.customStatement('DETACH DATABASE $_attachedAlias;');
      } finally {
        await _db.customStatement('PRAGMA foreign_keys = ON;');
      }
    }
  }

  /// Identidades y diario de la copia; época nueva para que el escritorio no reutilice
  /// cursores anteriores. La autoridad del enlace vive en el almacén seguro y no cambia.
  Future<void> _restaurarIdentidades() async {
    for (final sentencia in <String>[
      'DELETE FROM sc_sync_conflictos',
      'DELETE FROM sc_sync_recibos',
      'DELETE FROM sc_sync_diario',
      'DELETE FROM sc_sync_revisiones',
      'DELETE FROM sc_sync_identidades',
      'INSERT INTO sc_sync_identidades (tabla, clave, registro, compartida, eliminado) '
          'SELECT tabla, clave, registro, compartida, eliminado FROM $_attachedAlias.sc_sync_identidades',
      'INSERT INTO sc_sync_revisiones SELECT entidad, registro, revision '
          'FROM $_attachedAlias.sc_sync_revisiones',
      'INSERT INTO sc_sync_diario (seq, registro, origen) '
          'SELECT seq, registro, NULL FROM $_attachedAlias.sc_sync_diario ORDER BY seq',
      'UPDATE sc_sync_control SET aplicando = 0, origen = NULL, registro = NULL WHERE id = 1',
      'UPDATE sc_sync_contexto SET epoca = lower(hex(randomblob(16))) WHERE id = 1',
      'UPDATE sc_sync_pares SET cursor = 0, epoca = NULL',
    ]) {
      await _db.customStatement('$sentencia;');
    }
  }

  Future<bool> _attachedTableExists(String table) async {
    final QueryRow row = await _db
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM $_attachedAlias.sqlite_master '
          "WHERE type = 'table' AND name = ?",
          variables: <Variable<Object>>[Variable.withString(table)],
        )
        .getSingle();
    return row.read<int>('cnt') > 0;
  }

  /// Columnas presentes tanto en la tabla local como en la del respaldo.
  Future<List<String>> _sharedColumns(String table) async {
    Future<List<String>> columnsOf(String schema) async {
      final List<QueryRow> rows = await _db
          .customSelect(
            'SELECT name FROM pragma_table_info(?, ?)',
            variables: <Variable<Object>>[Variable.withString(table), Variable.withString(schema)],
          )
          .get();
      return rows.map((QueryRow r) => r.read<String>('name')).toList();
    }

    final Set<String> backupColumns = (await columnsOf(_attachedAlias)).toSet();
    return (await columnsOf('main')).where(backupColumns.contains).toList();
  }

  /// Abre el selector de archivos del sistema y restaura un respaldo `.sqlite` seleccionado por el usuario.
  Future<({bool cancelled, bool restored})> importDatabaseFromPicker({
    required String dialogTitle,
  }) async {
    final PlatformFile? picked = await FilePicker.pickFile(
      dialogTitle: dialogTitle,
      type: FileType.any,
    );

    final String? path = picked?.path;
    if (path == null || path.isEmpty) {
      return (cancelled: true, restored: false);
    }

    final bool restored = await restoreDatabaseFromFile(path);
    return (cancelled: false, restored: restored);
  }
}

/// Provider de Riverpod para inyectar BackupService.
final backupServiceProvider = Provider<BackupService>((Ref ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return BackupService(db, clock: ref.watch(clockProvider));
});

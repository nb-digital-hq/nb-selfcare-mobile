import 'dart:io';

import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

/// Se ejecuta en el isolate nativo antes de que Drift inicie una migración.
/// Un fallo de copia impide abrir para migrar; nunca sustituye un respaldo previo.
File? respaldarAntesDeMigrar(CommonDatabase base, {required int versionDestino}) {
  try {
    return _respaldar(base, versionDestino: versionDestino);
  } catch (_) {
    throw StateError('MIGRATION_BACKUP_FAILED');
  }
}

File? _respaldar(CommonDatabase base, {required int versionDestino}) {
  final version = base.select('PRAGMA user_version').single.values.single as int;
  if (version <= 0 || version >= versionDestino) return null;
  final principal = base
      .select('PRAGMA database_list')
      .where((fila) => fila['name'] == 'main')
      .single;
  final ruta = principal['file'] as String;
  if (ruta.isEmpty) return null;

  final carpeta = File(ruta).parent.createTempSync('.nb-selfcare-migracion-v$version-');
  final respaldo = File('${carpeta.path}/respaldo.sqlite');
  try {
    // VACUUM incorpora el WAL confirmado sin copiar archivos mientras cambian.
    base.execute('VACUUM INTO ?', [respaldo.path]);
    final copia = sqlite3.open(respaldo.path, mode: OpenMode.readOnly);
    try {
      final integridad = copia.select('PRAGMA integrity_check');
      final versionCopiada = copia.select('PRAGMA user_version').single.values.single;
      if (integridad.length != 1 ||
          integridad.single.values.single != 'ok' ||
          versionCopiada != version) {
        throw StateError('MIGRATION_BACKUP_INVALID');
      }
    } finally {
      copia.close();
    }
    return respaldo;
  } catch (_) {
    try {
      carpeta.deleteSync(recursive: true);
    } catch (_) {
      // La copia parcial sigue dentro del directorio privado; no se usa para migrar.
    }
    throw StateError('MIGRATION_BACKUP_FAILED');
  }
}

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show QueryRow, Variable;

import '../../sync/contrato.dart';
import '../../sync/esquema_v9.dart';
import '../app_database.dart';

/// Tipo SQLite de una columna compartida, según `adaptadores-v1.json`.
enum TipoDeColumna { texto, real, entero, booleano }

class ColumnaCompartida {
  const ColumnaCompartida(this.nombre, this.tipo, this.nulo);
  final String nombre;
  final TipoDeColumna tipo;
  final bool nulo;
}

class AlternativaNatural {
  const AlternativaNatural(this.columnas, this.excepto);
  final List<String> columnas;
  final Map<String, Object?> excepto;
}

/// Adaptador declarativo de una tabla. Los nombres que llegan a SQL salen de aquí,
/// nunca del escritorio.
class TablaCompartida {
  const TablaCompartida({
    required this.tabla,
    required this.entidad,
    required this.clave,
    required this.columnas,
    required this.referencias,
    required this.natural,
  });
  final String tabla;
  final EntidadSincronizada entidad;
  final String clave;
  final List<ColumnaCompartida> columnas;
  final Map<String, String> referencias;
  final List<AlternativaNatural> natural;
}

final List<TablaCompartida> tablasCompartidas = _cargar();

List<TablaCompartida> _cargar() {
  final json = jsonDecode(adaptadoresSincronizacionV1) as Map<String, Object?>;
  if (json['version'] != 1) throw StateError('SYNC_SPEC');
  return [
    for (final t in (json['tablas']! as List).cast<Map<String, Object?>>())
      TablaCompartida(
        tabla: t['tabla']! as String,
        entidad: EntidadSincronizada.values.firstWhere((e) => e.codigo == t['entidad']),
        clave: t['clave']! as String,
        columnas: [
          for (final c in (t['columnas']! as List).cast<Map<String, Object?>>())
            ColumnaCompartida(
              c['nombre']! as String,
              TipoDeColumna.values.byName(c['tipo']! as String),
              c['nulo']! as bool,
            ),
        ],
        referencias: (t['referencias']! as Map).cast<String, String>(),
        natural: [
          for (final a in (t['natural']! as List).cast<Map<String, Object?>>())
            AlternativaNatural(
              (a['columnas']! as List).cast<String>(),
              (a['excepto']! as Map).cast<String, Object?>(),
            ),
        ],
      ),
  ];
}

TablaCompartida? tablaDeEntidad(EntidadSincronizada e) {
  for (final t in tablasCompartidas) {
    if (t.entidad == e) return t;
  }
  return null;
}

TablaCompartida? tablaLlamada(String nombre) {
  for (final t in tablasCompartidas) {
    if (t.tabla == nombre) return t;
  }
  return null;
}

class FalloDeSincronizacion implements Exception {
  const FalloDeSincronizacion(this.codigo);
  final String codigo;
  @override
  String toString() => 'FalloDeSincronizacion($codigo)';
}

/// Resultado del escritorio para un cambio enviado.
class ResultadoDelPc {
  const ResultadoDelPc(this.id, this.estado, this.revision);
  final String id;
  final String estado;
  final int revision;
}

String identificadorAleatorio([Random? azar]) {
  final r = azar ?? Random.secure();
  return List<String>.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Motor del teléfono: prepara sus cambios pendientes y aplica los del escritorio,
/// que es quien reconcilia. Todo ocurre en transacciones `BEGIN IMMEDIATE`.
class MotorDeSincronizacion {
  MotorDeSincronizacion(this._db);
  final AppDatabase _db;

  Future<T> _escritura<T>(Future<T> Function() accion) async {
    final resultado = await _db.exclusively(() async {
      await _db.customStatement('BEGIN IMMEDIATE');
      try {
        final r = await accion();
        await _db.customStatement('COMMIT');
        return r;
      } catch (_) {
        await _db.customStatement('ROLLBACK');
        rethrow;
      }
    });
    return resultado;
  }

  Future<List<QueryRow>> _filas(String sql, [List<Object?> args = const []]) =>
      _db.customSelect(sql, variables: [for (final a in args) _variable(a)]).get();

  Variable<Object> _variable(Object? v) => switch (v) {
    null => const Variable<Object>(null),
    final int n => Variable<int>(n),
    final double x => Variable<double>(x),
    final bool b => Variable<int>(b ? 1 : 0),
    final String s => Variable<String>(s),
    _ => throw const FalloDeSincronizacion('INVALID_INPUT'),
  };

  Future<void> _ejecutar(String sql, [List<Object?> args = const []]) =>
      _db.customStatement(sql, [for (final a in args) a is bool ? (a ? 1 : 0) : a]);

  Future<String?> _identidad(String tabla, String clave) async {
    final f = await _filas(
      'SELECT registro FROM sc_sync_identidades WHERE tabla = ? AND clave = ?',
      [tabla, clave],
    );
    return f.isEmpty ? null : f.single.read<String>('registro');
  }

  /// Instantánea compartida de una fila, con las referencias como identidades estables.
  Future<Map<String, Object?>?> leer(TablaCompartida t, String clave) async {
    final lista = t.columnas.map((c) => '"${c.nombre}"').join(', ');
    final f = await _filas('SELECT $lista FROM "${t.tabla}" WHERE CAST("${t.clave}" AS TEXT) = ?', [
      clave,
    ]);
    if (f.isEmpty) return null;
    final fila = f.single.data;
    final datos = <String, Object?>{};
    for (final c in t.columnas) {
      final v = fila[c.nombre];
      Object? valor;
      if (v == null) {
        valor = null;
      } else if (t.referencias.containsKey(c.nombre)) {
        valor = await _identidad(t.referencias[c.nombre]!, '$v');
        if (valor == null) throw const FalloDeSincronizacion('STORAGE_FAILURE');
      } else {
        valor = switch (c.tipo) {
          TipoDeColumna.booleano => v is int ? v != 0 : v,
          TipoDeColumna.entero => v is double && v == v.truncateToDouble() ? v.toInt() : v,
          TipoDeColumna.real => v is int ? v.toDouble() : v,
          TipoDeColumna.texto => v is String ? v : '$v',
        };
      }
      datos[c.nombre] = valor;
    }
    return datos;
  }

  Future<List<Object?>> _traducir(TablaCompartida t, Map<String, Object?> datos) async {
    if (datos.length != t.columnas.length) throw const FalloDeSincronizacion('INVALID_INPUT');
    final salida = <Object?>[];
    for (final c in t.columnas) {
      if (!datos.containsKey(c.nombre)) throw const FalloDeSincronizacion('INVALID_INPUT');
      final v = datos[c.nombre];
      if (v == null) {
        if (!c.nulo) throw const FalloDeSincronizacion('INVALID_INPUT');
        salida.add(null);
      } else if (t.referencias.containsKey(c.nombre)) {
        if (v is! String || !RegExp(r'^[0-9a-f]{32}$').hasMatch(v)) {
          throw const FalloDeSincronizacion('INVALID_INPUT');
        }
        final destino = tablaLlamada(t.referencias[c.nombre]!)!;
        final local = await _local(destino, v);
        if (local == null || local.eliminado) throw const FalloDeSincronizacion('INVALID_INPUT');
        salida.add(int.parse(local.clave));
      } else {
        salida.add(switch ((c.tipo, v)) {
          (TipoDeColumna.booleano, final bool b) => b ? 1 : 0,
          (TipoDeColumna.entero, final num n)
              when n == n.truncate() && n.abs() <= maxRevisionCompartida =>
            n.toInt(),
          (TipoDeColumna.real, final num n) when n.isFinite => n.toDouble(),
          (TipoDeColumna.texto, final String s) => s,
          _ => throw const FalloDeSincronizacion('INVALID_INPUT'),
        });
      }
    }
    return salida;
  }

  Future<({String clave, bool eliminado})?> _local(TablaCompartida t, String registro) async {
    final f = await _filas(
      'SELECT tabla, clave, eliminado FROM sc_sync_identidades WHERE registro = ?',
      [registro],
    );
    if (f.isEmpty) return null;
    if (f.single.read<String>('tabla') != t.tabla) {
      throw const FalloDeSincronizacion('INVALID_INPUT');
    }
    final clave = f.single.read<String>('clave');
    final existe = await _filas('SELECT 1 FROM "${t.tabla}" WHERE CAST("${t.clave}" AS TEXT) = ?', [
      clave,
    ]);
    return (clave: clave, eliminado: f.single.read<int>('eliminado') == 1 || existe.isEmpty);
  }

  Future<String?> _equivalente(TablaCompartida t, List<Object?> valores) async {
    for (final a in t.natural) {
      final condiciones = <String>[];
      final args = <Object?>[t.tabla];
      var valida = true;
      for (final col in a.columnas) {
        final i = t.columnas.indexWhere((c) => c.nombre == col);
        if (i < 0) {
          valida = false;
          break;
        }
        args.add(valores[i]);
        condiciones.add('f."$col" IS ?');
      }
      a.excepto.forEach((col, excluido) {
        final i = t.columnas.indexWhere((c) => c.nombre == col);
        if (i >= 0 && valores[i] == excluido) valida = false;
      });
      if (!valida || (args.length > 1 && args.skip(1).every((v) => v == null))) continue;
      final donde = condiciones.isEmpty ? '' : ' AND ${condiciones.join(' AND ')}';
      final f = await _filas(
        'SELECT i.clave FROM "${t.tabla}" f JOIN sc_sync_identidades i '
        'ON i.tabla = ? AND i.clave = CAST(f."${t.clave}" AS TEXT) '
        'WHERE i.compartida = 0 AND i.eliminado = 0$donde LIMIT 1',
        args,
      );
      if (f.isNotEmpty) return f.first.read<String>('clave');
    }
    return null;
  }

  Future<void> _control(String? origen, String? registro) => _ejecutar(
    'UPDATE sc_sync_control SET aplicando = ?, origen = ?, registro = ? WHERE id = 1',
    [origen == null ? 0 : 1, origen, registro],
  );

  /// Escribe la versión del escritorio tal como llega: sin recompensas ni consumos nuevos.
  Future<void> _escribir(String origen, CambioSincronizado cambio, int revision) async {
    final t = tablaDeEntidad(cambio.entidad);
    if (t == null) throw const FalloDeSincronizacion('INVALID_INPUT');
    final registro = cambio.registro;
    var local = await _local(t, registro);
    if (local == null && cambio.operacion == OperacionSincronizada.guardar) {
      final valores = await _traducir(t, cambio.datos!);
      final clave = await _equivalente(t, valores);
      if (clave != null) {
        // Una fila equivalente que nunca se compartió adopta la identidad del escritorio.
        await _ejecutar(
          'UPDATE sc_sync_identidades SET registro = ? WHERE tabla = ? AND clave = ?',
          [registro, t.tabla, clave],
        );
        local = await _local(t, registro);
      }
    }
    await _control(origen, registro);
    try {
      if (cambio.operacion == OperacionSincronizada.eliminar) {
        if (local != null && !local.eliminado) {
          final antes = await leer(t, local.clave);
          await _ejecutar('DELETE FROM "${t.tabla}" WHERE CAST("${t.clave}" AS TEXT) = ?', [
            local.clave,
          ]);
          await _proyectar(t, antes, null);
        }
      } else {
        final datos = cambio.datos!;
        final valores = await _traducir(t, datos);
        if (local != null && !local.eliminado) {
          final antes = await leer(t, local.clave);
          final asignaciones = t.columnas.map((c) => '"${c.nombre}" = ?').join(', ');
          await _ejecutar(
            'UPDATE "${t.tabla}" SET $asignaciones WHERE CAST("${t.clave}" AS TEXT) = ?',
            [...valores, local.clave],
          );
          await _proyectar(t, antes, datos);
        } else {
          await _ejecutar('DELETE FROM sc_sync_diario WHERE registro = ?', [registro]);
          await _ejecutar('DELETE FROM sc_sync_identidades WHERE registro = ?', [registro]);
          final lista = t.columnas.map((c) => '"${c.nombre}"').join(', ');
          final marcas = List.filled(valores.length, '?').join(', ');
          await _ejecutar('INSERT INTO "${t.tabla}" ($lista) VALUES ($marcas)', valores);
          await _proyectar(t, null, datos);
        }
      }
      await _ejecutar(
        'UPDATE sc_sync_identidades SET compartida = ?, en_conflicto = 0 WHERE registro = ?',
        [revision, registro],
      );
      await _ejecutar(
        'INSERT INTO sc_sync_revisiones (entidad, registro, revision) VALUES (?, ?, ?) '
        'ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision',
        [cambio.entidad.codigo, registro, revision],
      );
    } finally {
      await _control(null, null);
    }
  }

  Future<void> _proyectar(
    TablaCompartida t,
    Map<String, Object?>? antes,
    Map<String, Object?>? despues,
  ) async {
    if (t.tabla == 'hydration_logs') {
      for (final dia in {antes?['date_key'], despues?['date_key']}.whereType<String>()) {
        await _ejecutar(
          'UPDATE daily_summaries SET water_consumed_ml = '
          '(SELECT coalesce(sum(volume_ml), 0) FROM hydration_logs WHERE date_key = ?) '
          'WHERE date_key = ?',
          [dia, dia],
        );
      }
    } else if (t.tabla == 'coin_ledger') {
      int cantidad(Map<String, Object?>? d) => (d?['amount'] as num?)?.toInt() ?? 0;
      final delta = cantidad(despues) - cantidad(antes);
      if (delta != 0) {
        await _ejecutar('UPDATE pet_status SET coins_balance = max(0, coins_balance + ?)', [delta]);
      }
    }
  }

  /// Cambios locales sin confirmar, con sus dependencias desconocidas para el escritorio.
  Future<List<CambioSincronizado>> pendientes({int limite = maxCambiosPorLote}) async {
    final filas = await _filas(
      'SELECT d.registro FROM sc_sync_diario d '
      'JOIN sc_sync_identidades i USING (registro) '
      'JOIN sc_sync_revisiones r USING (registro) '
      'WHERE d.origen IS NULL AND i.en_conflicto = 0 AND r.revision > i.compartida '
      'ORDER BY d.seq LIMIT ?',
      [limite],
    );
    final cambios = <CambioSincronizado>[];
    final emitidos = <String>{};
    for (final f in filas) {
      if (cambios.length >= limite) break;
      await _emitir(f.read<String>('registro'), cambios, emitidos, limite, 0);
    }
    return cambios;
  }

  Future<void> _emitir(
    String registro,
    List<CambioSincronizado> cambios,
    Set<String> emitidos,
    int limite,
    int profundidad,
  ) async {
    if (profundidad > 4 || cambios.length >= limite || !emitidos.add(registro)) return;
    final i = await _filas(
      'SELECT tabla, clave, eliminado, compartida FROM sc_sync_identidades WHERE registro = ?',
      [registro],
    );
    if (i.isEmpty) return;
    final t = tablaLlamada(i.single.read<String>('tabla'));
    if (t == null) return;
    final eliminado = i.single.read<int>('eliminado') == 1;
    final datos = eliminado ? null : await leer(t, i.single.read<String>('clave'));
    if (datos != null) {
      for (final col in t.referencias.keys) {
        final r = datos[col];
        if (r is String) {
          final dep = await _filas(
            'SELECT compartida FROM sc_sync_identidades WHERE registro = ?',
            [r],
          );
          if (dep.isNotEmpty && dep.single.read<int>('compartida') == 0) {
            await _emitir(r, cambios, emitidos, limite, profundidad + 1);
          }
        }
      }
    }
    cambios.add(
      CambioSincronizado.desdeJson({
        'id': identificadorAleatorio(),
        'registro': registro,
        'entidad': t.entidad.codigo,
        'base': i.single.read<int>('compartida'),
        'operacion': datos == null ? 'eliminar' : 'guardar',
        'datos': datos,
      }),
    );
  }

  /// Aplica las respuestas del escritorio a los cambios enviados.
  Future<void> confirmar(List<CambioSincronizado> enviados, List<ResultadoDelPc> resultados) async {
    final porId = {for (final c in enviados) c.id: c};
    await _escritura(() async {
      for (final r in resultados) {
        final c = porId[r.id];
        if (c == null) continue;
        if (r.estado == 'aplicado') {
          // Si hubo otra edición local mientras viajaba, sigue pendiente sobre la base nueva.
          final igual = await _sinCambiosDesde(c);
          await _ejecutar('UPDATE sc_sync_identidades SET compartida = ? WHERE registro = ?', [
            r.revision,
            c.registro,
          ]);
          await _ejecutar(
            'INSERT INTO sc_sync_revisiones (entidad, registro, revision) VALUES (?, ?, ?) '
            'ON CONFLICT (entidad, registro) DO UPDATE SET revision = excluded.revision',
            [c.entidad.codigo, c.registro, igual ? r.revision : r.revision + 1],
          );
        } else {
          // Conflicto o rechazo: queda a la espera de la decisión en el escritorio o de otra edición.
          await _ejecutar('UPDATE sc_sync_identidades SET en_conflicto = 1 WHERE registro = ?', [
            c.registro,
          ]);
        }
      }
    });
  }

  Future<bool> _sinCambiosDesde(CambioSincronizado c) async {
    final i = await _filas(
      'SELECT tabla, clave, eliminado FROM sc_sync_identidades WHERE registro = ?',
      [c.registro],
    );
    if (i.isEmpty) return true;
    final t = tablaLlamada(i.single.read<String>('tabla'))!;
    final ahora = i.single.read<int>('eliminado') == 1
        ? null
        : await leer(t, i.single.read<String>('clave'));
    return jsonEncode(ahora) == jsonEncode(c.datos);
  }

  /// Aplica los cambios del escritorio. Una edición local aún no enviada se conserva:
  /// el escritorio decidirá cuando llegue. Devuelve cuántos registros cambiaron.
  Future<int> aplicar(String pc, List<CambioSincronizado> cambios) async {
    var aplicados = 0;
    await _escritura(() async {
      for (final c in cambios) {
        final estado = await _filas(
          'SELECT i.compartida, i.en_conflicto, coalesce(r.revision, 0) AS revision '
          'FROM sc_sync_identidades i LEFT JOIN sc_sync_revisiones r USING (registro) '
          'WHERE i.registro = ?',
          [c.registro],
        );
        if (estado.isNotEmpty) {
          final compartida = estado.single.read<int>('compartida');
          final pendiente = estado.single.read<int>('revision') > compartida;
          final enConflicto = estado.single.read<int>('en_conflicto') == 1;
          if (c.base < compartida) continue;
          if (pendiente && !enConflicto) continue;
          // En conflicto, solo una decisión del escritorio (revisión posterior) sustituye lo local.
          if (pendiente && enConflicto && c.base <= compartida) continue;
        }
        try {
          await _escribir(pc, c, c.base + 1);
          aplicados++;
        } on FalloDeSincronizacion {
          // Un registro inválido o con referencias ausentes no detiene el resto del lote.
        }
      }
    });
    if (aplicados > 0) _db.markTablesUpdated(_db.allTables);
    return aplicados;
  }

  /// Cursor y época del escritorio conocidos por este teléfono.
  Future<({String? epoca, int cursor})> cursor(String pc) async {
    final f = await _filas('SELECT epoca, cursor FROM sc_sync_pares WHERE nodo = ?', [pc]);
    if (f.isEmpty) return (epoca: null, cursor: 0);
    return (epoca: f.single.readNullable<String>('epoca'), cursor: f.single.read<int>('cursor'));
  }

  Future<void> guardarCursor(String pc, String epoca, int cursor, String instante) => _escritura(
    () => _ejecutar(
      'INSERT INTO sc_sync_pares (nodo, epoca, cursor, ultima) VALUES (?, ?, ?, ?) '
      'ON CONFLICT (nodo) DO UPDATE SET epoca = excluded.epoca, cursor = excluded.cursor, '
      'ultima = excluded.ultima',
      [pc, epoca, cursor, instante],
    ),
  );

  /// Resumen para la pantalla de conexión.
  Future<({int pendientes, int enRevision, String? ultima})> resumen() async {
    final f = await _filas(
      'SELECT '
      '(SELECT count(*) FROM sc_sync_diario d JOIN sc_sync_identidades i USING (registro) '
      ' JOIN sc_sync_revisiones r USING (registro) '
      ' WHERE d.origen IS NULL AND i.en_conflicto = 0 AND r.revision > i.compartida) AS pendientes, '
      '(SELECT count(*) FROM sc_sync_identidades WHERE en_conflicto = 1) AS en_revision, '
      '(SELECT max(ultima) FROM sc_sync_pares) AS ultima',
    );
    final r = f.single;
    return (
      pendientes: r.read<int>('pendientes'),
      enRevision: r.read<int>('en_revision'),
      ultima: r.readNullable<String>('ultima'),
    );
  }
}

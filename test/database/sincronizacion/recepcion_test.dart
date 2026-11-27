import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/sincronizacion/recepcion.dart';
import 'package:nb_selfcare/core/sync/contrato.dart';
import 'package:sqlite3/common.dart' show AllowedArgumentCount;

String id(String caracter) => caracter * 32;
CambioSincronizado cambio(String operacion, int base, int volumen) => CambioSincronizado.desdeJson({
  'id': id(operacion),
  'registro': id('a'),
  'entidad': 'agua',
  'base': base,
  'operacion': 'guardar',
  'datos': <String, Object?>{'volumen': volumen},
});
Future<void> preparar(AppDatabase db) async {
  // El esquema 9 ya instala estas tablas; la receta las vuelve a crear vacías y aisladas.
  for (final t in [
    'sc_sync_conflictos',
    'sc_sync_recibos',
    'sc_sync_revisiones',
    'sc_sync_contexto',
  ]) {
    await db.customStatement('DROP TABLE IF EXISTS $t');
  }
  final sql = File('test/fixtures/sincronizacion/recepcion-v1.sql').readAsStringSync();
  // La receta solo contiene sentencias DDL simples, sin cuerpos de triggers.
  final sentencias = sql
      .split('\n')
      .where((linea) => !linea.trimLeft().startsWith('--'))
      .join('\n');
  for (final sentencia in sentencias.split(';')) {
    if (sentencia.trim().isNotEmpty) await db.customStatement(sentencia);
  }
  await db.customStatement('INSERT INTO sc_sync_contexto VALUES(1,?)', [id('e')]);
  await db.customStatement('CREATE TABLE agua(id TEXT PRIMARY KEY, volumen INTEGER NOT NULL)');
  await db.customStatement('CREATE TABLE efectos(cantidad INTEGER NOT NULL)');
  await db.customStatement('INSERT INTO efectos VALUES(0)');
}

Future<int> entero(AppDatabase db, String sql) async =>
    (await db.customSelect(sql).getSingle()).read<int>('valor');

class Agua implements PropietarioDeRegistro {
  const Agua({this.fallarDespues = false});
  final bool fallarDespues;
  @override
  Future<Map<String, Object?>?> comprobar(AppDatabase db, CambioSincronizado cambio) async {
    if (cambio.entidad != EntidadSincronizada.agua) throw const FormatoDeSincronizacion();
    if (cambio.operacion == OperacionSincronizada.guardar) {
      final volumen = cambio.datos?['volumen'];
      if (volumen is! int || volumen < 1 || volumen > 10000) throw const FormatoDeSincronizacion();
    }
    final filas = await db
        .customSelect(
          'SELECT volumen FROM agua WHERE id=?',
          variables: [Variable<String>(cambio.registro)],
        )
        .get();
    return filas.isEmpty ? null : <String, Object?>{'volumen': filas.single.read<int>('volumen')};
  }

  @override
  Future<void> aplicar(AppDatabase db, CambioSincronizado cambio) async {
    if (cambio.operacion == OperacionSincronizada.guardar) {
      await db.customStatement(
        'INSERT INTO agua VALUES(?,?) ON CONFLICT(id) DO UPDATE SET volumen=excluded.volumen',
        [cambio.registro, cambio.datos!['volumen']],
      );
    } else {
      await db.customStatement('DELETE FROM agua WHERE id=?', [cambio.registro]);
    }
    await db.customStatement('UPDATE efectos SET cantidad=cantidad+1');
    if (fallarDespues) throw StateError('fallo sintético');
  }
}

class AguaConInstantanea extends Agua {
  AguaConInstantanea(this.instantanea);
  final Map<String, Object?> instantanea;
  @override
  Future<Map<String, Object?>?> comprobar(AppDatabase db, CambioSincronizado cambio) async {
    await super.comprobar(db, cambio);
    return instantanea;
  }
}

void main() {
  test(
    'el conflicto conserva la instantánea validada aunque el propietario modifique su mapa',
    () async {
      final instantanea = <String, Object?>{'volumen': 250};
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (sqlite) {
            sqlite.createFunction(
              functionName: 'mutar_instantanea',
              argumentCount: const AllowedArgumentCount(0),
              directOnly: false,
              function: (_) {
                instantanea['volumen'] = 999;
                return 1;
              },
            );
          },
        ),
      );
      try {
        await preparar(db);
        final buzon = BuzonDeRecepcion(db);
        await buzon.recibir(
          epoca: id('e'),
          nodo: id('1'),
          cambio: cambio('2', 0, 250),
          propietario: const Agua(),
        );
        await db.customStatement(
          "CREATE TRIGGER mutar BEFORE INSERT ON sc_sync_recibos WHEN NEW.resultado='conflicto' BEGIN SELECT mutar_instantanea(); END;",
        );
        await buzon.recibir(
          epoca: id('e'),
          nodo: id('1'),
          cambio: cambio('3', 0, 500),
          propietario: AguaConInstantanea(instantanea),
        );
        expect(instantanea['volumen'], 999);
        final fila = await db.customSelect('SELECT actual FROM sc_sync_conflictos').getSingle();
        expect((jsonDecode(fila.read<String>('actual')) as Map)['volumen'], 250);
      } finally {
        await db.close();
      }
    },
  );
  test('el recibo sobrevive al cierre del archivo y no depende de memoria', () async {
    final carpeta = await Directory.systemTemp.createTemp('nb-selfcare-recepcion-');
    final archivo = File('${carpeta.path}/prueba.sqlite');
    try {
      final primera = AppDatabase(NativeDatabase(archivo));
      try {
        await preparar(primera);
        await BuzonDeRecepcion(primera).recibir(
          epoca: id('e'),
          nodo: id('1'),
          cambio: cambio('2', 0, 250),
          propietario: const Agua(),
        );
      } finally {
        await primera.close();
      }
      final segunda = AppDatabase(NativeDatabase(archivo));
      try {
        final recibo = await BuzonDeRecepcion(segunda).recibir(
          epoca: id('e'),
          nodo: id('1'),
          cambio: cambio('2', 0, 250),
          propietario: const Agua(fallarDespues: true),
        );
        expect(recibo.estado, EstadoRecepcion.aplicado);
        expect(await entero(segunda, 'SELECT cantidad AS valor FROM efectos'), 1);
      } finally {
        await segunda.close();
      }
    } finally {
      await carpeta.delete(recursive: true);
    }
  });
  test('una base sin infraestructura no la recibe en silencio', () async {
    final aislada = AppDatabase(NativeDatabase.memory());
    try {
      await aislada.customStatement('DROP TABLE sc_sync_conflictos');
      await aislada.customStatement('DROP TABLE sc_sync_recibos');
      await aislada.customStatement('DROP TABLE sc_sync_contexto');
      await expectLater(
        BuzonDeRecepcion(aislada).recibir(
          epoca: id('e'),
          nodo: id('1'),
          cambio: cambio('2', 0, 250),
          propietario: const Agua(),
        ),
        throwsA(isA<FalloDeRecepcion>()),
      );
      expect(
        await entero(
          aislada,
          "SELECT count(*) AS valor FROM sqlite_master WHERE name IN ('sc_sync_contexto', 'sc_sync_recibos')",
        ),
        0,
      );
    } finally {
      await aislada.close();
    }
  });
  group('Recepción con infraestructura preparada', () {
    late AppDatabase db;
    late BuzonDeRecepcion buzon;
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await preparar(db);
      buzon = BuzonDeRecepcion(db);
    });
    tearDown(() => db.close());
    Future<ReciboDeRecepcion> recibir(
      CambioSincronizado dato, {
      String? epoca,
      Agua propietario = const Agua(),
    }) => buzon.recibir(
      epoca: epoca ?? id('e'),
      nodo: id('1'),
      cambio: dato,
      propietario: propietario,
    );

    test('un recibo repetido no vuelve a ejecutar los efectos', () async {
      for (var i = 0; i < 2; i++) {
        final resultado = await recibir(cambio('2', 0, 250));
        expect(resultado.estado, EstadoRecepcion.aplicado);
        expect(resultado.revision, 1);
      }
      expect(await entero(db, 'SELECT cantidad AS valor FROM efectos'), 1);
      expect(await entero(db, 'SELECT count(*) AS valor FROM sc_sync_recibos'), 1);
    });

    test('reutilizar identidad con otro contenido no sustituye el dato confirmado', () async {
      await recibir(cambio('2', 0, 250));
      expect((await recibir(cambio('2', 0, 500))).estado, EstadoRecepcion.operacionAlterada);
      expect(await entero(db, 'SELECT volumen AS valor FROM agua'), 250);
    });
    test('un conflicto conserva las dos propuestas y su recibo', () async {
      await recibir(cambio('2', 0, 250));
      for (var i = 0; i < 2; i++) {
        final resultado = await recibir(cambio('3', 0, 500));
        expect(resultado.estado, EstadoRecepcion.conflicto);
        expect(resultado.revision, 1);
      }
      final fila = await db
          .customSelect('SELECT actual,propuesta FROM sc_sync_conflictos')
          .getSingle();
      expect((jsonDecode(fila.read<String>('actual')) as Map)['volumen'], 250);
      expect(((jsonDecode(fila.read<String>('propuesta')) as Map)['datos'] as Map)['volumen'], 500);
      expect(await entero(db, 'SELECT cantidad AS valor FROM efectos'), 1);
      await db.customStatement('DELETE FROM sc_sync_conflictos');
      await expectLater(recibir(cambio('3', 0, 500)), throwsA(isA<FalloDeRecepcion>()));
    });
    test('fallar después del dato o al insertar el recibo revierte todo', () async {
      await expectLater(
        recibir(cambio('2', 0, 250), propietario: const Agua(fallarDespues: true)),
        throwsA(isA<FalloDeRecepcion>()),
      );
      await db.customStatement(
        "CREATE TRIGGER rechazar BEFORE INSERT ON sc_sync_recibos BEGIN SELECT RAISE(ABORT,'fallo sintetico'); END;",
      );
      await expectLater(recibir(cambio('2', 0, 250)), throwsA(isA<FalloDeRecepcion>()));
      for (final tabla in ['agua', 'sc_sync_revisiones', 'sc_sync_recibos']) {
        expect(await entero(db, 'SELECT count(*) AS valor FROM $tabla'), 0);
      }
      expect(await entero(db, 'SELECT cantidad AS valor FROM efectos'), 0);
      await db.customStatement('BEGIN IMMEDIATE');
      await db.customStatement('ROLLBACK');
    });
    test('una propuesta inválida no se conserva ni siquiera como conflicto', () async {
      await expectLater(recibir(cambio('2', 3, 0)), throwsA(isA<FormatoDeSincronizacion>()));
      expect(await entero(db, 'SELECT count(*) AS valor FROM sc_sync_recibos'), 0);
    });
    test('borrar conserva revisión y una época nueva no reintroduce recibos antiguos', () async {
      await recibir(cambio('2', 0, 250));
      final baja = CambioSincronizado.desdeJson({
        ...cambio('3', 1, 0).aJson(),
        'operacion': 'eliminar',
        'datos': null,
      });
      expect((await recibir(baja)).revision, 2);
      expect(await entero(db, 'SELECT count(*) AS valor FROM agua'), 0);
      expect((await recibir(cambio('4', 1, 500))).estado, EstadoRecepcion.conflicto);
      expect(
        await entero(db, 'SELECT count(*) AS valor FROM sc_sync_conflictos WHERE actual IS NULL'),
        1,
      );
      await db.customStatement('UPDATE sc_sync_contexto SET epoca=?', [id('f')]);
      for (final epoca in [id('e'), id('f')]) {
        expect(
          (await recibir(cambio('2', 0, 250), epoca: epoca)).estado,
          EstadoRecepcion.epocaCambiada,
        );
      }
      expect(await entero(db, 'SELECT count(*) AS valor FROM agua'), 0);
    });
    test('el límite de revisión no desborda ni confirma parcialmente', () async {
      await db.customStatement("INSERT INTO sc_sync_revisiones VALUES('agua',?,?)", [
        id('a'),
        maxRevisionCompartida,
      ]);
      expect(
        (await recibir(cambio('2', maxRevisionCompartida, 250))).estado,
        EstadoRecepcion.revisionAgotada,
      );
      expect(await entero(db, 'SELECT cantidad AS valor FROM efectos'), 0);
    });
    test('dos peticiones no confirman la misma revisión base', () async {
      final resultados = await Future.wait([
        recibir(cambio('2', 0, 250)),
        recibir(cambio('3', 0, 500)),
      ]);
      expect(resultados.where((r) => r.estado == EstadoRecepcion.aplicado), hasLength(1));
      expect(resultados.where((r) => r.estado == EstadoRecepcion.conflicto), hasLength(1));
      expect(await entero(db, 'SELECT cantidad AS valor FROM efectos'), 1);
    });

    test('las claves foráneas desactivadas impiden aplicar un cambio', () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await expectLater(recibir(cambio('2', 0, 250)), throwsA(isA<FalloDeRecepcion>()));
      expect(await entero(db, 'SELECT cantidad AS valor FROM efectos'), 0);
    });
  });
}

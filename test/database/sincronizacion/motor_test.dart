import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/sincronizacion/motor.dart';
import 'package:nb_selfcare/core/sync/contrato.dart';

import '../../drift/app_database/generated/schema.dart';

Future<int> entero(AppDatabase db, String sql) async =>
    (await db.customSelect(sql).getSingle()).data.values.single as int;

CambioSincronizado agua(String registro, int base, int ml, {String id = 'c'}) =>
    CambioSincronizado.desdeJson({
      'id': id * 32,
      'registro': registro,
      'entidad': 'agua',
      'base': base,
      'operacion': 'guardar',
      'datos': <String, Object?>{
        'date_key': '2026-11-20',
        'logged_at': '2026-11-20T10:00:00.000',
        'volume_ml': ml,
      },
    });

void main() {
  late AppDatabase db;
  late MotorDeSincronizacion motor;
  final pc = 'e' * 32;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    motor = MotorDeSincronizacion(db);
    await db.customSelect('SELECT 1').get();
  });
  tearDown(() => db.close());

  test('el esquema 9 instala identidades, diario y disparadores', () async {
    expect(db.schemaVersion, 9);
    await db.customStatement(
      "INSERT INTO hydration_logs (date_key, logged_at, volume_ml) VALUES ('2026-11-20', 'x', 250)",
    );
    expect(
      await entero(db, "SELECT count(*) FROM sc_sync_identidades WHERE tabla = 'hydration_logs'"),
      1,
    );
    expect(await entero(db, 'SELECT count(*) FROM sc_sync_diario'), greaterThan(0));
    final pendientes = await motor.pendientes();
    final propio = pendientes.where((c) => c.entidad == EntidadSincronizada.agua).single;
    expect(propio.base, 0);
    expect(propio.datos!['volume_ml'], 250);
    expect(propio.datos!.containsKey('synced_to_health_connect'), isFalse);
  });

  test('confirmar deja el registro compartido y una edición nueva vuelve a estar pendiente', () async {
    await db.customStatement(
      "INSERT INTO hydration_logs (date_key, logged_at, volume_ml) VALUES ('2026-11-20', 'x', 250)",
    );
    final lote = await motor.pendientes();
    final propio = lote.where((c) => c.entidad == EntidadSincronizada.agua).toList();
    await motor.confirmar(propio, [ResultadoDelPc(propio.single.id, 'aplicado', 1)]);
    expect((await motor.pendientes()).where((c) => c.entidad == EntidadSincronizada.agua), isEmpty);
    await db.customStatement('UPDATE hydration_logs SET volume_ml = 300');
    final otra = (await motor.pendientes())
        .where((c) => c.entidad == EntidadSincronizada.agua)
        .single;
    expect(otra.base, 1);
  });

  test('lo recibido del escritorio se aplica una vez, sin eco ni monedas nuevas', () async {
    final registro = 'a' * 32;
    expect(await motor.aplicar(pc, [agua(registro, 0, 500)]), 1);
    expect(await motor.aplicar(pc, [agua(registro, 0, 500)]), 0);
    expect(await entero(db, 'SELECT sum(volume_ml) FROM hydration_logs'), 500);
    // Lo que llegó del escritorio no se le devuelve.
    expect((await motor.pendientes()).where((c) => c.registro == registro), isEmpty);
    await motor.aplicar(pc, [
      CambioSincronizado.desdeJson({
        'id': 'd' * 32,
        'registro': registro,
        'entidad': 'agua',
        'base': 1,
        'operacion': 'eliminar',
      }),
    ]);
    expect(await entero(db, 'SELECT count(*) FROM hydration_logs'), 0);
  });

  test(
    'una edición local sin enviar no se pisa; una decisión posterior del escritorio sí',
    () async {
      final registro = 'a' * 32;
      await motor.aplicar(pc, [agua(registro, 0, 500)]);
      await db.customStatement('UPDATE hydration_logs SET volume_ml = 600');
      await motor.aplicar(pc, [agua(registro, 1, 700, id: 'f')]);
      expect(await entero(db, 'SELECT volume_ml FROM hydration_logs'), 600);
      final enviado = (await motor.pendientes()).where((c) => c.registro == registro).toList();
      await motor.confirmar(enviado, [ResultadoDelPc(enviado.single.id, 'conflicto', 2)]);
      expect((await motor.resumen()).enRevision, 1);
      // La resolución del escritorio llega con una revisión posterior.
      await motor.aplicar(pc, [agua(registro, 3, 650, id: '9')]);
      expect(await entero(db, 'SELECT volume_ml FROM hydration_logs'), 650);
      expect((await motor.resumen()).enRevision, 0);
    },
  );

  test('los datos del escritorio se validan contra el contrato', () async {
    final malo = CambioSincronizado.desdeJson({
      'id': '1' * 32,
      'registro': '2' * 32,
      'entidad': 'agua',
      'base': 0,
      'operacion': 'guardar',
      'datos': <String, Object?>{'date_key': '2026-11-20', 'logged_at': 'x', 'volume_ml': 'DROP'},
    });
    expect(await motor.aplicar(pc, [malo]), 0);
    expect(await entero(db, 'SELECT count(*) FROM hydration_logs'), 0);
  });

  test('migrar del 8 al 9 conserva los datos y da identidad a cada registro previo', () async {
    final carpeta = Directory.systemTemp.createTempSync('nb-sync-v8-');
    try {
      final archivo = File('${carpeta.path}/base.sqlite');
      final v8 = GeneratedHelper().databaseForVersion(NativeDatabase(archivo), 8);
      await v8.customStatement(
        "INSERT INTO hydration_logs (date_key, logged_at, volume_ml) VALUES ('2026-11-01', 'x', 300)",
      );
      await v8.close();
      final actual = AppDatabase(NativeDatabase(archivo));
      try {
        expect(await entero(actual, 'PRAGMA user_version'), 9);
        expect(await entero(actual, 'SELECT sum(volume_ml) FROM hydration_logs'), 300);
        final previo = (await MotorDeSincronizacion(
          actual,
        ).pendientes()).where((c) => c.entidad == EntidadSincronizada.agua).single;
        expect(previo.base, 0);
      } finally {
        await actual.close();
      }
    } finally {
      carpeta.deleteSync(recursive: true);
    }
  });
}

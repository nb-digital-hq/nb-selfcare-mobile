// Recorrido de proceso con el servidor real del escritorio, lanzado por su prueba
// `dos_telefonos_reales_sincronizan_a_traves_del_escritorio`. Datos sintéticos, nunca un teléfono.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/database/seeder/database_seeder.dart';
import 'package:nb_selfcare/core/database/sincronizacion/motor.dart';
import 'package:nb_selfcare/core/network/sincronizacion/credenciales.dart';
import 'package:nb_selfcare/core/network/sincronizacion/sincronizador.dart';

class Almacen implements AlmacenSeguroDeEnlace {
  Almacen(this.valor);
  String? valor;
  @override
  Future<String?> leer() async => valor;
  @override
  Future<void> escribir(String valor) async => this.valor = valor;
}

Future<int> entero(AppDatabase db, String sql) async =>
    (await db.customSelect(sql).getSingle()).data.values.single as int;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final ruta = Platform.environment['NB_SELFCARE_QA_ENLACE'];
  test('dos teléfonos sincronizan a través del escritorio', () async {
    final enlace = jsonDecode(File(ruta!).readAsStringSync()) as Map<String, Object?>;
    final telefonos = (enlace['telefonos']! as List).cast<Map<String, Object?>>();
    Future<(AppDatabase, SincronizadorConPc)> telefono(Map<String, Object?> t) async {
      final db = AppDatabase(NativeDatabase.memory());
      await DatabaseSeeder.seedIfEmpty(db);
      final almacen = Almacen(
        jsonEncode({
          'version': 1,
          'nodo': t['nodo'],
          'pc': {
            'host': enlace['host'],
            'puerto': enlace['puerto'],
            'huella': enlace['huella'],
            'nodo': t['pc'],
            'credencial': t['credencial'],
          },
        }),
      );
      return (
        db,
        SincronizadorConPc(
          motor: MotorDeSincronizacion(db),
          credenciales: CredencialesDelEnlace(almacen),
          autorizado: () => true,
          ahora: DateTime.now,
        ),
      );
    }

    final (a, syncA) = await telefono(telefonos[0]);
    final (b, syncB) = await telefono(telefonos[1]);
    await a.customStatement(
      "INSERT INTO hydration_logs (date_key, logged_at, volume_ml) VALUES ('2026-11-20', '2026-11-20T10:00:00.000', 500)",
    );
    final alimento = await entero(a, 'SELECT min(id) FROM food_items');
    await a.customStatement(
      'INSERT INTO food_logs (date_key, logged_at, meal_type, food_item_id, grams_consumed, total_kcal, '
      'total_protein_g, total_carbs_g, total_fat_g, total_fiber_g, total_sodium_mg, total_potassium_mg, '
      "total_magnesium_mg) VALUES ('2026-11-20', '2026-11-20T13:00:00.000', 'lunch', $alimento, 150, 195, "
      '4, 42, 0.5, 1, 2, 50, 18)',
    );
    final primero = await syncA.sincronizar();
    expect(primero.enviados, greaterThanOrEqualTo(2));
    expect(await entero(a, 'SELECT count(*) FROM body_measurements'), 1);

    await syncB.sincronizar();
    expect(await entero(b, 'SELECT sum(volume_ml) FROM hydration_logs'), 500);
    expect(await entero(b, 'SELECT count(*) FROM food_logs'), 1);
    expect(await entero(b, 'SELECT count(*) FROM body_measurements'), 1);

    await a.customStatement('UPDATE hydration_logs SET volume_ml = 600');
    await syncA.sincronizar();
    await syncB.sincronizar();
    expect(await entero(b, 'SELECT sum(volume_ml) FROM hydration_logs'), 600);
    expect((await MotorDeSincronizacion(a).resumen()).pendientes, 0);
    await a.close();
    await b.close();
  }, skip: ruta == null ? 'lo lanza la prueba de proceso del escritorio' : false);
}

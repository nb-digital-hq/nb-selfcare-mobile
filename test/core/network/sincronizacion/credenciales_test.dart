import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/network/sincronizacion/cliente.dart';
import 'package:nb_selfcare/core/network/sincronizacion/credenciales.dart';

class Memoria implements AlmacenSeguroDeEnlace {
  String? valor;
  bool falla = false;
  int escrituras = 0;
  @override
  Future<String?> leer() async => valor;
  @override
  Future<void> escribir(String valor) async {
    if (falla) throw StateError('detalle interno que no debe salir');
    escrituras++;
    this.valor = valor;
  }
}

void main() {
  String fixture() => jsonEncode({
    'version': 1,
    'nodo': 'a' * 32,
    'pc': {
      'host': '192.168.1.4',
      'puerto': 43127,
      'huella': base64.encode(List<int>.filled(32, 7)),
      'nodo': 'b' * 32,
      'credencial': 'A' * 43,
    },
  });
  test('cargas concurrentes crean una sola identidad persistida', () async {
    final memoria = Memoria();
    final gestor = CredencialesDelEnlace(memoria);
    final estados = await Future.wait(
      List<Future<EstadoDelEnlace>>.generate(10, (_) => gestor.cargar()),
    );
    expect(estados.map((e) => e.nodo).toSet(), hasLength(1));
    expect(estados.first.nodo, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(memoria.escrituras, 1);
    final reiniciado = await CredencialesDelEnlace(memoria).cargar();
    expect(reiniciado.nodo, estados.first.nodo);
    expect(reiniciado.pc, isNull);
  });
  test('desvincular conserva la identidad y no expone los secretos al depurar', () async {
    final memoria = Memoria()..valor = fixture();
    final gestor = CredencialesDelEnlace(memoria);
    final inicial = await gestor.cargar();
    expect(inicial.pc!.toString(), isNot(contains('A' * 43)));
    expect(inicial.toString(), isNot(contains(inicial.nodo)));
    final borrado = await gestor.guardarPc(null);
    expect(borrado.nodo, inicial.nodo);
    expect((await CredencialesDelEnlace(memoria).cargar()).pc, isNull);
  });
  test('un almacén dañado se rechaza sin generar otra identidad', () async {
    final memoria = Memoria()..valor = 'no-json';
    await expectLater(
      CredencialesDelEnlace(memoria).cargar(),
      throwsA(isA<FalloDeEnlace>().having((e) => e.codigo, 'codigo', 'STORAGE_FAILURE')),
    );
    expect(memoria.valor, 'no-json');
    expect(memoria.escrituras, 0);
  });
  test('una escritura rechazada no borra el par ni bloquea las lecturas siguientes', () async {
    final memoria = Memoria()..valor = fixture();
    final gestor = CredencialesDelEnlace(memoria);
    memoria.falla = true;
    await expectLater(
      gestor.guardarPc(null),
      throwsA(
        isA<FalloDeEnlace>().having((e) => e.toString(), 'error', 'FalloDeEnlace(STORAGE_FAILURE)'),
      ),
    );
    expect(memoria.valor, fixture());
    expect((await gestor.cargar()).pc, isNotNull);
  });
  test(
    'una copia de credenciales manipulada no autoriza hosts públicos ni un nodo propio como PC',
    () async {
      for (final alteracion in <void Function(Map<String, Object?>)>[
        (j) => (j['pc']! as Map<String, Object?>)['host'] = '8.8.8.8',
        (j) => (j['pc']! as Map<String, Object?>)['nodo'] = j['nodo'],
        (j) => j['version'] = 2,
        (j) => j['extra'] = true,
      ]) {
        final json = jsonDecode(fixture()) as Map<String, Object?>;
        alteracion(json);
        final memoria = Memoria()..valor = jsonEncode(json);
        await expectLater(CredencialesDelEnlace(memoria).cargar(), throwsA(isA<FalloDeEnlace>()));
        expect(memoria.escrituras, 0);
      }
    },
  );
}

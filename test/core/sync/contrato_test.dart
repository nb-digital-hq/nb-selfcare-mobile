import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/sync/contrato.dart';

Map<String, Object?> ejemplo() =>
    jsonDecode(File('test/fixtures/sincronizacion/lote-v1.json').readAsStringSync())
        as Map<String, Object?>;
void main() {
  test('el lote grabado conserva identidad revisión y borrado', () {
    final json = ejemplo();
    expect(LoteSincronizado.desdeJson(json).aJson(), json);
  });
  test('un reintento no puede repetir operaciones en el mismo lote', () {
    final json = ejemplo();
    final cambios = json['cambios']! as List;
    cambios.add(cambios.first);
    expect(() => LoteSincronizado.desdeJson(json), throwsA(isA<FormatoDeSincronizacion>()));
  });
  test('se rechazan versiones identificadores y revisiones incompatibles', () {
    for (final par in [('version', 2), ('nodo', '../privado')]) {
      final json = ejemplo();
      json[par.$1] = par.$2;
      expect(() => LoteSincronizado.desdeJson(json), throwsA(isA<FormatoDeSincronizacion>()));
    }
    final json = ejemplo();
    ((json['cambios']! as List).first as Map)['base'] = maxRevisionCompartida + 1;
    expect(() => LoteSincronizado.desdeJson(json), throwsA(isA<FormatoDeSincronizacion>()));
  });
  test('un borrado no admite datos y un guardado no vacía registros', () {
    for (final indice in [0, 1]) {
      final json = ejemplo();
      ((json['cambios']! as List)[indice] as Map)['datos'] = indice == 0
          ? <String, Object?>{}
          : {'texto': 'privado'};
      expect(() => LoteSincronizado.desdeJson(json), throwsA(isA<FormatoDeSincronizacion>()));
    }
  });
  test('las cotas se miden en bytes y no en caracteres', () {
    final json = ejemplo();
    ((json['cambios']! as List).first as Map)['datos'] = {'texto': List.filled(40000, 'ñ').join()};
    expect(() => LoteSincronizado.desdeJson(json), throwsA(isA<FormatoDeSincronizacion>()));
  });
  test('el lote conserva una instantánea aunque cambie el mapa de origen', () {
    final json = ejemplo();
    final cambios = json['cambios']! as List<Object?>;
    final primero = cambios.first! as Map<String, Object?>;
    final elementos = <Object?>[
      <String, Object?>{'cantidad': 1},
    ];
    primero['datos'] = <String, Object?>{'elementos': elementos};
    final lote = LoteSincronizado.desdeJson(json);
    (elementos.first! as Map<String, Object?>)['cantidad'] = 2;
    final guardados = lote.cambios.first.datos!['elementos']! as List<Object?>;
    expect((guardados.first! as Map<String, Object?>)['cantidad'], 1);
    expect(() => guardados.add(3), throwsUnsupportedError);
    expect(
      () => (guardados.first! as Map<String, Object?>)['cantidad'] = 3,
      throwsUnsupportedError,
    );
  });
  test('campos desconocidos y representación privada son seguros', () {
    final json = ejemplo();
    json['secreto'] = true;
    expect(() => LoteSincronizado.desdeJson(json), throwsA(isA<FormatoDeSincronizacion>()));
    final lote = LoteSincronizado.desdeJson(ejemplo());
    expect(lote.toString(), isNot(contains('11111111')));
    expect(lote.cambios.first.toString(), isNot(contains('mililitros')));
  });
}

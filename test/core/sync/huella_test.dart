import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/sync/contrato.dart';
import 'package:nb_selfcare/core/sync/huella.dart';

void main() {
  final casos =
      jsonDecode(File('test/fixtures/sincronizacion/huellas-v1.json').readAsStringSync()) as List;
  for (final entrada in casos) {
    final caso = entrada as Map<String, Object?>;
    test('la huella ${caso['caso']} coincide con el vector independiente y Rust', () {
      final json = caso['cambio']! as Map<String, Object?>;
      final nodo = caso['nodo']! as String;
      final cambio = CambioSincronizado.desdeJson(json);
      expect(huellaDelCambio(nodo, cambio), caso['sha256']);
      final invertido = Map<String, Object?>.fromEntries(json.entries.toList().reversed);
      if (invertido['datos'] case final Map<String, Object?> datos) {
        invertido['datos'] = Map<String, Object?>.fromEntries(datos.entries.toList().reversed);
      }
      expect(huellaDelCambio(nodo, CambioSincronizado.desdeJson(invertido)), caso['sha256']);
    });
  }

  test('se distinguen cambios de nodo, contenido, identidad, revisión y tipos', () {
    final caso = casos.first as Map<String, Object?>;
    final original = caso['cambio']! as Map<String, Object?>;
    final nodo = caso['nodo']! as String;
    final huella = huellaDelCambio(nodo, CambioSincronizado.desdeJson(original));
    for (final entrada in <String, Object?>{
      'id': '4' * 32,
      'registro': '6' * 32,
      'entidad': 'diario',
      'base': 1,
      'datos': <String, Object?>{'dia': '2026-01-01', 'mililitros': '250'},
    }.entries) {
      final cambio = CambioSincronizado.desdeJson({...original, entrada.key: entrada.value});
      expect(huellaDelCambio(nodo, cambio), isNot(huella));
    }
    expect(huellaDelCambio('2' * 32, CambioSincronizado.desdeJson(original)), isNot(huella));
    expect(
      () => huellaDelCambio('inválido', CambioSincronizado.desdeJson(original)),
      throwsA(isA<FormatoDeSincronizacion>()),
    );
  });

  test('números equivalentes no producen cambios ficticios', () {
    final original = (casos.first as Map<String, Object?>)['cambio']! as Map<String, Object?>;
    String huella(Object valor) => huellaDelCambio(
      '1' * 32,
      CambioSincronizado.desdeJson({
        ...original,
        'datos': <String, Object?>{'valor': valor},
      }),
    );
    expect(huella(1), huella(1.0));
    expect(huella(0), huella(-0.0));
    expect(huella(1), isNot(huella('1')));
    expect(huella(<Object?>[1, 2]), isNot(huella(<Object?>[2, 1])));
  });

  test('se rechazan números inseguros y sustitutos Unicode aislados', () {
    final original = (casos.first as Map<String, Object?>)['cambio']! as Map<String, Object?>;
    for (final dato in <Map<String, Object?>>[
      for (final numero in <num>[
        9007199254740992,
        -9007199254740992,
        1e100,
        double.infinity,
        double.nan,
      ])
        <String, Object?>{'valor': numero},
      <String, Object?>{'valor': '\ud800'},
      <String, Object?>{'\udc00': 'valor'},
    ]) {
      expect(
        () => CambioSincronizado.desdeJson({...original, 'datos': dato}),
        throwsA(isA<FormatoDeSincronizacion>()),
      );
    }
  });
}

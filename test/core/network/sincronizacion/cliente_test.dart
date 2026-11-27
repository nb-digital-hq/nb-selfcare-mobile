import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/network/sincronizacion/cliente.dart';

void main() {
  ClienteDeEscritorio cliente({bool Function()? autorizado}) => ClienteDeEscritorio(
    host: InternetAddress.loopbackIPv4,
    puerto: 1,
    huella: base64.encode(List<int>.filled(32, 7)),
    autorizado: autorizado ?? () => false,
    ahora: () => DateTime.utc(2026, 11, 25),
  );
  test('sin consentimiento rechaza antes de intentar conectar', () async {
    final conexion = cliente();
    addTearDown(conexion.cerrar);
    await expectLater(
      conexion.comprobarEstado(nodo: 'a' * 32, credencial: 'A' * 43),
      throwsA(isA<FalloDeEnlace>().having((e) => e.codigo, 'codigo', 'CONSENT_REQUIRED')),
    );
  });
  test('una credencial no canónica se rechaza sin consultar el permiso ni la red', () async {
    var consultas = 0;
    final conexion = cliente(
      autorizado: () {
        consultas++;
        return true;
      },
    );
    addTearDown(conexion.cerrar);
    await expectLater(
      conexion.comprobarEstado(nodo: 'a' * 32, credencial: '${'A' * 42}B'),
      throwsA(isA<FalloDeEnlace>().having((e) => e.codigo, 'codigo', 'INVALID_INPUT')),
    );
    expect(consultas, 0);
  });
  test('un cliente cerrado no vuelve a abrir conexiones aunque recupere consentimiento', () async {
    final conexion = cliente(autorizado: () => true);
    conexion.cerrar();
    conexion.cerrar();
    await expectLater(
      conexion.comprobarEstado(nodo: 'a' * 32, credencial: 'A' * 43),
      throwsA(isA<FalloDeEnlace>().having((e) => e.codigo, 'codigo', 'CONSENT_REQUIRED')),
    );
  });
  test('una dirección pública no se convierte en destino por tener un pin', () {
    expect(
      () => ClienteDeEscritorio(
        host: InternetAddress('8.8.8.8'),
        puerto: 443,
        huella: base64.encode(List<int>.filled(32, 7)),
        autorizado: () => true,
        ahora: () => DateTime.utc(2026),
      ),
      throwsA(isA<FalloDeEnlace>().having((e) => e.codigo, 'codigo', 'INVALID_INPUT')),
    );
  });
}

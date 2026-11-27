import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/network/sincronizacion/invitacion.dart';
import 'package:nb_selfcare/core/sync/contrato.dart';

void main() {
  Map<String, Object?> ejemplo() =>
      jsonDecode(File('test/fixtures/sincronizacion/invitacion-v1.json').readAsStringSync())
          as Map<String, Object?>;
  test('acepta el QR de escritorio sin filtrar su credencial al depurar', () {
    final invitacion = InvitacionDeEscritorio.desdeTexto(jsonEncode(ejemplo()));
    expect(invitacion.host.address, '192.168.1.4');
    expect(invitacion.puerto, 43127);
    expect(invitacion.toString(), isNot(contains(invitacion.credencial)));
    expect(invitacion.toString(), isNot(contains(invitacion.host.address)));
  });
  test('rechaza red pública, DNS, multicast, direcciones vacías y mapeadas', () {
    for (final ip in [
      '8.8.8.8',
      '0.0.0.0',
      '224.0.0.1',
      '255.255.255.255',
      '::',
      'ff02::1',
      '2001:4860:4860::8888',
      '::ffff:192.168.1.2',
      'localhost',
      'fe80::1%wlan0',
    ]) {
      expect(
        () => InvitacionDeEscritorio.desdeTexto(jsonEncode(ejemplo()..['host'] = ip)),
        throwsA(isA<FormatoDeSincronizacion>()),
        reason: ip,
      );
    }
  });
  test('acepta las mismas redes locales que el escritorio', () {
    for (final ip in [
      '127.0.0.1',
      '192.168.1.4',
      '10.1.2.3',
      '172.16.1.4',
      '169.254.1.4',
      '::1',
      'fd12::4',
      'fe80::4',
    ]) {
      expect(
        InvitacionDeEscritorio.desdeTexto(jsonEncode(ejemplo()..['host'] = ip)).host,
        isNotNull,
      );
    }
  });
  test('rechaza versiones, protocolos, puertos y secretos malformados', () {
    for (final campo in <String, Object?>{
      'app': 'nb-books',
      'version': 2,
      'puerto': 0,
      'huella': 'invalida',
      'credencial': 'invalida',
      'extra': true,
    }.entries) {
      expect(
        () => InvitacionDeEscritorio.desdeTexto(jsonEncode(ejemplo()..[campo.key] = campo.value)),
        throwsA(isA<FormatoDeSincronizacion>()),
      );
    }
    expect(
      () => InvitacionDeEscritorio.desdeTexto('a' * 4097),
      throwsA(isA<FormatoDeSincronizacion>()),
    );
    expect(
      () => InvitacionDeEscritorio.desdeTexto('no-json'),
      throwsA(isA<FormatoDeSincronizacion>()),
    );
  });
}

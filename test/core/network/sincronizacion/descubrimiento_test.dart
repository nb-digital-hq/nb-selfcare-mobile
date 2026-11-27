import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/network/sincronizacion/cliente.dart';
import 'package:nb_selfcare/core/network/sincronizacion/descubrimiento.dart';
import 'package:nsd/nsd.dart' as nsd;

nsd.Service servicio(
  String nombre, {
  String? host,
  int puerto = 43127,
  String tipo = tipoDeServicioSelfCare,
}) => nsd.Service(
  name: nombre,
  type: tipo,
  host: host,
  port: puerto,
  txt: {
    'version': Uint8List.fromList([49]),
  },
);
void main() {
  test('sin permiso no inicia descubrimiento nativo', () async {
    var inicios = 0;
    final descubridor = DescubridorDePc(
      iniciar: () async {
        inicios++;
        return nsd.Discovery('sintetica');
      },
    );
    await expectLater(
      descubridor.buscar(autorizado: () => false),
      throwsA(isA<FalloDeEnlace>().having((e) => e.codigo, 'codigo', 'CONSENT_REQUIRED')),
    );
    expect(inicios, 0);
  });
  test(
    'incluye servicios que aparecieron antes de instalar el listener y cierra la sesión',
    () async {
      final d = nsd.Discovery('sintetica')..add(servicio('SelfCare-1', host: '192.168.1.4'));
      var cierres = 0;
      final descubridor = DescubridorDePc(
        iniciar: () async => d,
        detener: (_) async {
          cierres++;
        },
        resolver: (s) async => s,
      );
      final encontrados = await descubridor.buscar(
        autorizado: () => true,
        limite: const Duration(milliseconds: 30),
      );
      expect(encontrados, hasLength(1));
      expect(encontrados.single.host.address, '192.168.1.4');
      expect(encontrados.single.toString(), isNot(contains('192.168')));
      expect(cierres, 1);
      expect(encontrados.clear, throwsUnsupportedError);
    },
  );
  test('un anuncio no puede consultar DNS público ni autorizar una dirección pública', () async {
    final d = nsd.Discovery('sintetica')
      ..add(servicio('SelfCare-1', host: 'example.com'))
      ..add(servicio('SelfCare-2', host: '8.8.8.8'))
      ..add(servicio('SelfCare-3', host: '127.0.0.1'))
      ..add(servicio('SelfCare-4', host: '192.168.1.4', tipo: '_nbbooks._tcp'));
    var consultas = 0;
    final descubridor = DescubridorDePc(
      iniciar: () async => d,
      detener: (_) async {},
      resolver: (s) async => s,
      resolverHost: (_) async {
        consultas++;
        return [InternetAddress('192.168.1.9')];
      },
    );
    expect(
      await descubridor.buscar(autorizado: () => true, limite: const Duration(milliseconds: 30)),
      isEmpty,
    );
    expect(consultas, 0);
  });
  test('solo resuelve el hostname propio local y filtra sus respuestas', () async {
    final d = nsd.Discovery('sintetica')
      ..add(servicio('SelfCare-1', host: 'nbselfcare-43127.local.'));
    final descubridor = DescubridorDePc(
      iniciar: () async => d,
      detener: (_) async {},
      resolver: (s) async => s,
      resolverHost: (_) async => [InternetAddress('8.8.8.8'), InternetAddress('192.168.1.9')],
    );
    final encontrados = await descubridor.buscar(
      autorizado: () => true,
      limite: const Duration(milliseconds: 30),
    );
    expect(encontrados.map((s) => s.host.address), ['192.168.1.9']);
  });
  test(
    'la cancelación cierra un inicio tardío y no abre otra sesión mientras queda pendiente',
    () async {
      final inicio = Completer<nsd.Discovery>();
      final cerrado = Completer<void>();
      var cierres = 0;
      final descubridor = DescubridorDePc(
        iniciar: () => inicio.future,
        detener: (_) async {
          cierres++;
          cerrado.complete();
        },
      );
      final busqueda = descubridor.buscar(autorizado: () => true);
      descubridor.cancelar();
      await expectLater(
        busqueda,
        throwsA(isA<FalloDeEnlace>().having((e) => e.codigo, 'codigo', 'CANCELLED')),
      );
      await expectLater(
        descubridor.buscar(autorizado: () => true),
        throwsA(isA<FalloDeEnlace>().having((e) => e.codigo, 'codigo', 'COMPONENT_UNAVAILABLE')),
      );
      inicio.complete(nsd.Discovery('tardia'));
      await cerrado.future;
      expect(cierres, 1);
    },
  );
  test('acota los candidatos y las resoluciones concurrentes', () async {
    final d = nsd.Discovery('sintetica');
    for (var n = 1; n <= 20; n++) {
      d.add(servicio('SelfCare-$n', host: '10.0.0.$n'));
    }
    var activos = 0, maximo = 0, resueltos = 0;
    final descubridor = DescubridorDePc(
      iniciar: () async => d,
      detener: (_) async {},
      resolver: (s) async {
        activos++;
        if (activos > maximo) maximo = activos;
        await Future<void>.delayed(const Duration(milliseconds: 1));
        activos--;
        resueltos++;
        return s;
      },
    );
    final encontrados = await descubridor.buscar(
      autorizado: () => true,
      limite: const Duration(milliseconds: 50),
    );
    expect(encontrados.length, 8);
    expect(resueltos, 8);
    expect(maximo, lessThanOrEqualTo(2));
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/network/sincronizacion/cliente.dart';
import 'package:nb_selfcare/core/network/sincronizacion/credenciales.dart';
import 'package:nb_selfcare/core/network/sincronizacion/descubrimiento.dart';
import 'package:nb_selfcare/core/network/sincronizacion/reconexion.dart';

class MemoriaDeReconexion implements AlmacenSeguroDeEnlace {
  String valor = jsonEncode({
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
  bool falla = false;
  int escrituras = 0;
  @override
  Future<String?> leer() async => valor;
  @override
  Future<void> escribir(String valor) async {
    if (falla) throw StateError('detalle que no se expone');
    escrituras++;
    this.valor = valor;
  }
}

class DescubrimientoSintetico extends DescubridorDePc {
  List<CandidatoDePc> candidatos = [];
  int busquedas = 0;
  @override
  Future<List<CandidatoDePc>> buscar({
    required bool Function() autorizado,
    Duration limite = const Duration(seconds: 6),
  }) async {
    busquedas++;
    return candidatos;
  }
}

class SondeoSintetico implements SondeadorDePc {
  SondeoSintetico(this.accion);
  final Future<void> Function() accion;
  bool cerrado = false;
  @override
  Future<void> comprobarEstado({required String nodo, required String credencial}) {
    expect(nodo, 'a' * 32);
    expect(credencial, 'A' * 43);
    return accion();
  }

  @override
  void cerrar() => cerrado = true;
}

Matcher fallo(String codigo) => isA<FalloDeEnlace>().having((e) => e.codigo, 'código', codigo);

void main() {
  late MemoriaDeReconexion memoria;
  late CredencialesDelEnlace gestor;
  late DescubrimientoSintetico descubridor;
  late List<SondeoSintetico> clientes;
  late List<String> direcciones;
  late bool autorizado;
  late Future<void> Function(CandidatoDePc) probar;
  late RestablecedorDelEnlace enlace;

  setUp(() {
    memoria = MemoriaDeReconexion();
    gestor = CredencialesDelEnlace(memoria);
    descubridor = DescubrimientoSintetico();
    clientes = [];
    direcciones = [];
    autorizado = true;
    probar = (_) async {};
    enlace = RestablecedorDelEnlace(
      credenciales: gestor,
      autorizado: () => autorizado,
      ahora: () => DateTime.utc(2026, 11, 25),
      descubridor: descubridor,
      crearCliente: (candidato, pc) {
        expect(pc.huella, base64.encode(List<int>.filled(32, 7)));
        direcciones.add(candidato.host.address);
        final cliente = SondeoSintetico(() => probar(candidato));
        clientes.add(cliente);
        return cliente;
      },
    );
  });
  tearDown(() => enlace.cancelar());

  test('sin consentimiento no abre clientes ni inicia descubrimiento', () async {
    autorizado = false;
    await expectLater(enlace.reconectar(), throwsA(fallo('CONSENT_REQUIRED')));
    expect(clientes, isEmpty);
    expect(descubridor.busquedas, 0);
    expect(memoria.escrituras, 0);
  });

  test('una dirección vigente no descubre ni reescribe el almacén', () async {
    final estado = await enlace.reconectar();
    expect(estado.pc!.host.address, '192.168.1.4');
    expect(descubridor.busquedas, 0);
    expect(memoria.escrituras, 0);
    expect(clientes.every((c) => c.cerrado), isTrue);
  });

  test(
    'solo guarda una dirección nueva tras el sondeo autenticado conservando identidad y secretos',
    () async {
      probar = (candidato) async {
        if (candidato.host.address != '192.168.1.9') throw const FalloDeEnlace('NETWORK_FAILURE');
      };
      descubridor.candidatos = [
        CandidatoDePc(InternetAddress('192.168.1.4'), 43127),
        CandidatoDePc(InternetAddress('192.168.1.8'), 43127),
        CandidatoDePc(InternetAddress('192.168.1.9'), 43128),
      ];
      final previo = await gestor.cargar();
      final nuevo = await enlace.reconectar();
      expect(direcciones, ['192.168.1.4', '192.168.1.8', '192.168.1.9']);
      expect(nuevo.pc!.host.address, '192.168.1.9');
      expect(nuevo.pc!.puerto, 43128);
      expect(nuevo.pc!.nodo, previo.pc!.nodo);
      expect(nuevo.pc!.huella, previo.pc!.huella);
      expect(nuevo.pc!.credencial, previo.pc!.credencial);
      expect(nuevo.nodo, previo.nodo);
      expect(memoria.escrituras, 1);
      expect((await CredencialesDelEnlace(memoria).cargar()).pc!.host.address, '192.168.1.9');
      expect(clientes.every((c) => c.cerrado), isTrue);
    },
  );

  test('un anuncio sin prueba válida no modifica el vínculo', () async {
    probar = (_) async => throw const FalloDeEnlace('NETWORK_FAILURE');
    descubridor.candidatos = [CandidatoDePc(InternetAddress('192.168.1.9'), 43127)];
    final previo = memoria.valor;
    await expectLater(enlace.reconectar(), throwsA(fallo('NETWORK_FAILURE')));
    expect(memoria.valor, previo);
    expect(memoria.escrituras, 0);
    expect(clientes.every((c) => c.cerrado), isTrue);
  });

  test('cancelar cierra el sondeo y descarta su respuesta tardía', () async {
    final iniciado = Completer<void>();
    final respuesta = Completer<void>();
    probar = (_) {
      iniciado.complete();
      return respuesta.future;
    };
    final pendiente = enlace.reconectar();
    final comprobacion = expectLater(pendiente, throwsA(fallo('CANCELLED')));
    await iniciado.future;
    enlace.cancelar();
    await comprobacion;
    expect(clientes.single.cerrado, isTrue);
    respuesta.complete();
    await Future<void>.delayed(Duration.zero);
    expect(memoria.escrituras, 0);
    expect(descubridor.busquedas, 0);
  });

  test('desvincular mientras responde el PC no resucita el par', () async {
    final iniciado = Completer<void>();
    final respuesta = Completer<void>();
    probar = (_) {
      iniciado.complete();
      return respuesta.future;
    };
    final comprobacion = expectLater(enlace.reconectar(), throwsA(fallo('CANCELLED')));
    await iniciado.future;
    await gestor.guardarPc(null);
    respuesta.complete();
    await comprobacion;
    expect((await gestor.cargar()).pc, isNull);
    expect(memoria.escrituras, 1);
  });

  test('la revocación impide confirmar incluso si el sondeo acaba bien', () async {
    probar = (_) async {
      autorizado = false;
    };
    await expectLater(enlace.reconectar(), throwsA(fallo('CONSENT_REQUIRED')));
    expect(memoria.escrituras, 0);
    expect(descubridor.busquedas, 0);
  });

  test('un emparejamiento nuevo no se sustituye con la respuesta del anterior', () async {
    final iniciado = Completer<void>();
    final respuesta = Completer<void>();
    probar = (_) {
      iniciado.complete();
      return respuesta.future;
    };
    final comprobacion = expectLater(enlace.reconectar(), throwsA(fallo('CANCELLED')));
    await iniciado.future;
    final otroAlmacen = MemoriaDeReconexion();
    final json = jsonDecode(otroAlmacen.valor) as Map<String, Object?>;
    (json['pc']! as Map<String, Object?>)['nodo'] = 'c' * 32;
    otroAlmacen.valor = jsonEncode(json);
    final nuevo = (await CredencialesDelEnlace(otroAlmacen).cargar()).pc!;
    await gestor.guardarPc(nuevo);
    respuesta.complete();
    await comprobacion;
    expect((await gestor.cargar()).pc!.nodo, 'c' * 32);
    expect(memoria.escrituras, 1);
  });

  test(
    'el plazo total acota respuestas nativas que no terminan y excluye intentos simultáneos',
    () async {
      final iniciado = Completer<void>();
      probar = (_) {
        iniciado.complete();
        return Completer<void>().future;
      };
      final primero = expectLater(
        enlace.reconectar(plazoTotal: const Duration(milliseconds: 50)),
        throwsA(fallo('NETWORK_FAILURE')),
      );
      await iniciado.future;
      await expectLater(enlace.reconectar(), throwsA(fallo('COMPONENT_UNAVAILABLE')));
      await primero;
      expect(clientes.single.cerrado, isTrue);
      expect(memoria.escrituras, 0);
      probar = (_) async {};
      expect((await enlace.reconectar()).pc, isNotNull);
    },
  );

  test(
    'una escritura segura fallida conserva la dirección anterior y no confirma reconexión',
    () async {
      probar = (candidato) async {
        if (candidato.host.address == '192.168.1.4') throw const FalloDeEnlace('NETWORK_FAILURE');
      };
      descubridor.candidatos = [CandidatoDePc(InternetAddress('192.168.1.9'), 43127)];
      memoria.falla = true;
      final previo = memoria.valor;
      await expectLater(enlace.reconectar(), throwsA(fallo('STORAGE_FAILURE')));
      expect(memoria.valor, previo);
      expect(memoria.escrituras, 0);
    },
  );
}

// Prueba de proceso: solo fixture efímero y servidor TLS de QA, nunca un teléfono.
import 'dart:convert';
import 'dart:io';

import 'package:nb_selfcare/core/network/sincronizacion/candidatos.dart';
import 'package:nb_selfcare/core/network/sincronizacion/cliente.dart';
import 'package:nb_selfcare/core/network/sincronizacion/credenciales.dart';
import 'package:nb_selfcare/core/network/sincronizacion/invitacion.dart';
import 'package:nb_selfcare/core/network/sincronizacion/reconexion.dart';

class AlmacenSintetico implements AlmacenSeguroDeEnlace {
  AlmacenSintetico(this.valor);
  String valor;
  int escrituras = 0;
  @override
  Future<String?> leer() async => valor;
  @override
  Future<void> escribir(String valor) async {
    escrituras++;
    this.valor = valor;
  }
}

class DescubrimientoSintetico implements BuscadorDePc {
  DescubrimientoSintetico(this.candidato);
  final CandidatoDePc candidato;
  int busquedas = 0;
  @override
  void cancelar() {}
  @override
  Future<List<CandidatoDePc>> buscar({
    required bool Function() autorizado,
    Duration limite = const Duration(seconds: 6),
  }) async {
    if (!autorizado()) throw const FalloDeEnlace('CONSENT_REQUIRED');
    busquedas++;
    return [candidato];
  }
}

Future<void> exigirCodigo(Future<void> operacion, String codigo) async {
  try {
    await operacion;
  } on FalloDeEnlace catch (error) {
    if (error.codigo == codigo) return;
    rethrow;
  }
  throw StateError('No se rechazó la operación');
}

Future<void> main(List<String> args) async {
  ClienteDeEscritorio? cliente;
  try {
    if (args.length != 1) throw const FormatException();
    final archivo = File(args.single).absolute;
    if (!archivo.parent.path.startsWith(
          '${Directory.systemTemp.path}${Platform.pathSeparator}nb-selfcare-qa-enlace-',
        ) ||
        archivo.lengthSync() > 8192) {
      throw const FormatException();
    }
    final datos = jsonDecode(await archivo.readAsString()) as Map<String, Object?>;
    final invitacion = InvitacionDeEscritorio.desdeTexto(jsonEncode(datos['invitacion']));
    final nodo = datos['nodo']! as String;
    final instante = DateTime.parse(datos['ahora']! as String);
    final vencido = ClienteDeEscritorio(
      host: invitacion.host,
      puerto: invitacion.puerto,
      huella: invitacion.huella,
      autorizado: () => true,
      ahora: () => DateTime.utc(2300),
    );
    try {
      await exigirCodigo(
        vencido.comprobarEstado(nodo: nodo, credencial: 'A' * 43),
        'NETWORK_FAILURE',
      );
    } finally {
      vencido.cerrar();
    }
    final incorrecto = ClienteDeEscritorio(
      host: invitacion.host,
      puerto: invitacion.puerto,
      huella: base64.encode(List<int>.filled(32, 0)),
      autorizado: () => true,
      ahora: () => instante,
    );
    try {
      await exigirCodigo(
        incorrecto.comprobarEstado(nodo: nodo, credencial: 'A' * 43),
        'NETWORK_FAILURE',
      );
    } finally {
      incorrecto.cerrar();
    }
    var permitido = true;
    cliente = ClienteDeEscritorio(
      host: invitacion.host,
      puerto: invitacion.puerto,
      huella: invitacion.huella,
      autorizado: () => permitido,
      ahora: () => instante,
    );
    final alta = await cliente.emparejar(invitacion, nodo);
    await cliente.comprobarEstado(nodo: nodo, credencial: alta.credencial);
    final direccionAnterior = invitacion.host.type == InternetAddressType.IPv4
        ? '::1'
        : '127.0.0.1';
    final almacen = AlmacenSintetico(
      jsonEncode({
        'version': 1,
        'nodo': nodo,
        'pc': {
          'host': direccionAnterior,
          'puerto': invitacion.puerto,
          'huella': invitacion.huella,
          'nodo': alta.nodo,
          'credencial': alta.credencial,
        },
      }),
    );
    final descubridor = DescubrimientoSintetico(CandidatoDePc(invitacion.host, invitacion.puerto));
    final restablecedor = RestablecedorDelEnlace(
      credenciales: CredencialesDelEnlace(almacen),
      descubridor: descubridor,
      autorizado: () => permitido,
      ahora: () => instante,
    );
    final reconectado = await restablecedor.reconectar();
    if (reconectado.pc!.host.address != invitacion.host.address ||
        reconectado.pc!.huella != invitacion.huella ||
        reconectado.pc!.credencial != alta.credencial ||
        almacen.escrituras != 1 ||
        descubridor.busquedas != 1) {
      throw StateError('RECONEXION_INVALIDA');
    }
    stdout.writeln('ENLACE_LISTO');
    final orden = await stdin.transform(utf8.decoder).transform(const LineSplitter()).first;
    if (orden != 'REVOCADO') throw const FormatException();
    await exigirCodigo(
      cliente.comprobarEstado(nodo: nodo, credencial: alta.credencial),
      'CONSENT_REQUIRED',
    );
    await exigirCodigo(restablecedor.reconectar().then((_) {}), 'CONSENT_REQUIRED');
    if (almacen.escrituras != 1 || descubridor.busquedas != 1) {
      throw StateError('REVOCACION_INVALIDA');
    }
    permitido = false;
    await exigirCodigo(
      cliente.comprobarEstado(nodo: nodo, credencial: alta.credencial),
      'CONSENT_REQUIRED',
    );
    stdout.writeln('REVOCACION_CORRECTA');
  } catch (_) {
    stderr.writeln('PRUEBA_ENLACE_FALLIDA');
    exitCode = 1;
  } finally {
    cliente?.cerrar();
  }
}

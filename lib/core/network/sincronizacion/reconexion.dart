import 'dart:async';

import 'candidatos.dart';
import 'cliente.dart';
import 'credenciales.dart';

/// El propietario cancela al pausar la app, revocar el permiso o desvincular.
/// Solo confirma una dirección tras TLS fijado y estado autenticado, sin reenviar
/// invitaciones ni crear otra identidad. No aplica registros sanitarios.
class RestablecedorDelEnlace {
  RestablecedorDelEnlace({
    required this._credenciales,
    required this._descubridor,
    required bool Function() autorizado,
    required DateTime Function() ahora,
    SondeadorDePc Function(CandidatoDePc, PcEmparejado)? crearCliente,
  }) : _autorizado = autorizado,
       _crearCliente =
           crearCliente ??
           ((candidato, pc) => ClienteDeEscritorio(
             host: candidato.host,
             puerto: candidato.puerto,
             huella: pc.huella,
             autorizado: autorizado,
             ahora: ahora,
           ));

  final CredencialesDelEnlace _credenciales;
  final bool Function() _autorizado;
  final BuscadorDePc _descubridor;
  final SondeadorDePc Function(CandidatoDePc, PcEmparejado) _crearCliente;
  _IntentoDeReconexion? _actual;

  void cancelar() {
    _actual?.cancelar();
    _descubridor.cancelar();
  }

  Future<EstadoDelEnlace> reconectar({Duration plazoTotal = const Duration(seconds: 30)}) async {
    if (!_autorizado()) throw const FalloDeEnlace('CONSENT_REQUIRED');
    if (_actual != null) throw const FalloDeEnlace('COMPONENT_UNAVAILABLE');
    if (plazoTotal <= Duration.zero || plazoTotal > const Duration(minutes: 1)) {
      throw const FalloDeEnlace('INVALID_INPUT');
    }
    final intento = _IntentoDeReconexion(_autorizado);
    _actual = intento;
    final temporizador = Timer(plazoTotal, () {
      intento.caducado = true;
      cancelar();
    });
    try {
      final estado = await intento.esperar(_credenciales.cargar);
      final pc = estado.pc;
      if (pc == null) throw const FalloDeEnlace('COMPONENT_UNAVAILABLE');

      Future<EstadoDelEnlace> probar(CandidatoDePc candidato) async {
        intento.comprobar();
        final cliente = _crearCliente(candidato, pc);
        intento.clientes.add(cliente);
        try {
          await intento.esperar(
            () => cliente.comprobarEstado(nodo: estado.nodo, credencial: pc.credencial),
          );
          return await intento.esperar(
            () => _credenciales.actualizarDireccion(
              estado,
              host: candidato.host,
              puerto: candidato.puerto,
              vigente: () => intento.vigente && _autorizado(),
            ),
          );
        } finally {
          cliente.cerrar();
          intento.clientes.remove(cliente);
        }
      }

      try {
        return await probar(CandidatoDePc(pc.host, pc.puerto));
      } on FalloDeEnlace catch (fallo) {
        if (fallo.codigo != 'NETWORK_FAILURE') rethrow;
        intento.comprobar();
      }

      final candidatos = await intento.esperar(() => _descubridor.buscar(autorizado: _autorizado));
      final vistos = <String>{'${pc.host.address}:${pc.puerto}'};
      for (final candidato in candidatos.take(8)) {
        if (!vistos.add('${candidato.host.address}:${candidato.puerto}')) continue;
        try {
          return await probar(candidato);
        } on FalloDeEnlace catch (fallo) {
          if (fallo.codigo != 'NETWORK_FAILURE') rethrow;
          intento.comprobar();
        }
      }
      throw const FalloDeEnlace('NETWORK_FAILURE');
    } on FalloDeEnlace {
      rethrow;
    } catch (_) {
      intento.comprobar();
      throw const FalloDeEnlace('NETWORK_FAILURE');
    } finally {
      temporizador.cancel();
      cancelar();
      _actual = null;
    }
  }
}

class _IntentoDeReconexion {
  _IntentoDeReconexion(this.autorizado);
  final bool Function() autorizado;
  final fin = Completer<void>();
  final clientes = <SondeadorDePc>{};
  bool caducado = false;
  bool get vigente => !fin.isCompleted;

  void comprobar() {
    if (!autorizado()) throw const FalloDeEnlace('CONSENT_REQUIRED');
    if (caducado) throw const FalloDeEnlace('NETWORK_FAILURE');
    if (!vigente) throw const FalloDeEnlace('CANCELLED');
  }

  Future<T> esperar<T>(Future<T> Function() operacion) async {
    comprobar();
    final resultado = await Future.any<T>([
      Future<T>.sync(operacion),
      fin.future.then((_) {
        comprobar();
        throw const FalloDeEnlace('CANCELLED');
      }),
    ]);
    comprobar();
    return resultado;
  }

  void cancelar() {
    if (!fin.isCompleted) fin.complete();
    for (final cliente in clientes.toList()) {
      cliente.cerrar();
    }
  }
}

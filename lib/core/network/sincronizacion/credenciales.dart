import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'cliente.dart';
import 'invitacion.dart';
import 'validacion.dart';

abstract interface class AlmacenSeguroDeEnlace {
  Future<String?> leer();
  Future<void> escribir(String valor);
}

class PcEmparejado {
  PcEmparejado._(this.host, this.puerto, this.huella, this.nodo, this.credencial);
  final InternetAddress host;
  final int puerto;
  final String huella;
  final String nodo;
  final String credencial;

  factory PcEmparejado.desdeAlta(InvitacionDeEscritorio invitacion, AltaDelPc alta) =>
      PcEmparejado._validar({
        'host': invitacion.host.address,
        'puerto': invitacion.puerto,
        'huella': invitacion.huella,
        'nodo': alta.nodo,
        'credencial': alta.credencial,
      });

  factory PcEmparejado._validar(Map<String, Object?> json) {
    final direccion = json['host'];
    final puerto = json['puerto'];
    if (json.length != 5 ||
        !json.keys.every({'host', 'puerto', 'huella', 'nodo', 'credencial'}.contains) ||
        direccion is! String ||
        direccion.length > 64 ||
        direccion.contains('%') ||
        puerto is! int ||
        puerto < 1 ||
        puerto > 65535 ||
        !huellaValida(json['huella']) ||
        !identificadorValido(json['nodo']) ||
        !credencialValida(json['credencial'])) {
      throw const FalloDeEnlace('STORAGE_FAILURE');
    }
    final host = InternetAddress.tryParse(direccion);
    if (host == null || !esDireccionLocal(host)) throw const FalloDeEnlace('STORAGE_FAILURE');
    return PcEmparejado._(
      host,
      puerto,
      json['huella']! as String,
      json['nodo']! as String,
      json['credencial']! as String,
    );
  }
  Map<String, Object?> _json() => {
    'host': host.address,
    'puerto': puerto,
    'huella': huella,
    'nodo': nodo,
    'credencial': credencial,
  };
  @override
  String toString() => 'PcEmparejado(protocolo: 1)';
}

class EstadoDelEnlace {
  EstadoDelEnlace._(this.nodo, this.pc);
  final String nodo;
  final PcEmparejado? pc;
  @override
  String toString() => 'EstadoDelEnlace(emparejado: ${pc != null})';
}

/// Un único propietario por aplicación. Serializa lecturas y escrituras para no crear
/// dos identidades al abrir varias vistas. Desvincular conserva la identidad del teléfono.
class CredencialesDelEnlace {
  CredencialesDelEnlace(this._almacen);
  final AlmacenSeguroDeEnlace _almacen;
  Future<void> _cola = Future<void>.value();

  Future<T> _serializar<T>(Future<T> Function() accion) {
    final operacion = _cola.then((_) => accion());
    _cola = operacion.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operacion;
  }

  Future<EstadoDelEnlace> cargar() => _serializar(_cargar);
  Future<EstadoDelEnlace> _cargar() async {
    try {
      final texto = await _almacen.leer();
      if (texto == null) {
        final random = Random.secure();
        final nodo = List<int>.generate(
          16,
          (_) => random.nextInt(256),
        ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        final estado = EstadoDelEnlace._(nodo, null);
        await _guardar(estado);
        return estado;
      }
      if (utf8.encode(texto).length > 16384) throw const FalloDeEnlace('STORAGE_FAILURE');
      final json = jsonDecode(texto);
      if (json is! Map<String, Object?> ||
          json.length != 3 ||
          !json.keys.every({'version', 'nodo', 'pc'}.contains) ||
          json['version'] is! int ||
          json['version'] != 1 ||
          !identificadorValido(json['nodo']) ||
          (json['pc'] != null && json['pc'] is! Map<String, Object?>)) {
        throw const FalloDeEnlace('STORAGE_FAILURE');
      }
      final pc = json['pc'] == null
          ? null
          : PcEmparejado._validar(json['pc']! as Map<String, Object?>);
      if (pc?.nodo == json['nodo']) throw const FalloDeEnlace('STORAGE_FAILURE');
      return EstadoDelEnlace._(json['nodo']! as String, pc);
    } catch (_) {
      throw const FalloDeEnlace('STORAGE_FAILURE');
    }
  }

  Future<EstadoDelEnlace> guardarPc(PcEmparejado? pc) => _serializar(() async {
    final anterior = await _cargar();
    if (pc?.nodo == anterior.nodo) throw const FalloDeEnlace('INVALID_INPUT');
    final siguiente = EstadoDelEnlace._(anterior.nodo, pc);
    await _guardar(siguiente);
    return siguiente;
  });

  /// La prueba TLS no autoriza a resucitar un vínculo retirado mientras esperaba.
  Future<EstadoDelEnlace> actualizarDireccion(
    EstadoDelEnlace esperado, {
    required InternetAddress host,
    required int puerto,
    required bool Function() vigente,
  }) => _serializar(() async {
    final anterior = await _cargar();
    final pc = anterior.pc;
    final previo = esperado.pc;
    if (!vigente() ||
        pc == null ||
        previo == null ||
        anterior.nodo != esperado.nodo ||
        pc.host.address != previo.host.address ||
        pc.puerto != previo.puerto ||
        pc.nodo != previo.nodo ||
        pc.huella != previo.huella ||
        pc.credencial != previo.credencial) {
      throw const FalloDeEnlace('CANCELLED');
    }
    final siguientePc = PcEmparejado._validar({
      ...pc._json(),
      'host': host.address,
      'puerto': puerto,
    });
    if (pc.host.address == host.address && pc.puerto == puerto) return anterior;
    final siguiente = EstadoDelEnlace._(anterior.nodo, siguientePc);
    if (!vigente()) throw const FalloDeEnlace('CANCELLED');
    await _guardar(siguiente);
    return siguiente;
  });

  Future<void> _guardar(EstadoDelEnlace estado) async {
    try {
      await _almacen.escribir(
        jsonEncode({'version': 1, 'nodo': estado.nodo, 'pc': estado.pc?._json()}),
      );
    } catch (_) {
      throw const FalloDeEnlace('STORAGE_FAILURE');
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../sync/contrato.dart';
import 'invitacion.dart';
import 'validacion.dart';

/// Cota del cuerpo de sincronización, la misma que aplica el escritorio.
const maxBytesDeSincronizacion = 14 * 1024 * 1024;

/// Errores estables, sin URL, certificado, contenido sanitario ni credenciales.
class FalloDeEnlace implements Exception {
  const FalloDeEnlace(this.codigo);
  final String codigo;
  @override
  String toString() => 'FalloDeEnlace($codigo)';
}

class AltaDelPc {
  AltaDelPc._(this.nodo, this.credencial);
  final String nodo;
  final String credencial;
  @override
  String toString() => 'AltaDelPc(protocolo: $versionSincronizacion)';
}

/// Superficie mínima para probar el estado sin acoplar la reconexión a sockets.
abstract interface class SondeadorDePc {
  Future<void> comprobarEstado({required String nodo, required String credencial});
  void cerrar();
}

/// Cliente local directo, sin raíces del sistema y con pin en cada negociación TLS.
/// El propietario cierra el cliente al revocar consentimiento o descartar la pantalla.
class ClienteDeEscritorio implements SondeadorDePc {
  ClienteDeEscritorio({
    required this.host,
    required this.puerto,
    required this.huella,
    required this.autorizado,
    required DateTime Function() ahora,
  }) {
    if (!esDireccionLocal(host) || puerto < 1 || puerto > 65535 || !huellaValida(huella)) {
      throw const FalloDeEnlace('INVALID_INPUT');
    }
    _cliente = HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..findProxy = ((_) => 'DIRECT')
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 10)
      ..maxConnectionsPerHost = 2
      ..autoUncompress = false
      ..userAgent = 'NBSelfCareMobile/1'
      ..badCertificateCallback = (certificado, direccion, port) =>
          !_cerrado &&
          autorizado() &&
          direccion == host.address &&
          port == puerto &&
          !ahora().isBefore(certificado.startValidity) &&
          !ahora().isAfter(certificado.endValidity) &&
          base64.encode(sha256.convert(certificado.der).bytes) == huella;
  }
  final InternetAddress host;
  final int puerto;
  final String huella;
  final bool Function() autorizado;
  late final HttpClient _cliente;
  bool _cerrado = false;

  void _comprobarPermiso() {
    if (_cerrado || !autorizado()) {
      cerrar();
      throw const FalloDeEnlace('CONSENT_REQUIRED');
    }
  }

  Future<AltaDelPc> emparejar(InvitacionDeEscritorio invitacion, String nodo) async {
    if (!identificadorValido(nodo) ||
        invitacion.host.address != host.address ||
        invitacion.puerto != puerto ||
        invitacion.huella != huella) {
      throw const FalloDeEnlace('INVALID_INPUT');
    }
    final json = await _peticion(
      'POST',
      '/v1/emparejar',
      datos: {'version': versionSincronizacion, 'nodo': nodo, 'credencial': invitacion.credencial},
    );
    final pc = json['nodo'];
    final token = json['credencial'];
    if (json.length != 3 ||
        (json['version'] is! int || json['version'] != versionSincronizacion) ||
        pc is! String ||
        pc == nodo ||
        !identificadorValido(pc) ||
        token is! String ||
        !credencialValida(token)) {
      throw const FalloDeEnlace('INVALID_INPUT');
    }
    return AltaDelPc._(pc, token);
  }

  @override
  Future<void> comprobarEstado({required String nodo, required String credencial}) async {
    if (!identificadorValido(nodo) || !credencialValida(credencial)) {
      throw const FalloDeEnlace('INVALID_INPUT');
    }
    final json = await _peticion('GET', '/v1/estado', nodo: nodo, token: credencial);
    if (json.length != 1 || (json['version'] is! int || json['version'] != versionSincronizacion)) {
      throw const FalloDeEnlace('INVALID_INPUT');
    }
  }

  /// Envía cambios pendientes y recibe los del escritorio. El contenido sanitario
  /// viaja solo dentro de TLS fijado y nunca aparece en errores.
  Future<Map<String, Object?>> sincronizar({
    required String nodo,
    required String credencial,
    required Map<String, Object?> peticion,
  }) {
    if (!identificadorValido(nodo) || !credencialValida(credencial)) {
      throw const FalloDeEnlace('INVALID_INPUT');
    }
    return _peticion(
      'POST',
      '/v1/sincronizar',
      datos: peticion,
      nodo: nodo,
      token: credencial,
      limite: maxBytesDeSincronizacion,
      plazo: const Duration(seconds: 60),
    );
  }

  Future<Map<String, Object?>> _peticion(
    String metodo,
    String ruta, {
    Map<String, Object?>? datos,
    String? nodo,
    String? token,
    int limite = 4096,
    Duration plazo = const Duration(seconds: 10),
  }) async {
    HttpClientRequest? solicitud;
    Future<Map<String, Object?>> enviar() async {
      _comprobarPermiso();
      final url = Uri(scheme: 'https', host: host.address, port: puerto, path: ruta);
      final peticion = await _cliente.openUrl(metodo, url);
      solicitud = peticion;
      _comprobarPermiso();
      peticion.followRedirects = false;
      peticion.maxRedirects = 0;
      peticion.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (token != null) peticion.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (nodo != null) peticion.headers.set('x-selfcare-nodo', nodo);
      if (datos != null) {
        final bytes = utf8.encode(jsonEncode(datos));
        if (bytes.length > limite) throw const FalloDeEnlace('INVALID_INPUT');
        peticion.headers.contentType = ContentType.json;
        peticion.contentLength = bytes.length;
        peticion.add(bytes);
      }
      final respuesta = await peticion.close();
      _comprobarPermiso();
      if (respuesta.statusCode == 401 || respuesta.statusCode == 403) {
        throw const FalloDeEnlace('CONSENT_REQUIRED');
      }
      if (respuesta.statusCode != 200 ||
          respuesta.contentLength > limite ||
          respuesta.headers.contentType?.mimeType != 'application/json') {
        throw const FalloDeEnlace('NETWORK_FAILURE');
      }
      final bytes = <int>[];
      await for (final bloque in respuesta) {
        _comprobarPermiso();
        if (bytes.length + bloque.length > limite) throw const FalloDeEnlace('INVALID_INPUT');
        bytes.addAll(bloque);
      }
      _comprobarPermiso();
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map<String, Object?>) throw const FalloDeEnlace('INVALID_INPUT');
      return json;
    }

    try {
      return await enviar().timeout(
        plazo,
        onTimeout: () {
          solicitud?.abort();
          cerrar();
          throw const FalloDeEnlace('NETWORK_FAILURE');
        },
      );
    } on FalloDeEnlace {
      solicitud?.abort();
      rethrow;
    } on StateError {
      solicitud?.abort();
      if (_cerrado || !autorizado()) {
        throw const FalloDeEnlace('CONSENT_REQUIRED');
      }
      throw const FalloDeEnlace('NETWORK_FAILURE');
    } on IOException {
      solicitud?.abort();
      throw const FalloDeEnlace('NETWORK_FAILURE');
    } on FormatException {
      solicitud?.abort();
      throw const FalloDeEnlace('INVALID_INPUT');
    }
  }

  @override
  void cerrar() {
    _cerrado = true;
    _cliente.close(force: true);
  }
}

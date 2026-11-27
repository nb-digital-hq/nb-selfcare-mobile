import 'dart:convert';
import 'dart:io';

import '../../sync/contrato.dart';
import 'validacion.dart';

/// Comprueba direcciones numéricas sin resolver DNS ni realizar una conexión.
bool esDireccionLocal(InternetAddress ip) {
  final bytes = ip.rawAddress;
  if (ip.type == InternetAddressType.IPv4) {
    return bytes[0] == 10 ||
        bytes[0] == 127 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 169 && bytes[1] == 254);
  }
  if (ip.type != InternetAddressType.IPv6 || bytes.length != 16) return false;
  return (bytes.take(15).every((b) => b == 0) && bytes[15] == 1) ||
      (bytes[0] & 0xfe) == 0xfc ||
      (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80);
}

/// QR propio de SelfCare. No autoriza por sí mismo una conexión.
/// La credencial efímera nunca se incluye en toString ni en errores.
class InvitacionDeEscritorio {
  InvitacionDeEscritorio._(this.host, this.puerto, this.huella, this.credencial);
  final InternetAddress host;
  final int puerto;
  final String huella;
  final String credencial;

  factory InvitacionDeEscritorio.desdeTexto(String texto) {
    if (utf8.encode(texto).length > 4096) throw const FormatoDeSincronizacion();
    try {
      final valor = jsonDecode(texto);
      if (valor is! Map<String, Object?> ||
          valor.length != 6 ||
          !valor.keys.every(
            {'app', 'version', 'host', 'puerto', 'huella', 'credencial'}.contains,
          ) ||
          valor['app'] != 'nb-selfcare' ||
          valor['version'] is! int ||
          valor['version'] != versionSincronizacion) {
        throw const FormatoDeSincronizacion();
      }
      final direccion = valor['host'];
      final puerto = valor['puerto'];
      final huella = valor['huella'];
      final credencial = valor['credencial'];
      if (direccion is! String ||
          direccion.contains('%') ||
          puerto is! int ||
          puerto < 1 ||
          puerto > 65535 ||
          huella is! String ||
          !huellaValida(huella) ||
          credencial is! String ||
          !credencialValida(credencial)) {
        throw const FormatoDeSincronizacion();
      }
      final host = InternetAddress.tryParse(direccion);
      if (host == null || !esDireccionLocal(host)) throw const FormatoDeSincronizacion();
      return InvitacionDeEscritorio._(host, puerto, huella, credencial);
    } on FormatException {
      throw const FormatoDeSincronizacion();
    }
  }

  @override
  String toString() => 'InvitacionDeEscritorio(protocolo: $versionSincronizacion)';
}

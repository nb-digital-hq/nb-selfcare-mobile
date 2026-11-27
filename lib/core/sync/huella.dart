import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'contrato.dart';

/// Huella de operación, sin autorizar conexiones ni aplicar registros.
/// Tampoco debe escribirse en registros: permite correlacionar contenido privado.
String huellaDelCambio(String nodo, CambioSincronizado cambio) {
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(nodo)) throw const FormatoDeSincronizacion();
  final salida = BytesBuilder(copy: false)..add(utf8.encode('NB-SelfCare/operacion/1\u0000'));
  _codificar(<String, Object?>{'nodo': nodo, 'cambio': cambio.aJson()}, salida);
  return sha256.convert(salida.takeBytes()).toString();
}

void _longitud(int cantidad, BytesBuilder salida) {
  final bytes = ByteData(4)..setUint32(0, cantidad);
  salida.add(bytes.buffer.asUint8List());
}

void _codificar(Object? valor, BytesBuilder salida) {
  if (valor == null) {
    salida.addByte(0);
  } else if (valor is bool) {
    salida.addByte(valor ? 2 : 1);
  } else if (valor is num) {
    salida.addByte(3);
    final bytes = ByteData(8)..setFloat64(0, valor == 0 ? 0 : valor.toDouble());
    salida.add(bytes.buffer.asUint8List());
  } else if (valor is String) {
    salida.addByte(4);
    final bytes = utf8.encode(valor);
    _longitud(bytes.length, salida);
    salida.add(bytes);
  } else if (valor is List<Object?>) {
    salida.addByte(5);
    _longitud(valor.length, salida);
    for (final elemento in valor) {
      _codificar(elemento, salida);
    }
  } else if (valor is Map<String, Object?>) {
    salida.addByte(6);
    _longitud(valor.length, salida);
    final claves = valor.keys.toList()..sort(_compararUtf8);
    for (final clave in claves) {
      _codificar(clave, salida);
      _codificar(valor[clave], salida);
    }
  } else {
    throw const FormatoDeSincronizacion();
  }
}

int _compararUtf8(String a, String b) {
  final primera = utf8.encode(a);
  final segunda = utf8.encode(b);
  final limite = primera.length < segunda.length ? primera.length : segunda.length;
  for (var i = 0; i < limite; i++) {
    if (primera[i] != segunda[i]) return primera[i].compareTo(segunda[i]);
  }
  return primera.length.compareTo(segunda.length);
}

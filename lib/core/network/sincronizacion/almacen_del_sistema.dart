import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'credenciales.dart';

/// Sin respaldo a preferencias o SQLite cuando el almacén seguro no está disponible.
class AlmacenDeEnlaceDelSistema implements AlmacenSeguroDeEnlace {
  const AlmacenDeEnlaceDelSistema();
  static const _clave = 'selfcare.enlace.v1';
  static const _almacen = FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: false));
  @override
  Future<String?> leer() => _almacen.read(key: _clave);
  @override
  Future<void> escribir(String valor) => _almacen.write(key: _clave, value: valor);
}

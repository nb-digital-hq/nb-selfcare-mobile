import 'package:http/http.dart' as http;

// Única puerta de red de la app. Todo cliente HTTP se construye aquí, y
// `tool/guardianes/red.dart` rechaza cualquier cliente, socket o imagen remota
// fuera de `lib/core/network/`. Hay exactamente dos destinos y los dos los
// pide la persona con un gesto explícito:
//  - Open Food Facts, al escanear un código que no está en el teléfono o al
//    tocar "Buscar en Open Food Facts"; el resultado se guarda al instante;
//  - la API de publicaciones de GitHub, al tocar "Buscar actualizaciones"
//    (Android).
// No existe telemetría ni ningún otro destino.

/// Motivo por el que la app sale a internet. Cada uno tiene sus hosts.
enum Destino {
  openFoodFacts(<String>{'world.openfoodfacts.org'}),
  actualizaciones(<String>{'api.github.com', 'github.com'});

  const Destino(this.hosts);

  /// Hosts a los que se permite la primera petición. Las redirecciones del
  /// propio servidor (p. ej. GitHub hacia su almacenamiento de archivos) las
  /// sigue el cliente interno sin abrir nuevos destinos desde la app.
  final Set<String> hosts;
}

/// Petición rechazada por ir a un host que no pertenece a su [Destino].
class SalidaNoPermitida implements Exception {
  const SalidaNoPermitida(this.destino, this.host);

  final Destino destino;
  final String host;

  @override
  String toString() => 'SalidaNoPermitida(${destino.name}, $host)';
}

/// Cliente HTTP limitado a los hosts de [destino].
http.Client clienteDeRed(Destino destino) => _ClienteAcotado(destino, http.Client());

class _ClienteAcotado extends http.BaseClient {
  _ClienteAcotado(this._destino, this._interno);

  final Destino _destino;
  final http.Client _interno;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final Uri url = request.url;
    if (url.scheme != 'https' || !_destino.hosts.contains(url.host)) {
      throw SalidaNoPermitida(_destino, url.host);
    }
    return _interno.send(request);
  }

  @override
  void close() => _interno.close();
}

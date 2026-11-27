import 'dart:io';

class CandidatoDePc {
  const CandidatoDePc(this.host, this.puerto);
  final InternetAddress host;
  final int puerto;
  @override
  String toString() => 'CandidatoDePc([REDACTADO])';
}

/// El descubrimiento entrega direcciones; no autentica ni conserva credenciales.
abstract interface class BuscadorDePc {
  Future<List<CandidatoDePc>> buscar({
    required bool Function() autorizado,
    Duration limite = const Duration(seconds: 6),
  });
  void cancelar();
}

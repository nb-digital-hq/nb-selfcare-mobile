import 'dart:convert';

bool identificadorValido(Object? valor) =>
    valor is String && RegExp(r'^[0-9a-f]{32}$').hasMatch(valor);

bool huellaValida(Object? valor) {
  if (valor is! String || valor.length != 44) return false;
  try {
    return base64.decode(valor).length == 32 && base64.encode(base64.decode(valor)) == valor;
  } on FormatException {
    return false;
  }
}

bool credencialValida(Object? valor) {
  if (valor is! String || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(valor)) return false;
  try {
    return base64Url.encode(base64Url.decode(base64Url.normalize(valor))).replaceAll('=', '') ==
        valor;
  } on FormatException {
    return false;
  }
}

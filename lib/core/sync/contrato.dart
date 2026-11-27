import 'dart:convert';

/// Protocolo propio de SelfCare. No autoriza conexiones ni aplica datos al dominio.
const versionSincronizacion = 1;
const maxCambiosPorLote = 200;
const maxBytesPorRegistro = 64 * 1024;
const maxRevisionCompartida = 9007199254740991;

class FormatoDeSincronizacion implements Exception {
  const FormatoDeSincronizacion();
  @override
  String toString() => 'SYNC_INVALID_INPUT';
}

bool _identificador(Object? valor) => valor is String && RegExp(r'^[0-9a-f]{32}$').hasMatch(valor);

bool _unicodeValido(String valor) {
  final unidades = valor.codeUnits;
  for (var i = 0; i < unidades.length; i++) {
    final unidad = unidades[i];
    if (unidad >= 0xd800 && unidad <= 0xdbff) {
      if (++i >= unidades.length || unidades[i] < 0xdc00 || unidades[i] > 0xdfff) return false;
    } else if (unidad >= 0xdc00 && unidad <= 0xdfff) {
      return false;
    }
  }
  return true;
}

bool _estructuraAcotada(Object? valor, [int profundidad = 0]) {
  if (profundidad > 16) return false;
  if (valor == null || valor is bool) return true;
  if (valor is String) return _unicodeValido(valor);
  if (valor is num) return valor.isFinite && valor.abs() <= maxRevisionCompartida;
  if (valor is List) {
    return valor.length <= 512 && valor.every((e) => _estructuraAcotada(e, profundidad + 1));
  }
  if (valor is Map<String, Object?>) {
    return valor.length <= 128 &&
        valor.keys.every(_unicodeValido) &&
        valor.values.every((e) => _estructuraAcotada(e, profundidad + 1));
  }
  return false;
}

// La validación precede esta copia: profundidad y tamaño ya están acotados.
Object? _instantanea(Object? valor) {
  if (valor is Map<String, Object?>) {
    return Map<String, Object?>.unmodifiable(
      valor.map((clave, dato) => MapEntry(clave, _instantanea(dato))),
    );
  }
  if (valor is List<Object?>) {
    return List<Object?>.unmodifiable(valor.map(_instantanea));
  }
  return valor;
}

void _campos(Map<String, Object?> json, Set<String> admitidos) {
  if (json.keys.any((k) => !admitidos.contains(k))) {
    throw const FormatoDeSincronizacion();
  }
}

enum EntidadSincronizada {
  perfil('perfil'),
  inventarioNibi('inventario_nibi'),
  descanso('descanso'),
  alimento('alimento'),
  combo('combo'),
  comboAlimento('combo_alimento'),
  receta('receta'),
  ingrediente('ingrediente'),
  comida('comida'),
  agua('agua'),
  peso('peso'),
  entrenamiento('entrenamiento'),
  ayuno('ayuno'),
  diario('diario'),
  accionNibi('accion_nibi'),
  tratamiento('tratamiento'),
  toma('toma'),
  ciclo('ciclo'),
  digestion('digestion'),
  cafeina('cafeina'),
  plan('plan'),
  meta('meta'),
  sesionCuidado('sesion_cuidado'),
  habito('habito'),
  habitoHecho('habito_hecho'),
  chequeo('chequeo'),
  chequeoHecho('chequeo_hecho'),
  sintoma('sintoma'),
  signo('signo'),
  consumo('consumo'),
  bienestar('bienestar'),
  libre('libre'),
  eventoLibre('evento_libre');

  const EntidadSincronizada(this.codigo);
  final String codigo;
}

enum OperacionSincronizada { guardar, eliminar }

class CambioSincronizado {
  CambioSincronizado._(this.id, this.registro, this.entidad, this.base, this.operacion, this.datos);
  final String id;
  final String registro;
  final EntidadSincronizada entidad;
  final int base;
  final OperacionSincronizada operacion;
  final Map<String, Object?>? datos;

  factory CambioSincronizado.desdeJson(Map<String, Object?> json) {
    _campos(json, {'id', 'registro', 'entidad', 'base', 'operacion', 'datos'});
    final base = json['base'];
    final datos = json['datos'];
    if (!_identificador(json['id']) ||
        !_identificador(json['registro']) ||
        base is! int ||
        base < 0 ||
        base > maxRevisionCompartida) {
      throw const FormatoDeSincronizacion();
    }
    final entidad = EntidadSincronizada.values.firstWhere(
      (e) => e.codigo == json['entidad'],
      orElse: () => throw const FormatoDeSincronizacion(),
    );
    final operacion = OperacionSincronizada.values.firstWhere(
      (e) => e.name == json['operacion'],
      orElse: () => throw const FormatoDeSincronizacion(),
    );
    if (operacion == OperacionSincronizada.guardar) {
      if (datos is! Map<String, Object?> ||
          datos.isEmpty ||
          !_estructuraAcotada(datos) ||
          utf8.encode(jsonEncode(datos)).length > maxBytesPorRegistro) {
        throw const FormatoDeSincronizacion();
      }
    } else if (datos != null) {
      throw const FormatoDeSincronizacion();
    }
    return CambioSincronizado._(
      json['id']! as String,
      json['registro']! as String,
      entidad,
      base,
      operacion,
      datos == null ? null : _instantanea(datos) as Map<String, Object?>,
    );
  }
  Map<String, Object?> aJson() => {
    'id': id,
    'registro': registro,
    'entidad': entidad.codigo,
    'base': base,
    'operacion': operacion.name,
    'datos': datos,
  };
  @override
  String toString() => 'CambioSincronizado([REDACTADO])';
}

class LoteSincronizado {
  LoteSincronizado._(this.nodo, this.lote, this.cambios);
  final String nodo;
  final String lote;
  final List<CambioSincronizado> cambios;

  factory LoteSincronizado.desdeJson(Map<String, Object?> json) {
    _campos(json, {'version', 'nodo', 'lote', 'cambios'});
    final cambios = json['cambios'];
    if (json['version'] is! int ||
        json['version'] != versionSincronizacion ||
        !_identificador(json['nodo']) ||
        !_identificador(json['lote']) ||
        cambios is! List ||
        cambios.isEmpty ||
        cambios.length > maxCambiosPorLote) {
      throw const FormatoDeSincronizacion();
    }
    final resultado = <CambioSincronizado>[];
    final vistos = <String>{};
    for (final entrada in cambios) {
      if (entrada is! Map<String, Object?>) throw const FormatoDeSincronizacion();
      final cambio = CambioSincronizado.desdeJson(entrada);
      if (!vistos.add(cambio.id)) throw const FormatoDeSincronizacion();
      resultado.add(cambio);
    }
    return LoteSincronizado._(
      json['nodo']! as String,
      json['lote']! as String,
      List.unmodifiable(resultado),
    );
  }
  Map<String, Object?> aJson() => {
    'version': versionSincronizacion,
    'nodo': nodo,
    'lote': lote,
    'cambios': cambios.map((e) => e.aJson()).toList(),
  };
  @override
  String toString() =>
      'LoteSincronizado(version: $versionSincronizacion, cantidad: ${cambios.length})';
}

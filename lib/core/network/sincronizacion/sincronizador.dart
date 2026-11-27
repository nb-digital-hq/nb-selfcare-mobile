import '../../database/sincronizacion/motor.dart';
import '../../sync/contrato.dart';
import 'cliente.dart';
import 'credenciales.dart';
import 'validacion.dart';

/// Superficie del cliente que usa el sincronizador; permite probarlo sin sockets.
abstract interface class CanalDeSincronizacion {
  Future<Map<String, Object?>> sincronizar({
    required String nodo,
    required String credencial,
    required Map<String, Object?> peticion,
  });
  void cerrar();
}

class _CanalDelCliente implements CanalDeSincronizacion {
  _CanalDelCliente(this._cliente);
  final ClienteDeEscritorio _cliente;
  @override
  Future<Map<String, Object?>> sincronizar({
    required String nodo,
    required String credencial,
    required Map<String, Object?> peticion,
  }) => _cliente.sincronizar(nodo: nodo, credencial: credencial, peticion: peticion);
  @override
  void cerrar() => _cliente.cerrar();
}

class ResumenDeSincronizacion {
  const ResumenDeSincronizacion({
    required this.enviados,
    required this.recibidos,
    required this.enRevision,
  });
  final int enviados;
  final int recibidos;
  final int enRevision;
  @override
  String toString() => 'ResumenDeSincronizacion([REDACTADO])';
}

/// Un ciclo completo con el escritorio emparejado: envía lo pendiente, aplica lo
/// recibido y avanza el cursor. Si el escritorio restauró una copia, vuelve a leer.
class SincronizadorConPc {
  SincronizadorConPc({
    required this._motor,
    required this._credenciales,
    required bool Function() autorizado,
    required DateTime Function() ahora,
    CanalDeSincronizacion Function(PcEmparejado pc)? crearCanal,
  }) : _ahora = ahora,
       _crearCanal =
           crearCanal ??
           ((pc) => _CanalDelCliente(
             ClienteDeEscritorio(
               host: pc.host,
               puerto: pc.puerto,
               huella: pc.huella,
               autorizado: autorizado,
               ahora: ahora,
             ),
           ));

  final MotorDeSincronizacion _motor;
  final CredencialesDelEnlace _credenciales;
  final DateTime Function() _ahora;
  final CanalDeSincronizacion Function(PcEmparejado) _crearCanal;
  bool _enCurso = false;

  Future<ResumenDeSincronizacion> sincronizar() async {
    if (_enCurso) throw const FalloDeEnlace('COMPONENT_UNAVAILABLE');
    _enCurso = true;
    try {
      return await _ciclo();
    } finally {
      _enCurso = false;
    }
  }

  Future<ResumenDeSincronizacion> _ciclo() async {
    final estado = await _credenciales.cargar();
    final pc = estado.pc;
    if (pc == null) throw const FalloDeEnlace('NOT_FOUND');
    final canal = _crearCanal(pc);
    var enviados = 0;
    var recibidos = 0;
    try {
      for (var vuelta = 0; vuelta < 100; vuelta++) {
        final cursor = await _motor.cursor(pc.nodo);
        final lote = await _motor.pendientes();
        final respuesta = await canal.sincronizar(
          nodo: estado.nodo,
          credencial: pc.credencial,
          peticion: {
            'version': versionSincronizacion,
            'epoca': cursor.epoca,
            'cursor': cursor.cursor,
            'lote': lote.isEmpty
                ? null
                : {
                    'version': versionSincronizacion,
                    'nodo': estado.nodo,
                    'lote': identificadorAleatorio(),
                    'cambios': [for (final c in lote) c.aJson()],
                  },
          },
        );
        final r = _leerRespuesta(respuesta);
        await _motor.confirmar(lote, r.resultados);
        enviados += r.resultados.where((x) => x.estado == 'aplicado').length;
        recibidos += await _motor.aplicar(pc.nodo, r.cambios);
        await _motor.guardarCursor(pc.nodo, r.epoca, r.cursor, _ahora().toIso8601String());
        if (r.reiniciar) continue;
        if (lote.isEmpty && !r.mas) break;
      }
      final resumen = await _motor.resumen();
      return ResumenDeSincronizacion(
        enviados: enviados,
        recibidos: recibidos,
        enRevision: resumen.enRevision,
      );
    } finally {
      canal.cerrar();
    }
  }

  static ({
    String epoca,
    bool reiniciar,
    List<ResultadoDelPc> resultados,
    List<CambioSincronizado> cambios,
    int cursor,
    bool mas,
  })
  _leerRespuesta(Map<String, Object?> json) {
    const campos = {'version', 'epoca', 'reiniciar', 'resultados', 'cambios', 'cursor', 'mas'};
    final epoca = json['epoca'];
    final reiniciar = json['reiniciar'];
    final resultados = json['resultados'];
    final cambios = json['cambios'];
    final cursor = json['cursor'];
    final mas = json['mas'];
    if (json.length != campos.length ||
        !json.keys.every(campos.contains) ||
        json['version'] != versionSincronizacion ||
        !identificadorValido(epoca) ||
        reiniciar is! bool ||
        mas is! bool ||
        cursor is! int ||
        cursor < 0 ||
        resultados is! List ||
        cambios is! List ||
        resultados.length > maxCambiosPorLote ||
        cambios.length > maxCambiosPorLote) {
      throw const FalloDeEnlace('INVALID_INPUT');
    }
    try {
      return (
        epoca: epoca! as String,
        reiniciar: reiniciar,
        resultados: [
          for (final x in resultados.cast<Map<String, Object?>>())
            if (identificadorValido(x['id']) &&
                const {'aplicado', 'conflicto', 'rechazado'}.contains(x['estado']) &&
                x['revision'] is int)
              ResultadoDelPc(x['id']! as String, x['estado']! as String, x['revision']! as int)
            else
              throw const FalloDeEnlace('INVALID_INPUT'),
        ],
        cambios: [
          for (final c in cambios.cast<Map<String, Object?>>()) CambioSincronizado.desdeJson(c),
        ],
        cursor: cursor,
        mas: mas,
      );
    } on FormatoDeSincronizacion {
      throw const FalloDeEnlace('INVALID_INPUT');
    } on TypeError {
      throw const FalloDeEnlace('INVALID_INPUT');
    }
  }
}

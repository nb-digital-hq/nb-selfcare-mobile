import 'dart:async';
import 'dart:io';

import 'package:nsd/nsd.dart' as nsd;

import 'candidatos.dart';
import 'cliente.dart';
import 'invitacion.dart';

export 'candidatos.dart';

const tipoDeServicioSelfCare = '_nb-selfcare._tcp';

/// Devuelve candidatos, nunca identidad autenticada. Cada conexión posterior sigue
/// verificando el pin antes de entregar una credencial. El propietario cancela al
/// pausar la app o revocar el permiso. No habilita registros del plugin.
class DescubridorDePc implements BuscadorDePc {
  DescubridorDePc({
    Future<nsd.Discovery> Function()? iniciar,
    Future<void> Function(nsd.Discovery)? detener,
    Future<nsd.Service> Function(nsd.Service)? resolver,
    Future<List<InternetAddress>> Function(String)? resolverHost,
  }) : _iniciar = iniciar ?? (() => nsd.startDiscovery(tipoDeServicioSelfCare, autoResolve: false)),
       _detener = detener ?? nsd.stopDiscovery,
       _resolver = resolver ?? nsd.resolve,
       _resolverHost = resolverHost ?? (InternetAddress.lookup);

  final Future<nsd.Discovery> Function() _iniciar;
  final Future<void> Function(nsd.Discovery) _detener;
  final Future<nsd.Service> Function(nsd.Service) _resolver;
  final Future<List<InternetAddress>> Function(String) _resolverHost;
  Completer<void>? _cancelacion;
  bool _inicioPendiente = false;
  bool _cierrePendiente = false;
  bool _cierreFallido = false;

  @override
  void cancelar() {
    final actual = _cancelacion;
    if (actual != null && !actual.isCompleted) actual.complete();
  }

  @override
  Future<List<CandidatoDePc>> buscar({
    required bool Function() autorizado,
    Duration limite = const Duration(seconds: 6),
  }) async {
    if (!autorizado()) throw const FalloDeEnlace('CONSENT_REQUIRED');
    if (_cancelacion != null || _inicioPendiente || _cierrePendiente || _cierreFallido) {
      throw const FalloDeEnlace('COMPONENT_UNAVAILABLE');
    }
    if (limite <= Duration.zero || limite > const Duration(seconds: 10)) {
      throw const FalloDeEnlace('INVALID_INPUT');
    }
    final cancelacion = Completer<void>();
    _cancelacion = cancelacion;
    final fin = Completer<void>();
    final temporizador = Timer(limite, fin.complete);
    var cerrada = false;
    var cierreSolicitado = false;
    nsd.Discovery? sesion;
    final candidatos = <String, CandidatoDePc>{};
    final vistos = <String>{};
    final cola = <nsd.Service>[];
    var activos = 0;
    bool vigente() => !cerrada && !fin.isCompleted && !cancelacion.isCompleted && autorizado();
    Future<void> cerrar(nsd.Discovery d) async {
      if (cierreSolicitado) return;
      cierreSolicitado = true;
      _cierrePendiente = true;
      final operacion = Future<void>.sync(() => _detener(d));
      unawaited(
        operacion.then<void>(
          (_) {
            _cierrePendiente = false;
          },
          onError: (Object _, StackTrace _) {
            _cierrePendiente = false;
            _cierreFallido = true;
          },
        ),
      );
      await operacion.timeout(const Duration(seconds: 2));
    }

    Future<void> procesar(nsd.Service servicio) async {
      try {
        if (!vigente()) return;
        final resuelto = await _resolver(servicio).timeout(const Duration(seconds: 2));
        if (!vigente() || resuelto.port == null || resuelto.port! < 1 || resuelto.port! > 65535) {
          return;
        }
        final version = resuelto.txt?['version'];
        if (version == null || version.length != 1 || version.single != 49) return;
        var direcciones = resuelto.addresses ?? <InternetAddress>[];
        if (direcciones.isEmpty && resuelto.host != null) {
          final host = resuelto.host!;
          final ip = InternetAddress.tryParse(host);
          if (ip != null) {
            direcciones = [ip];
          } else if (RegExp(
            r'^nbselfcare-[a-z0-9-]{1,48}\.local\.?$',
            caseSensitive: false,
          ).hasMatch(host)) {
            // El lookup automático del plugin está desactivado: un anuncio no
            // puede hacer consultar DNS público antes de validar su anfitrión.
            if (!vigente()) return;
            direcciones = await _resolverHost(host).timeout(const Duration(seconds: 2));
          }
        }
        if (!vigente()) return;
        for (final ip in direcciones.take(32)) {
          if (candidatos.length >= 8) break;
          if (!esDireccionLocal(ip) ||
              ip.isLoopback ||
              ip.address.contains('%') ||
              (ip.type == InternetAddressType.IPv6 &&
                  ip.rawAddress[0] == 0xfe &&
                  (ip.rawAddress[1] & 0xc0) == 0x80)) {
            continue;
          }
          candidatos['${ip.address}:${resuelto.port}'] = CandidatoDePc(ip, resuelto.port!);
        }
      } catch (_) {
        // Un anuncio defectuoso no impide resolver otros pares y no se registra.
      }
    }

    void bombear() {
      while (vigente() && activos < 2 && cola.isNotEmpty) {
        final servicio = cola.removeAt(0);
        activos++;
        unawaited(
          procesar(servicio).whenComplete(() {
            activos--;
            bombear();
          }),
        );
      }
    }

    void escuchar(nsd.Service servicio, nsd.ServiceStatus estado) {
      final nombre = servicio.name;
      if (!vigente() ||
          estado != nsd.ServiceStatus.found ||
          vistos.length >= 8 ||
          servicio.type?.replaceFirst(RegExp(r'\.$'), '') != tipoDeServicioSelfCare ||
          nombre == null ||
          nombre.length > 63 ||
          !nombre.startsWith('SelfCare-') ||
          !vistos.add(nombre)) {
        return;
      }
      cola.add(servicio);
      bombear();
    }

    try {
      _inicioPendiente = true;
      final inicio = Future<nsd.Discovery>.sync(_iniciar).then(
        (d) {
          _inicioPendiente = false;
          sesion = d;
          if (cerrada) unawaited(cerrar(d).catchError((Object _) {}));
          return d;
        },
        onError: (Object error, StackTrace traza) {
          _inicioPendiente = false;
          Error.throwWithStackTrace(error, traza);
        },
      );
      final d = await Future.any<nsd.Discovery>([
        inicio,
        fin.future.then((_) => throw const FalloDeEnlace('NETWORK_FAILURE')),
        cancelacion.future.then((_) => throw const FalloDeEnlace('CANCELLED')),
      ]);
      d.addServiceListener(escuchar);
      for (final servicio in d.services.take(8)) {
        escuchar(servicio, nsd.ServiceStatus.found);
      }
      await Future.any<void>([fin.future, cancelacion.future]);
      if (!autorizado()) throw const FalloDeEnlace('CONSENT_REQUIRED');
      if (cancelacion.isCompleted) throw const FalloDeEnlace('CANCELLED');
      return List<CandidatoDePc>.unmodifiable(candidatos.values);
    } on FalloDeEnlace {
      rethrow;
    } catch (_) {
      throw const FalloDeEnlace('NETWORK_FAILURE');
    } finally {
      cerrada = true;
      temporizador.cancel();
      final d = sesion;
      if (d != null) {
        d.removeServiceListener(escuchar);
        try {
          await cerrar(d);
        } catch (_) {
          /* La operación de cierre ya fue solicitada al sistema. */
        }
      }
      _cancelacion = null;
    }
  }
}

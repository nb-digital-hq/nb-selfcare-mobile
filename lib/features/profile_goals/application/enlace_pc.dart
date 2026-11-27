import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/sincronizacion/motor.dart';
import '../../../core/network/sincronizacion/almacen_del_sistema.dart';
import '../../../core/network/sincronizacion/cliente.dart';
import '../../../core/network/sincronizacion/credenciales.dart';
import '../../../core/network/sincronizacion/descubrimiento.dart';
import '../../../core/network/sincronizacion/invitacion.dart';
import '../../../core/network/sincronizacion/reconexion.dart';
import '../../../core/network/sincronizacion/sincronizador.dart';
import '../../../core/sync/contrato.dart';

/// Preferencia local: la persona vinculó este teléfono con un ordenador y permite
/// hablar con él dentro de su red. Retirarla detiene cualquier conexión.
const preferenciaEnlacePc = 'sync.pc.permitido';

class EstadoEnlacePc {
  const EstadoEnlacePc({
    this.cargando = true,
    this.vinculado = false,
    this.sincronizando = false,
    this.ultima,
    this.pendientes = 0,
    this.enRevision = 0,
    this.error,
  });
  final bool cargando;
  final bool vinculado;
  final bool sincronizando;
  final DateTime? ultima;
  final int pendientes;
  final int enRevision;

  /// Código canónico del último fallo, sin detalles de red ni contenido.
  final String? error;

  EstadoEnlacePc copiar({
    bool? cargando,
    bool? vinculado,
    bool? sincronizando,
    DateTime? ultima,
    int? pendientes,
    int? enRevision,
    String? error,
    bool sinError = false,
  }) => EstadoEnlacePc(
    cargando: cargando ?? this.cargando,
    vinculado: vinculado ?? this.vinculado,
    sincronizando: sincronizando ?? this.sincronizando,
    ultima: ultima ?? this.ultima,
    pendientes: pendientes ?? this.pendientes,
    enRevision: enRevision ?? this.enRevision,
    error: sinError ? null : (error ?? this.error),
  );
}

final credencialesDelEnlaceProvider = Provider<CredencialesDelEnlace>(
  (Ref ref) => CredencialesDelEnlace(const AlmacenDeEnlaceDelSistema()),
);

final enlacePcProvider = NotifierProvider<EnlacePc, EstadoEnlacePc>(EnlacePc.new);

/// Caso de uso de la conexión con SelfCare de escritorio: vincular con el QR,
/// sincronizar y desvincular. La presentación no toca la red ni SQLite.
class EnlacePc extends Notifier<EstadoEnlacePc> {
  bool _permitido = false;
  SincronizadorConPc? _sincronizador;

  AppDatabase get _db => ref.read(appDatabaseProvider);
  DateTime _ahora() => ref.read(clockProvider).now();

  @override
  EstadoEnlacePc build() {
    unawaited(_cargar());
    return const EstadoEnlacePc();
  }

  SincronizadorConPc get _sync => _sincronizador ??= SincronizadorConPc(
    motor: MotorDeSincronizacion(_db),
    credenciales: ref.read(credencialesDelEnlaceProvider),
    autorizado: () => _permitido,
    ahora: _ahora,
  );

  Future<void> _cargar() async {
    try {
      _permitido = await _db.readUiPreference(preferenciaEnlacePc) == '1';
      final enlace = await ref.read(credencialesDelEnlaceProvider).cargar();
      final resumen = await MotorDeSincronizacion(_db).resumen();
      state = state.copiar(
        cargando: false,
        vinculado: _permitido && enlace.pc != null,
        ultima: resumen.ultima == null ? null : DateTime.tryParse(resumen.ultima!),
        pendientes: resumen.pendientes,
        enRevision: resumen.enRevision,
      );
    } on Object {
      state = state.copiar(cargando: false, error: 'STORAGE_FAILURE');
    }
  }

  /// Vincula con el texto del QR que muestra el ordenador y hace la primera sincronización.
  Future<bool> vincular(String textoQr) async {
    final InvitacionDeEscritorio invitacion;
    try {
      invitacion = InvitacionDeEscritorio.desdeTexto(textoQr);
    } on FormatoDeSincronizacion {
      state = state.copiar(error: 'INVALID_INPUT');
      return false;
    }
    _permitido = true;
    final cliente = ClienteDeEscritorio(
      host: invitacion.host,
      puerto: invitacion.puerto,
      huella: invitacion.huella,
      autorizado: () => _permitido,
      ahora: _ahora,
    );
    try {
      final credenciales = ref.read(credencialesDelEnlaceProvider);
      final propio = await credenciales.cargar();
      final alta = await cliente.emparejar(invitacion, propio.nodo);
      await credenciales.guardarPc(PcEmparejado.desdeAlta(invitacion, alta));
      await _db.writeUiPreference(preferenciaEnlacePc, '1');
      state = state.copiar(vinculado: true, sinError: true);
    } on FalloDeEnlace catch (e) {
      _permitido = state.vinculado;
      state = state.copiar(error: e.codigo);
      return false;
    } finally {
      cliente.cerrar();
    }
    await sincronizar();
    return true;
  }

  /// Un ciclo de sincronización. En silencio, los fallos de red no se muestran:
  /// el teléfono sigue funcionando sin el ordenador.
  Future<void> sincronizar({bool silencioso = false}) async {
    if (!_permitido || state.sincronizando || !state.vinculado) return;
    state = state.copiar(sincronizando: true, sinError: true);
    try {
      try {
        await _sync.sincronizar();
      } on FalloDeEnlace catch (e) {
        if (e.codigo != 'NETWORK_FAILURE') rethrow;
        // El ordenador pudo cambiar de dirección o de puerto: se busca en la red local
        // con el mismo certificado fijado y se reintenta una vez.
        await RestablecedorDelEnlace(
          credenciales: ref.read(credencialesDelEnlaceProvider),
          descubridor: DescubridorDePc(),
          autorizado: () => _permitido,
          ahora: _ahora,
        ).reconectar(plazoTotal: const Duration(seconds: 15));
        await _sync.sincronizar();
      }
      final resumen = await MotorDeSincronizacion(_db).resumen();
      state = state.copiar(
        sincronizando: false,
        ultima: _ahora(),
        pendientes: resumen.pendientes,
        enRevision: resumen.enRevision,
      );
    } on FalloDeEnlace catch (e) {
      state = state.copiar(sincronizando: false, error: silencioso ? null : e.codigo);
    } on Object {
      state = state.copiar(sincronizando: false, error: silencioso ? null : 'INTERNAL');
    }
  }

  /// Retira el vínculo en este teléfono. Los datos se conservan en ambos equipos.
  Future<void> desvincular() async {
    _permitido = false;
    await ref.read(credencialesDelEnlaceProvider).guardarPc(null);
    await _db.writeUiPreference(preferenciaEnlacePc, '0');
    state = state.copiar(vinculado: false, sinError: true);
  }
}

/// Sincroniza al volver a la app, cada pocos minutos en primer plano y poco
/// después de cada escritura local. Nunca en segundo plano.
class SincronizacionAutomatica {
  SincronizacionAutomatica(this._ref);
  final Ref _ref;
  AppLifecycleListener? _ciclo;
  Timer? _periodico;
  Timer? _tras;
  StreamSubscription<Object?>? _cambios;

  void iniciar() {
    _ciclo = AppLifecycleListener(
      onResume: () {
        _programarPeriodico();
        _ahora();
      },
      onPause: () {
        _periodico?.cancel();
        _tras?.cancel();
      },
    );
    _programarPeriodico();
    _cambios = _ref.read(appDatabaseProvider).tableUpdates().listen((_) {
      _tras?.cancel();
      _tras = Timer(const Duration(seconds: 20), _ahora);
    });
    _ahora();
  }

  void _programarPeriodico() {
    _periodico?.cancel();
    _periodico = Timer.periodic(const Duration(minutes: 5), (_) => _ahora());
  }

  void _ahora() => unawaited(_ref.read(enlacePcProvider.notifier).sincronizar(silencioso: true));

  void detener() {
    _ciclo?.dispose();
    _periodico?.cancel();
    _tras?.cancel();
    unawaited(_cambios?.cancel());
  }
}

final sincronizacionAutomaticaProvider = Provider<SincronizacionAutomatica>((Ref ref) {
  final s = SincronizacionAutomatica(ref)..iniciar();
  ref.onDispose(s.detener);
  return s;
});

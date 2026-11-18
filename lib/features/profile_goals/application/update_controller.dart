import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/update_service.dart';

enum UpdatePhase { idle, checking, upToDate, available, downloading, ready, error }

/// Estado de Ajustes › Acerca de. [failure] o [needsPermission] explican el
/// último paso que no siguió; la UI los traduce.
class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.installedVersion = '',
    this.release,
    this.progress = 0,
    this.failure,
    this.needsPermission = false,
  });

  final UpdatePhase phase;
  final String installedVersion;
  final Publicacion? release;
  final double progress;
  final UpdateFailure? failure;
  final bool needsPermission;

  bool get busy => phase == UpdatePhase.checking || phase == UpdatePhase.downloading;

  bool get hasNewVersion =>
      phase == UpdatePhase.available ||
      phase == UpdatePhase.downloading ||
      phase == UpdatePhase.ready;

  UpdateState copyWith({
    UpdatePhase? phase,
    String? installedVersion,
    Publicacion? release,
    double? progress,
    UpdateFailure? failure,
    bool needsPermission = false,
  }) => UpdateState(
    phase: phase ?? this.phase,
    installedVersion: installedVersion ?? this.installedVersion,
    release: release ?? this.release,
    progress: progress ?? this.progress,
    failure: failure,
    needsPermission: needsPermission,
  );
}

/// Actualización desde GitHub (como NB Sound): nunca consulta sola; el botón
/// "Buscar actualizaciones" es el consentimiento (ADR-18). Android solo instala
/// un APK firmado con la misma llave que la app instalada.
class UpdateController extends Notifier<UpdateState> {
  List<String> _abis = const <String>[];
  File? _apk;

  UpdateService get _s => ref.read(updateServiceProvider);

  @override
  UpdateState build() {
    unawaited(Future<void>(_loadVersion));
    return const UpdateState();
  }

  Future<void> _loadVersion() async {
    final ({String version, List<String> abis}) i = await _s.info();
    _abis = i.abis;
    state = state.copyWith(installedVersion: i.version, failure: state.failure);
  }

  Future<void> check() async {
    if (state.busy) return;
    state = state.copyWith(phase: UpdatePhase.checking);
    try {
      if (state.installedVersion.isEmpty) await _loadVersion();
      final Publicacion p = await _s.ultimaPublicacion();
      state = state.copyWith(
        phase: compararVersiones(p.version, state.installedVersion) > 0
            ? UpdatePhase.available
            : UpdatePhase.upToDate,
        release: p,
      );
    } on UpdateError catch (e) {
      state = state.copyWith(phase: UpdatePhase.error, failure: e.motivo);
    }
  }

  /// Descarga (si hace falta) e instala la versión nueva.
  Future<void> install() async {
    final Publicacion? p = state.release;
    if (p == null || state.busy) return;
    try {
      if (!await _s.puedeInstalar()) {
        await _s.abrirPermisoInstalar();
        state = state.copyWith(needsPermission: true);
        return;
      }
      File? apk = _apk;
      if (apk == null || !apk.existsSync()) {
        final ApkPublicado? chosen = elegirApk(p.apks, _abis);
        if (chosen == null) throw const UpdateError(UpdateFailure.sinApk);
        final Directory dir = await _s.carpetaTemporal();
        final File target = File('${dir.path}/nb_selfcare_update.apk');
        if (target.existsSync()) await target.delete();
        state = state.copyWith(phase: UpdatePhase.downloading, progress: 0);
        apk = await _s.descargar(
          chosen,
          target,
          onProgreso: (double v) => state = state.copyWith(progress: v),
        );
        _apk = apk;
      }
      state = state.copyWith(phase: UpdatePhase.ready, progress: 1);
      await _s.instalar(apk);
    } on UpdateError catch (e) {
      state = state.copyWith(phase: UpdatePhase.available, failure: e.motivo);
    }
  }

  void openRepo() => unawaited(_s.abrirUrl(kUrlRepo));
}

final NotifierProvider<UpdateController, UpdateState> updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

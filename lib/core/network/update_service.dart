import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'salidas.dart';

/// Repositorio de GitHub donde se publican las versiones de NB SelfCare Mobile.
const String kRepoGithub = 'nb-digital-hq/nb-selfcare-mobile';
const String kUrlRepo = 'https://github.com/$kRepoGithub';
const String kUrlUltimaRelease = 'https://api.github.com/repos/$kRepoGithub/releases/latest';

/// Un APK adjunto a una publicación.
class ApkPublicado {
  const ApkPublicado({required this.nombre, required this.url, required this.bytes, this.sha256});

  final String nombre;
  final String url;
  final int bytes;

  /// Huella publicada por GitHub (`digest: sha256:…`), si la hay.
  final String? sha256;
}

/// Una versión publicada en GitHub.
class Publicacion {
  const Publicacion({
    required this.version,
    required this.notas,
    required this.apks,
    required this.url,
  });

  /// Lee la respuesta de `releases/latest`. Los campos que falten o vengan
  /// con otro tipo se ignoran: nunca rompe la pantalla.
  factory Publicacion.fromJson(Map<String, Object?> j) {
    final String tag = (j['tag_name'] is String ? j['tag_name']! as String : '').trim();
    final Object? assets = j['assets'];
    return Publicacion(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      notas: (j['body'] is String ? j['body']! as String : '').trim(),
      url: j['html_url'] is String ? j['html_url']! as String : kUrlRepo,
      apks: <ApkPublicado>[
        if (assets is List<Object?>)
          for (final Object? a in assets)
            if (a is Map<String, Object?> &&
                a['name'] is String &&
                (a['name']! as String).toLowerCase().endsWith('.apk'))
              ApkPublicado(
                nombre: a['name']! as String,
                url: a['browser_download_url'] is String
                    ? a['browser_download_url']! as String
                    : '',
                bytes: a['size'] is num ? (a['size']! as num).toInt() : 0,
                sha256: switch (a['digest']) {
                  final String d when d.startsWith('sha256:') => d.substring(7).toLowerCase(),
                  _ => null,
                },
              ),
      ],
    );
  }

  /// Versión sin la `v` inicial (p. ej. `1.2.0`).
  final String version;
  final String notas;
  final List<ApkPublicado> apks;
  final String url;
}

/// Compara dos versiones `x.y.z` (ignora sufijos `-…`/`+…`). >0 si [a] es mayor.
int compararVersiones(String a, String b) {
  List<int> partes(String v) => v
      .split(RegExp(r'[-+]'))
      .first
      .split('.')
      .map((String p) => int.tryParse(p.trim()) ?? 0)
      .toList();
  final List<int> x = partes(a);
  final List<int> y = partes(b);
  for (int i = 0; i < 3; i++) {
    final int d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

/// Elige el APK para un dispositivo con [abis] (en orden de preferencia).
///
/// Se usa siempre el de la ABI: con `--split-per-abi` su versionCode es mayor
/// que el del universal, así que el universal no podría instalarse encima. Solo
/// si la publicación no trae APK por ABI se recurre al universal.
ApkPublicado? elegirApk(List<ApkPublicado> apks, List<String> abis) {
  for (final String abi in abis) {
    for (final ApkPublicado a in apks) {
      if (a.nombre.contains('-$abi.apk') || a.nombre.contains('-$abi-')) return a;
    }
  }
  final bool hayPorAbi = apks.any(
    (ApkPublicado a) => RegExp(r'(arm64-v8a|armeabi-v7a|x86_64|x86)').hasMatch(a.nombre),
  );
  if (hayPorAbi) return null;
  for (final ApkPublicado a in apks) {
    if (a.nombre.contains('universal')) return a;
  }
  return apks.length == 1 ? apks.first : null;
}

/// Motivos por los que una actualización no siguió (la UI los traduce).
enum UpdateFailure {
  sinPublicaciones,
  limiteGithub,
  sinConexion,
  sinApk,
  descargaFallida,
  descargaIncompleta,
  huellaDistinta,
  instalacionFallida,
}

class UpdateError implements Exception {
  const UpdateError(this.motivo);

  final UpdateFailure motivo;

  @override
  String toString() => 'UpdateError($motivo)';
}

/// Acceso a GitHub (solo cuando la persona lo pide) y al instalador nativo.
class UpdateService {
  UpdateService({http.Client? client, MethodChannel? channel})
    : _client = client ?? clienteDeRed(Destino.actualizaciones),
      _channel = channel ?? const MethodChannel('com.nb.selfcare/updater');

  final http.Client _client;
  final MethodChannel _channel;

  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'NB-SelfCare-Mobile',
  };

  /// Versión instalada y ABIs del teléfono.
  Future<({String version, List<String> abis})> info() async {
    try {
      final Map<Object?, Object?>? r = await _channel.invokeMapMethod<Object?, Object?>('info');
      final Object? abis = r?['abis'];
      return (
        version: r?['version'] is String ? r!['version']! as String : '',
        abis: <String>[
          if (abis is List<Object?>)
            for (final Object? a in abis)
              if (a is String) a,
        ],
      );
    } on MissingPluginException {
      return (version: '', abis: const <String>[]);
    }
  }

  Future<Publicacion> ultimaPublicacion() async {
    final http.Response r;
    try {
      r = await _client
          .get(Uri.parse(kUrlUltimaRelease), headers: _headers)
          .timeout(const Duration(seconds: 20));
    } on Exception {
      throw const UpdateError(UpdateFailure.sinConexion);
    }
    if (r.statusCode == 404) throw const UpdateError(UpdateFailure.sinPublicaciones);
    if (r.statusCode == 403 || r.statusCode == 429) {
      throw const UpdateError(UpdateFailure.limiteGithub);
    }
    if (r.statusCode != 200) throw const UpdateError(UpdateFailure.sinConexion);
    final Object? body = jsonDecode(r.body);
    if (body is! Map<String, Object?>) throw const UpdateError(UpdateFailure.sinPublicaciones);
    return Publicacion.fromJson(body);
  }

  /// Descarga [apk] a [destino] y comprueba tamaño y huella SHA-256.
  Future<File> descargar(
    ApkPublicado apk,
    File destino, {
    void Function(double progreso)? onProgreso,
  }) async {
    try {
      final http.StreamedResponse r = await _client
          .send(
            http.Request('GET', Uri.parse(apk.url))..headers['User-Agent'] = 'NB-SelfCare-Mobile',
          )
          .timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) throw const UpdateError(UpdateFailure.descargaFallida);
      final int total = r.contentLength ?? apk.bytes;
      final IOSink sink = destino.openWrite();
      int recibido = 0;
      try {
        await for (final List<int> chunk in r.stream.timeout(const Duration(seconds: 60))) {
          sink.add(chunk);
          recibido += chunk.length;
          if (total > 0) onProgreso?.call((recibido / total).clamp(0.0, 1.0));
        }
      } finally {
        await sink.close();
      }
    } on UpdateError {
      rethrow;
    } on Exception {
      throw const UpdateError(UpdateFailure.descargaFallida);
    }
    final int tam = await destino.length();
    if (apk.bytes > 0 && tam != apk.bytes) {
      await destino.delete();
      throw const UpdateError(UpdateFailure.descargaIncompleta);
    }
    final String? esperado = apk.sha256;
    if (esperado != null) {
      final Digest d = await sha256.bind(destino.openRead()).first;
      if (d.toString() != esperado) {
        await destino.delete();
        throw const UpdateError(UpdateFailure.huellaDistinta);
      }
    }
    return destino;
  }

  Future<bool> puedeInstalar() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

  Future<void> abrirPermisoInstalar() => _channel.invokeMethod<void>('openInstallSettings');

  /// Directorio temporal donde se guarda el APK descargado.
  Future<Directory> carpetaTemporal() => getTemporaryDirectory();

  Future<void> instalar(File apk) async {
    try {
      await _channel.invokeMethod<bool>('install', <String, String>{'path': apk.path});
    } on PlatformException {
      throw const UpdateError(UpdateFailure.instalacionFallida);
    }
  }

  Future<void> abrirUrl(String url) =>
      _channel.invokeMethod<void>('openUrl', <String, String>{'url': url});
}

final Provider<UpdateService> updateServiceProvider = Provider<UpdateService>(
  (Ref ref) => UpdateService(),
);

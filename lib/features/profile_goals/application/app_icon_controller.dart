import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/theme/sc_theme.dart';

/// Preferencia local con el ícono elegido.
const String kAppIconPrefKey = 'app_icon';

/// Íconos que la app ofrece: `''` es el por defecto (rojo del logo) y cada
/// tema del catálogo tiene el suyo (el logo con el color de acento del tema).
List<String> availableAppIcons() => <String>['', for (final ScThemeDef t in kScThemes) t.key];

/// True si [key] es un ícono que la app ofrece.
bool isValidAppIcon(String key) => key.isEmpty || kScThemes.any((ScThemeDef t) => t.key == key);

/// Asset del logo para [key] (mismo dibujo que el ícono del lanzador).
String appIconAsset(String key) =>
    'assets/app_icons/logo_${key.isEmpty || !isValidAppIcon(key) ? 'default' : key}.png';

/// Ícono activo. Conmuta el ícono del lanzador de Android vía activity-alias
/// (canal nativo) y guarda la elección en las preferencias locales.
class AppIconController extends Notifier<String> {
  static const MethodChannel _channel = MethodChannel('com.nb.selfcare/app_icon');

  @override
  String build() {
    unawaited(Future<void>(_load));
    return '';
  }

  Future<void> _load() async {
    final String? saved = await ref.read(appDatabaseProvider).readUiPreference(kAppIconPrefKey);
    if (saved == null || saved == state) return;
    if (!isValidAppIcon(saved)) {
      // Un tema retirado: se vuelve al ícono por defecto.
      state = saved;
      await select('');
      return;
    }
    state = saved;
  }

  /// Aplica el ícono [key]. Android lo cambia al salir de la app (cambiarlo
  /// con la app abierta la cerraría de golpe).
  Future<void> select(String key) async {
    final String previous = state;
    if (key == previous) return;
    state = key;
    await ref.read(appDatabaseProvider).writeUiPreference(kAppIconPrefKey, key);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setIcon', <String, String>{
        'key': key,
        'previous': previous,
      });
    } on PlatformException {
      // La preferencia queda guardada; se reintenta la próxima vez.
    } on MissingPluginException {
      // Pruebas y plataformas sin el canal nativo.
    }
  }
}

final NotifierProvider<AppIconController, String> appIconProvider =
    NotifierProvider<AppIconController, String>(AppIconController.new);

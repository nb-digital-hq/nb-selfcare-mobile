import 'dart:async';

import 'package:flutter/widgets.dart' show Locale, WidgetsFlutterBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import 'generated/app_localizations.dart';

/// Idiomas de la interfaz. [sistema] sigue la configuración del teléfono; lo
/// que no sea inglés ni portugués cae en español, el idioma fuente.
enum Idioma { sistema, es, en, pt }

/// Clave de la preferencia en `ui_preferences`.
const String kIdiomaPrefKey = 'idioma';

/// Idioma efectivo de [preferido] (nunca [Idioma.sistema]).
Locale localeDe(Idioma preferido, {Locale? delSistema}) {
  final Idioma efectivo = preferido == Idioma.sistema
      ? switch ((delSistema ?? _localeDelSistema()).languageCode) {
          'en' => Idioma.en,
          'pt' => Idioma.pt,
          _ => Idioma.es,
        }
      : preferido;
  return Locale(efectivo == Idioma.sistema ? 'es' : efectivo.name);
}

/// Locale del sistema a través del binding, para que las pruebas puedan fijarlo.
Locale _localeDelSistema() => WidgetsFlutterBinding.ensureInitialized().platformDispatcher.locale;

Idioma idiomaDeClave(String? clave) =>
    Idioma.values.firstWhere((Idioma i) => i.name == clave, orElse: () => Idioma.sistema);

/// Preferencia de idioma, persistida. Al cambiar fija también el formato de
/// cifras y fechas de `intl` ("82,5" en español y portugués, "82.5" en inglés).
class IdiomaController extends Notifier<Idioma> {
  @override
  Idioma build() {
    unawaited(_hidratar());
    _aplicar(Idioma.sistema);
    return Idioma.sistema;
  }

  Future<void> _hidratar() async {
    try {
      final String? guardado = await ref.read(appDatabaseProvider).readUiPreference(kIdiomaPrefKey);
      final Idioma idioma = idiomaDeClave(guardado);
      if (idioma != state) {
        _aplicar(idioma);
        state = idioma;
      }
    } on Object {
      // Sin base de datos (pruebas o cierre) se queda el idioma del sistema.
    }
  }

  Future<void> elegir(Idioma idioma) async {
    _aplicar(idioma);
    state = idioma;
    await ref.read(appDatabaseProvider).writeUiPreference(kIdiomaPrefKey, idioma.name);
  }

  void _aplicar(Idioma idioma) => Intl.defaultLocale = localeDe(idioma).languageCode;
}

final NotifierProvider<IdiomaController, Idioma> idiomaControllerProvider =
    NotifierProvider<IdiomaController, Idioma>(IdiomaController.new);

/// Locale efectivo de la interfaz.
final Provider<Locale> localeActivoProvider = Provider<Locale>(
  (Ref ref) => localeDe(ref.watch(idiomaControllerProvider)),
);

/// Textos en el idioma activo para servicios sin `BuildContext` (avisos,
/// informe en PDF, consejos de ayuno).
final Provider<AppLocalizations> l10nProvider = Provider<AppLocalizations>(
  (Ref ref) => lookupAppLocalizations(ref.watch(localeActivoProvider)),
);

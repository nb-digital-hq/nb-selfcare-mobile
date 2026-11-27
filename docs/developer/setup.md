# Puesta en marcha

> **Estado:** Aplicable.

## Herramientas

* Flutter estable 3.47.6 (Dart 3.13), la versión de `.fvmrc`. Android SDK 36 y JDK 17 o posterior.
* `just` para los atajos (opcional: cada receta es un comando de Flutter o Dart).
* Para iOS: macOS con Xcode.
* Para regenerar íconos: Python 3 con Pillow y `rsvg-convert`.

Antes de resolver dependencias, comprobar `flutter --version` contra `.fvmrc`. Si el SDK global difiere,
usar FVM o una copia aislada de la versión fijada, anteponiendo su directorio `bin` al `PATH` de esa sesión.
`flutter pub get --enforce-lockfile` comprueba la resolución fijada sin aceptar cambios silenciosos del lockfile.

## Primeros comandos

```bash
flutter pub get
dart run build_runner build   # Drift
flutter gen-l10n                                           # textos
just verify                                                # o los comandos de abajo
flutter run                                                # dispositivo o emulador
```

`just verify` equivale a:

```bash
dart format --output=none --set-exit-if-changed $(git ls-files 'lib/*.dart' 'test/*.dart' 'tool/*.dart')
flutter analyze
flutter test
dart run tool/guardianes/todos.dart
```

## Datos de demostración

```bash
flutter run --dart-define=NB_DEMO=true
```

Con una base vacía, crea el perfil ficticio "Alex" y siembra 30 días de comidas, pesajes, ayunos, diario, tomas y
hábitos. Es la edición con la que se graban las capturas y el video. Nunca se usa con datos reales.

# Empaquetado

> **Estado:** Implementado.

## Android

| Campo | Valor |
|---|---|
| `applicationId` | `com.nb.selfcare` |
| Nombre visible | NB SelfCare |
| Versión | `version` de `pubspec.yaml` (`1.0.0+5`); con `--split-per-abi` el `versionCode` es 1000 × índice de la ABI + build |
| SDK mínimo / objetivo | 26 (Android 8.0) / 36 |
| Reducción | R8 activo; reglas en `android/app/proguard-rules.pro` |

```bash
flutter build apk --release --split-per-abi   # arm64-v8a, armeabi-v7a, x86_64
flutter build apk --release                   # universal
```

### Firma

La publicación se firma con la clave de NB SelfCare Mobile (`android/key.properties` apunta al almacén). Ninguno de
los dos se versiona. Sin `key.properties`, Gradle firma con la clave de depuración para no bloquear el desarrollo;
ese APK no actualiza una instalación de publicación. Perder la clave impide publicar actualizaciones con la misma
identidad: se custodia fuera del repositorio con copia cifrada.

### Lo que lleva el APK

Las fuentes, las previsualizaciones del ícono y la semilla de alimentos (en código). Ningún modelo, ninguna imagen
de Nibi (se dibuja) y ningún dato de demostración salvo que se compile con `NB_DEMO=true`.

## iOS

```bash
flutter build ios --release --no-codesign
```

`ediciones.yml` empaqueta el resultado como `.ipa` sin firmar. Para instalarlo hay que firmarlo con un perfil propio.
Sin probar en un dispositivo real.

## Íconos

Todos salen de `assets/images/logo.svg` con `python3 tool/gen_app_icons.py` (lanzador, adaptativo claro y oscuro,
monocromo, una variante por tema, previsualizaciones e iOS).

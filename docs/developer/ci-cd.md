# Integración continua

> **Estado:** Implementado. Android se verifica entero en Linux; iOS compila en macOS pero **no se ha verificado
> en un dispositivo real**.

## Flujos

| Flujo | Cuándo | Qué hace |
|---|---|---|
| `ci.yml` | Cada push a `main` y cada pull request | Ver abajo |
| `ediciones.yml` | A mano, al preparar una versión | Compila el `.ipa` de iOS sin firmar como artefacto |

## `ci.yml`

| Trabajo | Sistema | Qué comprueba |
|---|---|---|
| Procedencia y convenciones | Linux, solo en pull requests | Conventional Commits y `Signed-off-by` en cada commit |
| Verificación | Ubuntu | Código generado, textos, `dart format`, `flutter analyze`, `flutter test` y guardianes |
| Android | Ubuntu | `flutter build apk --release --split-per-abi` con firma de depuración (la clave de publicación no está en la CI) |
| iOS | macOS | `flutter build ios --release --no-codesign` |

Flutter se fija a la misma versión estable en todos los trabajos.

## Notas

* El código generado (`*.g.dart`, `lib/core/l10n/generated/`) no se versiona; cada trabajo lo genera.
* Los nombres de archivo no difieren solo en mayúsculas: rompería macOS.
* Las pruebas con tiempos usan un `Clock` fijo; las que esperan a la base de datos usan márgenes que aguantan un
  ejecutor lento. En local se reproduce con `taskset -c 0-3 flutter test`.
* Las ejecuciones fallidas o canceladas se borran del historial de Actions.

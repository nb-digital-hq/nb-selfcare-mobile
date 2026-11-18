# ADR-007: Plataformas y distribución

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

La app se verifica en Android en un dispositivo real. iOS comparte el código Flutter, pero ni se puede firmar ni
probar sin equipos de Apple. NB Digital no publica sus apps móviles en tiendas.

## Decisión

| Plataforma | Estado | Entrega |
|---|---|---|
| Android 8.0 o posterior (`arm64-v8a`, `armeabi-v7a`, `x86_64` y universal) | Verificada en dispositivo real | APK firmados con la clave de NB SelfCare Mobile |
| iOS 13 o posterior | **Sin probar** en dispositivo real; compila en la CI | `.ipa` **sin firmar**, para instalar con una firma propia |

* La única vía de distribución son las publicaciones de `github.com/nb-digital-hq/nb-selfcare-mobile`, con
  `SHA256SUMS` firmado con Ed25519.
* En Android la app se actualiza desde Ajustes, Acerca de y actualizaciones, a petición de la persona.
* En iOS no existen Health Connect, los recordatorios programados, el cronómetro en la pantalla de bloqueo, la
  vibración guiada, el ícono por tema ni el actualizador: dependen de servicios de Android y sus entradas no se
  muestran (`lib/core/platform/plataforma.dart`). Comida, Cuerpo, Cuidado, Nibi, el ayuno, el diario, la báscula,
  el escáner y las copias de seguridad funcionan igual.

## Consecuencias

* La CI compila iOS en macOS en cada cambio, para que la edición sin probar no se rompa en silencio
  ([CI](../developer/ci-cd.md)).
* Las notas de cada versión dicen qué se verificó en un teléfono real y qué no.

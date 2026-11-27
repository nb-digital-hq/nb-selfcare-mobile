# Cadena de suministro

> **Estado:** Implementado.

## Dependencias

* Versiones fijadas en `pubspec.lock`, que se versiona.
* Licencias comprobadas en cada verificación por `tool/guardianes/licencias.dart`; avisos generados en
  `THIRD-PARTY-NOTICES.md` ([política](../architecture/dependency-policy.md)).
* Dependabot vigila `pub`, Gradle y GitHub Actions **solo con alertas**: no abre pull requests
  (`open-pull-requests-limit: 0`). Las actualizaciones se hacen a mano y se verifican con la suite completa.

## Alertas

Una alerta nueva se resuelve actualizando la dependencia. Una alerta que no afecte a la app y no tenga arreglo se
descarta en GitHub con su motivo escrito y se anota aquí con la fecha.

| Fecha | Alerta | Motivo |
|---|---|---|
| — | Ninguna descartada | — |

## Compatibilidad del compilador Android

Con Flutter 3.47.6, `camera_android_camerax` y `nsd_android` aplican Kotlin Gradle Plugin; Gradle lo advierte como
compatibilidad de herramientas. No es una excepción de vulnerabilidad ni de licencia, y no se fuerzan versiones
transitivas fuera de las restricciones aprobadas.

## Firma de las publicaciones

* Los APK se firman con la clave de NB SelfCare Mobile (RSA 4096). La huella SHA-256 del certificado es
  `2A:B8:EB:92:9D:00:EA:D3:3D:B8:53:65:6A:18:0F:DF:28:33:61:89:7A:C9:9C:9A:C3:D0:ED:F8:3F:5A:DB:F0`.
* `SHA256SUMS` lista la huella de cada archivo de la publicación y `SHA256SUMS.sig` es su firma Ed25519 con la
  clave de publicación de NB SelfCare Mobile, cuya parte pública está en
  [`clave-de-publicacion.pem`](../architecture/api/clave-de-publicacion.pem).
* El `.ipa` de iOS sale de GitHub Actions sin firma de Apple y entra en la misma lista firmada.

Comprobación ([publicación](../developer/releases.md)):

```bash
openssl pkeyutl -verify -pubin -inkey clave-de-publicacion.pem -rawin -in SHA256SUMS -sigfile SHA256SUMS.sig
sha256sum --check --strict SHA256SUMS
apksigner verify --print-certs NB-SelfCare-Mobile-1.0.0-arm64-v8a.apk
```

## Datos de terceros

* Catálogo de alimentos de la semilla: USDA FoodData Central, dominio público.
* Productos consultados bajo demanda: Open Food Facts, Open Database License; no se distribuyen con la app.
* Fuentes Manrope y Space Grotesk: SIL Open Font License 1.1 (`assets/fonts/OFL.txt`).

## Lo que no entra en el repositorio

Claves privadas, almacenes de firma, `key.properties`, binarios compilados y configuración de herramientas de
agentes (`tool/guardianes/secretos.dart`).

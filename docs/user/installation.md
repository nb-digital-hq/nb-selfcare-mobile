# Instalación

> **Estado:** Implementado. Android verificado; iOS sin probar.

## Android (8.0 o posterior)

1. Abre la última publicación en `github.com/nb-digital-hq/nb-selfcare-mobile/releases`.
2. Descarga el APK de tu teléfono. Casi todos los teléfonos actuales usan `arm64-v8a`; si no sabes cuál, el
   `universal` sirve en cualquiera.
3. Ábrelo y permite instalar apps de esa fuente cuando Android lo pida. Al no venir de una tienda, Android muestra
   un aviso: es normal.
4. Las versiones siguientes se instalan desde la propia app: Ajustes, Acerca de y actualizaciones, "Buscar
   actualizaciones".

## iOS (sin probar)

El `.ipa` se publica sin firma de Apple. Para instalarlo hace falta firmarlo con un perfil propio (por ejemplo, con
una cuenta de desarrollador). No se ha probado en un iPhone real. En iOS no existen Health Connect, los
recordatorios programados, la vibración guiada, el ícono por tema ni el actualizador.

## Verificar la descarga

Cada publicación incluye `SHA256SUMS` y su firma `SHA256SUMS.sig`:

```bash
openssl pkeyutl -verify -pubin -inkey clave-de-publicacion.pem -rawin -in SHA256SUMS -sigfile SHA256SUMS.sig
sha256sum --check --ignore-missing SHA256SUMS
```

La clave pública está en el repositorio, en `docs/architecture/api/clave-de-publicacion.pem`.

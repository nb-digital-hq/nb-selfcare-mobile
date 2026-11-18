# Privacidad

> **Estado:** Implementado. La declaración vinculante en inglés es [PRIVACY.md](../../PRIVACY.md).

## Lo que la app no hace

* Ninguna cuenta, registro ni comprobación de licencia.
* Ninguna telemetría, analítica, informe de fallos ni seguimiento de uso, tampoco "anónimos" o desactivables.
* Ningún SDK de terceros que informe a nadie, ninguna publicidad.
* Ningún registro: `print`, `debugPrint`, `log` y `android.util.Log` están prohibidos (`tool/guardianes/registro.dart`).
* Ninguna copia automática a la nube: `android:allowBackup="false"`.

## Dónde están los datos

En una base SQLite dentro del almacenamiento privado de la app ([almacenamiento](../architecture/storage.md)). Salen
del teléfono solo si la persona exporta una copia (un `.sqlite` que ella envía donde quiere) o comparte el informe
PDF.

## Salidas de red

| Destino | Cuándo | Qué se envía | Qué vuelve |
|---|---|---|---|
| `world.openfoodfacts.org` | Al escanear un código que no está en el catálogo o al tocar "Buscar en Open Food Facts" | El código de barras o las palabras buscadas y un `User-Agent` que identifica la app, sin datos de la persona | El producto, que se guarda en el catálogo |
| `api.github.com`, `github.com` | Solo en Android, al tocar "Buscar actualizaciones" | La petición de la última versión | La lista de archivos de la publicación y, si la persona lo pide, el APK |

Cómo se comprueba: `lib/core/network/salidas.dart` construye cada cliente limitado a los hosts de su destino y
solo con HTTPS; `tool/guardianes/red.dart` rechaza cualquier cliente, socket o imagen remota fuera de
`lib/core/network/` y cualquier conexión en Kotlin; `test/qa_audit/architecture_guardrails_test.dart` rechaza SDK de
nube o telemetría.

## Servicios del sistema

| Servicio | Uso | Control de la persona |
|---|---|---|
| Health Connect (Android) | Lee pasos, sueño, pulso en reposo, peso, grasa, agua y los signos vitales declarados; escribe pesajes, grasa, agua y respiración | Conectar y retirar permisos en Health Connect |
| Reconocimiento de voz | Dictado de comidas, solo si el teléfono lo ofrece sin conexión | Tocar el micrófono |
| Cámara | Escáner (zxing-cpp, en el teléfono), foto de perfil y del diario | Permiso de cámara |
| Bluetooth | Leer los anuncios de la báscula declarada | Permiso de Bluetooth |
| Notificaciones y alarmas | Ayuno, recordatorios y pausas activas | Ajustes, Recordatorios |

## Datos sensibles en la pantalla de bloqueo

Los avisos de tomas son discretos por defecto: no dicen el nombre del medicamento, y todos los recordatorios son
privados en la pantalla de bloqueo. El aviso de suelo pélvico dice siempre "Tu momento de 3 minutos".

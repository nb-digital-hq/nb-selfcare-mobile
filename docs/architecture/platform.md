# Plataforma

> **Estado:** Implementado. Android verificado en dispositivo real; iOS sin probar.

## 1. Android

`minSdk 26` (Android 8.0), `targetSdk 36`. Publicación con R8 y firma con la clave del proyecto si existe
`android/key.properties`; sin ese archivo, Gradle firma con la clave de depuración ([empaquetado](../developer/packaging.md)).

### 1.1 Permisos

| Permiso | Para qué | Cuándo se pide |
|---|---|---|
| `BLUETOOTH_SCAN` (`neverForLocation`), `BLUETOOTH_CONNECT`; en Android 11 o anterior, `BLUETOOTH`, `BLUETOOTH_ADMIN` y ubicación | Leer la báscula | Al tocar "Pesarme" |
| `health.READ_*` y `health.WRITE_*` | Health Connect ([ADR-021](../adr/021-health-connect.md)) | Al conectar Health Connect o declarar un aparato |
| `POST_NOTIFICATIONS`, `POST_PROMOTED_NOTIFICATIONS` | Cronómetro del ayuno, recordatorios, pausas activas | Al empezar un ayuno o activar un recordatorio |
| `SCHEDULE_EXACT_ALARM` | Recordatorios a la hora exacta (sin él, con una ventana de hasta una hora) | Desde Ajustes, Permisos |
| `RECEIVE_BOOT_COMPLETED` | Reprogramar recordatorios y el ayuno tras reiniciar | Permiso normal |
| `VIBRATE` | Guiar el suelo pélvico sin mirar la pantalla | Permiso normal |
| `CAMERA` | Escáner de códigos, foto de perfil y del diario | Al abrir el escáner o la cámara |
| `RECORD_AUDIO` | Dictado de comidas con reconocimiento sin conexión | Al tocar el micrófono |
| `INTERNET` | Las dos salidas de red ([ADR-004](../adr/004-network-exit.md)) | Permiso normal |
| `REQUEST_INSTALL_PACKAGES` | Instalar una versión nueva descargada desde Acerca de | Al tocar "Instalar" |

`android:allowBackup="false"`. El manifiesto declara las acciones que exige Health Connect para abrir la política de
privacidad (`/privacidad`).

### 1.2 Código nativo (`android/app/src/main/kotlin/com/nb/selfcare/`)

| Clase | Qué hace |
|---|---|
| `MainActivity` | Canales de Flutter, permisos, ajustes, disponibilidad del dictado sin conexión, modelo del teléfono, marcador (líneas de apoyo), vibración e ícono por tema |
| `health/HealthConnectBridge` | Permisos, lecturas diarias, signos vitales declarados y escrituras |
| `notifications/FastingNotifier` | Notificación del ayuno con el cronómetro del sistema, promovida a Live Update en Android 16 ([ADR-016](../adr/016-native-fasting-timer.md)) |
| `notifications/ReminderScheduler`, `ReminderReceiver` | Recordatorios con `AlarmManager`, privados en la pantalla de bloqueo |
| `notifications/ReminderActionReceiver` | Botón "Hecho" de las tomas, que funciona con la app cerrada |
| `notifications/RescheduleReceiver` | Reprograma todo al reiniciar, al cambiar la hora o al conceder alarmas exactas |
| `notifications/MovementNudgeWorker` | Pausas activas: sin pasos en una hora (09:00 a 21:00), una invitación a moverse |
| `AppUpdater` | Entrega el APK ya verificado al instalador del sistema |

Los textos que pinta Android (canales y avisos del ayuno y de las pausas) están en `res/values`, `values-en` y
`values-pt`. Los recordatorios llevan el texto que les da Flutter en el idioma activo.

### 1.3 Canales

Todos se llaman con `callNative`, que nunca lanza: un método ausente o una respuesta de tipo inesperado devuelven
`null`.

| Canal | Uso |
|---|---|
| `com.nb.selfcare/health_connect` | Health Connect |
| `com.nb.selfcare/notifications` | Ayuno, recordatorios, pausas, acciones de las tomas |
| `com.nb.selfcare/system` | Permisos, ajustes, dictado, modelo, marcador, vibración |
| `com.nb.selfcare/app_icon` | Ícono por tema (`activity-alias` aplicado al salir de la app) |
| `com.nb.selfcare/updater` | Versión instalada, ABI e instalación |

## 2. iOS

El proyecto de `ios/` compila en la CI y se entrega como `.ipa` sin firmar, **sin probar en un dispositivo real**
([ADR-007](../adr/007-platforms-and-distribution.md)). `lib/core/platform/plataforma.dart` oculta en iOS lo que
depende de servicios de Android: Health Connect, los recordatorios programados y sus permisos, la vibración guiada,
el ícono por tema y el actualizador. Comida, Cuerpo (incluida la báscula Bluetooth), Cuidado, Nibi, el ayuno, el
diario, el escáner, el dictado y las copias de seguridad usan los mismos paquetes de Flutter en ambas plataformas.
`ios/Runner/Info.plist` declara los textos de uso de cámara, micrófono, reconocimiento de voz, Bluetooth y fotos.

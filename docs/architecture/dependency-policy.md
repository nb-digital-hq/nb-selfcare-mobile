# Política de dependencias

> **Estado:** Aplicable. La licencia la comprueba `tool/guardianes/licencias.dart`.

Una dependencia nueva se justifica en su pull request por tres criterios:

1. **Coste:** qué añade al tamaño del APK y al arranque, y si el SDK ya lo resuelve.
2. **Licencia:** solo Apache-2.0, MIT, BSD, ISC o Zlib en lo que se distribuye. Nada GPL, AGPL o LGPL y ningún
   binario propietario (como Google ML Kit, Firebase o los servicios de Google Play).
3. **Mantenimiento:** publicaciones recientes y compatibilidad con la versión estable de Flutter.

Prohibidas siempre: SDK de analítica, publicidad o informes de fallos remotos, `google_fonts` (descarga fuentes al
ejecutarse) y cualquier cliente de red fuera de `lib/core/network/`.

**Excepción documentada:** `bluez` y `dbus` (MPL-2.0) aparecen en `pubspec.lock` como dependencias de
`universal_ble` en Linux. No se compilan en Android ni en iOS; si algún día lo hicieran, MPL-2.0 es copyleft por
archivo y sigue siendo compatible con Apache-2.0.

`THIRD-PARTY-NOTICES.md` se regenera con `dart run tool/guardianes/licencias.dart --escribir`; la CI falla si está
desactualizado. Las fuentes empaquetadas (Manrope y Space Grotesk) tienen la SIL Open Font License 1.1, con su texto
en `assets/fonts/OFL.txt`.

## Dependencias directas

| Paquete | Para qué |
|---|---|
| `flutter_riverpod`, `go_router`, `intl`, `flutter_localizations` | Estado, navegación, idiomas y formatos |
| `drift`, `drift_flutter`, `sqlite3`, `path_provider`, `path` | SQLite con FTS5 empaquetado |
| `dynamic_color` | Tema "Colores de tu fondo" (Material You) |
| `universal_ble` | Lectura de la báscula por Bluetooth LE |
| `http`, `crypto` | Las dos salidas de red y la verificación del APK descargado |
| `flutter_zxing`, `camera` | Escáner de códigos de barras con zxing-cpp |
| `image_picker` | Foto de perfil y foto del diario |
| `file_picker`, `share_plus` | Exportar e importar la copia `.sqlite` |
| `pdf`, `printing` | Informe en PDF |
| `speech_to_text` | Dictado de comidas con el reconocimiento del teléfono, solo sin conexión |

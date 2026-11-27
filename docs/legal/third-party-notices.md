# Avisos de terceros

> **Estado:** Implementado. Se genera con `dart run tool/guardianes/licencias.dart --escribir`.

`THIRD-PARTY-NOTICES.md`, en la raíz, contiene el texto completo de la licencia de cada paquete que se distribuye
con la app, a partir de `pubspec.lock`. La CI falla si no coincide con las dependencias. Cada publicación lo
adjunta.

Además de los paquetes de Dart, la app incluye:

* Las fuentes Manrope y Space Grotesk (SIL Open Font License 1.1), con su texto en `assets/fonts/OFL.txt`.
* A través de los paquetes, bibliotecas nativas con licencias permisivas: AndroidX, CameraX y Health Connect Client
  (Apache-2.0), zxing-cpp (Apache-2.0) y SQLite (dominio público).
* Un catálogo de alimentos derivado de USDA FoodData Central (dominio público).

`bluez` y `dbus` (MPL-2.0) figuran en `pubspec.lock` como dependencias de `universal_ble` para Linux; no se
compilan en Android ni en iOS y se listan igualmente en los avisos.

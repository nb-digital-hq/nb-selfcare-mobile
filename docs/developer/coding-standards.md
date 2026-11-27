# Normas de código

> **Estado:** Aplicable.

* `analysis_options.yaml` con `flutter_lints` y `strict-casts`, `strict-inference` y `strict-raw-types`;
  `flutter analyze` sin avisos.
* `dart format` sin cambios en los archivos versionados (ancho de línea en `analysis_options.yaml`); el código
  generado por Drift y `gen-l10n` no se versiona y queda fuera de la comprobación.
* Sin `dynamic` salvo al decodificar JSON crudo antes de validarlo.
* Identificadores, comentarios y documentación en español. Los comentarios explican **por qué**: lo descartado y la
  razón cuando la decisión no es obvia. No narran el historial del código.
* Sin emoticonos en ninguna parte ni marcas de trabajo pendiente.
* Textos visibles siempre en los ARB, con sus tres idiomas ([internacionalización](../architecture/i18n.md)); cifras
  con `NumberFormats` y fechas con `DateFormats`.
* La hora sale de `Clock`; nunca `DateTime.now()` fuera de `core/clock`.
* Los colores, radios, espacios y movimiento salen de los tokens (`context.sc`, `context.type`, `ScRadius`, `ScSpace`,
  `ScMotion`); toda vista funciona en los temas de color y de papel.
* Nada de red fuera de `lib/core/network/` y nada de registros ([Constitución](../architecture/constitution.md)).
* Los errores esperables se convierten en estados de la interfaz con un mensaje para la persona; ninguna pantalla
  muestra trazas. Lo registrado por la persona nunca se pierde por un fallo nativo (`bestEffort`).
* Cada propiedad nueva lleva su prueba y cada defecto corregido, su prueba de regresión. Las pruebas se nombran por
  la propiedad que comprueban.

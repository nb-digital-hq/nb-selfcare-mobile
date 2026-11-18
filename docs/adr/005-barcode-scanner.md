# ADR-005: Escáner de códigos con ZXing

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

Registrar un producto envasado con la cámara es el camino más rápido para la comida del día. El paquete habitual en
Flutter usa en Android Google ML Kit, un binario propietario que se distribuye dentro del APK, tiene sus propios
términos y envía a Google métricas de uso de la API. Eso choca con la [licencia](003-licensing-model.md) y con la
promesa de cero telemetría. La lectura de la tabla nutricional por foto dependía también de ML Kit.

## Alternativas consideradas

1. **ML Kit para códigos y etiquetas.** Muy buena lectura, pero propietario y con telemetría.
2. **ZXing (`flutter_zxing`, MIT, sobre zxing-cpp con licencia Apache-2.0) para códigos; sin lectura de etiquetas.**
   Todo abierto, nada sale del teléfono.
3. **ZXing para códigos y Tesseract para etiquetas.** Tesseract lee mal las tablas nutricionales y pesa decenas de
   megabytes.

## Decisión

* El escáner usa `flutter_zxing` con la cámara de CameraX, limitado a EAN-13, EAN-8, UPC-A y UPC-E, con
  `tryHarder` y rotación activados para tolerar ángulos y poca luz. La linterna se controla desde la propia hoja.
* No hay lectura de la tabla nutricional por foto. Un producto que no está en el catálogo ni en Open Food Facts se
  crea a mano, y su código queda asociado para las próximas lecturas.
* Siempre se puede escribir el código con el teclado.

## Consecuencias

* Todo lo que se distribuye es código abierto y el APK no lleva servicios de Google.
* R8 no necesita reglas para el escáner: el código nativo se resuelve por símbolo desde Dart.

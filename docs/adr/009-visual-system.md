# ADR-009: Sistema visual

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

Una app de salud se mira varias veces al día. Muchos colores de acento, una caja alrededor de cada sección y
párrafos de explicación permanentes la hacen ruidosa. Además, parte de quienes la usan prefieren pantallas o temas
de aspecto papel, donde las animaciones dejan estelas.

## Decisión

* **Un acento por pantalla.** Los iconos de encabezado van en el tono del texto secundario; las acciones rápidas y
  los atajos usan siempre el acento del tema.
* **Colores semánticos fijos** solo para datos: proteína, carbohidratos, grasa, agua, pasos, ayuno, calorías,
  éxito, aviso y error. Un color significa siempre lo mismo.
* **Superficies sin borde en los temas de color**: la tarjeta se separa del fondo por tono. Radio de 20 dp en
  tarjetas, 16 dp en mosaicos y 14 dp en controles.
* **Temas de papel**: cada tema declara si es de papel (`ScColors.isFlat`). En papel: elevación cero, filetes de
  1,5 px, esquinas de 14/10/8 dp y ningún movimiento (`ScMotion` devuelve duración cero, Nibi no tiene ticker).
  Los temas de papel aparecen siempre en el selector; no dependen del hardware.
* **Ayuda bajo demanda.** Las explicaciones largas viven en "Saber más" o al tocar la cifra, no fijas en la tarjeta.
* Todos los temas cumplen contraste AA: texto ≥ 7:1, secundario y terciario ≥ 4,5:1, texto de botón sobre acento
  ≥ 4,5:1 y acento ≥ 3:1.

## Consecuencias

* Cualquier widget nuevo lee los tokens de `context.sc`, `context.type`, `ScRadius` y `ScMotion`.
* `test/design_system/theme_catalog_test.dart` y `motion_test.dart` lo vigilan; las capturas cubren un tema claro,
  uno oscuro y dos de papel. Ver [convenciones de interfaz](../design/ui-conventions.md).

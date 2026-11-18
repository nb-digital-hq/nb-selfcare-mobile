# Convenciones de interfaz

> **Estado:** Aplicable. Lo vigilan `test/design_system/`, `test/accessibility/` y las capturas de
> `tool/screenshots/`.

## 1. Estructura

* **Cinco pestañas** y el perfil en el avatar de cada cabecera ([ADR-008](../adr/008-information-architecture.md)).
* Cabecera grande con el título de la pestaña y, a la derecha, sus acciones y el avatar (`TabHeaderActions`). Solo
  Inicio lleva la fecha y el saludo.
* El ayuno se ve una vez por pestaña: en Inicio, su tarjeta; en las demás, la barra fija mientras hay uno en curso.
* Cada pantalla tiene **un dato protagonista** en una tarjeta destacada (la disposición del día, el balance, el peso,
  el santuario) y el resto en tarjetas tranquilas.

## 2. Color

* Un acento por pantalla, el del tema. Los iconos de encabezado (`CardHeader`, `MetricLabel`) van en el tono del texto
  secundario; las acciones rápidas (`QuickActionButton`) y los atajos (`ActionTile`) usan siempre el acento.
* Los colores semánticos (`ScColors.protein`, `carbs`, `fat`, `water`, `steps`, `fasting`, `calories`, `success`,
  `warning`, `danger`) solo pintan **datos**: anillos, barras, gráficas e insignias de estado. Un color significa
  siempre lo mismo en toda la app.
* En los temas de color las tarjetas no llevan borde: se separan del fondo por tono (`bg2` sobre `bg`). En papel,
  filete de tinta de 1,5 px.

## 3. Tipografía y cifras

* Cifras con Space Grotesk y dígitos tabulares (`context.type.metricXL…metricS`); la unidad, pequeña y en tono
  secundario (`MetricValue`). Las cifras cuentan hasta su valor nuevo al cambiar (`AnimatedMetricValue`).
* Rótulos sobre cifras en versalitas (`overline`). Textos de apoyo en `caption`, como mucho dos líneas en una
  cabecera de tarjeta.
* Las explicaciones largas no viven fijas en la tarjeta: van en "Saber más" (`ScienceOnDemandSheet`) o al tocar la
  cifra (por ejemplo, la tendencia de peso).

## 4. Componentes y acciones

* Una acción principal por bloque: `FilledButton` solo para ella; las de tarjeta, `QuickActionButton` tonal; las
  secundarias, botones de texto.
* Sin cajas dentro de cajas: las superficies interiores se distinguen por tono (`bg3`).
* Iconos sin recuadro y sin emoji: los estados de ánimo del diario son iconos de Material.
* Toda acción que borra ofrece Deshacer (`showUndoSnackBar`).
* Zona táctil mínima de 48 dp.

## 5. Radios, espacios y movimiento

| Token | Color | Papel |
|---|---|---|
| `ScRadius.card` / `tile` / `control` | 20 / 16 / 14 dp | 14 / 10 / 8 dp |
| `ScSpace` | Múltiplos de 4 dp; margen lateral 16 dp | Igual |
| `ScMotion` | 110 a 650 ms con `easeOutCubic` | Cero: cada cambio en un fotograma |

| Microinteracción | Color | Papel o "Quitar animaciones" |
|---|---|---|
| Pulsar tarjeta o acción (`Pressable`) | Se hunde a 0,97–0,985 y rebota | Sin cambio |
| Cifras | Cuentan hasta el valor nuevo | Cambio en un fotograma |
| Barras y anillos | Avanzan con `easeOutCubic` | Sin animación |
| Entrada de pantalla (`Entrance`) | Bloques escalonados | Aparecen tal cual |
| Barra inferior | Píldora tonal que se desliza | Contorno de tinta, sin transición |
| Respuesta háptica | Selección y confirmaciones | Igual |

Los anillos que avanzan cada segundo (ayuno) no animan cambios, para no dibujar sin pausa.

## 6. Temas de papel

Cada tema declara si es de papel (`ScColors.isFlat`). En papel: elevación cero, filetes de 1,5 px, esquinas más
rectas, ningún movimiento, gráficas que distinguen series por grosor y trazo, y Nibi en pose fija con paleta de
tinta. Los cuatro temas de papel aparecen siempre en el selector ([ADR-009](../adr/009-visual-system.md)).

## 7. Rendimiento

* Barra inferior sólida, sin desenfoque de fondo.
* `RepaintBoundary` en anillos, barras, gráficas y barra de ayuno.
* Imágenes decodificadas al tamaño mostrado; Nibi es vectorial.
* El armazón solo se reconstruye si cambia el ayuno o la tarjeta de ayuno de Inicio.

## 8. Accesibilidad

* Contraste AA en los 24 temas (`theme_catalog_test`).
* Etiquetas semánticas en acciones con solo icono; los anillos y gráficas tienen descripción.
* Texto al 200 %, 320 px de ancho y tableta sin desbordes (`ui_stress_test`).
* `test/accessibility/guidelines_test.dart` aplica las pautas de Android (tamaño de toque, etiquetas, contraste).

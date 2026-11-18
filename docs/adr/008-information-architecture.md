# ADR-008: Cinco pestañas

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

La app reúne lo que normalmente reparten varias apps: comida, cuerpo, cuidado, ayuno, diario y una mascota. Una
barra con seis destinos y el ayuno repetido en varias pantallas hacía que cada vista compitiera por la atención en
vez de guiarla.

## Alternativas consideradas

1. **Cinco pestañas, perfil en el avatar y el ayuno en un solo sitio fijo.**
2. **Seis pestañas con el perfil en la barra.** El perfil se consulta poco y ocupaba un destino principal.
3. **Menú lateral.** Esconde lo frecuente y suma un toque a cada destino.

## Decisión

* La barra inferior tiene cinco destinos: **Inicio**, **Comida**, **Cuerpo**, **Cuidado** y **Nibi** (con el nombre
  de la mascota si es corto). Cada uno conserva su estado (`StatefulShellRoute`).
* El **perfil** se abre desde el avatar de la esquina superior derecha de cada pestaña (`ProfileButton`) y vive en
  `/perfil` como página, con Ajustes dentro.
* El **ayuno** tiene un solo lugar por pestaña: en Inicio, su tarjeta (desde donde también se empieza); en las demás,
  la barra fija sobre la navegación mientras hay uno en curso. Si alguien oculta la tarjeta de Inicio, la barra
  aparece también ahí.
* **Nibi en Inicio** es una fila de compañía (avatar, un mensaje y un dato), no un panel: el santuario, la tienda y
  los cuidados viven en su pestaña.
* En **Comida**, el buscador y una fila de cinco atajos van arriba; el balance del día y las comidas, justo después.

## Consecuencias

* Cada información aparece una vez. Los textos de ayuda que se repetían se piden tocando el dato o el botón "Saber
  más" ([convenciones de interfaz](../design/ui-conventions.md)).

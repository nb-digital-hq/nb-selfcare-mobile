# ADR-015: Minerales esenciales

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

La mayoría de productos envasados declaran cuatro a seis nutrientes. Mostrar treinta barras en cero inventa
carencias.

## Decisión

La app destaca sodio, potasio, magnesio y fibra, y guarda calcio, hierro, zinc y vitaminas C, D y B12. Un nutriente
que la etiqueta no declara se guarda como desconocido y se muestra como "Dato no reportado", nunca como cero.

## Consecuencias

Menos ruido y ninguna falsa alarma. Detalle en [nutrición](../architecture/nutrition.md).

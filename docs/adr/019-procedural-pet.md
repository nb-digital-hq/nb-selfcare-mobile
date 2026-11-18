# ADR-019: Nibi dibujado en código

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

Un archivo de animación externo puede faltar o corromperse y añade una dependencia binaria.

## Decisión

Nibi, sus objetos y sus escenarios se dibujan con `CustomPainter`. Las posturas salen de funciones puras del tiempo
(`NibiChoreography`), lo que permite probarlas fotograma a fotograma.

## Consecuencias

Ningún recurso que pueda faltar; en papel, una pose fija con paleta de tinta.

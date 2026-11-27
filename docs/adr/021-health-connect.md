# ADR-021: Health Connect

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

Health Connect es el almacén de salud de Android: relojes, básculas y otras apps escriben ahí. Pedir todos los
permisos a todo el mundo contradice la mínima exposición.

## Decisión

* Lectura: pasos, sueño (con fases y hora de despertar), frecuencia cardiaca en reposo, peso, grasa e hidratación;
  y cada signo vital solo si se declara su aparato.
* Escritura: pesajes, grasa por bioimpedancia, vasos de agua y sesiones de respiración (si el proveedor lo admite).
* Las lecturas se guardan con su identificador de Health Connect para no duplicarse y se descartan valores
  imposibles. Las mediciones manuales de signos vitales no se exportan.

## Consecuencias

Sin Health Connect todo funciona a mano. Solo existe en Android.

# ADR-014: Entrenamientos por bloques

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

Registrar series, repeticiones y pesos lleva más tiempo que el que la mayoría está dispuesta a dedicar.

## Decisión

Un entrenamiento se registra con tipo (fuerza, funcional, cardio, deporte), minutos y esfuerzo percibido (suave,
moderado, intenso). El gasto neto sale de una tabla de MET descontando el reposo y usando el último peso. Los pasos
se leen de Health Connect o se añaden a mano.

## Consecuencias

Menos de cinco segundos por entrenamiento. Detalle en [entrenamiento y movimiento](../architecture/workout-and-neat.md).

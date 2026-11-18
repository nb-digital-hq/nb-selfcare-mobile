# ADR-018: Gamificación positiva

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

Las mascotas que enferman o mueren y las rachas que se pierden de golpe generan culpa justo cuando alguien está
cansado o enfermo.

## Decisión

Nibi nunca enferma, nunca muere y nunca regaña. Las monedas premian la constancia una vez al día por acción; el buen
sueño las multiplica por 1,5. Un día sin actividad consume un escudo de racha; si no quedan, la racha vuelve a 1 sin
reproches y los escudos se conservan.

## Consecuencias

`test/qa_audit/architecture_guardrails_test.dart` prohíbe el vocabulario de muerte, enfermedad o culpa en el código
de Nibi. Detalle en [Nibi y recompensas](../architecture/nibi-and-rewards.md).

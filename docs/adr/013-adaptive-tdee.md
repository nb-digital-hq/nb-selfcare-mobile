# ADR-013: Gasto diario adaptativo

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

Las fórmulas de gasto suponen factores de actividad fijos y fallan por cientos de calorías. Ajustar con el peso de
un solo día amplifica el agua y el contenido digestivo.

## Decisión

Cada 14 días, con al menos 10 días con comidas y 6 pesajes, el gasto se recalcula con la variación del peso
tendencia (media móvil exponencial, α = 0,1) y la media de calorías: `TDEE = ingesta media − ΔEMA × 7700 / 14`. El
cambio está acotado a ±150 kcal por semana y nunca baja del metabolismo basal.

## Consecuencias

La meta se ajusta a cómo responde el cuerpo de cada persona sin oscilaciones. La persona puede pasar a metas
manuales en cualquier momento.

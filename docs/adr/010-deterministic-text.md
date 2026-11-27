# ADR-010: Texto y dictado sin modelo de lenguaje

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

Escribir o dictar "200 g de pollo y una manzana" es más rápido que buscar cada alimento. Un modelo de lenguaje local
pesa más de un gigabyte, tarda en cargar y puede inventar cantidades.

## Decisión

`TextAssistant` usa reglas deterministas: separa por comas y conectores, reconoce cantidades ("200 g", "2 huevos"),
unidades y artículos en español, inglés y portugués, y busca cada término en el catálogo local con FTS5. Los
nutrientes salen siempre de la base de datos; si un término no está, se registra con valores de respaldo de su
categoría. Antes de guardar siempre hay una revisión editable. El dictado usa el reconocimiento de voz del teléfono
solo si funciona sin conexión.

El mismo enfoque sugiere ánimo, energía y estrés para una entrada del diario, con listas de palabras por idioma.

## Consecuencias

Resultado instantáneo, sin descargas y comprobable con pruebas de texto aleatorio (`text_parsing_fuzz_test`).

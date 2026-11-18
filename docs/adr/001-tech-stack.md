# ADR-001: Flutter, Drift y Riverpod

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

NB SelfCare Mobile es la aplicación móvil del pilar de salud y hábitos de la suite NB Digital. La suite usa dos
pilas: Rust con Tauri y Svelte en escritorio, y Flutter con Drift y Riverpod en móvil. La app necesita dibujo
propio a la frecuencia de la pantalla (Nibi, anillos, gráficas), SQLite con búsqueda de texto y un modelo de datos
reactivo.

## Alternativas consideradas

1. **Flutter + Drift + Riverpod.** Una base de código para Android e iOS, SQLite tipado con migraciones
   verificables y FTS5, estado reactivo sin código repetitivo.
2. **Kotlin nativo.** Integración perfecta con Android, pero sin iOS y sin compartir conocimiento con el resto de
   apps móviles de la suite.
3. **React Native.** Puente JavaScript y dependencia de un ecosistema ajeno a la suite.

## Decisión

Flutter (canal estable, versión fijada en `.fvmrc`), Drift sobre SQLite empaquetado (`sqlite3` con FTS5),
Riverpod 3 para estado e inyección, go_router para la navegación. El código nativo se limita a lo que Flutter no
cubre (Health Connect, alarmas, notificaciones, instalador, íconos alternativos) y vive en
`android/app/src/main/kotlin/`.

## Consecuencias

* La app comparte arquitectura y herramientas con NB Sound Mobile y el resto de móviles de la suite.
* La versión de Flutter se fija para que la CI y la verificación local den el mismo resultado
  ([CI](../developer/ci-cd.md)).

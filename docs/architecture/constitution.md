# Constitución

> **Estado:** Aplicable. Se modifica únicamente mediante un ADR aceptado.

Ningún cambio se integra en `main` si rompe una de estas reglas. Cada regla dice qué la hace cumplir: una regla sin
mecanismo es una intención.

## 1. Nada sale del teléfono sin que la persona lo pida

La app solo habla con Open Food Facts cuando la persona escanea un código desconocido o lo busca, y en Android con
GitHub cuando toca "Buscar actualizaciones". El [ADR-025](../adr/025-desktop-sync.md) permite además el enlace
local con un PC emparejado mediante consentimiento y cifrado; no autoriza hosts arbitrarios. No hay telemetría,
analítica, informes de fallos ni cuentas.

**Mecanismo:** `tool/guardianes/red.dart` rechaza cualquier cliente de red fuera de `lib/core/network/` y cualquier
conexión en el código nativo; `salidas.dart` limita cada cliente a los hosts de su destino
([ADR-004](../adr/004-network-exit.md)).

## 2. Nada de la persona en los registros

La app no escribe registros: ni `print` en Dart ni `Log` en Kotlin. Pesos, comidas, medicamentos y síntomas no
llegan nunca al logcat.

**Mecanismo:** `tool/guardianes/registro.dart`.

## 3. Los datos son de la persona y viven en su teléfono

Un único archivo SQLite, sin copia automática a la nube, exportable e importable como archivo `.sqlite`. Una
migración publicada no se edita nunca.

**Mecanismo:** prueba de `allowBackup="false"` en `architecture_guardrails_test`, pruebas de migración desde cada
esquema publicado y pruebas de copia de ida y vuelta ([almacenamiento](storage.md)).

## 4. La hora sale de un solo sitio

Ninguna regla llama a `DateTime.now()`: la hora llega de `Clock`, lo que permite fijarla en las pruebas.

**Mecanismo:** `architecture_guardrails_test` (guardrail 7).

## 5. Las capas no se saltan

La presentación lee y escribe por `features/*/application/`, nunca por un DAO; `core/` y `shared/` no dependen de
`features/`.

**Mecanismo:** `architecture_guardrails_test` (guardrails 8, 9 y 10).

## 6. Sin culpa

Nibi nunca muere, enferma, se entristece por la persona ni regaña. Ningún texto reprocha; las tomas se marcan
"tomada" u "omitida" y los reinicios de Libre conservan lo logrado.

**Mecanismo:** `architecture_guardrails_test` (guardrail 6) y revisión ([ADR-018](../adr/018-positive-gamification.md)).

## 7. Lo que se distribuye es abierto

Todo componente dentro del APK o del `.ipa` es compatible con Apache 2.0 y de código abierto.

**Mecanismo:** `tool/guardianes/licencias.dart` clasifica cada paquete del `pubspec.lock` y regenera los avisos
([ADR-003](../adr/003-licensing-model.md)).

## 8. Toda la interfaz en tres idiomas y en todos los temas

Ningún texto visible queda solo en español, y toda vista funciona en los temas de color y en los de papel.

**Mecanismo:** `tool/guardianes/i18n.dart`, `test/design_system/` y las capturas de `tool/screenshots/`
([ADR-006](../adr/006-internationalization.md), [ADR-009](../adr/009-visual-system.md)).

## 9. La documentación es parte del cambio

Un cambio con impacto en la arquitectura o en el uso no está terminado hasta que su documento lo refleja, con su
etiqueta de estado.

**Mecanismo:** revisión y `tool/guardianes/docs.dart`.

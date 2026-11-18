# Pruebas

> **Estado:** Implementado.

`flutter test` ejecuta todas las suites; deben pasar también con otras zonas horarias (`TZ=America/Bogota`,
`Europe/Madrid`, `Pacific/Chatham`). Las pruebas fijan el idioma del sistema en español, el idioma fuente
(`test/flutter_test_config.dart`).

| Carpeta | Qué cubre |
|---|---|
| `biometrics/`, `domain/`, `chronobiology/`, `protocol/` | Fórmulas (Katch-McArdle, US Navy, MET, EMA, falsa subida, gasto adaptativo con su límite), recompensas y racha, fases del ayuno, cafeína, protocolo semanal |
| `database/`, `drift/` | DAOs, búsqueda FTS5 sin tildes, unicidad del libro de monedas, copias de ida y vuelta, migraciones desde cada esquema publicado |
| `application/`, `health/`, `nutrition/` | Casos de uso: pesaje en cascada, comidas, agua, ayuno, informe, tratamientos, Health Connect, actualizaciones, semilla y menú |
| `care/`, `quit/`, `pet/` | Reglas y servicios de Cuidado, Libre y Nibi (coreografías, reacciones, respiración, tienda) |
| `features/`, `accessibility/` | Pantallas, bienvenida, navegación de cinco pestañas y pautas de accesibilidad |
| `design_system/` | Contraste AA de los 24 temas y movimiento desactivado en papel |
| `qa_audit/` | Pruebas de arquitectura ([visión general](../architecture/system-overview.md)) |
| `edge_cases/` | Respuestas nativas imposibles, Open Food Facts caído o con basura, 50 000 tramas de báscula aleatorias, texto aleatorio en tres idiomas, copias corruptas, cambios de horario, 120 días de uso imperfecto, estrés de interfaz (24 temas, texto al 200 %, 320 px, tableta) y un "mono" que toca la app al azar |

## Guardianes

`dart run tool/guardianes/todos.dart` ejecuta:

| Guardián | Comprueba |
|---|---|
| `red` | Ningún cliente de red fuera de `lib/core/network/`; ninguna conexión nativa |
| `registro` | Ningún registro en Dart ni en Kotlin |
| `secretos` | Ni claves privadas ni almacenes de firma ni configuración de herramientas de agentes |
| `i18n` | Mismas claves y marcadores en español, inglés y portugués; ninguna clave sin uso; sin emoji |
| `licencias` | Licencias permitidas y `THIRD-PARTY-NOTICES.md` al día |
| `version` | Misma versión y fecha en `pubspec.yaml`, `app_constants.dart`, `CHANGELOG.md` y `CITATION.cff` |
| `docs` | Títulos, estados, enlaces, emoticonos, rutas locales y pendientes |

## Capturas

`flutter test tool/screenshots --update-goldens` siembra 30 días de datos ficticios y captura cada pantalla en
cuatro temas (Esmeralda Nocturna, Salvia y Lino, Papel claro y Papel sepia), además de los estados de Nibi y una
galería de su dibujo. Con `--dart-define=LANG=en` o `pt` captura en ese idioma. Las capturas de la documentación
salen de aquí ([recursos](../assets/branding/README.md)).

## En el teléfono

La lógica la cubren las suites; la experiencia se comprueba con el paquete de publicación instalado (nunca con
`flutter run`) y con datos de demostración, nunca con datos reales: bienvenida desde cero, cada pestaña, escáner,
dictado, báscula si la hay, ayuno con la pantalla bloqueada, recordatorios y su botón "Hecho", Health Connect,
copia de seguridad y restauración, cambio de idioma y de tema, y actualización encima de la versión anterior.

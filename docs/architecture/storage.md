# Almacenamiento

> **Estado:** Implementado.

Un único archivo SQLite gestionado con Drift. Es la fuente de verdad de la app y, a la vez, la copia de seguridad
de la persona ([ADR-002](../adr/002-offline-first.md)).

## 1. Convenciones

- **Fechas como texto ISO-8601** (`store_date_time_values_as_text: true` en `build.yaml`): el archivo se lee con
  cualquier herramienta de SQLite.
- **`date_key` (`AAAA-MM-DD`)** en todo registro diario: agrupa por día de calendario local.
- **Enums con `TypeConverter`**: se guarda el valor estable (`mi_scale_2_ble`, `breakfast`…), nunca el índice.
- **La edad no se guarda**: se calcula desde `birth_date` con la fecha de `Clock`.
- **"Sin dato" no es 0**: los micronutrientes desconocidos son `NULL` ([ADR-015](../adr/015-essential-micronutrients.md)).
- Nombres en *snake case*, claves foráneas activas y modo WAL.

## 2. Tablas (esquema 8)

| Área | Tabla | Contenido |
|---|---|---|
| Perfil | `user_profiles` | Datos personales, metas, tema, fase de dieta, macros manuales, ciclado de calorías, equipos declarados, módulos de Cuidado, avisos discretos, hora de dormir, banderas de seguridad |
| | `ui_preferences` | Preferencias clave y valor: idioma, disposición de Inicio, ícono, idioma de la semilla |
| | `reminders` | Recordatorios con hora, días y estado |
| Cuerpo | `body_measurements` | Pesajes (báscula, manual, Health Connect) con tendencia, métricas de bioimpedancia, cinta y explicación de falsa subida |
| | `tdee_calibrations` | Historial del gasto adaptativo |
| | `milestone_goals` | Metas intermedias de peso |
| | `workout_blocks` | Entrenamientos (tipo, minutos, esfuerzo, MET, kcal netas) |
| | `female_cycle_logs` | Ciclo menstrual |
| Actividad | `daily_summaries` | Pasos, sueño con fases, hora de despertar y frecuencia cardiaca en reposo por día |
| | `health_sync_checkpoints` | Último punto sincronizado con Health Connect por tipo de dato |
| Comida | `food_items` y su índice FTS5 | Catálogo: semilla USDA, Open Food Facts, creados por la persona, recetas |
| | `food_logs` | Lo comido, con macros y micronutrientes ya calculados |
| | `meal_combos`, `meal_combo_items` | Combos habituales |
| | `recipes`, `recipe_ingredients` | Recetas por raciones |
| | `hydration_logs` | Cada vaso de agua |
| | `caffeine_logs` | Tomas de cafeína |
| | `supplements_tracker`, `supplement_logs` | Medicamentos y suplementos (horas, días, reserva, avisos) y cada toma |
| Ayuno | `fasting_sessions` | Ayunos (protocolo, inicio, fin, meta) |
| Diario | `journal_entries` | Texto, ánimo, energía, estrés, etiquetas, resumen y foto (JPEG reducido, dentro de la base para que viaje en la copia) |
| | `digestive_logs` | Escala de Bristol y molestias |
| Nibi | `pet_status` | Nombre, monedas, racha, escudos, objetos y lo que lleva puesto |
| | `coin_ledger` | Libro de monedas; índice único por día y tipo salvo compras |
| Plan | `protocol_plans` | Protocolo semanal |
| Cuidado | `care_sessions` | Sesiones guiadas: suelo pélvico, pausas, descanso visual, respiración |
| | `custom_habits`, `habit_logs` | Hábitos propios y su marca diaria |
| | `checkups`, `checkup_logs` | Chequeos preventivos y cuándo se hizo cada uno |
| | `symptom_logs` | Síntomas con intensidad y nota |
| | `vital_readings` | Tensión, glucosa, oxígeno y temperatura (identificador externo único) |
| | `substance_logs` | Alcohol (enlazado a su registro en Comida) y tabaco |
| | `wellbeing_checks` | Índice OMS-5 |
| Libre | `quit_trackers`, `quit_events` | Contadores para dejar hábitos, ganas superadas y reinicios |

El índice `food_items_fts` (FTS5, `unicode61 remove_diacritics 2`) se mantiene con tres *triggers*: buscar
"platano" encuentra "plátano".

## 3. Migraciones

`schemaVersion = 8`. Cada versión publicada tiene su volcado en `drift_schemas/` y una migración paso a paso
(`app_database.steps.dart`, generado con `dart run drift_dev make-migrations`).
`test/drift/app_database/migration_test.dart` migra cada versión a todas las posteriores y comprueba que los datos
sobreviven. Una migración publicada no se edita nunca.

La apertura nativa ejecuta `respaldo_de_migracion.dart` en el isolate de SQLite antes de que Drift migre un
archivo existente. Usa `VACUUM INTO` para incluir el WAL confirmado y verifica integridad y versión de la copia.
Cada intento conserva un respaldo distinto en un subdirectorio privado junto a la base; no sobrescribe los
anteriores. Si no puede respaldar o validar, la apertura falla antes de migrar. Las bases nuevas, actuales y en
memoria no generan esta copia.

## 4. Semilla

Al crear la base se escriben unos 165 alimentos con valores de USDA FoodData Central y la porción habitual
(`core/database/seeder/`), en el idioma de la interfaz de ese momento (`seed_foods_i18n.dart`). El idioma usado se
guarda en `ui_preferences.semilla_idioma`, de modo que los alimentos que se añadan en versiones posteriores llegan
en ese mismo idioma y el catálogo nunca mezcla idiomas.

## 5. Copia de seguridad (`BackupService`)

- **Exportar:** `VACUUM INTO` a un archivo temporal privado, compartido con el diálogo del sistema. La copia es
  consistente aunque la app esté escribiendo.
- **Restaurar:** se inspecciona el archivo (integridad, referencias, tablas mínimas y versión). Si es de una versión
  anterior, se migra una copia temporal. Se reserva acceso exclusivo al ejecutor de Drift, incluidos los isolates
  conectados, y se guarda un respaldo íntegro del estado actual mediante `VACUUM INTO`. Cada respaldo se conserva
  en un directorio privado distinto junto a la base, con prefijo `.nb-selfcare-restauracion-`; no sobrescribe otro.
  Su integridad y versión se comprueban en un isolate antes de modificar el destino. Si falla, no restaura.
- Después se copian las tablas columna a columna en `BEGIN IMMEDIATE`, se reconstruye FTS5 y se comprueban las
  referencias del destino antes de confirmar. Una referencia rota revierte la operación, aunque el archivo de
  origen omita sus restricciones. Se retira el adjunto y se reactivan las claves también al fallar. Solo se avisa
  a la interfaz después de confirmar. El archivo original seleccionado nunca se modifica.
- El origen se clona en segundo plano con `VACUUM INTO`, incluyendo su WAL confirmado, y se valida la instantánea
  obtenida. Copiar solo el archivo principal podría omitir datos todavía presentes en el WAL. Una copia que no
  contiene todas las tablas del esquema migrado se rechaza antes de borrar filas del destino.
- Un archivo que no es una copia de NB SelfCare (una foto, un ZIP, un `.sqlite` truncado o corrupto) se rechaza con
  un mensaje claro.

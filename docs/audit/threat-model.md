# Modelo de amenazas

> **Estado:** Aplicable.

| Amenaza | Mitigación |
|---|---|
| Fuga de datos de salud a terceros | Sin SDK de terceros que informen, sin cuentas ni servidores; dos destinos de red sin datos de la persona ([privacidad](privacy.md)) |
| Una dependencia que abre conexiones propias | Toda construcción de clientes de red está en `lib/core/network/` (`tool/guardianes/red.dart`) y cada cliente rechaza hosts ajenos |
| Fuga por registros | No hay registros (`tool/guardianes/registro.dart`) |
| Copia automática a la nube del sistema | `android:allowBackup="false"`, comprobado por una prueba |
| Una copia de seguridad manipulada o corrupta | Se valida integridad, tablas y versión antes de restaurar; se copia columna a columna dentro de una transacción; el archivo de origen no se modifica |
| Una respuesta de Open Food Facts con basura | Cada campo se valida y se normaliza; valores imposibles se descartan (`open_food_facts_resilience_test`) |
| Una respuesta nativa inesperada | `callNative` nunca lanza; tipos inesperados devuelven `null` (`native_contract_test`) |
| Tramas de báscula falsas o corruptas | El decodificador acota cada campo; 50 000 tramas aleatorias en `scale_edges_test` |
| Una actualización manipulada | Solo se instala si el tamaño y el SHA-256 coinciden con los publicados; Android exige además la misma firma que la app instalada |
| Datos de salud en la pantalla de bloqueo | Avisos discretos y privados por defecto |
| Pérdida de datos en una actualización | Migraciones con prueba desde cada esquema publicado |

Fuera de alcance: un dispositivo con acceso de superusuario, una persona con el teléfono desbloqueado y los
servicios del sistema (Health Connect, reconocimiento de voz).

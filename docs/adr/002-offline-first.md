# ADR-002: Todo vive en el teléfono

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

Peso, comidas, medicamentos, síntomas, fotos del diario y ciclo menstrual son de lo más íntimo que una persona
registra. Cualquier servidor sería un punto de fuga y un coste que alguien acabaría pagando con esos datos.

## Alternativas consideradas

1. **Sin servidores, con copia exportable.** Privacidad completa; la persona es responsable de su copia.
2. **Sincronización cifrada propia.** Exige cuentas, infraestructura y un modelo de negocio.
3. **Copia automática de Android.** Replica la base de datos en la nube de Google sin que la persona lo decida.

## Decisión

* Un único archivo SQLite en el almacenamiento privado de la app. Ninguna cuenta, ningún servidor propio.
* `android:allowBackup="false"`: el sistema nunca copia los datos a la nube.
* La copia de seguridad es el propio archivo `.sqlite`, generado con `VACUUM INTO` y compartido con el diálogo del
  sistema. Restaurar valida el archivo y migra copias de versiones anteriores.
* Las fechas se guardan como texto ISO-8601: la copia se lee con cualquier herramienta de SQLite.

## Consecuencias

* La app funciona igual sin conexión. Las dos únicas salidas a internet se describen en [ADR-004](004-network-exit.md).
* Perder el teléfono sin una copia es perder los datos; la app lo explica en Ajustes, Tus datos.
* Ver [almacenamiento](../architecture/storage.md) y [privacidad](../audit/privacy.md).

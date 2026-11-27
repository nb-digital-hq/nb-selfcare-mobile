# Sincronización local con el escritorio

> **Estado:** Aceptado.

## Contexto

Una copia exportada conserva datos, pero no comunica dos instalaciones mientras ambas siguen registrando.
El teléfono debe mantener su autonomía y su funcionamiento sin conexión.

## Decisión

La aplicación se sincroniza en ambos sentidos con SelfCare de escritorio mediante vinculación explícita,
transporte local cifrado, fijación de certificado y credenciales revocables en el almacenamiento seguro del SO.
No se añade nube, cuenta ni telemetría. El cliente pertenece a `core/network/` y la presentación sigue usando
casos de uso de `features/*/application/`.

Las operaciones tienen identidad estable y revisión base. Las eliminaciones viajan como bajas y los conflictos
conservan los cambios de ambas instalaciones hasta su resolución. Los reintentos no duplican registros ni
recompensas. Cada cambio sigue validando las reglas de salud; una toma no genera monedas por llegar del PC.
Una restauración de copia no clona credenciales ni autoridad de dispositivo.

## Consecuencias

El ordenador vinculado es un destino local distinto de las dos salidas públicas y la Constitución conserva su
principio de consentimiento. El escritorio reconcilia los cambios simultáneos. El [contrato](../architecture/pc-contract.md)
tiene modelos, esquema y pruebas equivalentes en Dart y Rust.

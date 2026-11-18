# ADR-023: Actualizaciones desde GitHub

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

La app se instala fuera de una tienda. Sin un mecanismo propio, cada versión nueva exige descargar el APK a mano.

## Decisión

En Android, Ajustes, Acerca de y actualizaciones tiene "Buscar actualizaciones". Solo entonces se consulta
`api.github.com/repos/nb-digital-hq/nb-selfcare-mobile/releases/latest`, se elige el APK de la arquitectura del
teléfono, se comprueban su tamaño y su SHA-256 publicados y se entrega al instalador del sistema. Nunca se consulta
en segundo plano.

## Consecuencias

* Android rechaza un APK firmado con otra clave: solo se instalan versiones del mismo autor.
* Es uno de los dos destinos de red ([ADR-004](004-network-exit.md)).

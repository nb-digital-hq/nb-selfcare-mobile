# ADR-011: Lectura directa de la báscula

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

La app del fabricante de la Xiaomi Mi Body Composition Scale 2 exige una cuenta y exporta a Health Connect solo
una parte de las métricas.

## Decisión

La app escucha los anuncios Bluetooth de la báscula (servicio `0x181B`, trama de 13 bytes), sin emparejar ni
conectarse, decodifica peso e impedancia en Dart y calcula las 13 métricas de composición en el teléfono. El
contrato `BodyScaleDriver` permite añadir otras básculas; las demás marcas entran por Health Connect.

## Consecuencias

* Ninguna cuenta del fabricante y ningún dato sale del teléfono.
* Con marcapasos, implantes o embarazo declarados se ignora la impedancia y solo se registra el peso.
* Detalle en [biometría y báscula](../architecture/biometrics-and-scale.md).

# ADR-004: Una sola puerta de red

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

La app no necesita internet para funcionar, pero dos tareas sí lo requieren: identificar un producto envasado que
no está en el catálogo local y descargar una versión nueva. Si cualquier parte del código pudiera abrir una
conexión, la promesa de privacidad dependería de la disciplina de cada cambio.

## Alternativas consideradas

1. **Una puerta única con destinos acotados y un guardián automático.** La promesa se comprueba en cada cambio.
2. **Revisión manual.** Frágil: un paquete nuevo o un descuido abren una salida sin que nadie lo note.
3. **Sin red en absoluto.** Obligaría a teclear cada producto envasado y a actualizar con cable.

## Decisión

* Todo cliente HTTP se construye en `lib/core/network/salidas.dart` (`clienteDeRed(Destino)`), que rechaza cualquier
  host que no pertenezca al destino pedido y cualquier esquema que no sea HTTPS.
* Hay exactamente dos destinos, y los dos empiezan con un gesto de la persona:

| Destino | Hosts | Cuándo |
|---|---|---|
| `openFoodFacts` | `world.openfoodfacts.org` | Al escanear un código que no está en el teléfono o al tocar "Buscar en Open Food Facts" |
| `actualizaciones` | `api.github.com`, `github.com` | Solo en Android, al tocar "Buscar actualizaciones" |

* Ninguna petición lleva datos de la persona: solo el código de barras o las palabras buscadas, o la petición de la
  última versión.
* `tool/guardianes/red.dart` rechaza cualquier cliente HTTP, socket, WebSocket o imagen remota fuera de
  `lib/core/network/`, y cualquier conexión en el código Kotlin.

## Consecuencias

* Añadir un destino es una decisión nueva (ADR) y un cambio visible en [privacidad](../../PRIVACY.md).
* Los productos de Open Food Facts se guardan al instante: el mismo código no vuelve a pedirse.

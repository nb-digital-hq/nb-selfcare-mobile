# Libre: hábitos que dejas

> **Estado:** Implementado.

Un contador por hábito, con la misma lógica del ayuno: el tiempo corre solo, se ve lo que ya ganaste y cada hito se
celebra. Un tropiezo nunca borra lo logrado ([ADR-024](../adr/024-quit-counters.md)).

## 1. Dónde está

- **Cuidado → Libre**: la tarjeta encabeza la pestaña con cada contador (racha viva, anillo hacia el próximo hito y dinero ahorrado). Se oculta en Ajustes → Módulos como cualquier apartado.
- **`/libre`**: todos los contadores. **`/libre/:id`**: el detalle.

## 2. Crear un contador

Se elige del catálogo o se escribe uno propio (máx. 40 caracteres):

| Hábito | Se mide en | Beneficios con fuente |
| :-- | :-- | :-- |
| Tabaco | cigarrillos al día | Sí (OMS, CDC, Sociedad Americana del Cáncer) |
| Vapeo | veces al día | Sí (NHS: abstinencia a la nicotina) |
| Alcohol | bebidas al día | Sí (incluye aviso de seguridad: dejarlo de golpe tras un consumo alto puede ser peligroso) |
| Azúcar y dulces, bebidas azucaradas, comida chatarra | porciones / vasos | Sí (adaptación del gusto dulce, energía estable) |
| Cafeína | tazas al día | Sí (Juliano y Griffiths, 2004: la abstinencia empieza a las 12–24 h, pico a las 20–51 h, dura 2–9 días) |
| Redes sociales, videojuegos | minutos al día | Sí (Hunt et al., 2018: limitar redes 3 semanas reduce soledad y depresión) |
| Apuestas | — | Sí |
| Cannabis | veces al día | Sí (Budney: pico de abstinencia entre los días 2 y 6; Hirvonen, 2012: receptores CB1 normalizados en ≈ 4 semanas) |
| Contenido para adultos | minutos al día | Solo hitos comunes |
| Morderse las uñas | — | Sí (crecimiento ≈ 3 mm/mes) |

Todo es opcional salvo el hábito: desde cuándo (ahora o una fecha pasada), lo que se gastaba al día, cuánto se consumía o el tiempo que se le dedicaba, y **tu porqué** (se muestra en el detalle y en "Tengo ganas"). Si se empieza con días ya ganados, los hitos pasados no se celebran de golpe.

## 3. El detalle

- **Racha viva**: anillo hacia el próximo hito, días en grande y hh:mm:ss (en papel, h y min, una vez por minuto). Insignia "Tu mejor racha" cuando la actual la iguala.
- **Lo que ya ganaste**: dinero ahorrado, unidades que no fueron, tiempo recuperado, mejor racha, tiempo libre total (si hubo reinicios) y ganas superadas. Dinero y unidades se calculan sobre el tiempo libre total, no solo la racha actual.
- **Lo que recupera tu cuerpo**: línea de tiempo con los beneficios alcanzados y una barra hacia el siguiente.
- **Hitos**: 1, 3, 7 y 14 días; 1 mes; 66 días (mediana para que un hábito sea automático, Lally et al., 2010); 3 y 6 meses; 1 y 2 años. Al alcanzar uno se celebra una vez por racha con +25 monedas (una vez al día).
- **Tengo ganas**: 3 minutos guiados para "surfear la ola" (inhalar 4 s, exhalar 6 s; en papel, el círculo no se mueve), con tu porqué y un consejo práctico. "Pasó la ola" lo registra y da +10 monedas la primera vez del día.
- **Reiniciar el contador**: pide confirmación con un mensaje sin culpa y una nota opcional ("¿Qué pasó?") para ver patrones; la racha que termina se suma al total y a la mejor racha; se puede deshacer.
- Menú: editar, archivar (con Deshacer) o eliminar (con su historial).

## 4. Datos

`quit_trackers` y `quit_events` ([almacenamiento](storage.md)). La lógica pura está en `lib/features/quit/domain/` (`QuitProgress.compute`, catálogo e hitos) y se prueba en `test/quit/`.

# ADR-016: Cronómetro de ayuno del sistema

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

Mostrar los segundos de un ayuno con un servicio en primer plano gasta batería todo el día.

## Decisión

En Android, la notificación del ayuno usa `setUsesChronometer`: el sistema cuenta los segundos sin la app en
memoria. El texto cambia en cada fase y a medianoche con alarmas inexactas. En Android 16 se promueve a Live Update.

## Consecuencias

Cero consumo en segundo plano. En iOS el ayuno se ve dentro de la app.

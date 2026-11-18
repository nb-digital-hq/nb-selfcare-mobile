# ADR-022: Medicamentos y avisos

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

Un aviso de medicación en la pantalla de bloqueo revela datos de salud, y convertir un tratamiento en un juego puede
hacer sentir culpa por una toma olvidada.

## Decisión

* Los avisos de tomas son discretos por defecto: sin el nombre del medicamento y privados en la pantalla de bloqueo.
* El aviso lleva un botón "Hecho" que funciona con la app cerrada: Android guarda la acción y la app la aplica al
  abrirse.
* Las tomas no dan monedas. Una toma se marca "tomada" u "omitida", nunca "olvidada".
* Las bebidas alcohólicas registradas en Cuidado suman sus calorías en Comida.

## Consecuencias

Marcar una toma no requiere red ni abrir la app; la reserva se descuenta al marcar y se devuelve al deshacer.

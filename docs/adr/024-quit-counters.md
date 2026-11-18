# ADR-024: Libre, contadores para dejar hábitos

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

Dejar un hábito (tabaco, alcohol, azúcar, redes) es de lo que más mejora la salud y lo que más se abandona tras un
tropiezo. Los contadores de "días limpios" suelen volver a cero y con ellos la sensación de logro.

## Decisión

* Cada contador guarda el inicio de la racha, el tiempo libre de rachas anteriores y la mejor racha. Reiniciar mueve
  el inicio, suma la racha al total y conserva la mejor; se puede deshacer y el texto nunca culpa.
* Hitos comunes (1, 3, 7 y 14 días, 1 mes, 66 días, 3 y 6 meses, 1 y 2 años) se celebran una vez por racha y dan
  monedas. 66 días es la mediana de automatización de un hábito (Lally et al., 2010).
* "Tengo ganas" guía tres minutos de respiración para dejar pasar la ola.
* Los beneficios por hábito citan fuentes de salud pública con lenguaje prudente. El alcohol muestra un aviso de
  seguridad sobre dejarlo de golpe.

## Consecuencias

Apartado de Cuidado con rutas `/libre` y `/libre/:id`. Convive con "Alcohol y tabaco" (registrar consumo para
reducir) sin mezclarse. Detalle en [Libre](../architecture/quit.md).

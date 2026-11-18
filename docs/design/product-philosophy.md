# Filosofía de producto

> **Estado:** Aplicable.

Una sola app, para una persona, que reúne lo que normalmente reparten varias apps de pago: comida y minerales,
báscula, gasto adaptativo, ayuno, sueño, medicamentos, hábitos, suelo pélvico, pausas activas, signos vitales,
síntomas, chequeos preventivos, contadores para dejar hábitos, diario y una mascota que hace agradable la
constancia.

## Principios

| Principio | Cómo se cumple |
|---|---|
| **Sin nube ni telemetría** | Todo vive en un archivo SQLite del teléfono; dos salidas de red, ambas pedidas por la persona |
| **Tus datos son tuyos** | La copia de seguridad es un archivo `.sqlite` legible con cualquier herramienta |
| **Menos de 15 segundos** | Ningún registro exige formularios largos y todo ofrece Deshacer |
| **Cascada reactiva** | Un pesaje o un cambio de día recalcula tendencia, metas, monedas y el ánimo de Nibi sin "actualizar" |
| **Sin culpa** | Nibi nunca enferma ni regaña; una racha perdida se reinicia sin reproches; un tropiezo en Libre conserva lo logrado |
| **Lo que no tienes no aparece** | Báscula y aparatos de signos vitales son opcionales; cada apartado de Cuidado se puede ocultar |
| **Degradación elegante** | Sin Health Connect, sin báscula, sin red o sin permisos, todo funciona a mano |
| **Calma visual** | Un acento por pantalla, cada dato en un solo lugar y la ayuda bajo demanda |

## Presupuesto de fricción

| Flujo | Toques | Tiempo |
|---|:-:|:-:|
| Vaso de agua | 1 | menos de 2 s |
| Repetir la comida de ayer | 1 | menos de 3 s |
| Combo habitual | 2 o 3 | menos de 6 s |
| Entrenamiento | 3 o 4 | menos de 5 s |
| Producto ya escaneado | 2 o 3 | menos de 8 s |
| Pesaje con la báscula | 1 y subirse | menos de 15 s |
| Entrada corta de diario | 2 y texto | menos de 15 s |
| Marcar una toma | 1 | menos de 2 s |

## Salud y seguridad

* **No es un dispositivo médico.** La bioimpedancia y las fases del ayuno son estimaciones.
* La bienvenida pregunta por marcapasos, implantes o embarazo (la báscula mide solo el peso), antecedentes de
  trastornos alimentarios (ritmo suave y ayunos de hasta 16 h) y medicación que baja la glucosa (aviso antes de
  cada ayuno).
* Nunca se proponen calorías por debajo del metabolismo basal.
* Signos vitales y chequeos son orientativos (AHA, ADA, OMS, Resolución 3280 de 2018) y remiten a consulta; un
  índice OMS-5 bajo muestra líneas de apoyo que abren el marcador sin llamar.

## Lo que la app no hace

Cuentas, nube, copias automáticas, funciones sociales, diagnósticos, dosis sugeridas, interacciones entre fármacos,
registro serie por serie, bibliotecas de meditaciones ni coach de inteligencia artificial.

# Ayuno, diario y analítica

> **Estado:** Implementado.

Ayuno intermitente con fases, diario privado, cafeína, digestión y patrones entre hábitos. Código en
`lib/features/fasting/`, `lib/features/journal/` y `lib/core/services/cross_analytics_engine.dart`.

## 1. Motor de Ayuno Intermitente y Fases Metabólicas

El cronómetro no mantiene procesos en segundo plano. Se empieza desde la tarjeta de Inicio; mientras dura, se ve en la barra fija sobre la
navegación ([ADR-008](../adr/008-information-architecture.md)).

* **Protocolos:** 14:10 (suave), 16:8 (el más popular), 18:6, 20:4 y personalizado (horas exactas). El ayuno puede empezar ahora o en una hora anterior ("Empecé antes"), y la hora de inicio se puede ajustar después.
* **Seguridad (`FastingDosageAdvisor`):** con antecedentes de trastornos alimentarios se proponen ayunos de hasta 16 h; con medicación que baja la glucosa, un aviso antes de empezar; tras un ayuno prolongado reciente, una sugerencia de pausa.
* **Romper el ayuno:** tras 18 h o más se ofrece una guía para la primera comida.

### Línea de Tiempo Fisiológica

La interfaz mapea la hora actual del ayuno con la transición bioquímica real:

| Intervalo | Fase Metabólica | Marcador Fisiológico |
| :-- | :-- | :-- |
| **$0\text{–}4\text{ h}$** | **Fase digestiva** | Digestión, absorción de glucosa y aminoácidos, insulina elevada. |
| **$4\text{–}12\text{ h}$** | **Usando glucógeno** | Caída de insulina a nivel basal; degradación de glucógeno hepático para mantener normoglucemia. |
| **$12\text{–}18\text{ h}$** | **Quema de grasa** | Agotamiento del glucógeno hepático; activación de lipasa sensible a hormonas y beta-oxidación de ácidos grasos. Se activa el aura en la mascota `Nibi`. |
| **$18\text{–}24\text{ h}$** | **Cetosis** | Producción hepática de cuerpos cetónicos ($\beta$-hidroxibutirato y acetoacetato). |
| **$> 24\text{ h}$** | **Autofagia** | Reciclaje lisosomal de orgánulos y proteínas dañadas. *Aviso de seguridad y recordatorio de electrolitos (Na, K, Mg)*. |

### Notificación sin consumo en segundo plano (Android)

La notificación usa el cronómetro del propio sistema (`FastingNotifier`, [ADR-016](../adr/016-native-fasting-timer.md)):
```kotlin
NotificationCompat.Builder(context, NotificationChannels.FASTING)
    .setUsesChronometer(true)
    .setChronometerCountDown(false)
    .setWhen(sessionStartedAtTimestamp)
    .setOngoing(true)
```
Android actualiza los segundos sin que la app esté en memoria. En **Android 16** se promueve a *Live Update* (chip en la barra de estado). El texto ("Ayuno 16:8 · Quema de grasa", "Meta mañana a las 15:28") se actualiza con alarmas inexactas en cada cambio de fase y a medianoche; los nombres de las fases coinciden con los de la app en los tres idiomas (lo verifica `native_contract_test`).

---

## 2. Diario Privado y Metadatos Locales

* **Entrada de Texto Libre:** Para registrar reflexiones, sensaciones de energía, comidas fuera de casa o eventos de vida.
* **Ánimo, energía y estrés** (1–5) con selectores de un toque, y frases guía (gratitud, sensación corporal, pequeño logro, soltar tensión) para empezar a escribir.
* **Foto de progreso:** se reduce y se guarda dentro de la base de datos; nunca va a la galería ni a la nube, y viaja en la copia de seguridad.
* **Etiquetas y resumen:** `TextAssistant.analyzeJournal` detecta temas con listas de palabras en español, inglés y portugués y escribe una línea de resumen en el idioma activo, sin modelos de lenguaje ([ADR-010](../adr/010-deterministic-text.md)). "Sugerir estado" propone ánimo, energía y estrés a partir del texto.
* **Cafeína y sueño:** cada toma con su dosis; un modelo farmacocinético (vida media de 5,5 h) estima cuánta queda al acostarse y sugiere la hora límite del último café.
* **Digestión:** escala de Bristol y molestias, para cruzarlas con lo comido.

---

## 3. Patrones entre hábitos (`CrossAnalyticsEngine`)

Con al menos 10 días emparejados, el motor calcula correlaciones de Pearson y diferencias de medias y las muestra en
Perfil, Descubrimientos:

| Pareja | Qué cruza |
|---|---|
| Estrés y carbohidratos | Nivel de estrés del diario y carbohidratos del día |
| Duración del ayuno y calorías | Horas de ayuno terminado y calorías del día |
| Sueño y energía | Horas de sueño y energía del diario del día siguiente |
| Agua y energía | Agua del día y energía del diario |
| Sueño y síntomas | Horas de sueño e intensidad de los síntomas |
| Alcohol y sueño | Bebidas de un día y sueño de esa noche |

El hallazgo se formula siempre como una relación observada en los propios registros, nunca como una orden médica.


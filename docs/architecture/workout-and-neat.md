# Entrenamiento y movimiento

> **Estado:** Implementado.

Gasto por ejercicio con bloques de esfuerzo percibido y actividad diaria por pasos ([ADR-014](../adr/014-workout-blocks.md)).

## 1. Modelo

El gasto se separa en dos:
1. **NEAT pasivo (Non-Exercise Activity Thermogenesis):** los pasos se leen de **Health Connect** al abrir la app (o se registran a mano con +1.000 / Ajustar).
2. **Entrenamiento Intencional:** Se captura en **$< 5\text{ segundos}$** mediante 3 selectores simples que calculan el gasto energético neto mediante el Equivalente Metabólico de la Tarea (**MET**).

---

## 2. La Interfaz de 3 Selectores

El modal `QuickRpeWorkoutSheet` presenta:

1. **Categoría de Actividad (`category`):**
   * `weights` — Pesas / Entrenamiento de Fuerza con sobrecarga.
   * `calisthenics` — Calistenia / Ejercicio Funcional / Peso Corporal.
   * `cardio` — Trote, Ciclismo, Natación, HIIT.
   * `sports` — Fútbol, Baloncesto, Tenis, Pádel, Artes Marciales.
2. **Duración en Minutos (`durationMinutes`):**
   * Atajos de $20$, $30$, $45$, $60$ y $90$ minutos y un deslizador de $10$ a $180$ minutos.
3. **Intensidad Percibida (`rpeIntensity`):**
   * `light` — RPE 1–4: Respiración tranquila, se puede mantener una conversación fluida.
   * `moderate` — RPE 5–7: Respiración acelerada, esfuerzo sostenido, hablar con pausas.
   * `intense` — RPE 8–10: Máximo esfuerzo, sudoración intensa, incapacidad para hablar.

---

## 3. Matriz Oficial de METs y Ecuación de Gasto Neto

Para no duplicar el gasto basal que ya está contabilizado en la Tasa Metabólica Basal (BMR) del usuario, se descuenta $1.0\text{ MET}$ (equivalente al reposo estático):

| Categoría (`category`)                 | `light` (MET) | `moderate` (MET) | `intense` (MET) |
| :------------------------------------- | :-----------: | :--------------: | :-------------: |
| `weights` (Fuerza / Musculación)       |      3.5      |       5.0        |       6.5       |
| `calisthenics` (Calistenia / Funcional)|      3.8      |       5.5        |       8.0       |
| `cardio` (Cardiovascular / Intervalos) |      5.0      |       7.5        |      10.5       |
| `sports` (Deportes de Contacto/Equipo) |      5.0      |       7.0        |       9.5       |

### Fórmula del Gasto Calórico Neto

$$\text{NetMET} = \text{appliedMet} - 1.0$$

$$\text{NetCaloriesBurned} = \text{round}\left(\text{NetMET} \times 3.5 \times \frac{W_{\text{actual}}}{200} \times \text{durationMinutes}\right)$$

Donde $W_{\text{actual}}$ es el **último peso registrado** (o el peso del perfil si aún no hay pesajes).

---

## 4. Impacto en el Balance Energético Diario

El gasto neto calculado se inserta en `workout_blocks` y se refleja inmediatamente en Inicio y en el balance de Comida:
$$\text{Calorías Restantes} = \text{Meta Adaptativa (TDEE)} + \text{Gasto Neto Entrenamientos} - \text{Calorías Consumidas}$$

Así la meta del día solo crece en proporción al esfuerzo real.


# Registro de decisiones de arquitectura

> **Estado:** Aplicable. Un ADR aceptado solo se cambia con otro ADR.

Cada decisión con impacto en la arquitectura, en la licencia o en lo que la app promete se registra aquí con su
contexto, las alternativas y sus consecuencias. La plantilla es [000-template.md](000-template.md).

| ADR | Decisión | Estado |
|---|---|---|
| [001](001-tech-stack.md) | Flutter, Drift y Riverpod | Aceptado |
| [002](002-offline-first.md) | Todo vive en el teléfono; la copia de seguridad es un archivo `.sqlite` | Aceptado |
| [003](003-licensing-model.md) | Apache 2.0 para la app; lo institucional, comercial y separado | Aceptado |
| [004](004-network-exit.md) | Una sola puerta de red, dos destinos, ambos pedidos por la persona | Aceptado |
| [005](005-barcode-scanner.md) | Escáner de códigos con ZXing; sin ML Kit ni lectura de etiquetas por foto | Aceptado |
| [006](006-internationalization.md) | Interfaz en español, inglés y portugués con ARB y el español como plantilla | Aceptado |
| [007](007-platforms-and-distribution.md) | Android verificado, iOS sin probar, distribución solo por GitHub | Aceptado |
| [008](008-information-architecture.md) | Cinco pestañas; el perfil en el avatar y el ayuno en una barra fija | Aceptado |
| [009](009-visual-system.md) | Un acento por pantalla, colores semánticos fijos y temas de color y de papel | Aceptado |
| [010](010-deterministic-text.md) | Texto y dictado con un analizador determinista, sin modelo de lenguaje | Aceptado |
| [011](011-direct-ble-scale.md) | Lectura directa de la Mi Scale 2 por Bluetooth, sin la app del fabricante | Aceptado |
| [012](012-body-fat-fusion.md) | Grasa corporal combinada: 60 % bioimpedancia y 40 % cinta métrica | Aceptado |
| [013](013-adaptive-tdee.md) | Gasto diario adaptativo con ventana de 14 días y ajuste acotado | Aceptado |
| [014](014-workout-blocks.md) | Entrenamientos por bloques de esfuerzo percibido, sin series | Aceptado |
| [015](015-essential-micronutrients.md) | Minerales esenciales y "dato no reportado" en lugar de 35 barras vacías | Aceptado |
| [016](016-native-fasting-timer.md) | Cronómetro de ayuno del propio sistema, sin servicio en primer plano | Aceptado |
| [017](017-single-user.md) | Una sola persona por teléfono, sin funciones sociales | Aceptado |
| [018](018-positive-gamification.md) | Nibi nunca enferma ni regaña; escudos de racha en lugar de castigos | Aceptado |
| [019](019-procedural-pet.md) | Nibi dibujado en código, sin archivos de animación | Aceptado |
| [020](020-declared-devices.md) | Lo que no se tiene no aparece: báscula y aparatos declarados | Aceptado |
| [021](021-health-connect.md) | Health Connect: leer lo declarado, escribir lo propio | Aceptado |
| [022](022-medication-reminders.md) | Medicamentos sin monedas, avisos discretos y "Hecho" desde la notificación | Aceptado |
| [023](023-in-app-updates.md) | Actualizaciones desde GitHub, solo cuando la persona lo pide | Aceptado |
| [024](024-quit-counters.md) | Libre: contadores para dejar hábitos, sin culpa | Aceptado |

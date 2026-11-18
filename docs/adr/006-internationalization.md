# ADR-006: Español, inglés y portugués

> **Estado:** Aceptado.

**Fecha:** 2026-11-18

## Contexto

La suite nace en español, pero quien la usa puede hablar inglés o portugués. La app tiene más de dos mil textos,
muchos con plurales y cifras.

## Alternativas consideradas

1. **ARB con `flutter gen-l10n` y el español como plantilla.** Mensajes ICU con plurales, accesores tipados y
   comprobación en compilación.
2. **Catálogo propio con el texto español como clave.** Sencillo, pero sin plurales ICU ni tipos.

## Decisión

* `lib/core/l10n/arb/app_es.arb` es la plantilla; `app_en.arb` y `app_pt.arb` tienen exactamente las mismas claves.
* El idioma se elige en Ajustes (el del teléfono, español, inglés o portugués) y se guarda en `ui_preferences`. "El
  del teléfono" cae en español si el sistema no está en inglés ni en portugués.
* Las cifras y fechas siguen el idioma activo ("82,5" en español y portugués, "82.5" en inglés) a través de
  `Intl.defaultLocale`.
* Los servicios sin `BuildContext` (avisos, informe PDF, consejos de ayuno, explicación de una falsa subida) reciben
  los textos del idioma activo con `l10nProvider`.
* El catálogo de alimentos de la semilla se escribe en el idioma de la interfaz la primera vez que se abre la app.
  El analizador de comidas y del diario entiende los tres idiomas.
* Los textos del lado nativo (canales y avisos que pinta Android) están en `res/values`, `values-en` y `values-pt`.
* `tool/guardianes/i18n.dart` exige las mismas claves y marcadores en los tres catálogos y ninguna clave sin uso.

## Consecuencias

* Un texto visible nuevo no se termina sin sus traducciones.
* Las líneas de apoyo emocional y la ruta de chequeos preventivos son de Colombia; en inglés y portugués se dice así
  y se remite al número de emergencias local. Ver [i18n](../architecture/i18n.md).

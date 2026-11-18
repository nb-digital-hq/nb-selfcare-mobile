# Estructura del código

> **Estado:** Implementado. La responsabilidad de cada módulo está en [visión general](../architecture/system-overview.md).

```text
lib/
  app/            Armazón, router, barra inferior, barra de ayuno, botón de perfil
  core/           clock, constants, database, domain, hardware, l10n, network, platform, services
  features/       Una carpeta por función: application, domain, presentation
  shared/         Tema, componentes y utilidades de interfaz
android/app/src/main/kotlin/   Health Connect, avisos, alarmas, actualizador, íconos por tema
android/app/src/main/res/      Íconos y textos nativos (values, values-en, values-pt)
ios/Runner/                    Proyecto iOS
drift_schemas/                 Volcados de cada esquema publicado
test/                          Pruebas por área (ver Pruebas)
tool/guardianes/               Guardianes de verificación
tool/screenshots/              Capturas de todas las pantallas
tool/gen_app_icons.py          Íconos desde el SVG del logotipo
```

Convenciones: identificadores y comentarios en español; las pantallas leen estado con `ref.watch` sobre
*providers* de `application/` y escriben con sus servicios; nunca llaman a la red ni a un DAO directamente.

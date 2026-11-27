# NB SelfCare Mobile para instituciones

> **Estado:** Aplicable. **Audiencia:** dirección, áreas de tecnología, talento humano, salud ocupacional,
> jurídicas y de cumplimiento.

NB SelfCare Mobile es una aplicación para personas: autocuidado diario en el teléfono de quien la usa, sin cuentas
ni servidores.

## Lo que la aplicación es

* **Completa y gratuita.** Ninguna función se reserva a una edición de pago.
* **Local.** Sin cuentas, sin servidores de NB Digital y sin telemetría ([privacidad](../audit/privacy.md)).
* **Abierta.** Apache License 2.0, con todo lo que se distribuye dentro de la app también abierto
  ([licencias](../legal/licensing.md)).

## Dos modelos sobre la misma base

* **Las aplicaciones para personas son de código abierto.** NB SelfCare Mobile es una de ellas.
* **Los módulos y servicios de gobernanza para instituciones son de pago**, con una licencia comercial institucional
  por suscripción, y no forman parte de este repositorio.
* **La frontera es técnica.** NB SelfCare Mobile no depende de ningún componente comercial, no habla con ningún
  servidor institucional y no envía a nadie los datos de salud de la persona.

NB SelfCare Mobile no contiene ninguna parte institucional. La oferta institucional de NB Digital para bienestar
laboral y programas de seguridad y salud en el trabajo (paneles de métricas agregadas y anónimas para áreas de
talento humano y salud ocupacional) se construye en el servidor institucional, se licencia aparte y no cambia esta
aplicación ni su licencia. Ningún dato sale de la app hacia ese servidor sin una decisión nueva, documentada y
aceptada por la persona.

## Despliegue en dispositivos gestionados

* **Android:** los APK firmados de cada publicación se pueden distribuir con la consola de gestión de dispositivos
  de la institución. La huella del certificado de firma está en [cadena de suministro](../audit/supply-chain.md).
* **iOS:** el `.ipa` se publica sin firma de Apple y sin haberse probado en un dispositivo real; una institución
  que lo despliegue lo firma con su propio perfil.
* La app no requiere salida a internet; las dos consultas posibles (Open Food Facts y actualizaciones) son opcionales
  y las pide la persona ([ADR-004](../adr/004-network-exit.md)).

## Datos personales

La app no trata datos personales en servidores: todo queda en el teléfono de la persona
([protección de datos](../legal/data-protection.md)). No es un dispositivo médico.

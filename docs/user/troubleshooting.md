# Solución de problemas

> **Estado:** Implementado.

| Problema | Qué hacer |
|---|---|
| La báscula no aparece | Activa el Bluetooth, súbete un momento para despertarla y vuelve a tocar "Pesarme". Si hay varias básculas en casa, fija la dirección de la tuya en los ajustes de la báscula |
| La báscula solo da el peso | Súbete descalzo y quédate quieto hasta que termine la medición; con marcapasos, implantes o embarazo declarados solo se mide el peso |
| El escáner no lee el código | Acerca o aleja el teléfono, enciende la linterna o escribe el código |
| No aparece el micrófono | Tu teléfono no ofrece reconocimiento de voz sin conexión; escribe la comida |
| Los recordatorios llegan tarde | Concede "Alarmas exactas" en Ajustes, Permisos |
| Health Connect no importa datos | Instálalo o actualízalo desde Google Play y concede los permisos en Ajustes, Tus equipos |
| "Buscar actualizaciones" falla | Revisa tu conexión; si GitHub limitó las consultas, espera unos minutos |
| No puedo restaurar una copia | El archivo debe ser una copia `.sqlite` de NB SelfCare; las fotos, ZIP o archivos dañados se rechazan |

Si algo sigue sin funcionar, abre una incidencia en el repositorio sin incluir datos de salud reales.

## No se sincroniza con el ordenador

Ambos equipos deben estar en la misma red local y NB SelfCare de escritorio abierto o en la bandeja, con la
conexión permitida en Ajustes > Teléfono. Las redes de invitados suelen aislar los dispositivos. Si el ordenador
cambió de dirección, la app lo busca de nuevo al sincronizar; si el ordenador retiró la autorización, vincula de
nuevo con un código nuevo. Los cambios simultáneos se deciden en el ordenador y nunca se pierden.

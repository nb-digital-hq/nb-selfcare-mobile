# Formato de intercambio con SelfCare de escritorio

> **Estado:** Implementado.

`lib/core/sync/contrato.dart` valida el mismo formato que el módulo Rust `sincronizacion::contrato` del
escritorio. La decisión es el [ADR-025](../adr/025-desktop-sync.md). La prueba usa
`test/fixtures/sincronizacion/lote-v1.json`, con datos sintéticos.

| Campo | Valor admitido |
|---|---|
| `version` | Entero 1 |
| `nodo`, `lote`, `id`, `registro` | 32 caracteres hexadecimales en minúscula |
| `cambios` | De 1 a 200; cada `id` de operación es único en el lote |
| `base` | Revisión entera de 0 a 9007199254740991 |
| `entidad` | Dominio definido en `EntidadSincronizada` |
| `operacion` | `guardar` o `eliminar` |
| `datos` | Objeto no vacío para guardar; nulo o ausente para eliminar |

Los registros se limitan a 64 KiB en UTF-8, profundidad 16, objetos de hasta 128 campos y arrays de hasta 512
valores. No se admiten campos desconocidos en el sobre ni en una operación. Las excepciones y `toString` no
exponen contenido ni identificadores.
Los números son finitos y su valor absoluto no supera 9007199254740991. Se rechazan sustitutos Unicode
aislados en cadenas y claves, para no sustituir contenido al codificarlo en UTF-8.

## Huella de operación

`core/sync/huella.dart` calcula SHA-256 con `crypto`, ya declarado en la aplicación. El prefijo UTF-8
`NB-SelfCare/operacion/1` y un byte cero preceden la codificación del objeto `{"nodo": nodo, "cambio": cambio}`.
Se incluyen todos los campos del cambio; una baja usa `datos: null`. El identificador del lote no interviene.

Cada valor lleva un byte de tipo: nulo 0, falso 1, verdadero 2, número 3, cadena 4, lista 5 y objeto 6.
Los números usan ocho bytes IEEE-754 binary64 en orden de red y normalizan cero negativo a positivo.
Las cadenas llevan su longitud UTF-8 en cuatro bytes sin signo en orden de red y después sus bytes.
Listas y objetos llevan su cantidad en cuatro bytes en orden de red. Las listas conservan orden; los objetos
ordenan claves por bytes UTF-8 y codifican cada clave como cadena seguida del valor. No se normaliza Unicode;
`1` y `1.0` coinciden, pero la cadena `"1"` es distinta.

El fixture `huellas-v1.json` contiene los mismos vectores independientes que Rust, con tipos, bajas,
subnormales y claves fuera del plano básico. Las pruebas comprueban equivalencia con campos reordenados y
distinción al modificar contenido, revisión o identidad. Las huellas permiten correlacionar contenido privado
y no se escriben en registros.

La validación estructural no autentica un PC ni permite escribir filas en la base. Los casos de uso deben
mantener las reglas de salud, la idempotencia y los conflictos definidos por el propietario. El formato no
transporta claves privadas.

## Recepción transaccional

`core/database/sincronizacion/recepcion.dart` mantiene recibos y conflictos en una transacción SQLite
`BEGIN IMMEDIATE`, bajo exclusión del ejecutor. Exige claves foráneas activas y época coincidente. La receta
`recepcion-v1.sql` se comparte con Rust como fixture; las mismas tablas forman parte del esquema 9.

Un recibo con la misma identidad y huella devuelve su resultado sin repetir la aplicación. Una identidad
reutilizada con otro contenido se rechaza como operación alterada. Una base concurrente conserva la instantánea
actual y la propuesta y devuelve conflicto. Escritura, revisión y recibo se confirman juntos; un fallo posterior
a escribir también revierte el registro. Las bajas conservan revisión y una operación de otra época no se
reintroduce. El llamador debe autenticar y comprobar consentimiento; el receptor no autoriza conexiones.

El propietario valida reglas y referencias sobre el mismo ejecutor. La instantánea que devuelve se valida y
se copia profundamente antes de esperar otra escritura; una mutación posterior de su mapa no altera el conflicto
conservado. Tras confirmar una aplicación nueva se actualizan las consultas observables; un reintento no repite
efectos. El propietario no abre otra transacción ni ejecuta servicios externos dentro de esa transacción.

Las pruebas usan un propietario sintético con SQLite real, archivo reabierto, fallos, concurrencia y mutación
del mapa durante la inserción del recibo.

## Invitación local

`core/network/sincronizacion/invitacion.dart` valida el QR compartido `invitacion-v1.json`. Contiene seis campos:
`app` (`nb-selfcare`), `version` (1), `host`, `puerto`, `huella` y `credencial`. Solo admite IP numérica privada,
de enlace local o loopback, sin DNS, zonas IPv6, multicast ni direcciones IPv4 mapeadas. El puerto está entre
1 y 65535. La huella son 32 bytes en base64 estándar canónica y la credencial efímera son 32 bytes en base64
URL canónica sin relleno. El texto completo no supera 4096 bytes UTF-8. La representación de depuración omite
credencial y dirección. El mismo texto puede pegarse en Ajustes cuando la cámara no está disponible.

## Transporte

`core/network/sincronizacion/cliente.dart` implementa el alta HTTPS, la consulta autenticada de estado y
`POST /v1/sincronizar` con el router propio de SelfCare. No usa raíces TLS del sistema, valida huella y vigencia, fuerza conexión directa,
rechaza redirecciones y limita tiempo y respuestas. El permiso se comprueba antes de enviar y al recibir; el
propietario cierra el cliente al revocar. La hora se inyecta desde `Clock` en la aplicación. Los errores son
códigos y nunca contienen dirección o credencial.

La prueba `tool/qa/enlace_local.dart`, iniciada por la prueba Rust del servidor, usa una invitación sintética
local, comprueba rechazo de huella ajena, alta, estado, reconexión y revocación en IPv4 e IPv6. La reconexión usa
el cliente TLS real y candidatos de descubrimiento simulados.

## Descubrimiento acotado

`descubrimiento.dart` busca `_nb-selfcare._tcp` durante seis segundos por defecto (máximo diez), con hasta ocho
servicios y dos resoluciones simultáneas. Acepta anuncios de versión 1 y direcciones privadas utilizables;
no acepta loopback, direcciones públicas ni IPv6 de enlace local sin zona. Solo consulta DNS para el patrón
propio `nbselfcare-….local`; el plugin no realiza resolución automática. El resultado es inmutable y contiene
candidatos sin autenticar. No se entrega una credencial hasta validar TLS con la huella ya emparejada.

Revocar el permiso o cancelar detiene la sesión. Un inicio o cierre nativo aún pendiente impide iniciar otra
sesión simultánea, y un fallo al cerrar bloquea la reutilización del descubridor. Las pruebas simulan anuncios,
resolución, cancelación e inicio tardío.

## Confirmación de una dirección nueva

`RestablecedorDelEnlace` prueba primero la dirección guardada. Si falla la red, pide candidatos al
`BuscadorDePc` inyectado por el propietario; su adaptador nativo es `DescubridorDePc`. Conserva el certificado
fijado y la credencial, y solo confirma la dirección después de un estado HTTPS autenticado. No genera otro
par ni reutiliza una invitación. Deduplica candidatos, prueba hasta ocho y acota el intento completo a treinta
segundos por defecto (máximo un minuto). Un rechazo de autorización no inicia otra búsqueda.

El propietario cancela al pausar la app, revocar el permiso o desvincular. La cancelación cierra los clientes,
detiene el descubrimiento y descarta respuestas tardías. Solo hay un intento simultáneo por propietario.
Antes de persistir se vuelve a leer el almacén seguro y se comprueba que identidad, dirección, certificado y
credencial siguen correspondiendo al estado que inició el sondeo. Una desvinculación o un emparejamiento nuevo
no se sustituye con un resultado anterior. Un error de escritura no confirma la dirección.

Las pruebas específicas cubren estas propiedades. El caso de uso de conexión lo invoca cuando una
sincronización falla por red, y reintenta una vez con la dirección confirmada.

## Persistencia de credenciales

`CredencialesDelEnlace` serializa el acceso a un único registro en `flutter_secure_storage`. La identidad del
móvil se genera con entropía segura y se conserva al desvincular el PC. Un registro dañado o una escritura
rechazada no regenera otra identidad ni confirma un cambio. La representación de depuración omite secretos y
direcciones. No hay respaldo a preferencias o SQLite. El adaptador nativo está separado del almacén en memoria
usado por las pruebas.

El adaptador de `almacen_del_sistema.dart` configura `resetOnError: false` en Android. No hereda el borrado
automático que el SDK habilita de forma predeterminada cuando no puede descifrar un registro. Un fallo nativo
se convierte en `STORAGE_FAILURE`, sin solicitar borrado ni escritura de otra identidad. Las regresiones del
canal de plataforma verifican la opción en lectura y escritura.

El proyecto iOS configura el llavero en Debug, Release y Profile, sin compartir grupos con otras apps. Sus
mensajes de permisos nativos están localizados en español, inglés y portugués. La sintaxis de recursos y el
contrato tienen pruebas.

## Esquema 9 y motor

El esquema 9 es el SQL generado por el escritorio a partir de su especificación de dominio y se conserva aquí en
`lib/core/sync/esquema_v9.dart`, sin editarlo a mano. La migración 8→9 lo ejecuta tras los pasos de Drift; no cambia
tablas existentes. Disparadores capturan cada escritura con identidad estable y revisión en su misma transacción.

`core/database/sincronizacion/motor.dart` prepara los pendientes (base en la revisión compartida y dependencias
desconocidas primero), confirma resultados, aplica lo recibido del escritorio y guarda cursor y época. Una edición
local aún no enviada no se sustituye; tras un conflicto, solo la decisión del escritorio (revisión posterior) la
reemplaza. Aplicar no vuelve a dar monedas ni descuenta reserva; agua y saldo se proyectan una vez.
`core/network/sincronizacion/sincronizador.dart` hace el ciclo completo con `POST /v1/sincronizar` dentro de TLS
fijado. `features/profile_goals/application/enlace_pc.dart` vincula con el QR, sincroniza al volver a la app, cada
cinco minutos en primer plano y veinte segundos después de una escritura, nunca en segundo plano.

Una restauración toma las identidades de la copia (migrada antes al 9) y cambia la época. Las pruebas cubren la
migración, el motor y un recorrido de proceso con el servidor real del escritorio (`tool/qa/sincronizacion_e2e_test.dart`).

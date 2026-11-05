# Solicitud de acceso a producción

Respuestas para el formulario "Solicitar acceso a producción" de Play
Console (Panel), que se activa después de 14 días de prueba cerrada con 12
o más verificadores. Los datos salen de `prueba-cerrada.md`. Se pueden
copiar tal cual; si el formulario pide menos caracteres, se recorta.

## Parte 1: la prueba cerrada

**¿Cómo reclutaste a los usuarios para la prueba cerrada?**

```
Invité a familiares, amigos y compañeros de trabajo por WhatsApp, con un
mensaje que explicaba el juego y los pasos para unirse con el enlace de la
prueba y la misma cuenta de Gmail de Play Store. Son el público real de la
app: familias y grupos de amigos que juegan charadas en reuniones. Entraron
18 personas a la lista y más de 12 aceptaron participar. A cada una le di
un código promocional para que pudiera probar también el contenido de pago
sin comprar nada.
```

**¿Qué tan fácil fue reclutar verificadores?** Ni fácil ni difícil.

**Describe la participación de los verificadores durante la prueba.**

```
Les mandé una lista de pruebas: una partida rápida, una partida por equipos
con la ruleta de castigos, ver y compartir el video del turno, el Celular
juez con un segundo celular, el Modo TV, crear una categoría propia y
Fotomímica. Jugaron en reuniones familiares y con amigos, en varios
modelos de Android. En la consola se ven 14 instalaciones y 13
dispositivos activos. Durante la prueba publiqué cinco versiones nuevas
(9 a 13) y los verificadores actualizaron con el aviso de actualización
que tiene la app.
```

**Resume los comentarios que recibiste y cómo los recogiste.**

```
Los comentarios llegaron por WhatsApp y por el correo de soporte, y los fui
anotando en una tabla con la fecha, el comentario y el cambio hecho. Los
principales: al inclinar el celular la respuesta era lenta; pedían una
pantalla para ponerse el celular en la frente antes de la cuenta, y que
funcionara sentados; a veces la palabra salía al revés; costaba encontrar
cómo jugar sin grabar; el video no aparecía en Mis videos si no se
guardaba; la ruleta tardaba en mostrar el castigo; el fondo oscuro no
oscurecía toda la app; algunas palabras de Deportes eran ejercicios y no
deportes; y después de usar el Modo TV la cámara no grababa.
```

## Parte 2: la app

**¿Quién es el público de la app?**

```
Personas de 13 años en adelante que juegan en grupo: familias, amigos y
compañeros en reuniones y fiestas, principalmente en Latinoamérica y en
español. Los niños juegan con el celular de un adulto.
```

**¿Cómo aporta valor a los usuarios?**

```
Charadeando es un juego de charadas: un jugador se pone el celular en la
frente y adivina la palabra con las pistas y la mímica de su equipo. Su
diferencia es que la cámara frontal graba el turno y arma un video con las
palabras encima, para reírse después y compartirlo. Tiene más de 25
categorías con palabras revisadas, partidas por equipos con puntaje,
ruleta de castigos, Modo TV para jugar con el televisor, un Celular juez
que marca desde el navegador sin instalar nada, categorías propias y
Fotomímica. Se juega sin cuenta y los videos no salen del celular.
```

**¿Cuántas instalaciones esperas el primer año?** 10.000 a 100.000 (o la
opción que se crea más realista).

## Parte 3: preparación para producción

**¿Qué cambios hiciste según lo que aprendiste en la prueba cerrada?**

```
Con cada comentario publiqué una versión nueva: la inclinación responde
más rápido (28° y 60 ms) y el "¡Correcto!" dura menos; antes de la cuenta
sale "Ponte el celular en la frente" y la cuenta arranca sola cuando el
celular está quieto, también sentados; la pantalla gira sola para que la
palabra nunca quede al revés; agregué Ajustes de video antes de cada turno
para grabar o no y elegir la resolución; botón Guardar, aviso y opción de
guardar automáticamente el video; la ruleta muestra el castigo más rápido;
el fondo Noche oscurece toda la app; expliqué cómo se juega por equipos;
corregí el Modo TV y reemplacé palabras de Deportes. También agregué el
aviso de actualización dentro de la app y el enlace a la política de
privacidad.
```

**¿Cómo decidiste que la app está lista para producción?**

```
Los verificadores jugaron partidas completas en varios celulares y los
problemas que reportaron ya están corregidos en la versión 13. Firebase
Crashlytics no muestra cierres del juego (solo un error aislado dentro de
la ventana de pagos de Google). Las compras dentro de la app funcionan con
cuentas de prueba, la ficha y las declaraciones de contenido están
completas, y la política de privacidad está publicada. Hay pruebas
automáticas (casi 400) que pasan antes de cada versión.
```

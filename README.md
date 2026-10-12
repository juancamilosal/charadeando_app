# Charadeando

Juego de charadas para Android e iOS hecho en Flutter. Un jugador se pone el
celular en la frente y adivina la palabra con las pistas de su grupo, mientras
la cámara frontal graba a los participantes para revivir las risas.

## Versión 0.1

- Diseño colorido con las fuentes Fredoka y Nunito (licencia OFL, en
  `assets/fonts`). Los colores no cambian con el modo oscuro del celular.
- Fondos (en el menú de Configuración de Categorías): el usuario elige el fondo de
  la app: Clásico (el degradado de siempre, con las tarjetas de color sin
  borde; viene elegido) o uno de un solo color: Uva, Noche, Crema, Mostaza,
  Coral o Turquesa. Cada uno trae su estilo de tarjetas: calcomanía (borde
  blanco y sombra sólida) en Uva, Noche, Coral y Turquesa; blancas con el
  borde y el título del color de la categoría en Crema; cómic (borde y
  sombra oscuros) en Mostaza. En los fondos claros los textos y botones van
  oscuros. Se guarda en el celular (`fondo.txt`) y se aplica en todas las
  pantallas desde que abre la app.
- Inicio: la bienvenida (la animación de cómo se juega, los pasos y
  "Listo") se muestra solo la
  primera vez que se abre la app; al tocar "Listo" queda guardado en el
  celular y las demás veces la app abre directo en Categorías. Categorías no
  tiene botón de atrás: "Cómo se juega", en el menú de Configuración, vuelve
  a abrir la bienvenida y "Listo" regresa.
- Barra de Categorías: el título "Selección de categoría" (se achica si no
  cabe en un celular angosto) y solo dos íconos: Mis videos y Configuración.
  Configuración abre un menú desde abajo, del mismo color del fondo elegido
  (en Clásico, el degradado; en Crema y Mostaza, con textos oscuros), con "Fondos" ("Cambia el color de la app") y "Cómo se
  juega" ("Ver la explicación otra vez"), cada una con su ícono en un cuadro
  de color y una flecha. Las opciones están en `settingsOptions`
  (`lib/widgets/settings_sheet.dart`), para sumar después sonido,
  vibración, premium o privacidad. Debajo de la barra va directo el
  selector "Todas | Mías", sin texto encima, y la cuadrícula no lleva el
  título "Categorías". "Salir de la categoría" y salir del turno
  llevan a Categorías.
- Pantalla de categorías: Libre, Animales, Geografía, Películas,
  Celebridades, Marcas, Deportes, Equipos de fútbol, Objetos, Comida,
  Profesiones, Acciones y Lugares (las 13 categorías de la colección
  `palabras`; las 5 últimas, por ahora con su ícono en vez de GIF). Libre
  deja elegir entre palabras manuales (las escriben los grupos) y
  automáticas (frases de la categoría LIBRE); las demás juegan con palabras
  automáticas de su categoría.
- Partida rápida o personalizada: al tocar una categoría del juego, una de
  Mis categorías, al empezar a jugar en "Combinar categorías" o al elegir
  cómo salen las palabras en Libre, se abre desde abajo (del color del
  fondo) el dibujo y el nombre de la categoría con dos tarjetas del mismo
  tamaño, lado a lado (una debajo de la otra si la pantalla mide menos de
  340 px): naranja "⚡ Partida rápida" ("1 minuto, sin configurar nada") y
  morada "⚙️ Personalizada" ("Grupos, rondas, video y ruleta"), con el
  estilo de las tarjetas del fondo. Personalizada va a la configuración.
- Partida rápida (`QuickGame`, `lib/services/quick_game.dart`): se salta la
  configuración. Sin grupos, un solo turno de 1 minuto, con hasta 20
  palabras (se piden 20 al servidor; de una categoría propia, 20 al azar),
  dificultad Mezcladas, aciertos con movimiento (o los botones del juez si
  hay un TV conectado) y el video con la resolución de la última
  configuración guardada ("sin video" no graba). No cambia la última
  configuración guardada. Con palabras manuales (Libre, "Las escribimos")
  va directo a escribirlas en una sola lista de 10 a 20, con el contador
  "12 de 20", una barra de avance y, desde 10, "Ya pueden jugar" en verde;
  al llegar a 20 no deja agregar más, y "Continuar" lleva al turno.
- Resultado de la partida rápida: "¡Tiempo!", "Animales · Partida rápida",
  los aciertos en grande, las píldoras "✓ 9 Correctos" y "↑ 3 Pases", las
  palabras en un panel blanco, cada una en su fila con sus puntos
  según la puntuación (por frase, "+1"; por palabra, uno por cada palabra;
  las pasadas, "0") y ✅ o ⏭️ a la derecha, "🎬 Ver video" (blanco; mientras se arma, "Preparando video…
  40%", y se puede guardar), "⚡ Otra rápida" (misma categoría, palabras
  nuevas), "⚙️ Personalizada" (a la configuración con la misma categoría) y
  "← Salir de la categoría". Sin ganador ni ruleta. Si salen sin guardar el
  video, se borra.
- Cada categoría puede tener un dibujo animado (GIF de 256 px en
  `assets/img/categorias/`, con el nombre de la categoría) que se ve en su
  tarjeta y, grande y animado, arriba de la configuración con el nombre de
  la categoría (una propia muestra su ícono en su color; una mezcla, los
  dibujos de las elegidas). Ya lo tienen: Libre (una hoja
  a la que se le van escribiendo las líneas), Animales, Geografía, Películas, Celebridades, Marcas,
  Deportes y Equipos de fútbol.
- En la pantalla de categorías los dibujos no se mueven todos a la vez: se
  animan uno por uno, en orden (Libre, Animales, Geografía, Películas,
  Celebridades, Marcas, Deportes y Equipos de fútbol), con una pausa corta
  entre uno y otro, y el ciclo vuelve a empezar. Los que no se ven en la
  pantalla se saltan. Quietos muestran su mejor cuadro: la hoja con sus
  líneas, el balón de Deportes en el centro después de rebotar. Ese cuadro
  también está como imagen en `assets/img/categorias/reposo/`, así que la
  tarjeta se ve completa desde el primer instante; el ciclo empieza un
  momento después de abrir la pantalla. La ruleta
  de castigos sigue moviéndose siempre y en "¿Cómo se juega?" el dibujo se
  mueve sin parar.
- Dificultad: Mezcladas (viene elegida: trae de todas, 300 palabras por
  categoría), Fácil (ideal con niños), Normal o Difícil (100 cada una). Se
  elige en la configuración de las palabras automáticas, en Libre y en todas
  las categorías. Las palabras manuales no tienen dificultad. En Directus se
  conserva la columna `dificultad`.
- "Sin grupos" o "En grupos": es lo primero de la configuración, debajo
  del dibujo y el nombre de la categoría, en todas las categorías, con "Sin
  grupos" marcado por defecto. Sin grupos solo salen las palabras y los jugadores
  se organizan como quieran: la configuración no muestra Grupos ni Palabras
  por grupo, con palabras manuales se escribe una sola lista (mínimo 10) y
  el turno, los resultados y el final muestran solo los puntos en total,
  sin ganador ni ruleta de castigo.
- Límites: de 2 a 4 grupos, de 1 a 10 rondas y de 30 segundos a 1:30 por
  turno.
- Libre pregunta "¿Cómo quieren las palabras?": "Las escribimos" (palabras
  manuales, antes de empezar) o "Al azar" (automáticas, el juego las pone) y
  sigue a la configuración.
- Solo se juega con palabras en español: el servidor entrega las de
  `idioma` `ESPAÑOL` (o `ESPANOL`) y las que no tienen idioma.
- Palabras automáticas: en la configuración se eligen los grupos, las
  rondas (hasta 10) y el tiempo por turno. Cada turno dura hasta que se
  acabe el tiempo, sin límite de palabras: se piden las que alcanzaría un
  grupo rápido (una cada 3 segundos) y, si a un grupo se le acaban, vuelven
  palabras ya jugadas, así que nunca se acaban antes del tiempo.
  La partida termina al completar las rondas. Al tocar
  "Continuar" se muestra "Buscando palabras…" mientras se traen al azar de la
  colección de Directus (`POST /juego/palabras`). La app ya no usa Gemini: las
  palabras son una base propia, revisada por el equipo. Durante el juego no
  se usa internet ni se piden más. El celular recuerda las últimas 500
  palabras jugadas para no repetirlas, y guarda el
  último lote para jugar sin internet. Ver `server/README.md`.
- La configuración viene con "Por frase" (la primera opción, antes de "Por
  palabra"), aciertos con "Movimiento", dificultad Mezcladas y video HD ya
  marcados. Al tocar "Continuar" se guarda en el celular la última
  configuración (nombres de los grupos, rondas, tiempo, palabras por grupo,
  dificultad, puntuación, aciertos y video), y la próxima partida aparece
  llena con ella. Es una sola para todas las categorías; el Modo TV no se
  guarda porque depende del televisor conectado.
- "Configuración aleatoria" (arriba en la configuración): el juego pone los
  nombres de los grupos (por defecto 2; si agregan más, también los nombra)
  y elige al azar el resto: rondas, tiempo por turno, dificultad,
  puntuación y aciertos. Cada toque da una configuración nueva, con otros nombres.
- Si una dificultad se queda sin palabras, el servidor completa con las
  otras, y si se acaban todas vuelve a usar las ya jugadas.
- Con las palabras escritas por los grupos, en el turno se ve cuántas
  faltan de toda la partida. Con las automáticas no se muestra, porque el
  turno dura hasta que se acabe el tiempo.
- Combinar categorías: arriba de la cuadrícula de categorías, el botón
  "Combinar categorías" abre desde abajo una ventana con las categorías del
  juego (sin Libre) y "Mis categorías" (si hay alguna), cada una con su
  dibujo o ícono y una casilla; se marca o desmarca tocando la fila. Las
  premium bloqueadas llevan candado y avisan que necesitan premium; las
  propias con menos de 10 palabras dicen "Faltan palabras" y no se marcan.
  El botón de abajo, "Empezar a jugar · 3 categorías", se activa con 2 o
  más. La app recuerda la última combinación (`combinacion.json`). Al
  empezar va a la configuración de siempre, donde la partida se llama
  "Mezcla: Animales, Películas y Mi familia" (o "Mezcla de 5 categorías"
  si son más de 3), igual que en la pantalla antes de cada turno. Las
  palabras se reparten en partes iguales entre las categorías elegidas (45
  con 3 son 15 de cada una; el sobrante, de a una), se completan con las
  otras si alguna no alcanza y se barajan juntas. Las del juego llegan de
  Directus en un solo pedido (`categorias`) con la dificultad elegida y sin
  repetir las ya jugadas; las propias salen del celular y no tienen
  dificultad (si solo hay propias, no se usa internet ni se muestra la
  dificultad). Cada palabra conserva su categoría, que el video muestra
  arriba de la palabra ("Película"); en la pantalla del juego no se
  muestra. Si el servidor devuelve palabras de categorías que no se
  pidieron (la extensión sin actualizar), se descartan y se pide cada
  categoría por separado.
- Mis categorías: en la pantalla de categorías hay un selector en forma de
  píldora, "Todas | ✨ Mías" (animado, y la app recuerda la última pestaña).
  "Todas" es lo de siempre; "Mías" muestra las categorías que creó el
  usuario ("Mi familia", "La oficina", "Viaje a Cartagena"), con la misma
  tarjeta que las demás: su nombre, ícono, color y cuántas palabras tiene.
  La primera tarjeta es "Nueva categoría"; si no hay ninguna, dice "Crea
  una categoría con tus propias palabras" con el botón "Crear mi primera
  categoría". Mantener presionada una
  tarjeta, o su botón de tres puntos, abre "Editar" y "Borrar" (pide
  confirmación).
- Crear o editar una categoría propia: nombre (obligatorio, hasta 24
  letras), descripción corta (opcional, hasta 60), color de la paleta de la
  app, uno de 20 íconos y las palabras. Las palabras se agregan una por una
  o pegando varias separadas por comas o saltos de línea; no se aceptan
  repetidas (sin importar mayúsculas ni tildes) y se pueden borrar. Se
  necesitan 10 para jugar ("Te faltan 4 palabras"), y se sugieren 30 o más
  para que no se repitan tan rápido. Arriba se ve la tarjeta mientras se
  edita.
- Una categoría propia se juega como las del juego: su "¿Cómo se juega?" y
  la configuración, sin dificultad (sus palabras no tienen). Las palabras
  salen del celular, así que funciona sin internet, también en Modo TV.
  Mis categorías se guardan solo en el celular (`mis_categorias.json`): no
  se suben a Directus ni a ningún servidor, y se pierden si se desinstala la
  app. `CustomCategoryStore.freeLimit` deja preparado el límite de
  categorías gratis (por ahora sin límite).
- Los nombres de las tarjetas nunca se parten a la mitad de una palabra: si
  no caben, se achica la letra y, como último recurso, se cortan con "…".
- Ruleta de castigos: una sección propia (en la pantalla de categorías, debajo
  de las tarjetas, una tarjeta blanca con una ruleta pequeña que gira y el
  nombre "Ruleta de castigos"; no es una categoría de palabras). Se elige la
  cantidad de campos (de 2 a 10, la ruleta se divide en partes iguales) y de
  dónde salen los castigos: "Los escribimos nosotros", "Que los ponga el
  juego" (unos 30 castigos para todo público, en `services/punishments.dart`)
  o "Mezclados" (el grupo escribe algunos y el juego completa los vacíos sin
  repetir). La ruleta queda guardada en el celular.
- Cómo gira: "Girar" la pone a toda velocidad y sigue sola hasta que tocan
  "¡Parar!" (o pasan 30 segundos). Entonces se elige el castigo al azar (el
  momento del toque no influye) y la ruleta frena durante 10 segundos con una
  curva que es rápida al principio y muy lenta al final, hasta quedar justo en
  el centro de ese campo. Cada campo que pasa por el indicador hace un "tic"
  con vibración, y al caer el castigo aparece en grande con una vibración
  fuerte, con "Girar otra vez" y "Listo". Si un castigo es muy largo para su
  campo, se corta con "…" (completo se ve al caer). La cara de la ruleta se
  dibuja una vez y solo se gira, así los textos quedan fijos a la ruleta
  mientras da vueltas.
- Al final de la partida, el grupo con menos puntos ve "¡Ruleta de castigo
  para …!" con "Girar" o "Sin castigo". Si varios empatan con menos puntos,
  cada uno gira su ruleta, uno después del otro; si todos empatan, no hay
  castigo. Usa la ruleta guardada en la sección o, si nunca se configuró, 8
  castigos del juego. En Modo TV la ruleta se ve en el televisor porque el
  celular duplica su pantalla. Queda preparado `PunishmentService` para
  traer los castigos de una colección `castigos` de Directus
  (`POST /juego/castigos`), pero todavía no se usa.
- Un solo celular, aciertos con movimiento: inclinar hacia abajo es acierto y
  hacia arriba es pasar.
- En la configuración, la sección Modo TV va al final, después de Video.
- Con un TV conectado, la animación de la bienvenida dice "El juez toca
  ¡Correcto! o Pasar en el celular." en vez de explicar cómo inclinarlo.
- Modo TV, en todas las categorías: se activa solo cuando el celular duplica
  la pantalla en un TV (AirPlay, Chromecast o HDMI). Mientras está activo, la
  configuración oculta las secciones de aciertos y de video, durante el turno el
  TV muestra solo el turno del grupo, el tiempo, "Finalizar juego", la
  palabra y los botones (sin marcador, para no confundir), y después los
  resultados del turno, y un
  juez del grupo rival marca "Pasar" y "¡Correcto!" con botones en el
  celular. En la configuración, sin TV se ve "Jugar en un TV" y el enlace
  "¿Cómo conectar un TV?", que abre desde abajo "Conectar a un televisor"
  con tres pasos numerados (Android o iPhone) y "Entendido"; con el TV
  conectado, "Modo TV activado · Sin video". El botón "Desconectar TV"
  detiene la transmisión (en Android) o muestra los pasos para hacerlo, y
  todo vuelve a lo normal. Antes del turno, en el Modo TV, se ve "De
  espaldas al TV" con las píldoras "✓ Correcto" y "⏭ Pasar" (los botones
  del juez) y, arriba junto a "Finalizar juego", un botón pequeño
  "Desconectar TV"; si el TV no está conectado, "¿Cómo conectar un TV?". Si el televisor se
  desconecta durante el turno, el juego queda en pausa y sigue al volver a
  conectarlo. La conexión se detecta con código nativo (`MainActivity.kt` y
  `AppDelegate.swift`).
- La configuración y los resultados se ven en vertical. La pantalla de antes
  del turno ya va en horizontal (en la rápida y en la personalizada): de
  fondo, la cámara frontal en vivo (todavía sin grabar; se graba desde la
  cuenta regresiva) con un degradado oscuro a la izquierda, arriba a la
  derecha "● Cámara" y "¡Que todos salgan en cámara!", y a la izquierda el
  grupo (o "Partida rápida"), "Celular a la frente" con las píldoras
  "↓ Acierto" y "↑ Pasar", una línea pequeña ("1 minuto · hasta 20
  palabras" o "Ronda 1 de 3") y "¡Listo!". Sin video o en Modo TV es la
  misma pantalla sobre el fondo de la app; mientras abre la cámara también
  se ve el fondo, y sin permiso de cámara se juega sin video. Al terminar el
  turno vuelve a vertical.
- Resultado de cada turno: "¡Tiempo!" y "Los Primos · Ronda 2 de 3" (sin
  grupos, "Ronda 2 de 3"), los puntos en grande ("Aciertos" si la
  puntuación es por frase), las píldoras de aciertos y pases, las palabras
  con ✅ y sus puntos ("+2") o ⏭️, y con grupos un marcador pequeño con el
  líder resaltado (la lista y las píldoras, igual que en la rápida). Abajo,
  "🎬 Ver video" con "Se borra al continuar", el botón
  que dice a quién le toca ("Turno de Los Tigres"; en el último turno, "Ver
  resultados") y "Finalizar juego".
- Resultado final: "¡Ganó Los Primos!" (o "¡Empate entre…!", o "¡Fin del
  juego!" sin grupos) con los puntos en grande, la tabla de puntajes con el
  primero resaltado, la ruleta de castigo ("Girar" o "Sin castigo") y abajo
  "Jugar otra vez" (misma configuración; pide palabras nuevas o las vuelven
  a escribir), "⚙️ Cambiar configuración" y "← Salir de la categoría".
- Palabras escritas por los grupos: las de cada grupo se reparten entre todos
  los demás, así que a nadie le salen las suyas y cada palabra se juega una
  sola vez. El texto se oculta al guardarlo. Funciona sin internet.
- Puntuación por palabra (cuentan artículos y conectores) o por frase. Pasar
  no suma ni resta, y las palabras pasadas no vuelven al mazo. Igualdad de
  puntos es empate.
- Video de cada turno con la cámara frontal, en 720p por defecto. También se
  puede jugar sin grabar. 1080p y la máxima resolución quedan bloqueadas como
  premium.
- El video se puede ver, guardar en la galería o compartir. Al continuar al
  siguiente turno se borra del celular; la app no guarda videos en ningún
  otro lugar.
- El video final muestra las palabras que se están adivinando, los aciertos y
  los pases. Se arma con FFmpeg (`ffmpeg_kit_flutter_new_video`, licencia
  LGPL) mientras se ven los resultados del turno.
- "Finalizar juego": antes de cada turno (arriba a la derecha), mientras
  se muestran las palabras (abajo a la izquierda; en Modo TV, arriba junto
  al tiempo), con el turno en pausa y en la tabla de puntajes. Pregunta antes de terminar y lleva a
  los resultados finales con los puntajes de ese momento (si el turno estaba
  en pausa, sus palabras marcadas cuentan). Si todavía no se jugó ningún
  turno, vuelve a Categorías.
- Mis videos (ícono de video en la barra de Categorías): al tocar "Guardar" en
  el video de un turno, se guarda en la galería (en Android, en
  `Movies/Charadeando`) y aparece en Mis videos, del más nuevo al más
  viejo, con su miniatura, el grupo y los puntos del turno, la categoría,
  la ronda, la fecha y los puntajes de ese momento. El video vive una sola
  vez, en la galería: Mis videos guarda solo su referencia y los datos de
  la partida en `mis_videos.json`, en el celular, y nunca se sube a ningún
  servidor. Al abrir la sección se quitan los que ya se borraron de la
  galería. Al borrar uno desde la app pregunta si se borra también de la
  galería. En iPhone con acceso limitado a las fotos no se quita ninguno
  (no se puede saber si siguen) y se ofrece "Elegir videos". En Android la
  app no pide el permiso de leer toda la galería: ve sin permiso los videos
  que ella misma guardó.
- Si la app sale a segundo plano durante el turno, el juego se pausa y al
  volver sigue donde quedó. El video se graba por partes y se unen al final.

- Textos cortos: máximo 10 a 12 palabras por mensaje y, donde se puede,
  íconos en vez de explicaciones ("Más rondas = más palabras", "¿Cuántas
  palabras escribe cada grupo?" con "20 en total", "El que pierde, gira" en
  la ruleta, "Guarda un video al final del turno y aparece aquí." y "Da
  permiso a la galería para ver tus videos" en Mis videos).

Pendiente para siguientes versiones: categorías con palabras de Directus,
Firebase App Check, modo celular juez con Realtime Database, compras, anuncios y marca de
agua. Además:

- Modo Reto: algunas palabras salen con una regla extra (solo mímica, sin
  hablar, con una sola mano, tarareando) y valen más puntos.
- Dificultad (fácil, normal, difícil): campo `dificultad` en las palabras de
  Directus (`FACIL`, `NORMAL`, `DIFICIL`), para que `POST /juego/palabras`
  traiga solo palabras de la dificultad elegida.
- Perfiles de grupo guardados en el celular, para no volver a escribir los
  nombres, con historial de victorias.

## Estructura

```
lib/
├── models/      clases del juego (GameConfig, Word, Group, Turn)
├── services/    cámara, sensores, videos y palabras
├── providers/   estado de la partida (Riverpod) y servicios
├── screens/     una pantalla por paso del flujo
├── widgets/     piezas reutilizables
├── router.dart  rutas (go_router)
└── main.dart
server/          extensión de Directus con la ruta del juego
```

## Desarrollo

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

La app se prueba en un celular real: necesita cámara frontal y acelerómetro.
En modo debug, durante el turno tocar la mitad izquierda de la pantalla pasa
y la mitad derecha acierta, para probar en un emulador.

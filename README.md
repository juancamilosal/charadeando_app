# Charadeando

Juego de charadas para Android e iOS hecho en Flutter. Un jugador se pone el
celular en la frente y adivina la palabra con las pistas de su equipo, mientras
la cámara frontal graba a los participantes para revivir las risas.

## Versión 0.1

- Diseño colorido con las fuentes Fredoka y Nunito (licencia OFL, en
  `assets/fonts`). Los colores no cambian con el modo oscuro del celular.
- Fondos (en Ajustes > Apariencia): el usuario elige el fondo de
  la app: Clásico (el degradado de siempre; viene elegido) o uno de un
  solo color: Uva, Noche, Crema, Mostaza, Coral o Turquesa. Cada uno trae
  su estilo de tarjetas: calcomanía (borde blanco y sombra sólida) en
  Clásico, Uva, Noche, Coral y Turquesa; blancas con el
  borde y el título del color de la categoría en Crema; cómic (borde y
  sombra oscuros) en Mostaza. En los fondos claros los textos y botones van
  oscuros. Se guarda en el celular (`fondo.txt`) y se aplica en todas las
  pantallas desde que abre la app.
- Inicio, "Cómo se juega" (`lib/screens/welcome_screen.dart`): siete
  pantallas sobre un degradado azul a violeta, que se pasan con el botón
  verde "Continuar" o deslizando, con puntos que dicen en cuál se está y
  "Omitir" arriba a la derecha: 1) "Muchas categorías para jugar"
  ("Animales, películas, deportes… y puedes crear las tuyas.") con las
  categorías pasando en dos filas de derecha a izquierda, como una
  vitrina: es solo informativa y no se pueden tocar; 2) "Cómo empezar" con los amigos jugando; 3) "¿Lo
  has acertado?" con el celular verde; 4) "¿No puedes adivinar?" con el
  celular naranja; 5) "Castiga al equipo que pierda" con la ruleta de
  castigos y algunos de ejemplo; 6) "Modo TV" con el celular del juez y
  el TV; 7) "¡Listos para divertirse!" con los
  cuatro amigos felices y "¡Vamos a jugar!". Los textos de acertar y pasar
  dicen cómo se marca según el controlador de Ajustes. Las ilustraciones
  están en `assets/img/inicio/` (WebP sin fondo). Se ven solo la primera
  vez que se abre la app (queda guardado en el celular); después abre
  directo en Categorías. "Cómo se juega", en Ajustes > Ayuda, las vuelve a
  abrir y al terminar u omitir regresa.
- Barra de navegación abajo (`StatefulShellRoute` de go_router, en
  `lib/widgets/app_nav_bar.dart`): "Ruleta", "Equipos", "Categorías" (en el
  centro; es la que abre al iniciar), "Videos" y "Ajustes", cada una con su
  ícono grande y su nombre (la Ruleta tiene un ícono de ruleta dibujado,
  con sus campos y el indicador arriba, porque Material no trae uno). Cada
  pestaña conserva su estado. La barra es
  blanca, con el borde de arriba curvo (sube un poco en el centro) y una
  sombra suave; la activa va en morado y las demás, en lila claro, así se
  ve igual con todos los fondos. Solo se ve en esas cinco pantallas: la bienvenida, la
  configuración, las palabras, el turno, los resultados, el video, Fondos y
  los editores se abren encima, sin la barra.
- Categorías: arriba solo el título "Selección de categoría" (se achica si
  no cabe en un celular angosto); Mis videos, la configuración y la Ruleta
  de castigos ahora están en la barra de abajo. Debajo va directo el
  selector "Todas | Mías", sin texto encima. "Salir de la categoría" y
  salir del turno llevan a Categorías.
- Equipos (`lib/screens/teams_screen.dart`): la lista de equipos guardados,
  cada uno con su nombre, su color, un ícono o emoji, sus jugadores y su
  historial (partidas, victorias y mejor puntaje). "Crear equipo" abre el
  editor: nombre (obligatorio, hasta 24 letras, sin repetir), color de la
  paleta de la app, ícono o emoji y jugadores (opcional). Mantener
  presionado un equipo o su botón de tres puntos: "Editar" y "Borrar" (pide
  confirmación). Sin equipos: "Crea tu primer equipo" con "Crear equipo".
  Se guardan solo en el celular (`equipos.json`), no en un servidor.
- Ajustes (`lib/screens/settings_screen.dart`), en tarjetas con un ícono en
  cada fila. "Preferencias de juego": "Música" y "Efectos de sonido"
  (encendidos; la app todavía no trae sonidos, pero `SoundService` ya
  respeta el ajuste), "Vibración" (encendida; todas las vibraciones pasan
  por `Haptics`, que no vibra si está apagada), "Rotación invertida"
  (apagada; encendida, el juego gira a horizontal derecha y la vista de la
  cámara y el video siguen esa orientación; la inclinación se mide en el
  eje de la pantalla, así que abajo sigue siendo acierto) y "Controlador":
  "Inclinación" (por defecto: abajo es acierto y arriba, pasar) o "Toque"
  (la mitad derecha de la pantalla es acierto y la izquierda, pasar, con
  una marca suave en cada borde durante el turno; en Modo TV el juez sigue
  con sus botones). "Apariencia": "Fondos". "Ayuda": "Cómo se juega". Se
  guardan en el celular (`ajustes.json`) y se aplican desde que abre la
  app. La animación de la bienvenida explica el controlador elegido.
- Pantalla de categorías (`lib/screens/category_screen.dart`), pestaña
  "Todas": arriba Libre, una tarjeta naranja centrada, del mismo tamaño
  que las de las secciones, y el botón "Combinar categorías", discreto: sin borde ni
  sombra, con un fondo translúcido y el texto del color de los textos del
  fondo (así no se confunde con los títulos blancos de las secciones).
  Después, las secciones, bien separadas, cada una con su título a la
  izquierda en una píldora (blanca con el texto morado en los fondos
  oscuros, morada con el texto blanco en los claros; Fredoka) y cuántas
  categorías tiene a la
  derecha ("8 categorías"), y sus tarjetas en
  una cuadrícula de 3 columnas, todas visibles:
  1. Clásicos: Animales, Comida, Objetos, Profesiones y Acciones.
  2. Entretenimiento: Películas, Series y novelas, Personajes, Superhéroes,
     Dibujos animados, Videojuegos, Música y canciones y Celebridades.
  3. Cultura general: Geografía, Lugares, Personajes históricos, Dichos y
     refranes y Marcas.
  4. Deportes: Deportes y Equipos de fútbol.
  5. Especiales ("Solo por temporada"): Navidad. Solo aparece cuando hay
     una especial en temporada; Navidad va del 1 de diciembre al 6 de enero
     y fuera de esas fechas no sale en ningún lado (ni en Combinar ni en la
     bienvenida). TEMPORAL: `allSeasonsProvider` está en `true` para probar
     Navidad todo el año; volver a `false` antes de publicar. Otra especial se agrega con su `Season` (mes y día de
     inicio y fin; por ejemplo, Halloween del 1 al 31 de octubre).
  En esta pantalla las tarjetas de una sección van en tonos de un mismo
  color (del más oscuro al más claro, alternados en orden), para que no se
  vea tan cargada y cada tarjeta se distinga de la de al lado: Clásicos
  verdes, Entretenimiento azules, Cultura general verdes azulados,
  Deportes azules oscuros y Especiales rojos (`CategorySection.shades`). Libre va
  en naranja, un color que no usa ninguna sección. En el resto de la app cada
  categoría conserva su color propio.
  6. Mis categorías (al final): la tarjeta "Nueva categoría" y las que creó
     el usuario, en la misma cuadrícula, con cuántas son a la derecha. Se
     juegan, editan y borran igual que en la pestaña "Mías".

  Cada categoría guarda su sección, su temporada, si es nueva (`isNew`) y
  si ya tiene palabras (`available`) en `lib/models/category.dart`; el enum
  va en el orden de la pantalla. Las nueve nuevas (Navidad, Series y
  novelas, Personajes, Superhéroes, Dibujos animados, Videojuegos, Música y
  canciones, Personajes históricos y Dichos y refranes) llevan la etiqueta
  amarilla "Nueva" arriba a la izquierda. Ya tienen palabras en Directus
  todas menos Navidad; una categoría sin palabras (hoy solo Navidad) lleva
  "Pronto" sobre su dibujo apagado: al tocarla avisa "¡Pronto!
  Estamos preparando las palabras de…" y no se juegan ni se combinan. Las
  que todavía no tienen dibujo muestran su ícono. Las tarjetas de las
  secciones llevan el dibujo arriba y el nombre debajo, grande, en dos
  renglones si es largo ("Personajes históricos") y sin partir
  palabras; solo una palabra muy larga ("Celebridades") se achica. En las
  tarjetas amarillas el texto va oscuro (y en las blancas del fondo Crema,
  naranja). Libre deja elegir entre palabras manuales (las escriben los
  equipos) y automáticas (frases de la categoría LIBRE); las demás juegan
  con palabras automáticas de su categoría. La pestaña "Mías" sigue igual.
  Los códigos de Directus y la regla de en qué categoría va cada persona o
  personaje están en `server/README.md`.
- Partida rápida o personalizada: al tocar una categoría del juego, una de
  Mis categorías, al empezar a jugar en "Combinar categorías" o al elegir
  cómo salen las palabras en Libre, se abre desde abajo (del color del
  fondo) el dibujo y el nombre de la categoría con dos tarjetas del mismo
  tamaño, lado a lado (una debajo de la otra si la pantalla mide menos de
  340 px): naranja "⚡ Partida rápida" ("1 minuto, sin configurar nada") y
  morada "⚙️ Personalizada" ("Equipos, rondas, video y ruleta"), con el
  estilo de las tarjetas del fondo. Personalizada va a la configuración.
- Partida rápida (`QuickGame`, `lib/services/quick_game.dart`): se salta la
  configuración. Sin equipos, un solo turno de 1 minuto, con hasta 20
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
- Cada categoría puede tener un dibujo: una imagen quieta (PNG de 256 px
  en `assets/img/categorias/`, con el código de la categoría en
  minúsculas, por ejemplo `lugares.png`) que se ve en su tarjeta, en
  Combinar categorías y, grande, arriba de la configuración con el nombre
  de la categoría (una propia muestra su ícono en su color; una mezcla, los
  dibujos de las elegidas). Ya no hay GIF: eran difíciles de mantener. Para
  agregar el dibujo de una categoría se pone su PNG en la carpeta y se suma
  a `CategoryArt.withImage` (`lib/widgets/category_art.dart`); mientras
  tanto muestra su ícono. Ya lo tienen: Libre, Animales, Geografía,
  Películas, Celebridades, Marcas, Deportes, Equipos de fútbol, Objetos,
  Comida, Profesiones, Acciones, Lugares, Series y novelas, Personajes,
  Superhéroes, Dibujos animados, Videojuegos, Música y canciones,
  Personajes históricos y Dichos y refranes (falta Navidad).
- Dificultad: Mezcladas (viene elegida: trae de todas, 300 palabras por
  categoría), Fácil (ideal con niños), Normal o Difícil (100 cada una). Se
  elige en la configuración de las palabras automáticas, en Libre y en todas
  las categorías. Las palabras manuales no tienen dificultad. En Directus se
  conserva la columna `dificultad`.
- "Sin equipos" o "En equipos": es lo primero de la configuración, debajo
  del dibujo y el nombre de la categoría, en todas las categorías, con "Sin
  equipos" marcado por defecto. En equipos se eligen de 2 a 4 equipos
  guardados (tocar para marcar; juegan en ese orden, con su número) y "Nuevo
  equipo" abre el mismo editor de Equipos y vuelve con el equipo marcado; si
  no hay ninguno guardado, se crean ahí mismo. Sin equipos solo salen las
  palabras y los jugadores se organizan como quieran: la configuración no
  muestra Equipos ni Palabras
  por equipo, con palabras manuales se escribe una sola lista (mínimo 10) y
  el turno, los resultados y el final muestran solo los puntos en total,
  sin ganador ni ruleta de castigo.
- Límites: de 2 a 4 equipos, de 1 a 10 rondas y de 30 segundos a 1:30 por
  turno.
- Libre pregunta "¿Cómo quieren las palabras?": "Las escribimos" (palabras
  manuales, antes de empezar) o "Al azar" (automáticas, el juego las pone) y
  sigue a la configuración.
- Solo se juega con palabras en español: el servidor entrega las de
  `idioma` `ESPAÑOL` (o `ESPANOL`) y las que no tienen idioma.
- Palabras automáticas: en la configuración se eligen los equipos, las
  rondas (hasta 10) y el tiempo por turno. Cada turno dura hasta que se
  acabe el tiempo, sin límite de palabras: se piden las que alcanzaría un
  equipo rápido (una cada 3 segundos) y, si a un equipo se le acaban, vuelven
  palabras ya jugadas, así que nunca se acaban antes del tiempo.
  La partida termina al completar las rondas. Al tocar
  "Continuar" se muestra "Buscando palabras…" mientras se traen al azar de la
  colección de Directus (`POST /juego/palabras`). La app ya no usa Gemini: las
  palabras son una base propia, revisada por el equipo. Durante el juego no
  se usa internet ni se piden más. El celular recuerda las últimas 500
  palabras jugadas para no repetirlas, y guarda el
  último lote para jugar sin internet. Ver `server/README.md`.
- La configuración viene con "Por frase" (la primera opción, antes de "Por
  palabra"), dificultad Mezcladas y video HD ya marcados. Cómo se marcan los
  aciertos ya no se elige ahí, sino en Ajustes > Controlador. Al tocar
  "Continuar" se guarda en el celular la última configuración (los equipos
  elegidos, rondas, tiempo, palabras por equipo, dificultad, puntuación y
  video), y la próxima partida aparece
  llena con ella. Es una sola para todas las categorías; el Modo TV no se
  guarda porque depende del televisor conectado.
- "Configuración aleatoria" (arriba en la configuración): el juego pone
  equipos con nombres al azar (por defecto 2, o tantos como haya elegidos),
  que son solo de esa partida y no se guardan en Equipos, y elige al azar
  el resto: rondas, tiempo por turno, dificultad y puntuación. Cada toque
  da una configuración nueva, con otros nombres.
- Al terminar una partida se suma al historial de cada equipo guardado la
  partida jugada, la victoria (si ganó; en empate no cuenta) y el mejor
  puntaje si lo superó.
- Si una dificultad se queda sin palabras, el servidor completa con las
  otras, y si se acaban todas vuelve a usar las ya jugadas.
- Con las palabras escritas por los equipos, en el turno se ve cuántas
  faltan de toda la partida. Con las automáticas no se muestra, porque el
  turno dura hasta que se acabe el tiempo.
- Combinar categorías: debajo de Libre, el botón "Combinar categorías"
  abre desde abajo una ventana con las categorías del juego (sin Libre) con
  los mismos títulos de sección y en el mismo orden que la pantalla, y al
  final "Mis categorías" (si hay alguna), cada una con su dibujo o ícono y
  una casilla; se marca o desmarca tocando la fila. Las de "Pronto" llevan
  esa etiqueta en vez de la casilla y no se marcan. Las premium bloqueadas
  llevan candado y avisan que necesitan premium; las propias con menos de 10 palabras dicen "Faltan palabras" y no se marcan.
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
- Ruleta de castigos: una sección propia ("Ruleta" en la barra de abajo; no
  es una categoría de palabras). Arriba se ve la ruleta con "Girar" y
  debajo su configuración; la ruleta se va armando con lo que se elige: la
  cantidad de campos, lo que se escribe en cada castigo (los vacíos con
  "?") o los castigos del juego ("Otros castigos" los cambia). Al girar se
  revisa que esté completa y, en "Jugadores y app", la app llena los vacíos;
  entonces la ruleta se abre a pantalla completa, sin la configuración ni
  la barra de abajo: solo la ruleta girando y "¡Parar!". La ruleta también
  se gira con el dedo: sigue al dedo y, si se suelta con impulso, gira
  hacia donde iba el dedo (a la derecha, en el sentido del reloj; a la
  izquierda, al revés; hacia arriba o abajo, según el lado) y frena sola; se
  toma de cualquier lado (arriba, abajo o a los costados: la ruleta se queda
  con el dedo apenas la toca, y la pantalla se desplaza tocando fuera de
  ella). Si se empuja en la sección, la de pantalla completa arranca donde
  quedó y gira hacia el mismo lado; la
  fuerza solo cambia cuánto tarda, el castigo sale igual al azar.
  "Listo" la deja quieta otra vez para seguir cambiándola. Se elige la
  cantidad de campos (de 2 a 10, la ruleta se divide en partes iguales) y de
  dónde salen los castigos, una opción por línea con lo que significa
  debajo: "Los escriben los jugadores", "Los pone la app" (unos 30 castigos
  para todo público, en `services/punishments.dart`) o "Jugadores y app" (el
  equipo escribe algunos y la app completa los vacíos sin repetir). Al girar, la ruleta queda guardada en el celular.
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
- Al final de la partida, el equipo con menos puntos ve "¡Ruleta de castigo
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
  TV muestra solo el turno del equipo, el tiempo, "Finalizar juego", la
  palabra y los botones (sin marcador, para no confundir), y después los
  resultados del turno, y un
  juez del equipo rival marca "Pasar" y "¡Correcto!" con botones en el
  celular. En la configuración, sin TV se ve "Jugar en un TV" y el enlace
  "¿Cómo conectar un TV?", que abre desde abajo "Conectar a un televisor"
  con tres pasos numerados (Android o iPhone) y "Entendido". Arriba de los
  pasos, un recuadro corto: "¿Ya duplicas la pantalla? Se conecta solo."
  (la app lo detecta sola); si se conecta con la ventana abierta, se pone
  verde con "¡TV conectado!". Con el TV
  conectado, "Modo TV activado · Sin video". El botón "Desconectar TV"
  detiene la transmisión (en Android) o muestra los pasos para hacerlo, y
  todo vuelve a lo normal. Antes del turno, en el Modo TV, se ven las
  píldoras "✓ Correcto" y "⏭ Pasar" (los botones del juez)
  y, arriba junto a "Finalizar juego", un ícono para desconectar el TV; si
  el TV no está conectado, "¿Cómo conectar un TV?". Si el televisor se
  desconecta durante el turno, el juego queda en pausa y sigue al volver a
  conectarlo. La conexión se detecta con código nativo (`MainActivity.kt` y
  `AppDelegate.swift`).
- La configuración y los resultados se ven en vertical. La pantalla de antes
  del turno ya va en horizontal (en la rápida y en la personalizada) y es
  muy simple: de fondo, la cámara frontal en vivo (todavía sin grabar; se
  graba desde la cuenta regresiva) con un degradado oscuro a la izquierda y
  arriba a la derecha "● Cámara"; a la izquierda, "Finalizar juego", a
  quién le toca (solo con equipos: "Turno de Los Primos"), las píldoras
  según el controlador ("↓ Acierto" y "↑ Pasar" con Inclinación; "Toca a la
  derecha: Acierto" y "Toca a la izquierda: Pasar" con Toque) y "¡Listo!". Sin video o en Modo TV es la misma
  pantalla sobre el fondo de la app; mientras abre la cámara también se ve
  el fondo, y sin permiso de cámara se juega sin video. La vista de la
  cámara se fija en horizontal. Al terminar el turno vuelve a vertical.
- Resultado de cada turno: "¡Tiempo!" y "Los Primos · Ronda 2 de 3" (sin
  equipos, "Ronda 2 de 3"), los puntos en grande ("Aciertos" si la
  puntuación es por frase), las píldoras de aciertos y pases, las palabras
  con ✅ y sus puntos ("+2") o ⏭️, y con equipos un marcador pequeño con el
  líder resaltado (la lista y las píldoras, igual que en la rápida). Abajo,
  "🎬 Ver video" con "Se borra al continuar", el botón
  que dice a quién le toca ("Turno de Los Tigres"; en el último turno, "Ver
  resultados") y "Finalizar juego".
- Resultado final: "¡Ganó Los Primos!" (o "¡Empate entre…!", o "¡Fin del
  juego!" sin equipos) con los puntos en grande, la tabla de puntajes con el
  primero resaltado, la ruleta de castigo ("Girar" o "Sin castigo") y abajo
  "Jugar otra vez" (misma configuración; pide palabras nuevas o las vuelven
  a escribir), "⚙️ Cambiar configuración" y "← Salir de la categoría".
- Palabras escritas por los equipos: las de cada equipo se reparten entre todos
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
- Mis videos ("Videos" en la barra de abajo): al tocar "Guardar" en
  el video de un turno, se guarda en la galería (en Android, en
  `Movies/Charadeando`) y aparece en Mis videos, del más nuevo al más
  viejo, con su miniatura, el equipo y los puntos del turno, la categoría,
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
  palabras escribe cada equipo?" con "20 en total", "El que pierde, gira" en
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

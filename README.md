# Charadeando

Juego de charadas para Android e iOS hecho en Flutter. Un jugador se pone el
celular en la frente y adivina la palabra con las pistas de su equipo, mientras
la cámara frontal graba a los participantes para revivir las risas.

## Versión 0.1

- Ícono de la app (`branding/icono.png`, generado con
  `dart run flutter_launcher_icons`): en Android 8+ es adaptativo, el ícono
  completo achicado (`branding/icono-adaptativo-app.png`) sobre `#1B024A`,
  con margen para que el recorte de cada celular (círculo, cuadrado
  redondeado…) no corte el dibujo.
- Splash nativo de Android (`flutter_native_splash`, también Android 12+;
  se regenera con `dart run flutter_native_splash:create`): solo el fondo
  `#1F0252`, a pantalla completa, sin ícono ni firma (en Android 12+, que
  siempre muestra un ícono, va uno transparente:
  `branding/splash/vacio-android12.png`). Así lo primero que se ve con
  dibujo es la pantalla de carga de Flutter, con los destellos, sin ver
  antes el logo solo. El tema normal de Android también usa `#1F0252`
  (`@color/fondo_carga`), así que entre las dos no se ve un destello
  blanco.
- Pantalla de carga (`SplashScreen`, ruta `/carga`, la primera de la app):
  armada por partes para cualquier tamaño. Fondo `#1F0252` con un brillo
  radial `#6E28E6` detrás del logo; el logo
  (`assets/img/marca/splash_logo.webp`) centrado al 72% del ancho, que
  entra en 600 ms con escala de 0.85 a 1 con un leve rebote y opacidad; 20
  destellos (`assets/img/marca/destello.webp`) repartidos como en
  `branding/splash/referencia.png`, de 8% a 30% del ancho, detrás del logo
  y lejos de la firma, la mayoría lilas y 6 teñidos de amarillo `#FFD23F`,
  turquesa `#1FC8B4` y magenta `#E5197E` (un filtro que toma el brillo del
  destello y lo pinta de ese color), cada uno titilando (opacidad y un poco
  de escala) con su ritmo y retraso; y "by ValkiriaCode" abajo, en el área
  segura (Nunito Bold 14, blanco al 70%). Precarga sus imágenes antes de
  mostrarlas. A los 1,8 s (o al tocarla) pasa con un fundido a Categorías,
  o a la bienvenida la primera vez. Con "Reducir animaciones" el logo
  aparece sin rebote y los destellos quedan quietos.
- Celular juez (gratis, como el Modo TV): en la configuración, la sección
  "Celular juez" (no sale en el Modo TV) con el interruptor "Usar celular
  juez". Al encenderlo la app crea una sala en el Worker
  `server/juez` (`JudgeService`, `POST <JUEZ_URL>/api/salas`; `JUEZ_URL` se
  cambia con `--dart-define`, por defecto `https://valkiriacode.com/juez`),
  muestra el QR (`qr_flutter`) con `https://valkiriacode.com/juez/<CÓDIGO>`
  y el código en grande, y dice "Esperando al juez…" o "Juez conectado ✓".
  Se puede seguir sin juez. Sin internet dice "El celular juez necesita
  internet en los dos celulares." (el juego normal sigue sin internet). Al
  abrir la configuración la app pregunta a `<JUEZ_URL>/api/salud`: si hay
  internet pero el Worker no responde como tal (por ejemplo, todavía no está
  publicado y la web devuelve 404), la sección no se muestra; y si falla al
  crear la sala, dice "El celular juez no está disponible por ahora. Pueden
  jugar inclinando el celular." y queda apagado. La
  app manda: se conecta por WebSocket (`web_socket_channel`, `JudgeRoom`,
  que se reconecta sola) y le envía a la sala el estado en cada cambio
  (palabra, categoría, segundos, equipo y puntos; `esperando`, `jugando`,
  `fin_turno` con aciertos y pasadas, `fin_partida`). Lo que marca el juez
  llama a lo mismo que inclinar el celular (con sus sonidos y animaciones).
  Con el juez conectado, la inclinación (y el toque) no marcan; si se
  desconecta en pleno turno, un aviso lo dice y la inclinación vuelve.
  Cada marca se confirma en la página del juez: mientras el celular de la
  frente muestra "¡Correcto!" o "Paso", el juez ve debajo del tiempo
  "✓ ¡Correcto!" o "→ Paso" (también si se marcó inclinando); si tocó y en
  2 segundos no llegó la confirmación, dice "No llegó, toca otra vez".
  Antes de cada turno el juez ve la misma cuenta regresiva (3, 2, 1, con
  "¡Prepárate!") que el celular de la frente.
  Al final del turno el juez ve el resumen como en la app (aciertos,
  pasadas, puntos y la lista de palabras con ✅ o ⏭️) y, mientras la app
  está en el resultado de ese turno, puede tocar una palabra para
  corregirla: el cambio llega al celular (con el aviso "El juez cambió
  "Pizza" a ✅ acertada.") y se recalculan los puntos. Al seguir, el resumen
  queda fijo en los dos lados. Los puntos que ve el juez son los del equipo
  en la partida; sin equipos, solo los de ese turno. Al final de la partida
  ve el ganador ("¡Ganó Los Tigres!" o "¡Empate entre…!") y las posiciones
  de los equipos con sus puntos (sin equipos, el total de la partida), y
  además el resumen del último turno. Al final de un turno o de la partida
  tiene "Cerrar": sale de la sala y vuelve a valkiriacode.com/juez, la
  página donde se escribe el código.
  Solo un celular puede ser el juez: otro que escanee dice "La sala ya
  tiene juez" (el mismo celular sí puede volver a entrar, por ejemplo si se
  le fue la señal). En el resultado de cada turno, "QR Juez" muestra el
  QR en grande y debajo la página y el código de la sala, para que el juez
  entre o vuelva a entrar escaneando o escribiendo el código.
- Corregir el turno: en el resultado de cada turno, "Toca una palabra si se
  marcó mal." Tocar una palabra la cambia entre ✅ acertada y ⏭️ pasada
  (`GameController.correctLastTurn`) y se recalculan los aciertos, los
  puntos y el marcador. Solo el último turno, antes de pasar al siguiente.
- Al cambiar de pestaña en la barra de abajo, la que se deja se borra: al
  volver empieza de nuevo, arriba del todo, sin lo escrito y sin ventanas
  abiertas (como "Combinar categorías"). Lo que se guarda en el celular
  (equipos, ruleta, categorías propias…) sigue ahí.
- Diseño colorido con las fuentes Fredoka y Nunito (licencia OFL, en
  `assets/fonts`). Los colores no cambian con el modo oscuro del celular.
- Fondos (en Ajustes > Apariencia): el usuario elige el fondo de
  la app: Clásico (el degradado de siempre; viene elegido) o uno de un
  solo color: Uva, Noche, Crema, Mostaza, Coral o Turquesa. Cada uno trae
  su estilo de tarjetas: calcomanía (borde blanco y sombra sólida) en
  Clásico, Uva, Noche, Coral y Turquesa; blancas con el
  borde y el título del color de la categoría en Crema; cómic (borde y
  sombra oscuros) en Mostaza. En los fondos claros los textos y botones van
  oscuros. Noche es un tema oscuro completo (`Backdrop.dark`): las
  tarjetas, las ventanas, las hojas de abajo, los campos de texto y la
  barra de abajo también van en azul oscuro con letras blancas, y los
  números y acentos morados pasan a blanco o morado claro. Los colores de
  las tarjetas salen de `context.surfaces` (`Surfaces.light` o
  `Surfaces.dark` en `lib/theme.dart`). Se guarda en el celular
  (`fondo.txt`) y se aplica en todas las pantallas desde que abre la app.
- Inicio, "Cómo se juega" (`lib/screens/welcome_screen.dart`): ocho
  pantallas sobre un degradado azul a violeta, que se pasan con el botón
  verde "Continuar" o deslizando, con puntos que dicen en cuál se está y
  "Omitir" arriba a la derecha: 1) "Muchas categorías para jugar"
  ("Animales, películas, deportes… y puedes crear las tuyas.") con las
  categorías pasando en dos filas de derecha a izquierda, como una
  vitrina: es solo informativa y no se pueden tocar; 2) "Cómo empezar" con los amigos jugando; 3) "¿Lo
  has acertado?" con el celular verde; 4) "¿No puedes adivinar?" con el
  celular naranja; 5) "Jueguen por equipos" ("Cada equipo tiene su turno.
  Suman puntos y gana el que más acierte.") con una tabla de puntos de
  ejemplo; 6) "Castiga al equipo que pierda" con la ruleta de
  castigos y algunos de ejemplo; 7) "Modo TV" con el celular del juez y
  el TV; 8) "¡Listos para divertirse!" con los
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
  cada uno con su nombre, su color, un ícono o emoji y su
  historial (partidas, victorias y mejor puntaje). "Crear equipo" abre el
  editor: nombre (obligatorio, hasta 24 letras, sin repetir), color de la
  paleta de la app e ícono o emoji. Los jugadores se quitaron del editor
  (quedan como idea: decir a quién le toca en cada turno); los que se
  escribieron antes siguen guardados en `equipos.json`. Mantener
  presionado un equipo o su botón de tres puntos: "Editar" y "Borrar" (pide
  confirmación). Sin equipos: "Crea tu primer equipo", tres pasos de cómo
  se juega por equipos (crearlos, elegir "En equipos" en una partida
  personalizada, se turnan y gana el que más puntos sume) y "Crear
  equipo".
  Se guardan solo en el celular (`equipos.json`), no en un servidor.
- Compras de pago único (`lib/widgets/premium_sheet.dart`,
  `PremiumController`): cada categoría de pago se puede comprar suelta, o
  todo junto con **Todo Charadeando** (en el código, "premium"), que además
  trae el video Full HD y Máxima, los videos sin marca de agua y las
  categorías propias sin límite. No se
  llama "Premium" para que no suene a suscripción. Las de pago
  (`GameCategory.paid`: todas menos las dos primeras de cada sección,
  `GameCategory.freePerSection`; gratis quedan Libre, Animales, Comida,
  Películas, Series y novelas, Geografía, Lugares, Deportes, Equipos de
  fútbol, Vacaciones y Halloween) llevan un
  candado amarillo en su tarjeta (con todos sus colores) y en Combinar. Al
  tocar una se abre "Desbloquea Anime": "Solo Anime · $4.000" y, debajo, "o
  mejor" el recuadro de Todo Charadeando con lo que trae (también las
  categorías nuevas que vayan llegando con las actualizaciones), "Todas las
  categorías · $15.000" y "Pago único · sin mensualidades". No se dice
  cuánto se ahorra. Los precios y la moneda los da Google Play; mientras
  no los da, se muestran $4.000 y $15.000 (`fallbackCategoryPrice`,
  `fallbackAllPrice`). Una
  resolución bloqueada (Full HD o Máxima con candado, en "Ajustes de
  video" antes del turno) o "Nueva
  categoría" sin cupo abren solo Todo Charadeando ("Desbloquea todo").
  Abajo, "Restaurar compras" y "Tengo un código". Los productos de Google
  Play (`PlayBilling`, con `in_app_purchase`; solo en Android) son
  `charadeando_premium` y `categoria_<código en minúsculas>`
  (`categoria_anime`). Cada compra se confirma a Google (si no, la devuelve
  a los 3 días), se guarda en el celular (`premium.json`) y la hoja se
  cierra con "¡Listo! Ya tienes Anime." (o "…Todo Charadeando."). Al abrir
  la app, si no lo tiene todo, se buscan las compras hechas (por si se
  reinstaló). Si se cierra la ventana de pago, Android lo avisa sin decir
  el producto (`productID` vacío); igual le llega a la hoja
  (`PlayBilling.eventFor`) y el botón deja de cargar. Si Google responde con
  error (también lo hace con "Ya tienes este artículo"), la hoja lo dice y
  busca las compras hechas, por si ya era suyo. Sin Google Play avisa
  que las compras no están disponibles.
  Los códigos promocionales de Google Play se canjean en Play Store y
  llegan como una compra más.
- Las categorías de pago que ya son suyas (compradas sueltas o con un
  código) pierden el candado y, cada 6 segundos, les pasa un brillo en
  diagonal (`Shine`); con Todo Charadeando brillan todas las tarjetas de las
  secciones, cada una a su tiempo para que no
  brillen todas juntas. Si el celular pide menos animaciones, no brillan.
- Fondo Oro (`Backdrop.oro`), exclusivo de Todo Charadeando: un degradado
  dorado (claro, con los textos oscuros y las tarjetas con borde blanco)
  al que cada 6 segundos le pasa un brillo en diagonal (`shiny`, con
  `Shine` detrás de todo). No aparece en "Fondos" hasta tener Todo
  Charadeando; al comprarlo o canjear un código que abre todo, la app se
  pone sola el fondo Oro (después se puede cambiar por otro en "Fondos",
  donde va al final, a lo ancho, con "Exclusivo de Todo Charadeando"). Si
  estaba elegido y ya no lo tiene, la app usa el clásico
  (`Backdrop.allowedWith`). Está en la lista de lo que trae Todo
  Charadeando ("Fondo exclusivo Oro").
- Insignia de Todo Charadeando: quien lo tiene (comprado o con un código
  que abre todo) ve un sello dorado con la medalla (`TodoCharadeandoSeal`)
  a la derecha de "Selección de categoría" (al tocarlo: "Tienes Todo
  Charadeando: todas las categorías desbloqueadas.") y, en Ajustes, una
  tarjeta dorada (`TodoCharadeandoCard`): "¡Lo tienes todo! Gracias por
  apoyar Charadeando.".
- Códigos propios ("Canjear código" en Ajustes o "Tengo un código" en la
  hoja): se validan en el servidor (`POST /juego/canjear`, ver
  `server/README.md`) con el código y el identificador del celular. Un
  código abre todo o algunas categorías (por ejemplo, solo Anime); si no
  sirve, el mensaje del servidor sale bajo el campo ("Este código ya
  venció."). Lo abierto se guarda en el celular y se suma a lo que ya
  había. El identificador es el SHA-256 de `charadeando:` + el
  `ANDROID_ID` (canal `charadeando/dispositivo` en `MainActivity.kt`), que
  no cambia al reinstalar la app; si no se puede leer, uno al azar guardado
  en `premium.json`. Al abrir la app sin nada desbloqueado guardado (por
  ejemplo, recién reinstalada), se recuperan solos los códigos que ese
  celular ya canjeó (`POST /juego/mis-codigos`, no gasta usos); sin
  internet se intenta la próxima vez. En la hoja de compra, "Restaurar mis
  códigos" hace lo mismo ("¡Listo! Recuperaste Anime." o "Este celular no
  tiene códigos canjeados.").
- Ajustes (`lib/screens/settings_screen.dart`), en tarjetas con un ícono en
  cada fila. "Compras" va primero: "Todo Charadeando" ("Todas las
  categorías, pago único"; si ya lo tiene, su tarjeta dorada), "Canjear
  código" y "Restaurar compras". "Preferencias de juego": "Música" (encendida: suena en bucle
  y bajita la música de la app, `assets/audio/musica.mp3`, con
  `audioplayers`; se detiene en cuanto se apaga el ajuste, se pausa con la
  app en segundo plano y se calla en el turno y al ver los videos, que
  tienen su propio sonido; todo pasa por `BackgroundMusic`), "Efectos de
  sonido" (encendidos: cada toque de un botón, tarjeta, fila o interruptor
  suena con `assets/audio/toque.mp3`; va enganchado a la animación de toque
  de Material, `TapSoundSplashFactory`, así que suena solo al completar el
  toque, no al deslizar ni en lo deshabilitado, y no suena en el turno ni
  en los videos; en el turno, cada acierto suena a "¡Correcto!" con
  `assets/audio/correcto.mp3` y cada palabra pasada, con
  `assets/audio/paso.mp3`; la cuenta regresiva pita en cada número
  (`assets/audio/cuenta.mp3`) y con uno más agudo al arrancar
  (`assets/audio/ya.mp3`); en los últimos 10 segundos del turno se oye
  el tic-tac de un reloj, un segundo a la vez (`assets/audio/reloj.mp3`),
  y una marimba suave cierra el turno, por tiempo o por quedarse sin
  palabras (`assets/audio/fin.mp3`), y la música de la app vuelve cuando
  la marimba termina (`BackgroundMusic.holdFor`), no encima de ella; la ruleta de castigos hace un clic
  (`assets/audio/ruleta.mp3`) cada vez que pasa un castigo, igual que la
  vibración, así que va al ritmo del giro y se espacia sola al frenar;
  cada sonido devuelve su reproductor al grupo al terminar;
  los efectos pasan por `AssetEffectPlayer` y
  los demás todavía no tienen archivo), "Vibración" (encendida; todas las vibraciones pasan
  por `Haptics`, que no vibra si está apagada) y "Controlador":
  "Inclinación" (por defecto: abajo es acierto y arriba, pasar) o "Toque"
  (la mitad derecha de la pantalla es acierto y la izquierda, pasar, con
  una marca suave en cada borde durante el turno; en Modo TV el juez sigue
  con sus botones). "Apariencia": "Fondos". "Privacidad": un solo
  interruptor, "Enviar datos anónimos" (encendido por
  defecto, `AppSettings.shareData`), que controla los reportes de errores y
  las estadísticas de las partidas (ver "Reportes, reseña y estadísticas"),
  y "Política de privacidad", que abre en el navegador
  https://valkiriacode.com/charadeando/privacidad (la misma de la ficha de
  Play; está en el sitio de ValkiriaCode, con `url_launcher`).
  "Ayuda": "Cómo se juega", "Califica Charadeando" (abre la ficha de Play
  Store con `in_app_review`) y "Créditos"
  (abre desde abajo de dónde salen la música, "Comedy" de nastelbom en
  Pixabay; los efectos de sonido, el toque de vadim_makes_sound y
  "¡Correcto!" de freesound_gamestudio, "Paso" de soynoviembre y la
  cuenta regresiva de transcendedlifting, el reloj de sspsurvival y la
  marimba del final de universfield y la ruleta de victorabdo, también
  de Pixabay; y las imágenes
  de las categorías, íconos de Flaticon; el de Anime, de smalllikeart; el
  de Futbolistas, de justicon, y los de Deportistas y Fotomímica (el
  mimo), de Magnific). Se
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
  derecha ("9 categorías"), y sus tarjetas en
  una cuadrícula de 3 columnas, todas visibles:
  1. Clásicos: Animales, Comida, Objetos, Profesiones y Acciones.
  2. Entretenimiento: Películas, Series y novelas, Personajes, Superhéroes,
     Dibujos animados, Anime, Videojuegos, Música y canciones y
     Celebridades.
  3. Cultura general: Geografía, Lugares, Personajes históricos, Dichos y
     refranes y Marcas.
  4. Deportes: Deportes, Equipos de fútbol, Futbolistas y Deportistas
     famosos.
  5. Especiales ("Solo por temporada"): Vacaciones (del 15 de junio al 31
     de julio), Halloween (del 1 al 31 de octubre) y Navidad (del 1 de
     diciembre al 6 de enero). Solo aparece cuando hay
     una especial en temporada; fuera de sus fechas no salen en ningún lado
     (ni en Combinar ni en la bienvenida). En modo debug
     (`flutter run`) salen todo el año para probarlas
     (`allSeasonsProvider` es `kDebugMode`); en la versión de lanzamiento,
     solo en su temporada. Otra especial se agrega con su `Season` (mes y día de inicio
     y fin).
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
  va en el orden de la pantalla. Una categoría con `isNew` lleva la
  etiqueta amarilla "Nueva" arriba a la izquierda (por ahora ninguna, en
  desarrollo). Una categoría sin palabras en Directus (`available`
  en falso; hoy todas tienen) lleva "Pronto" sobre su dibujo apagado: al
  tocarla avisa "¡Pronto! Estamos preparando las palabras de…" y no se juegan ni se combinan. Las
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
  configuración guardada (se cambia antes del turno). No cambia la última
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
  Superhéroes, Dibujos animados, Anime, Videojuegos, Música y canciones,
  Personajes históricos, Dichos y refranes, Vacaciones, Halloween y
  Navidad, Futbolistas y Deportistas: todas.
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
- Fotomímica: otro juego, con fotos de objetos en vez de palabras. En
  Categorías va en su propia sección, "Más juegos", después de las
  categorías y antes de "Mis categorías" (Libre y "Combinar categorías"
  quedan arriba como siempre). No es una tarjeta de categoría sino un
  cartel ancho y oscuro (`PhotoMimeSection`): su logo (el mimo),
  "NUEVO JUEGO", el nombre en grande, "Mira la foto y conviértete en ese
  objeto. ¡Sin hablar!", el botón "Jugar" y a la derecha dos fotos de
  ejemplo tipo polaroid (unas maracas y un helicóptero, en
  `assets/img/fotomimica/`, de 240 px en WebP). **Por ahora es gratis y
  completa** (`PhotoMimeBank.freeForNow`): salen todos los objetos, también
  los de pago, y no se muestra "Más objetos con Premium". Más adelante todo
  el juego será Premium; con `freeForNow = false`, sin
  Todo Charadeando, debajo va "Más objetos con Premium", que abre la hoja
  de compra. Por dentro es `GameCategory.photoMime` (sin sección ni candado).
  Se juega como una partida normal (equipos, turnos, aciertos, pasar,
  marcador y ruleta al
  final, partida rápida o personalizada, el mismo tiempo de turno), pero
  en vez de la palabra se ve la foto del objeto lo más grande posible, sin
  deformarla, sobre el mismo fondo de colores del turno con palabras, y
  debajo su nombre en letra pequeña (blanca) para quien actúa (`PhotoMimeView`, en `WordCard` y en el Modo TV). En su
  configuración no se ve la sección "Puntuación": se cuenta siempre un
  punto por acierto ("Por frase"), aunque la última partida fuera "Por
  palabra". Como todavía hay pocos objetos, se juegan como mucho 5 rondas
  (`GameConfig.maxPhotoMimeRounds`) y las fotos se repiten dentro de la
  partida: cada mazo se completa hasta lo que alcanzaría un grupo rápido
  (primero con los objetos que no tiene, después repitiendo, nunca la
  misma foto dos veces seguidas), y al terminar cada turno se rellena
  igual, mejor con fotos que ese grupo no acaba de ver. No tiene
  dificultad ni se combina con otras categorías (no sale en "Combinar
  categorías"). Antes de empezar, "Preparando imágenes…" con una barra y
  "27 de 60": `PhotoMimeBank` pide los objetos a `POST /juego/fotomimica`
  (hasta 90 por partida, más 10 de repuesto) y descarga TODAS las fotos al
  celular (`<cache>/fotomimica/<id>.webp`, de
  `/assets/<id>?width=720&quality=80&format=webp`), de a 4 a la vez; las
  que fallan o están dañadas se reemplazan por otro objeto. Así en el turno
  nunca se queda cargando una foto (además, mientras se ve "¡Correcto!" o
  "Paso", la siguiente queda lista en memoria). Sin internet dice "Sin
  conexión" y no deja empezar; con menos objetos que equipos, que todavía
  no hay suficientes. Las fotos ya descargadas no se vuelven a bajar (se
  guardan las 300 más recientes) y los ids jugados se recuerdan
  (`fotomimica_vistas.json`) para no repetirlos en las partidas siguientes.
  Con `freeForNow = false`, sin Premium solo salen los objetos gratis; con
  Todo Charadeando (compra o código), también los de pago. Cuáles son de pago se decide en Directus
  con el campo `premium` de cada objeto. Su logo, el mimo, está en
  `assets/img/categorias/fotomimica.png` (como el dibujo de las demás
  categorías) y se ve en el cartel y en la cabecera de la configuración.
- Combinar categorías: debajo de Libre, el botón "Combinar categorías"
  abre desde abajo una ventana con las categorías del juego (sin Libre) con
  los mismos títulos de sección y en el mismo orden que la pantalla, y al
  final "Mis categorías" (si hay alguna), cada una con su dibujo o ícono y
  una casilla; se marca o desmarca tocando la fila. Las de "Pronto" llevan
  esa etiqueta en vez de la casilla y no se marcan. Las premium bloqueadas
  llevan candado y abren la hoja de compra (si se desbloquean, quedan
  marcadas); las propias con menos de 10 palabras dicen "Faltan palabras" y no se marcan.
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
  "?") o los castigos del juego ("Otros castigos", justo debajo de la
  ruleta, los cambia sin bajar la pantalla). Al girar se
  revisa que esté completa y, en "Jugadores y app", la app llena los vacíos;
  entonces la ruleta se abre a pantalla completa, sin la configuración ni
  la barra de abajo: solo la ruleta girando y "¡Parar!". En la sección y en el final de la
  partida la ruleta no sigue al dedo (`dragToSpin: false`): deslizar encima
  baja la pantalla, se gira con "Girar" y tocar un campo abre un recuadro de
  su color con el castigo completo (`showPunishmentField`; en la ruleta a
  veces se corta con "…"). Al lado de cada castigo que se escribe hay un
  cuadrado con el color de su campo. En el final, después de girar y tocar
  "Listo", la ruleta se sigue viendo (con empate pasa al siguiente equipo). En la de
  pantalla completa sí se gira con el dedo: sigue al dedo y, si se suelta
  con impulso, gira hacia donde iba el dedo (a la derecha, en el sentido del
  reloj; a la izquierda, al revés; hacia arriba o abajo, según el lado) y
  frena sola; se toma de cualquier lado. La
  fuerza solo cambia cuánto tarda, el castigo sale igual al azar.
  "Listo" la deja quieta otra vez para seguir cambiándola. Se elige la
  cantidad de campos (de 2 a 10, la ruleta se divide en partes iguales) y de
  dónde salen los castigos, una opción por línea con lo que significa
  debajo: "Los escriben los jugadores", "Los pone la app" (los castigos
  familiares de la colección `castigos` de Directus, que la app trae al
  abrir con `POST /juego/castigos` (`PunishmentPool`); si no llegan, usa 20
  de respaldo de `services/punishments.dart`) o "Jugadores y app" (el
  equipo escribe algunos y la app completa los vacíos sin repetir). Al girar, la ruleta queda guardada en el celular.
- Cómo gira: "Girar" la pone a toda velocidad y sigue sola hasta que tocan
  "¡Parar!" (o pasan 30 segundos). Entonces se elige el castigo al azar (el
  momento del toque no influye) y la ruleta frena durante 7 segundos con una
  curva que es rápida al principio y muy lenta al final, hasta quedar justo en
  el centro de ese campo. Cada campo que pasa por el indicador hace un "tic"
  con vibración, y el castigo cae apenas a la ruleta le falta menos de 1°
  (`PunishmentRoulette.landWithin`, unos 6 segundos): el final de la curva
  ya se ve quieto y esperarlo se sentía como un retraso. Aparece en grande
  (entra en 0,4 s) con una vibración fuerte, con "Girar otra vez" y
  "Listo". Si un castigo es muy largo para su
  campo, se corta con "…" (completo se ve al caer). La cara de la ruleta se
  dibuja una vez y solo se gira, así los textos quedan fijos a la ruleta
  mientras da vueltas.
- Al final de la partida, el equipo con menos puntos ve "¡Ruleta de castigo
  para …!" con la misma ruleta de la sección Ruleta (`RouletteSetupView`,
  en `lib/screens/roulette_screen.dart`, con `compact`): la ruleta quieta
  con sus castigos, "Girar", "Sin castigo" y "Personalizar castigos",
  que abre una hoja desde abajo con una ruleta pequeña que muestra cada
  cambio, "Otros castigos" (si los pone la app), la configuración (cantidad de campos y
  de dónde salen los castigos) y "Listo". En la sección Ruleta la
  configuración sigue debajo de la ruleta. Usa la ruleta guardada
  o, si nunca se configuró, 8 castigos de la app. Al girar, la
  configuración queda guardada y la ruleta sigue girando a pantalla
  completa con los mismos castigos. Si varios empatan con menos puntos,
  cada uno gira su ruleta, uno después del otro; si todos empatan, no hay
  castigo. En Modo TV la ruleta se ve en el televisor porque el
  celular duplica su pantalla.
- Un solo celular, aciertos con movimiento: inclinar hacia abajo es acierto y
  hacia arriba es pasar. `TiltDetector` mide el ángulo de la pantalla con
  el horizonte de dos formas (el eje Z y la gravedad que queda en el plano
  de la pantalla) y usa la menor, así que girar la cabeza a un lado no
  cuenta. Pide unos 28° desde la posición neutra, sostenidos 60 ms (medidos
  con la hora de cada lectura del sensor, igual que el filtro que suaviza
  el temblor, para que en celulares con lecturas más espaciadas el acierto
  no tarde más); "¡Correcto!" o "Paso" se ve medio segundo antes de la
  palabra siguiente;
  la neutra se toma al empezar, puede estar inclinada hasta 50° (por
  ejemplo, con el celular debajo de la cara) y nunca pide pasar de 75°, así
  que siempre se puede pasar y acertar. Al empezar toma la gravedad que
  mide ese celular, y la neutra sigue despacio la postura del jugador.
- En la configuración, la sección Modo TV va al final, después de Video.
- Con un TV conectado, la animación de la bienvenida dice "El juez toca
  ¡Correcto! o Pasar en el celular." en vez de explicar cómo inclinarlo.
- Modo TV, en todas las categorías: se activa solo cuando el celular duplica
  la pantalla en un TV (AirPlay, Chromecast o HDMI). Como algunos celulares no
  avisan al dejar de duplicar, la app vuelve a preguntarle al sistema
  (`TvService.isConnected`, `confirmTvConnected`) al abrir la configuración,
  al elegir la forma de jugar y al volver a la app, y el código nativo revisa
  otra vez a los 0,5 y 2 segundos de cada cambio; así no queda en Modo TV,
  sin cámara, después de desconectar el televisor. Mientras está activo, la
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
  arriba a la derecha "● Video · HD" (ver "Ajustes de video"); a la izquierda, "Finalizar juego", a
  quién le toca (solo con equipos: "Turno de Los Primos"), las píldoras
  según el controlador ("↓ Acierto" y "↑ Pasar" con Inclinación; "Toca a la
  derecha: Acierto" y "Toca a la izquierda: Pasar" con Toque) y "¡Listo!". Sin video o en Modo TV es la misma
  pantalla sobre el fondo de la app; mientras abre la cámara también se ve
  el fondo, y sin permiso de cámara se juega sin video. Al terminar el
  turno vuelve a vertical.
- La pantalla del juego gira sola hacia el lado en que se tenga el celular
  (horizontal izquierda o derecha), así la palabra nunca queda al revés.
  Antes del turno, en "Ponte el celular en la frente" y durante la cuenta
  3, 2, 1 sigue al sensor
  aunque el giro automático del sistema esté apagado (Android:
  `SCREEN_ORIENTATION_SENSOR_LANDSCAPE` por el canal `charadeando/pantalla`
  de `MainActivity.kt`, que avisa cada giro con `giro`), y la vista de la
  cámara gira con ella (`CameraService.follow`). Si giran el celular en la
  cuenta, cuando ya se está grabando, esa parte del video se cierra y se
  graba otra con el lado nuevo, así no queda de cabeza. Cuando empieza el
  juego la pantalla se fija en el lado en que está
  (`ScreenOrientation.lock`): no gira al inclinar el celular para acertar
  o pasar.
  La inclinación se mide en el eje perpendicular a la pantalla, así que
  abajo es acierto en los dos lados. Reemplaza el antiguo ajuste "Rotación
  invertida".
- Con Inclinación, "¡Listo!" (o "Continuar") lleva primero a "Ponte el
  celular en la frente para comenzar": `ForeheadDetector` espera el celular
  de lado, con la pantalla de pie o inclinada hasta 55° (sentado, la frente
  queda inclinada hacia atrás) y quieto un segundo, y ahí arranca la cuenta
  3, 2, 1; así la inclinación se calibra con el celular ya en la frente.
  Acostado en la mesa o sacudiéndolo no cuenta. A los 8 segundos (tiempo
  para acomodarse) aparece "Empezar igual" y a los 15 la cuenta arranca
  sola por si no lo reconoce
  (con el celular en la frente el botón no se ve), y sin acelerómetro
  empieza de una. Con Toque, en Modo TV o con el
  celular juez conectado se va directo a la cuenta. Idea de un probador de
  la prueba cerrada.
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
  primero resaltado, la ruleta de castigo (con sus castigos a la vista, "Girar" o "Sin castigo") y abajo
  "Jugar otra vez" (misma configuración; pide palabras nuevas o las vuelven
  a escribir), "⚙️ Cambiar configuración" y "← Salir de la categoría".
- Palabras escritas por los equipos: las de cada equipo se reparten entre todos
  los demás, así que a nadie le salen las suyas y cada palabra se juega una
  sola vez. El texto se oculta al guardarlo. Funciona sin internet.
- Puntuación por palabra (cuentan artículos y conectores) o por frase. Pasar
  no suma ni resta, y las palabras pasadas no vuelven al mazo. Igualdad de
  puntos es empate.
- Video de cada turno con la cámara frontal, en 720p por defecto. Se elige
  en la pantalla de antes del turno: arriba a la derecha, "● Video · HD"
  (o "Sin grabar") abre "Ajustes de video", un panel pequeño con "Grabar
  video", "Guardar automáticamente" y la resolución (Normal "Más liviano", HD "Recomendado", Full HD
  y Máxima). Al cambiar la resolución la cámara se vuelve a abrir con la
  nueva, y se ve detrás del panel. Full HD y Máxima son de Todo
  Charadeando: con candado, y al tocarlas se abre la hoja de compra. Lo
  elegido se recuerda para los turnos y las partidas siguientes
  (`AppSettings.recordVideo` y la resolución de la última configuración);
  la configuración personalizada ya no tiene sección de video. Un "Jugar
  sin grabar" guardado antes vuelve a HD.
- El video se puede ver, guardar en la galería o compartir. En el
  resultado del turno, junto a "Ver video", está "Guardar" (lo guarda sin
  abrirlo; ya guardado dice "Guardado"), y debajo siempre se avisa
  "Guárdalo para verlo en Mis videos. Si no, se borra al continuar" ("al
  salir" en la rápida). Si está listo sin guardar y se toca continuar,
  otra rápida, personalizada, salir o finalizar, pregunta "¿Salir sin
  guardar el video?" con "Guardar" y "Salir sin guardar" (tocar afuera
  deja en el resultado). Con "Guardar automáticamente" (en "Ajustes de
  video", apagado por defecto, `AppSettings.autoSaveVideo`) cada video se
  guarda solo en la galería y en Mis videos cuando termina de armarse,
  aunque ya hayan salido del resultado (el armado sigue por detrás y borra
  su archivo temporal al guardarlo), y no se pregunta nada. Sin guardar,
  al continuar se borra del celular; la app no guarda videos en ningún
  otro lugar.
- El video final muestra las palabras que se están adivinando, los aciertos y
  los pases. Se arma con FFmpeg (`ffmpeg_kit_flutter_new_video`, licencia
  LGPL) mientras se ven los resultados del turno. Sin Todo Charadeando lleva
  el logo de Charadeando como marca de agua (`assets/img/marca/marca_agua.png`)
  abajo a la derecha, del 20 % del ancho del video (se mide con FFprobe) y un
  poco transparente, para no tapar la palabra ni "¡Correcto!"/"Paso". Si con
  el logo FFmpeg falla, el video se arma sin él.
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
server/juez/     Worker del celular juez (Cloudflare)
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

### Publicar en Google Play

El identificador de la app es `com.valkiriacode.charadeando` (en Android e
iOS). No se puede cambiar después de publicar.

La versión de lanzamiento se firma con la llave de subida. Ni la llave
(`.jks`) ni sus contraseñas van en el repositorio (`android/.gitignore`):
viven solo en el computador de quien publica.

1. Crear la llave una sola vez y guardarla en un lugar seguro (sin ella no
   se pueden publicar actualizaciones):
   ```sh
   keytool -genkey -v -keystore ~/charadeando-upload.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias upload
   ```
2. Crear `android/key.properties`:
   ```properties
   storePassword=<contraseña del almacén>
   keyPassword=<contraseña de la llave>
   keyAlias=upload
   storeFile=/ruta/a/charadeando-upload.jks
   ```
3. Subir el número después del `+` en `version:` de `pubspec.yaml` en
   cada publicación (`1.0.0+1`, `1.0.1+2`…) y generar el paquete:
   ```sh
   flutter build appbundle --release
   ```
   Queda en `build/app/outputs/bundle/release/app-release.aab`.

Sin `key.properties` la versión de lanzamiento se firma con la llave de
depuración (sirve para probar, pero Google Play no la acepta). Con la firma
de apps de Google Play activada, Google firma lo que llega a los celulares;
el ANDROID_ID depende de esa firma, así que los códigos canjeados con una
versión de depuración no aparecen en la de Play Store.

### Reportes, reseña y estadísticas

**Reportes de errores (Firebase Crashlytics, solo Android por ahora).**
`lib/services/crash_reporting.dart` arranca Firebase en `main.dart` y
manda como fatales los errores de Flutter (`FlutterError.onError`) y los
asíncronos que nadie atrapó (`PlatformDispatcher.instance.onError`). Los
errores que la app ya maneja y le muestra al jugador se mandan como no
fatales con `ErrorReporter.instance.report` (`error_reporter.dart`): abrir
la cámara (salvo el permiso negado), empezar o guardar una grabación, armar
el video con FFmpeg, una compra fallida y Directus sin respuesta o con
error (palabras, Fotomímica y castigos). Cada reporte lleva las claves
`pantalla` (la ruta), `modo_juego` (`normal`, `fotomimica`, `tv` o
`juez`), `grabando` y `resolucion`; nada personal. En modo debug nunca se
envía nada (`crashReportsAllowed`), y el interruptor de Privacidad lo
apaga.

`android/app/google-services.json` **no va en el repositorio**
(`android/.gitignore`), como `key.properties`: se descarga de la consola de
Firebase y se guarda solo en el computador de quien compila. Sin él la app
compila y funciona igual, sin enviar reportes (el plugin
`com.google.gms.google-services` solo se aplica si el archivo existe).

**Actualizaciones (`in_app_update`).** Al abrir la app (y al volver a ella,
como mucho una vez por hora) `AppUpdateController` le pregunta a Google Play
si hay una versión nueva. Si la hay, Play muestra su aviso ("Actualizar" /
"No, gracias") y la baja en segundo plano mientras se sigue jugando (la
actualización flexible); cuando termina, sale una ventana "¡Hay una versión
nueva!" (`showUpdateReady`) con "Más tarde" y "Actualizar", que la instala
(la app se cierra y se abre de nuevo). Se pregunta una vez
por sesión y nunca en el turno ni viendo un video. Solo funciona con la app
instalada desde Play (también en las pruebas interna y cerrada); en modo
debug no hace nada.

**Reseña (`in_app_review`).** En el resultado final, unos 2 segundos
después de ver al ganador, se pide la reseña de Play Store si se cumple
todo: es la 3.ª partida terminada o más, hubo ganador (con equipos y sin
empate), no hubo errores durante la partida y no se pidió en los últimos 30
días (`ReviewPolicy`). Las partidas terminadas y la fecha se guardan en
`resena.json`. Si ya abrieron la ruleta, no se pide encima. Google decide
si la ventana de verdad aparece.

**Estadísticas anónimas.** Al llegar al resultado final (o al salir de una
partida rápida) se envía `POST /juego/partida` con el modo, las categorías
(las propias solo como `MIS_CATEGORIAS`), la dificultad, cuántos equipos,
rondas y segundos por turno, palabras, aciertos y pases, cómo se marcaron
los aciertos, si se grabó video, la versión de la app y si terminó. Si
abandonan después de al menos un turno ("Abandonar" en el turno, o empezar
otra partida), va con `terminada: false`. Nada identifica a la persona ni
al celular (`GameStats.build`). Sin internet se guardan en
`estadisticas_pendientes.json` (como mucho 50) y se mandan después (al
abrir la app y con la siguiente partida); los errores al enviar nunca se
muestran ni demoran el juego. Con el interruptor apagado no se envía nada
y se borra lo pendiente.

La app habla con el servidor del juego en
`https://charadeando-api.valkiriacode.com` (`DirectusService.defaultBaseUrl`).
Para probar con otro servidor: `flutter run --dart-define=DIRECTUS_URL=https://...`.

Si no llegan las palabras, el jugador solo ve "No se pudieron traer las
palabras" con una indicación sencilla (revisar el internet o intentarlo en un
momento) y "Reintentar"; nunca el detalle técnico del servidor
(`DirectusException.userMessage`). El detalle (`hint`) queda para la pantalla
de prueba del servidor.

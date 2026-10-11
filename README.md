# Charadeando

Juego de charadas para Android e iOS hecho en Flutter. Un jugador se pone el
celular en la frente y adivina la palabra con las pistas de su grupo, mientras
la cámara frontal graba a los participantes para revivir las risas.

## Versión 0.1

- Diseño colorido con fondo de gradiente y las fuentes Fredoka y Nunito
  (licencia OFL, en `assets/fonts`). Los colores no cambian con el modo oscuro
  del celular.
- Pantalla de categorías: Libre, Animales, Geografía, Películas,
  Celebridades, Marcas, Deportes y Equipos de fútbol. Libre deja elegir entre
  palabras manuales (las escriben los grupos) y automáticas (frases de la
  categoría LIBRE); las demás muestran su propio "¿Cómo se juega?" (una
  animación con palabras de la categoría y los pasos) y siguen a la
  configuración con palabras automáticas de su categoría.
- Cada categoría puede tener un dibujo animado (GIF de 256 px en
  `assets/img/categorias/`, con el nombre de la categoría) que se ve en su
  tarjeta y en su "¿Cómo se juega?". Ya lo tienen todas: Libre (un lápiz
  que escribe), Animales, Geografía, Películas, Celebridades, Marcas,
  Deportes y Equipos de fútbol.
- Dificultad: Mezcladas (viene elegida: trae de todas, 300 palabras por
  categoría), Fácil (ideal con niños), Normal o Difícil (100 cada una). Se
  elige en la configuración de las palabras automáticas, en Libre y en todas
  las categorías. Las palabras manuales no tienen dificultad. En Directus se
  conserva la columna `dificultad`.
- Límites: de 2 a 4 grupos, de 1 a 10 rondas y de 30 segundos a 1:30 por
  turno.
- Libre explica con una animación cómo se juega y deja elegir entre palabras
  manuales y automáticas.
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
- Modo TV, en todas las categorías: se activa solo cuando el celular duplica
  la pantalla en un TV (AirPlay, Chromecast o HDMI). Mientras está activo, la
  configuración oculta las secciones de aciertos y de video, durante el turno el
  TV muestra solo el turno del grupo, el tiempo, "Finalizar juego", la
  palabra y los botones (sin marcador, para no confundir), y después los
  resultados del turno, y un
  juez del grupo rival marca "Pasar" y "¡Correcto!" con botones en el
  celular. El botón "Desconectar TV" detiene la transmisión (en Android) o
  explica cómo hacerlo, y todo vuelve a lo normal. Si el televisor se
  desconecta durante el turno, el juego queda en pausa y sigue al volver a
  conectarlo. La conexión se detecta con código nativo (`MainActivity.kt` y
  `AppDelegate.swift`).
- La configuración y los resultados se ven en vertical. Al tocar "¡Listo!" la
  pantalla gira a horizontal para la cuenta regresiva y el juego, y al terminar
  el turno vuelve a vertical.
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
  turno, vuelve al inicio.
- Si la app sale a segundo plano durante el turno, el juego se pausa y al
  volver sigue donde quedó. El video se graba por partes y se unen al final.

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

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
  tarjeta y en su "¿Cómo se juega?". Ya lo tienen Animales, Geografía,
  Películas y Celebridades; las demás muestran su ícono mientras tanto.
- Dificultad (Fácil, Normal o Difícil): se elige en la configuración de las
  palabras automáticas, en Libre y en todas las categorías, y solo se traen
  palabras de esa dificultad. Las palabras manuales no tienen dificultad.
- Libre explica con una animación cómo se juega y deja elegir entre palabras
  manuales (con la sugerencia de cuántas escribir) y automáticas.
- Palabras automáticas: en la configuración se eligen los grupos, cuántas
  palabras jugar (de 10 a 100, repartidas parejo entre los grupos) y la
  duración: hasta que se acaben las palabras, o por número de rondas (termina
  al completar las rondas o antes si se acaban las palabras). Al tocar
  "Continuar" se muestra "Buscando palabras…" mientras se traen al azar de la
  colección de Directus (`POST /juego/palabras`). La app ya no usa Gemini: las
  palabras son una base propia, revisada por el equipo. Durante el juego no
  se usa internet ni se piden más. El celular recuerda las últimas 500
  palabras jugadas para no repetirlas, y guarda el
  último lote para jugar sin internet. Ver `server/README.md`.
- Con palabras automáticas, la duración del juego va primero. Por número
  de rondas no se elige la cantidad de palabras: se traen las que alcanzan
  para todas las rondas (una cada 3 segundos de turno). Si una dificultad
  se queda sin palabras, se completa con las otras, y si se acaban todas se
  vuelven a usar las ya jugadas.
- En el turno se ve cuántas palabras faltan por adivinar en toda la partida
  ("Faltan 12 palabras"), también antes de empezar y en el Modo TV.
- Un solo celular, aciertos con movimiento: inclinar hacia abajo es acierto y
  hacia arriba es pasar.
- Modo TV, en todas las categorías: se activa solo cuando el celular duplica
  la pantalla en un TV (AirPlay, Chromecast o HDMI). Mientras está activo, la
  configuración oculta las secciones de aciertos y de video, el TV muestra la
  palabra, el tiempo, el grupo, el marcador y los resultados del turno, y un
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
- En la configuración ninguna opción viene elegida (duración, puntuación,
  aciertos): hay que escogerlas antes de continuar. Solo el video tiene valor
  por defecto.
- Video de cada turno con la cámara frontal, en 720p por defecto. También se
  puede jugar sin grabar. 1080p y la máxima resolución quedan bloqueadas como
  premium.
- El video se puede ver, guardar en la galería o compartir. Al continuar al
  siguiente turno se borra del celular; la app no guarda videos en ningún
  otro lugar.
- El video final muestra las palabras que se están adivinando, los aciertos y
  los pases. Se arma con FFmpeg (`ffmpeg_kit_flutter_new_video`, licencia
  LGPL) mientras se ven los resultados del turno.
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
- Modo fiesta para adultos (+18): categoría con candado y aviso de edad.
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

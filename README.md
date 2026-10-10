# Charadeando

Juego de charadas para Android e iOS hecho en Flutter. Un jugador se pone el
celular en la frente y adivina la palabra con las pistas de su grupo, mientras
la cámara frontal graba a los participantes para revivir las risas.

## Versión 0.1

- Diseño colorido con fondo de gradiente y las fuentes Fredoka y Nunito
  (licencia OFL, en `assets/fonts`). Los colores no cambian con el modo oscuro
  del celular.
- Pantalla de categorías: "Libre" (los grupos escriben las palabras) está
  disponible; Animales, Países, Películas, Celebridades, Marcas, Deportes y
  Equipos de fútbol aparecen como "Pronto" hasta tener el backend.
- Libre explica con una animación cómo se juega y deja elegir entre palabras
  manuales (con la sugerencia de cuántas escribir) y automáticas.
- Palabras automáticas: en la configuración se eligen los grupos, cuántas
  palabras jugar (de 10 a 100, repartidas parejo entre los grupos) y la
  duración: hasta que se acaben las palabras, o por número de rondas (termina
  al completar las rondas o antes si se acaban las palabras). Al tocar
  "Continuar" se muestra "Creando palabras…" mientras Gemini las crea por la
  ruta `POST /juego/crear` de Directus, que además las guarda en la colección
  con la categoría LIBRE. Si Gemini falla o repite palabras recientes, se
  completan con palabras de la colección (`POST /juego/palabras`) hasta la
  cantidad elegida. Durante el juego no se usa
  internet ni se piden más. El celular
  recuerda las últimas 500 palabras jugadas (ids y textos) para no repetirlas, y guarda el
  último lote para jugar sin internet. Ver `server/README.md`.
- Un solo celular, aciertos con movimiento: inclinar hacia abajo es acierto y
  hacia arriba es pasar.
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
agua.

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

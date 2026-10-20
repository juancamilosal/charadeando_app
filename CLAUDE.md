# Contexto del proyecto Charadeando

Resumen para que cualquier sesión nueva sepa en qué va el proyecto. Los
detalles de cada parte están en `README.md`, `server/README.md` y
`server/juez/README.md`.

## Proyecto y forma de trabajar

- **App:** Charadeando, juego de charadas familiar en Flutter (Android
  primero) que graba el turno en video.
- **Repositorio:** `juancamilosal/charadeando_app` (público). Se trabaja en
  la rama **`develop`**. **`main` es solo para el lanzamiento en Play Store:**
  no se mezcla `develop` en `main` hasta lanzar.
- **Idioma:** se responde en español. Textos de la app, código y comentarios
  también en español.
- **Antes de cada commit:** `git pull`, `dart format`, `flutter analyze`,
  `flutter test`, y actualizar `README.md` (y `server/README.md` o
  `server/juez/README.md` si aplica). Luego commit y push a `develop`.
- **No crear PR** salvo que se pida.
- **Capturas de pantalla:** siempre con el fondo **Clásico**.
- **Versiones:** se nombran como en Play Console, `5 (1.0.0)` (código de
  versión y nombre); en `pubspec.yaml` es `version: 1.0.0+5`. Cada versión
  que se sube a Play necesita un código mayor que la anterior.

## Lanzamiento en Google Play (en qué va)

- App `com.valkiriacode.charadeando` en prueba interna; la última subida
  es 6 (1.0.0) y `develop` va en 7 (1.0.0).
- Hechos: perfil de pagos (persona física, Colombia) con la cuenta
  Davibank aprobada (ya sin retención), programa de cargos del 15 %, los 17
  productos activos (opción de compra `comprar`) y verificadores de
  licencia; las compras de prueba funcionan (los errores intermitentes de
  Google del primer día eran por productos recién creados).
- Los 3 canjes de `codigos_canjes` en Directus están **pausados** (prefijo
  `pausado-` en `dispositivo`) para probar sin Premium; se reactivan
  quitando el prefijo, con confirmación del usuario.
- Sigue: revisar la ficha (`branding/ficha-play.md`) y hacer las capturas,
  contenido de la app (privacidad, seguridad de los datos, clasificación,
  público objetivo), prueba cerrada (12+ personas, 14 días) y producción.

## Reglas de seguridad

- Nunca pedir ni pegar tokens en el chat. No subir tokens ni códigos
  promocionales al repositorio.
- Las **palabras del juego no van en este repositorio**: están en el
  repositorio privado `juancamilosal/palabras-juego` (con el validador y la
  rutina que crea tandas nuevas).
- **Directus: siempre confirmar con el usuario antes de crear, editar o
  eliminar** cualquier cosa. Las consultas de solo lectura están permitidas.
- El acceso a Directus desde las sesiones va por *network secrets* (el proxy
  pone el `Authorization`). Con Node hace falta `NODE_USE_ENV_PROXY=1`.

## Servidor (Directus)

- Directus 11 con PostgreSQL y Redis, en un VPS de Webdock con Coolify:
  `https://charadeando-api.valkiriacode.com`. Claude Code está instalado en
  el VPS.
- La extensión `server/directus-extensions/charadeando-juego` tiene estas
  rutas (todas con límite por IP):
  - `POST /juego/crear`: palabras nuevas con Gemini (categoría `LIBRE`).
  - `POST /juego/palabras`: palabras al azar por categoría, dificultad
    (`FACIL`/`NORMAL`/`DIFICIL`) e idioma (`ESPAÑOL`), sin las ya jugadas;
    con `categorias` para "Combinar categorías".
  - `POST /juego/canjear` y `POST /juego/mis-codigos`: códigos promocionales
    (colección `codigos`). El celular se identifica con ANDROID_ID con
    SHA-256, así los códigos sobreviven a una reinstalación.
  - `POST /juego/castigos`: castigos de la ruleta (colección `castigos`, con
    100 cargados). La app tiene 20 de respaldo.
  - `POST /juego/fotomimica`: objetos con foto (colección Fotomímica, ya
    creada; scripts en `server/scripts/`).
  - `POST /juego/partida`: estadísticas anónimas de cada partida
    (colección `partidas`, sin IP ni datos del celular; panel de Insights
    "Estadísticas de Charadeando"; script `server/scripts/crear-partidas.mjs`).
  - `GET /juego/estado`: solo administradores; RAM, CPU, carga, disco y
    tamaño de la base.
- Al arrancar, la extensión crea el índice de palabras por categoría, idioma
  y dificultad.
- **Pendiente:** proteger la URL pública del flujo de Gemini y agregar
  Firebase App Check.
- Fotomímica: la colección `fotomimica` tiene 87 objetos publicados (todos
  gratis por ahora; la app los da gratis con `PhotoMimeBank.freeForNow`).
  Se agregan más con `server/scripts/importar-fotomimica.mjs`.
- Cómo instalar o actualizar la extensión: `server/README.md`.

## Funciones ya hechas en la app

- **Navegación y pantallas:** barra inferior con StatefulShellRoute (la
  pestaña que se deja se reinicia); categorías en secciones, con "Pronto",
  "Nueva" y especiales con fechas; "Combinar categorías", Mis categorías y
  modo Libre.
- **Partidas:** rápida y personalizada, con o sin equipos; equipos guardados
  con historial; pantalla de antes del turno en horizontal con la cámara;
  turno con inclinación o toque (Ajustes) y Modo TV; video del turno con las
  palabras encima (ffmpeg) y "Mis videos".
- **Resultados:** en el del turno se toca una palabra para corregirla; en el
  final, ganador o empate, tabla de puntos y ruleta de castigos (editable).
- **Premium:** pago único "Todo Charadeando" o categorías sueltas por Google
  Play, más códigos promocionales. Solo las dos primeras categorías de cada
  sección son gratis. El fondo Oro es exclusivo de quien compra todo, y
  quien compra todo graba los videos sin marca de agua (sin Premium llevan
  el logo abajo a la derecha). Precios: Todo Charadeando $15.000 y cada
  categoría $4.000 (IDs `charadeando_premium` y `categoria_<código>`).
- **Fotomímica:** cartel "Más juegos" antes de Mis categorías, con fotos
  precargadas.
- **Reportes, reseña y estadísticas:** Firebase Crashlytics solo en Android
  (`google-services.json` fuera del repo; sin él compila igual), reseña con
  `in_app_review` (`ReviewPolicy`) y estadísticas a `/juego/partida` con
  cola en el celular. Ajustes > Privacidad tiene un solo interruptor para
  reportes y estadísticas.
- **Marca y arranque:** splash nativo solo con el fondo y luego pantalla
  Flutter animada con destellos. Ícono y gráficos de Play en `branding/`.

## Celular juez (lo último que se hizo)

- Un segundo celular hace de juez desde el navegador, sin instalar la app:
  escanea un QR y marca "✓ Acierto" o "→ Pasar". Es gratis, como el Modo
  TV.
- **Worker de Cloudflare** `charadeando-juez` en `server/juez/`:
  - Rutas `valkiriacode.com/juez` y `/juez/*`, con un Durable Object `Sala`
    (SQLite + WebSocket Hibernation).
  - Creado en Cloudflare con Workers Builds; **publica desde `develop`** y
    al lanzar se cambia a `main`.
  - `GET /juez/api/salud`: si no responde, la app oculta la opción.
  - `POST /juez/api/salas`: sala con código de 6 letras y token del
    anfitrión (la sala guarda solo la huella).
  - `GET /juez/<CÓDIGO>`: página del juez. `GET /juez`: página para
    escribir el código.
  - Las salas se borran tras 3 horas sin actividad; sin datos personales.
  - Pruebas: `npm test` (node --test). Local: `npx wrangler dev`.
  - El módulo principal del Worker solo puede exportar el handler y la clase
    del Durable Object: exportar otra constante rompe workerd.
- **Página del juez:** palabra, categoría, tiempo y puntos; debajo del tiempo
  confirma cada marca ("✓ ¡Correcto!" o "→ Paso", y "No llegó, toca otra
  vez" si no llega en 2 s). Al final del turno, resumen con la lista de
  palabras (corregible mientras la app está en el resultado de ese turno).
  Al final de la partida, "¡Ganó X!" o "¡Empate entre…!" con las posiciones
  (sin equipos, el total). "Cerrar" al final del turno y de la partida
  vuelve a `/juez`.
- **Un solo juez por sala:** otro celular ve "La sala ya tiene juez". El
  mismo celular puede volver a entrar (id en `localStorage`; reemplaza la
  conexión anterior, cierre 4001).
- **En la app:** sección "Celular juez" en la configuración con QR y código;
  con el juez conectado, inclinar o tocar no marca; sin equipos el juez ve
  solo los puntos de cada turno; "QR Juez" en el resultado del turno muestra
  el QR, la página y el código; el juez también ve la cuenta 3, 2, 1
  antes de cada turno (campo `cuenta`). Archivos: `lib/services/judge_service.dart`,
  `lib/widgets/judge_setup.dart`, `lib/providers/providers.dart`
  (`judgeTurnSummary`, `judgeStandings`), `lib/screens/turn_screen.dart` y
  `lib/screens/turn_result_screen.dart`.

## Detalles técnicos

- Flutter 3.47, Riverpod 3 (`ref.mounted`; `Override` se importa de
  `flutter_riverpod/misc.dart`) y go_router. Las páginas del shell usan
  siempre `CustomTransitionPage` (evita claves duplicadas).
- Paquetes clave: camera, sensors_plus, ffmpeg_kit_flutter_new_video,
  in_app_purchase, qr_flutter, web_socket_channel.
- En pruebas con WebSocket o streams a veces hacen falta `tester.runAsync` y
  simular el canal de wakelock.
- La página del juez se revisa con Playwright y Chromium contra
  `wrangler dev`.

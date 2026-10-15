# Servidor de Charadeando

Directus 11 con PostgreSQL y Redis, desplegado con Coolify en el VPS.

## Seguridad de las palabras

- La colección `palabras` (campos `id`, `frase`, `categoria`) **no es
  pública**: el rol Public no tiene ningún permiso sobre ella. Solo se edita
  desde el panel de Directus o por la extensión.
- La app usa dos rutas propias de la extensión
  `directus-extensions/charadeando-juego`:
  - `POST /juego/crear` con `{ "n": 20 }` (máximo 100): llama por dentro al
    flujo de Gemini con instrucciones fijas, guarda en `palabras` las nuevas
    con la categoría `LIBRE` y las devuelve con su id. Gemini no recuerda
    los pedidos anteriores, así que cada pedido lleva una muestra al azar
    de 120 palabras ya guardadas para que no las repita. No se le da un tema:
    las palabras son de cualquier cosa (los temas son las categorías).
    Se le piden 40 % de palabras de más y se descartan las que ya existen o
    son variantes de otra ("Astronauta flotando" si ya está "Astronauta").
    Más de 25 palabras se piden en varios pedidos a Gemini en paralelo (de
    hasta 25, cada uno con su propia muestra a evitar) para que tarde lo mismo que uno
    solo; si alguno falla se usan los demás. Responde 502 si fallan todos o
    si no queda ninguna palabra nueva. 5 peticiones por minuto por IP.
  - `POST /juego/palabras`: solo lee; entrega palabras al azar de la
    categoría y dificultad pedidas, con un máximo de 450 por petición, y
    excluye hasta 500 ids que la app ya jugó. Si no alcanzan, completa con
    palabras no jugadas de las otras dificultades, luego con ya jugadas de
    la misma dificultad y por último con ya jugadas de cualquier
    dificultad, siempre de la misma categoría. Solo entrega palabras en
    español: `idioma` igual a `ESPAÑOL` (también `ESPANOL`, sin ñ) o sin
    idioma (las primeras tandas).
    Con `categorias` (una lista
    de hasta 20) reparte las `n` palabras en partes iguales entre ellas (el
    sobrante, de a una entre las primeras), con la misma lógica de
    dificultad y `excluir` para cada una; si alguna no alcanza, completa con
    las otras categorías de la lista. Es para "Combinar categorías" en la
    app. 10 peticiones por minuto por IP.
  - `POST /juego/canjear`: canjea un código promocional (ver "Códigos
    promocionales" abajo). 5 intentos por minuto por IP, para que no se
    puedan adivinar códigos probando.
  - `POST /juego/mis-codigos`: lo que abren los códigos que un celular ya
    canjeó, para recuperarlos al reinstalar la app (ver abajo). 5 intentos
    por minuto por IP.
  - `POST /juego/castigos` con `{ "n": 200 }` (de 1 a 200): castigos al
    azar de la colección `castigos` (campos `id` y `nombre`), como
    `{ "data": [{ "id": "...", "texto": "..." }] }`, sin vacíos ni
    repetidos. La app los trae una vez al abrir y los usa en la ruleta; si
    no llegan (sin internet, el servidor falla o hay menos de 10), usa sus
    20 castigos de respaldo. 10 peticiones por minuto por IP.
- Al arrancar, la extensión crea (si falta) el índice
  `palabras_categoria_idioma_dificultad` sobre `palabras (categoria,
  idioma, dificultad)`, los campos que filtra `/juego/palabras`. No cambia
  ninguna palabra ni se ve en Directus; la base de datos lo mantiene sola.
  En el registro de Directus aparece `[juego] Índice ... listo`. Para ver
  si una consulta lo usa: `EXPLAIN SELECT id FROM palabras WHERE categoria
  = 'ANIME';` (con pocas palabras PostgreSQL puede preferir recorrerlas
  todas, y es normal). Se quita con `DROP INDEX
  palabras_categoria_idioma_dificultad;`.
- El flujo de Gemini se cambia con la variable de entorno
  `CHARADEANDO_GEMINI_FLOW` (id del flujo); por defecto
  `2d91a34a-b82c-4f97-9e2f-12154ba86323`.

Cuerpo de `/juego/palabras` (todo opcional salvo `n`):

```json
{ "n": 45, "categoria": "ANIMALES", "dificultad": "FACIL", "excluir": ["id1", "id2"] }
```

Para varias categorías a la vez, `categorias` en lugar de `categoria` (si
llegan las dos, manda `categorias`). Debe ser una lista de 1 a 20 textos de
hasta 50 caracteres; si no, responde 400:

```json
{ "n": 45, "categorias": ["ANIMALES", "PELICULAS", "DEPORTES"], "dificultad": "FACIL" }
```

Con 45 y tres categorías son 15 de cada una.

Respuesta de las dos rutas:
`{ "data": [{ "id": "...", "frase": "...", "categoria": "..." }] }`.

Los topes `MAX_CREATE`, `MAX_COUNT`, `MAX_EXCLUDE` y `MAX_CATEGORIES` de
`index.js` deben coincidir con `DirectusService.maxCreate`, `maxCount`,
`maxExclude` y `maxCategories` en la app.

Pruebas del reparto y de la validación de `categorias`:
`node --test server/tests/juego.test.mjs`.

## Códigos promocionales

Con un código válido la app desbloquea todo (Premium) o algunas categorías.
Son para regalar (familia, sorteos, probadores); Google Play no permite
venderlos por fuera de la tienda.

### Crear las colecciones (una sola vez)

En Directus, **Settings → Data Model → Create Collection**:

1. `codigos`, con la clave primaria `id` (número automático) y estos campos:

   | Campo | Tipo | Notas |
   |---|---|---|
   | `codigo` | String, único | El código, por ejemplo `FAMILIA2026`. Letras, números, `-` o `_`, de 3 a 40. No importan mayúsculas ni espacios. |
   | `desbloquea` | String | `TODO`, o códigos de categorías separados por comas: `ANIME, FUTBOLISTAS`. |
   | `usos_max` | Integer, puede ser vacío | Cuántas veces se puede canjear. Vacío es sin límite. |
   | `usos` | Integer, por defecto `0` | Lo suma la extensión. |
   | `vence` | Date (o Datetime), puede ser vacío | Una fecha vale hasta el final de ese día. Vacío es sin vencimiento. |
   | `activo` | Boolean, por defecto `true` | Apágalo si un código se filtra. |

2. `codigos_canjes` (un renglón por cada celular que canjea un código):
   **no hace falta crearla**. La extensión la crea sola en la base de datos
   la primera vez que alguien canjea, con `id`, `codigo`, `dispositivo` y
   `fecha`. Para verla en el panel de Directus, en Settings → Data Model
   aparece como tabla sin configurar y se puede "configurar" con un clic.

Ninguna de las dos debe ser pública: el rol Public no tiene permisos sobre
ellas (como `palabras`). Solo la extensión las lee y escribe.

### Crear un código

En **Content → codigos → Create Item**, por ejemplo:

- `FAMILIA2026`, `desbloquea` = `TODO`, `usos_max` = 20: Premium para 20
  celulares.
- `ANIME-AMIGOS`, `desbloquea` = `ANIME`, `vence` = `2026-12-31`, sin
  `usos_max`: Anime para todos los que lo canjeen hasta fin de año.

Para los personales, usa códigos largos y difíciles de adivinar
(`PREMIUM-7K2Q-9XWD`). Los fáciles (`CHARADEANDO`) solo con pocos usos.

### Cómo responde

`POST /juego/canjear` con `{ "codigo": "FAMILIA2026", "dispositivo": "..." }`
(el identificador al azar que guarda la app):

- 200: `{ "data": { "todo": true, "categorias": [] } }`, o con `todo`
  falso y la lista de categorías que abre.
- 404 `Código no válido.` (no existe, está apagado o no abre nada), 410
  `Este código ya venció.`, 409 `Este código ya se usó todas las veces que
  permite.` La app muestra el mensaje tal cual.

Si el mismo celular canjea otra vez el mismo código (por ejemplo, después
de reinstalar la app), responde lo mismo sin gastar otro uso, aunque ya no
queden.

### El celular y la reinstalación

El `dispositivo` que manda la app es el SHA-256 (en hexadecimal) de
`charadeando:` + el `ANDROID_ID` del celular. Desde Android 8 ese valor es
fijo por app y celular: no cambia al desinstalar y reinstalar la app (solo
al restablecer el celular de fábrica). No se manda el `ANDROID_ID` tal
cual. Si no se puede leer, la app usa un identificador al azar guardado en
el celular, que sí se pierde al desinstalar.

`POST /juego/mis-codigos` con `{ "dispositivo": "..." }` cruza
`codigos_canjes` con `codigos` y responde lo que abren todos los códigos
que ese celular ya canjeó, con el mismo formato de `/juego/canjear`:
`{ "data": { "todo": true, "categorias": [] } }` (o `todo` falso y las
categorías). No gasta usos, ignora los códigos con `activo` falso y vale
aunque el código ya haya vencido: lo canjeado es de por vida. Sin canjes
responde `todo` falso y la lista vacía.

La app la llama sola al abrir si no tiene nada desbloqueado guardado (por
ejemplo, recién reinstalada); sin internet no pasa nada y lo intenta la
próxima vez. También con "Restaurar mis códigos" en la hoja de compra.

Pruebas: `node --test server/tests/juego.test.mjs`.

## Compra en Google Play

La app vende productos de pago único ("productos integrados en la
aplicación"): Premium, que abre todo, y cada categoría de pago suelta. Los
ids tienen que ser exactamente estos:

| Producto | Id |
|---|---|
| Todas las categorías (Todo Charadeando) | `charadeando_premium` |
| Objetos | `categoria_objetos` |
| Profesiones | `categoria_profesiones` |
| Acciones | `categoria_acciones` |
| Personajes | `categoria_personajes` |
| Superhéroes | `categoria_superheroes` |
| Dibujos animados | `categoria_dibujos_animados` |
| Anime | `categoria_anime` |
| Videojuegos | `categoria_videojuegos` |
| Música y canciones | `categoria_musica` |
| Celebridades | `categoria_celebridades` |
| Personajes históricos | `categoria_personajes_historicos` |
| Dichos y refranes | `categoria_dichos_refranes` |
| Marcas | `categoria_marcas` |
| Futbolistas | `categoria_futbolistas` |
| Deportistas | `categoria_deportistas` |
| Navidad | `categoria_navidad` |

Son de pago todas menos las dos primeras de cada sección (Animales y
Comida; Películas y Series y novelas; Geografía y Lugares; Deportes y
Equipos de fútbol; Vacaciones y Halloween) y Libre. Mientras Play no da los
precios (productos sin crear o celular sin Play), la app muestra $3.900 por
categoría y $14.900 Todas las categorías (`fallbackCategoryPrice` y
`fallbackAllPrice` en `lib/widgets/premium_sheet.dart`): conviene poner esos
mismos precios en Play Console, o cambiar los de la app.

Si se agrega otra categoría (después de las dos primeras de su sección), su producto es
`categoria_` y su código en minúsculas, y quien ya tenga Premium la recibe
sin pagar más.

1. Play Console → **Configuración → Perfil de pagos**: tener la cuenta de
   comerciante.
2. Subir a **Prueba interna** una versión que ya tenga `in_app_purchase`
   (Play no deja crear productos antes).
3. **Monetizar → Productos → Productos integrados en la aplicación →
   Crear producto**: uno por cada id de la tabla, con nombre, descripción y
   precio; activarlos.
4. Para probar sin que cobre: **Configuración → Prueba de licencias**, con
   los correos de los probadores, e instalar la app desde la prueba
   interna (instalada desde Android Studio no puede comprar).
5. Códigos de Google Play: **Monetizar → Promociones**, para
   `charadeando_premium` o para una categoría. Se canjean en Play Store y la app los recibe como
   una compra.

## Instalar o actualizar la extensión

Todo en la terminal del servidor.

1. Buscar la carpeta de extensiones de Directus:

   ```sh
   sudo docker inspect $(sudo docker ps -q --filter "name=directus") \
     --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
   ```

   Usa la ruta de la izquierda de la línea que termina en
   `/directus/extensions`. Si no aparece esa línea, en Coolify abre
   **Edit Compose File** y agrega en los `volumes` del servicio `directus`:

   ```yaml
   - 'directus-extensions:/directus/extensions'
   ```

   Guarda, toca **Restart current version** y repite este paso.

2. Descargar los archivos desde GitHub (la terminal web de Webdock corta
   los textos largos al pegarlos, así que no conviene copiarlos a mano).
   Cambia `COMMIT` por el commit que quieras instalar:

   ```sh
   EXT=/ruta/del/paso/1/charadeando-juego
   COMMIT=develop
   BASE=https://raw.githubusercontent.com/juancamilosal/charadeando_app/$COMMIT/server/directus-extensions/charadeando-juego
   sudo mkdir -p $EXT
   sudo curl -fsSL -o $EXT/index.js $BASE/index.js
   sudo curl -fsSL -o $EXT/package.json $BASE/package.json
   ```

3. Revisar que se descargaron completos: `sudo sha256sum $EXT/index.js` y
   comparar con `sha256sum` del archivo en el repositorio.

4. En Coolify, toca **Restart current version** y revisa que cargó:

   ```sh
   sudo docker logs $(sudo docker ps -q --filter "name=directus") 2>&1 | grep -i extension
   ```

5. Probar la ruta:

   ```sh
   curl -s -X POST https://charadeando-api.valkiriacode.com/juego/palabras \
     -H 'Content-Type: application/json' -d '{"n":3}'
   ```

   Debe devolver tres palabras. Y esta otra debe dar error 403, porque la
   colección no es pública:

   ```sh
   curl -s -o /dev/null -w '%{http_code}\n' \
     https://charadeando-api.valkiriacode.com/items/palabras
   ```

## Gemini

La extensión llama al flujo de Directus que habla con Gemini con este
cuerpo, igual que juego-palabras: `systemInstruction` (con `role: system`)
y `contents`. Lee el texto de Gemini en `respuesta` (o `texto`, `text`,
`message`), por ejemplo:

```json
{ "respuesta": "[\"Astronauta\", \"Bailar tango\"]" }
```

## Pendiente

- La URL pública del flujo (`/flows/trigger/...`) sigue aceptando cualquier
  texto. La app ya no la usa, así que se puede proteger, por ejemplo
  pidiendo un token en el flujo o pasándole a la extensión un id de flujo
  que no sea público.

- Firebase App Check (Play Integrity / App Attest) para que solo la app
  publicada pueda llamar a la ruta.

## Palabras

Las palabras del juego no están en este repositorio, que es público. Se
guardan en el repositorio privado `juancamilosal/palabras-juego`, junto con el
validador y la instrucción de la rutina que crea tandas nuevas.

La colección `palabras` tiene el campo `dificultad` (`FACIL`, `NORMAL`,
`DIFICIL`) además de `frase` y `categoria`.

### Códigos de las categorías

Cada categoría de la app busca sus palabras en `palabras` con su código en
el campo `categoria`. Todas tienen palabras. Una categoría nueva sin
palabras se marca con `available: false` en `lib/models/category.dart` y sale
con "Pronto" en la app hasta que se carguen.

| Categoría | Código |
|---|---|
| Libre | `LIBRE` |
| Vacaciones (del 15 de junio al 31 de julio) | `VACACIONES` |
| Halloween (del 1 al 31 de octubre) | `HALLOWEEN` |
| Navidad (del 1 de diciembre al 6 de enero) | `NAVIDAD` |
| Películas | `PELICULAS` |
| Series y novelas | `SERIES_NOVELAS` |
| Personajes | `PERSONAJES` |
| Superhéroes | `SUPERHEROES` |
| Dibujos animados | `DIBUJOS_ANIMADOS` |
| Anime | `ANIME` |
| Videojuegos | `VIDEOJUEGOS` |
| Música y canciones | `MUSICA` |
| Celebridades | `CELEBRIDADES` |
| Geografía | `GEOGRAFIA` |
| Lugares | `LUGARES` |
| Personajes históricos | `PERSONAJES_HISTORICOS` |
| Dichos y refranes | `DICHOS_REFRANES` |
| Marcas | `MARCAS` |
| Deportes | `DEPORTES` |
| Equipos de fútbol | `EQUIPOS_FUTBOL` |
| Futbolistas | `FUTBOLISTAS` |
| Deportistas | `DEPORTISTAS` |
| Animales | `ANIMALES` |
| Comida | `COMIDA` |
| Objetos | `OBJETOS` |
| Profesiones | `PROFESIONES` |
| Acciones | `ACCIONES` |

### Una persona o personaje va en una sola categoría

Para que la misma palabra no salga dos veces en una partida con categorías
combinadas, cada persona o personaje se carga en una sola categoría:

- Superhéroes (Spider-Man, Batman): solo en `SUPERHEROES`.
- Dibujos animados (Bob Esponja, Peppa Pig): solo en `DIBUJOS_ANIMADOS`.
- Anime (Goku, Naruto, Pikachu) y sus series (Dragon Ball, One Piece):
  solo en `ANIME`, aunque también sean dibujos animados o salgan en
  videojuegos.
- `PERSONAJES` queda para los de películas, libros y videojuegos (Harry
  Potter, Shrek, Mario Bros).
- Personas reales que hicieron historia (Simón Bolívar, Einstein): solo en
  `PERSONAJES_HISTORICOS`. Los artistas actuales van en `CELEBRIDADES` o, si
  son de la música, en `MUSICA`.
- Futbolistas (Messi, Cristiano Ronaldo, James Rodríguez): solo en
  `FUTBOLISTAS`. Los de los demás deportes (Michael Jordan, Serena
  Williams, Usain Bolt, Egan Bernal): solo en `DEPORTISTAS`.
  Ninguno de los dos va en `CELEBRIDADES`, y los clubes siguen en
  `EQUIPOS_FUTBOL`.

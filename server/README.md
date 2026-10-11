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
    dificultad, siempre de la misma categoría. 10 peticiones por minuto
    por IP.
- El flujo de Gemini se cambia con la variable de entorno
  `CHARADEANDO_GEMINI_FLOW` (id del flujo); por defecto
  `2d91a34a-b82c-4f97-9e2f-12154ba86323`.

Cuerpo de `/juego/palabras` (todo opcional salvo `n`):

```json
{ "n": 45, "categoria": "ANIMALES", "dificultad": "FACIL", "excluir": ["id1", "id2"] }
```

Respuesta de las dos rutas:
`{ "data": [{ "id": "...", "frase": "...", "categoria": "..." }] }`.

Los topes `MAX_CREATE`, `MAX_COUNT` y `MAX_EXCLUDE` de `index.js` deben
coincidir con `DirectusService.maxCreate`, `maxCount` y `maxExclude` en la
app.

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
   curl -s -X POST https://charadeando.vps.webdock.cloud/juego/palabras \
     -H 'Content-Type: application/json' -d '{"n":3}'
   ```

   Debe devolver tres palabras. Y esta otra debe dar error 403, porque la
   colección no es pública:

   ```sh
   curl -s -o /dev/null -w '%{http_code}\n' \
     https://charadeando.vps.webdock.cloud/items/palabras
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

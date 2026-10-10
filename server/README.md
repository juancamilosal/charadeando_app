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
  - `POST /juego/palabras`: solo lee; entrega palabras al azar, con un
    máximo de 450 por petición, excluye hasta 500 ids que la app ya jugó y
    completa con repetidas solo si no alcanzan. 10 peticiones por minuto
    por IP.
- El flujo de Gemini se cambia con la variable de entorno
  `CHARADEANDO_GEMINI_FLOW` (id del flujo); por defecto
  `2d91a34a-b82c-4f97-9e2f-12154ba86323`.

Cuerpo de `/juego/palabras` (todo opcional salvo `n`):

```json
{ "n": 45, "categoria": "ANIMAL", "excluir": ["id1", "id2"] }
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

## Palabras iniciales

`palabras/iniciales.json` tiene 1.000 palabras revisadas para empezar, cada
una con `frase`, `categoria` y `dificultad`:

```json
{ "frase": "Perro", "categoria": "ANIMALES", "dificultad": "FACIL" }
```

- Categorías: `ANIMALES`, `PAISES`, `PELICULAS`, `CELEBRIDADES`, `MARCAS`,
  `DEPORTES`, `EQUIPOS_FUTBOL`, `OBJETOS`, `COMIDA`, `PROFESIONES`,
  `ACCIONES` y `LUGARES`.
- Dificultad: `FACIL` (cosas comunes y fáciles de describir o imitar),
  `NORMAL` (menos comunes o de varias palabras) y `DIFICIL` (poco conocidas,
  abstractas o situaciones). En todas hay frases de 1 a 4 palabras.
- No hay frases repetidas ni variantes de una misma idea dentro de cada
  categoría.

`palabras/libre_AAAA-MM-DD.json` son tandas de 200 elementos con la
categoría `LIBRE`, una por fecha. Se importan igual.

Regla para la categoría `LIBRE`: no son palabras sueltas sino **frases** de
1 a 4 palabras que describen una acción, situación o emoción para actuar,
por ejemplo "Caminamos muy rápido", "Me duele la cabeza" o "Bailando bajo la
lluvia". Lo importante es que no sean repetitivas: ninguna frase es variante
de otra y ningún verbo o palabra importante aparece más de 3 veces.

- `FACIL`: una acción o situación concreta, fácil de actuar.
- `NORMAL`: una escena con más detalle o con dos ideas a la vez.
- `DIFICIL`: emociones, estados o ideas abstractas, más difíciles de
  mostrar.

Para importarlas en Directus:

1. En **Configuración → Modelo de datos → palabras**, crear el campo
   `dificultad` (tipo texto, interfaz desplegable con `FACIL`, `NORMAL` y
   `DIFICIL`).
2. En **Contenido → palabras**, abrir el panel lateral **Importar / Exportar**
   e importar el archivo. El archivo no trae `id`: Directus lo crea.

Para crear una tanda nueva de `LIBRE`, se guarda como
`palabras/libre_AAAA-MM-DD.json` y se valida contra todas las anteriores:

```sh
python3 server/palabras/validar_libre.py server/palabras/libre_AAAA-MM-DD.json
```

El script revisa el formato, que las frases tengan de 1 a 4 palabras, que
ninguna repita ni sea variante de otra tanda y que ningún verbo o palabra
importante aparezca más de 3 veces. Si encuentra algo, lo lista y termina
con error.

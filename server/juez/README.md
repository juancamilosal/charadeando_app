# charadeando-juez

Modo **"Celular juez"** de Charadeando: mientras una persona tiene el
celular en la frente, otra hace de juez desde **su** celular, sin instalar la
app. Escanea un QR, se abre una página con la palabra, el tiempo y el
marcador, y dos botones: "✓ Acierto" y "→ Pasar". Cada toque avanza la
palabra en el celular de la frente.

Es un Cloudflare Worker con un **Durable Object por sala** (almacenamiento
SQLite, que sirve en el plan gratis) y la API de **WebSocket Hibernation**
(mientras nadie manda nada, la sala no gasta tiempo de ejecución).

## Rutas (en `valkiriacode.com`)

| Ruta | Qué hace |
|---|---|
| `POST /juez/api/salas` | Crea una sala: `{ "codigo": "K7M2PQ", "tokenAnfitrion": "…" }` (201). Código de 6 letras sin las que se confunden (sin 0/O/1/I/L). El token (32 bytes al azar) solo lo tiene el celular de la frente; la sala guarda su huella SHA-256, no el token. Freno de 10 salas por minuto por IP. |
| `GET /juez/<CODIGO>` | La página del juez (HTML, CSS, JS y fuentes en un solo archivo, sin pedir nada a otros servidores). |
| `GET /juez` | Página para escribir el código si no se puede escanear el QR. |
| `GET /juez/api/salas/<CODIGO>/ws?rol=anfitrion&token=…` | WebSocket de la app. |
| `GET /juez/api/salas/<CODIGO>/ws?rol=juez` | WebSocket de la página del juez. |

## Mensajes (JSON)

- **Anfitrión → sala:** `{ "tipo": "estado", "palabra", "categoria", "segundos", "equipo", "puntos", "estado": "esperando" | "jugando" | "fin_turno" | "fin_partida", "aciertos"?, "pasadas"? }`.
  La sala guarda el último y se lo manda a cada juez que se conecta.
- **Juez → sala → anfitrión:** `{ "tipo": "accion", "accion": "acierto" | "pasar", "id" }`.
  El `id` (único) evita que una acción reenviada cuente dos veces.
- **Sala → anfitrión:** `{ "tipo": "jueces", "cantidad" }` cada vez que entra o sale un juez.
- **Sala → cualquiera:** `{ "tipo": "bienvenida", "rol" }` al conectarse, `{ "tipo": "error", "codigo" }` (`mensaje_invalido`, `sala_no_existe`, `token_invalido`, `sala_llena`, `otro_anfitrion`, `sala_cerrada`) y `{ "tipo": "aviso", "codigo": "sin_anfitrion" }`.

## Reglas

- Solo el anfitrión con su token envía `estado`; el juez solo `acierto` o `pasar`.
- Un anfitrión por sala (si el celular se reconecta, el anterior se cierra) y máximo **2 jueces**.
- Se ignoran más de **4 acciones por segundo** de cada juez (20 estados por segundo del anfitrión).
- Cada mensaje se valida: texto, máximo 2 KB, JSON, solo los campos conocidos y con su tipo y largo.
- La sala se **borra sola tras 3 horas sin actividad** (alarma del Durable Object).
- No se guarda ningún dato personal: solo la huella del token, el último estado del turno (palabra, categoría, tiempo, nombre del equipo y puntos), los ids de las últimas acciones y las horas de creación y de última actividad.

Los WebSockets rechazados se aceptan y se cierran enseguida con su motivo
(`4401` token, `4404` no existe, `4409` llena, `4400` rol, `4000`
reemplazado, `4410` cerrada), para que la página pueda decir por qué.

## Archivos

- `src/index.js`: el Worker (rutas) y el Durable Object `Sala`.
- `src/sala.js`: la lógica de la sala, sin depender de Cloudflare (se prueba con node).
- `src/logica.js`: códigos, tokens, validación de mensajes y límites.
- `src/pagina.js`: la página del juez y la de inicio.
- `src/fuentes.js`: Fredoka y Nunito (OFL) en WOFF2, solo con las letras del español. Se regenera con `pip install fonttools brotli && python3 scripts/fuentes.py`.

## Desarrollo

```sh
cd server/juez
npm ci
npm test            # pruebas con node --test
npx wrangler dev    # en http://localhost:8787/juez
```

Con `wrangler dev`: `curl -X POST localhost:8787/juez/api/salas` crea una
sala; abre `localhost:8787/juez/<CODIGO>` en dos navegadores (máximo 2
jueces) y conecta la app con
`flutter run --dart-define=JUEZ_URL=http://<IP-del-computador>:8787/juez`
(el celular y el computador en la misma red; `wrangler dev --ip 0.0.0.0`).

## Publicar

Se publica con **Workers Builds** desde la rama `main`, carpeta raíz
`/server/juez` (como el Worker del formulario de contacto de la web). El
comando de build es `npx wrangler deploy` (lo pone Cloudflare). La ruta y el
Durable Object están en `wrangler.toml`.

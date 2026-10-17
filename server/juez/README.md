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
| `GET /juez/api/salud` | `{ "ok": true, "servicio": "charadeando-juez" }`: la app lo pregunta para saber si mostrar la opción. |
| `GET /juez/<CODIGO>` | La página del juez (HTML, CSS, JS y fuentes en un solo archivo, sin pedir nada a otros servidores). |
| `GET /juez` | Página para escribir el código si no se puede escanear el QR. |
| `GET /juez/api/salas/<CODIGO>/ws?rol=anfitrion&token=…` | WebSocket de la app. |
| `GET /juez/api/salas/<CODIGO>/ws?rol=juez` | WebSocket de la página del juez. |

## Mensajes (JSON)

- **Anfitrión → sala:** `{ "tipo": "estado", "palabra", "categoria", "segundos", "equipo", "puntos", "estado": "esperando" | "jugando" | "fin_turno" | "fin_partida", "aciertos"?, "pasadas"?, "palabras"?, "editable"? }`.
  La sala guarda el último y se lo manda a cada juez que se conecta. Al
  final del turno, `palabras` es la lista del turno en orden
  (`[{ "texto", "acierto": true|false, "puntos"? }]`, hasta 100) y
  `editable` dice si el juez todavía puede corregirla (mientras la app está
  en el resultado de ese turno). Hasta 16 KB por mensaje.
- **Juez → sala → anfitrión:** `{ "tipo": "accion", "accion": "acierto" | "pasar", "id" }`.
  El `id` (único) evita que una acción reenviada cuente dos veces.
- **Juez → sala → anfitrión, al final del turno:** `{ "tipo": "accion", "accion": "corregir", "id", "indice", "acierto" }`
  cambia una palabra del resumen (se marcó mal). La sala solo la pasa si el
  último estado tiene `editable: true` y esa palabra existe; si no, le
  responde al juez `{ "tipo": "error", "codigo": "no_editable" }`. La app la
  aplica y manda el resumen nuevo, así el juez ve el cambio confirmado.
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

## Publicar en Cloudflare

Se publica con **Workers Builds**, carpeta raíz `/server/juez`.
**Por ahora desde la rama `develop`**: `main` queda para cuando se publique
la app en Play Store. Ese día se cambia la rama de producción a `main` en
**Workers & Pages → charadeando-juez → Settings → Builds**.

### Configuración (una sola vez)

1. **Crear el Worker desde el repositorio.** En el panel de Cloudflare:
   **Workers & Pages → Create → Import a repository** y elige
   `juancamilosal/charadeando_app` (si no aparece, conecta GitHub y dale
   acceso a ese repositorio).
2. **Datos del proyecto:**
   - **Project name:** `charadeando-juez` (igual que `name` en `wrangler.toml`).
   - **Production branch:** `develop`.
   - **Root directory:** `/server/juez`.
   - **Build command:** vacío.
   - **Deploy command:** `npx wrangler deploy`.
3. **Save and Deploy.** La primera publicación crea las rutas
   `valkiriacode.com/juez` y `valkiriacode.com/juez/*` y el Durable Object
   `Sala` (migración `v1`, con SQLite, que sirve en el plan gratis). Todo
   eso sale de `wrangler.toml`: no hay que crearlo a mano.
4. **Revisar la zona `valkiriacode.com`:** debe estar en la misma cuenta de
   Cloudflare y su registro DNS con la nube naranja (proxied); si no, la
   ruta no funciona. Si la web ya tiene una ruta como `valkiriacode.com/*`,
   la de `/juez` es más específica y gana.
5. **Comprobar:**
   ```sh
   curl https://valkiriacode.com/juez/api/salud
   # {"ok":true,"servicio":"charadeando-juez"}
   curl -X POST https://valkiriacode.com/juez/api/salas
   # {"codigo":"K7M2PQ","tokenAnfitrion":"…"}
   ```
   y abrir `https://valkiriacode.com/juez` (debe decir "Celular juez").
6. Desde ahí, cada `git push` a `develop` que cambie `server/juez` vuelve a
   publicar el Worker. En **Settings → Builds → Build watch paths** se
   puede poner `server/juez/*` para que no se publique con cambios de la
   app.

### Al lanzar en Play Store

En **Workers & Pages → charadeando-juez → Settings → Builds**, cambiar
**Production branch** de `develop` a `main` y guardar. La próxima
publicación sale de `main`.

### Si el Worker no está publicado

La app pregunta primero a `GET /juez/api/salud`. Si no responde como el
Worker (por ejemplo, la web devuelve 404), la sección "Celular juez" no se
muestra en la configuración; y si falla al crear la sala, dice que el
celular juez no está disponible por ahora y se sigue jugando inclinando el
celular.

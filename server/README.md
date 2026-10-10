# Servidor de Charadeando

Directus 11 con PostgreSQL y Redis, desplegado con Coolify en el VPS.

## Seguridad de las palabras

- La colección `palabras` (campos `id`, `frase`, `categoria`) **no es
  pública**: el rol Public no tiene ningún permiso sobre ella. Solo se edita
  desde el panel de Directus.
- La app pide las palabras a una ruta propia, `POST /juego/palabras`
  (extensión `directus-extensions/charadeando-juego`), que:
  - solo lee;
  - entrega palabras al azar, con un máximo de 450 por petición;
  - excluye hasta 500 ids que la app ya jugó, y completa con repetidas solo
    si no alcanzan;
  - permite 10 peticiones por minuto por IP (responde 429 al pasarse).

Cuerpo de la petición (todo opcional salvo `n`):

```json
{ "n": 45, "categoria": "ANIMAL", "excluir": ["id1", "id2"] }
```

Respuesta: `{ "data": [{ "id": "...", "frase": "...", "categoria": "..." }] }`.

Los topes `MAX_COUNT` y `MAX_EXCLUDE` de `index.js` deben coincidir con
`DirectusService.maxCount` y `DirectusService.maxExclude` en la app.

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

2. Crear la carpeta de la extensión (cambia la ruta por la del paso 1):

   ```sh
   EXT=/ruta/del/paso/1/charadeando-juego
   sudo mkdir -p $EXT
   ```

3. Copiar los dos archivos de `server/directus-extensions/charadeando-juego`
   de este repositorio: abre cada uno en GitHub, copia su contenido y
   pégalo con:

   ```sh
   sudo nano $EXT/package.json
   sudo nano $EXT/index.js
   ```

   (En nano: pegar con clic derecho o Ctrl+Shift+V, guardar con Ctrl+O y
   Enter, salir con Ctrl+X.)

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

La app pide las palabras primero al flujo de Directus
`POST /flows/trigger/2d91a34a-b82c-4f97-9e2f-12154ba86323`, con el cuerpo
de Gemini (`systemInstruction` y `contents`). La app acepta como respuesta
la lista de textos directa, envuelta en `data`, o la respuesta cruda de
Gemini (`candidates[].content.parts[].text`).

## Pendiente

- Que el flujo de Gemini arme las instrucciones en el servidor y la app solo
  mande la cantidad. Hoy el flujo acepta cualquier texto, así que alguien
  podría usarlo para hacerle cualquier pregunta a Gemini con tu clave.
- Límite de peticiones para el flujo de Gemini.

- Firebase App Check (Play Integrity / App Attest) para que solo la app
  publicada pueda llamar a la ruta.

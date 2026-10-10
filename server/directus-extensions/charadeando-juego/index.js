// Ruta pública del juego: POST /juego/palabras
//
// El rol Public de Directus no tiene permisos sobre la colección, así que
// esta es la única forma de leer las palabras sin iniciar sesión. Solo lee,
// entrega un subconjunto al azar con un tope fijo y limita las peticiones
// por IP para que no se pueda copiar la tabla de golpe.

const COLLECTION = 'palabras';

/// Tope de palabras por petición: 6 grupos × 50 palabras más el margen
/// para las que se pasan. Debe coincidir con DirectusService.maxCount.
const MAX_COUNT = 450;

/// Ids que la app puede pedir excluir (las últimas palabras que jugó).
const MAX_EXCLUDE = 500;

/// Peticiones permitidas por IP en cada ventana. Una partida hace una al
/// empezar y, si se acaban las palabras, alguna más entre turnos.
const RATE_POINTS = 10;
const RATE_WINDOW_MS = 60 * 1000;

const hits = new Map();

function allowed(ip) {
  const now = Date.now();
  const entry = hits.get(ip);
  if (!entry || now - entry.start > RATE_WINDOW_MS) {
    hits.set(ip, { start: now, count: 1 });
    return true;
  }
  entry.count++;
  return entry.count <= RATE_POINTS;
}

// Limpia las IPs viejas para que el mapa no crezca sin fin.
setInterval(() => {
  const now = Date.now();
  for (const [ip, entry] of hits) {
    if (now - entry.start > RATE_WINDOW_MS) hits.delete(ip);
  }
}, RATE_WINDOW_MS).unref();

function badRequest(res, message) {
  return res.status(400).json({ errors: [{ message }] });
}

export default {
  id: 'juego',
  handler: (router, { database, logger }) => {
    router.post('/palabras', async (req, res) => {
      const ip = req.accountability?.ip ?? req.ip ?? 'desconocida';
      if (!allowed(ip)) {
        return res
          .status(429)
          .json({ errors: [{ message: 'Demasiadas peticiones. Espera un minuto.' }] });
      }

      const body = req.body ?? {};
      const n = Number(body.n ?? 20);
      if (!Number.isInteger(n) || n < 1 || n > MAX_COUNT) {
        return badRequest(res, `"n" debe ser un número entre 1 y ${MAX_COUNT}.`);
      }

      const categoria = body.categoria ?? null;
      if (categoria !== null && (typeof categoria !== 'string' || categoria.length > 50)) {
        return badRequest(res, '"categoria" no es válida.');
      }

      const excluir = body.excluir ?? [];
      if (
        !Array.isArray(excluir) ||
        excluir.length > MAX_EXCLUDE ||
        !excluir.every((id) => (typeof id === 'string' && id.length <= 64) || Number.isInteger(id))
      ) {
        return badRequest(res, `"excluir" debe ser una lista de hasta ${MAX_EXCLUDE} ids.`);
      }

      try {
        const query = () => {
          const q = database(COLLECTION).select('id', 'frase', 'categoria').orderByRaw('random()');
          if (categoria) q.where('categoria', categoria);
          return q;
        };

        // Primero las que la app no ha jugado; si no alcanzan, se completa
        // con palabras ya jugadas para que la partida no quede corta.
        const fresh = await query().whereNotIn('id', excluir).limit(n);
        let data = fresh;
        if (fresh.length < n) {
          const used = fresh.map((w) => w.id);
          const repeated = await query().whereNotIn('id', used).limit(n - fresh.length);
          data = [...fresh, ...repeated];
        }
        return res.json({ data });
      } catch (error) {
        logger.error(error, '[juego] No se pudieron leer las palabras');
        return res.status(500).json({ errors: [{ message: 'No se pudieron leer las palabras.' }] });
      }
    });
  },
};

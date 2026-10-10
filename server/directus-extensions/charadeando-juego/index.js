// Rutas públicas del juego:
//
//   POST /juego/crear     Le pide palabras nuevas a Gemini (por el flujo de
//                         Directus), las guarda en la colección con la
//                         categoría LIBRE y las devuelve.
//   POST /juego/palabras  Entrega palabras al azar de la colección.
//
// El rol Public de Directus no tiene permisos sobre la colección, así que
// estas rutas son la única forma de leer o crear palabras sin iniciar
// sesión. Las instrucciones para Gemini están fijas aquí: la app solo manda
// la cantidad. Ambas rutas tienen tope y límite de peticiones por IP.

const COLLECTION = 'palabras';

/// Categoría de las palabras que crea Gemini.
const GEMINI_CATEGORY = 'LIBRE';

/// Flujo de Directus que llama a Gemini. Se puede cambiar con la variable
/// de entorno CHARADEANDO_GEMINI_FLOW.
const DEFAULT_GEMINI_FLOW = '2d91a34a-b82c-4f97-9e2f-12154ba86323';

/// Gemini puede tardar con listas largas.
const GEMINI_TIMEOUT_MS = 60 * 1000;

/// Gemini tarda más mientras más palabras escribe, así que las listas
/// largas se piden en varios pedidos en paralelo de este tamaño.
const GEMINI_CHUNK = 25;

/// Gemini no recuerda los pedidos anteriores: si siempre se le pide lo
/// mismo, tiende a dar las mismas palabras. Cada pedido arranca de un tema
/// elegido al azar, distinto para cada pedido en paralelo.
export const GEMINI_THEMES = [
  'objetos de la casa',
  'comidas y bebidas',
  'animales',
  'oficios y profesiones',
  'deportes',
  'lugares y ciudades',
  'personajes de cuentos y películas',
  'medios de transporte',
  'instrumentos musicales',
  'ropa y accesorios',
  'fiestas y celebraciones',
  'naturaleza y clima',
  'acciones de todos los días',
  'juegos y juguetes',
  'cuerpo humano',
  'tecnología',
  'escuela y oficina',
  'vacaciones y viajes',
  'cine y televisión',
  'situaciones graciosas',
];

/// Cuántas palabras de la colección se le muestran a Gemini para que no
/// las repita. Una muestra al azar, para no alargar demasiado el pedido.
const AVOID_SAMPLE = 120;

/// Se le piden a Gemini algunas palabras de más, porque se descartan las
/// que ya existen o se parecen a otras.
const GEMINI_EXTRA = 0.4;

const GEMINI_INSTRUCTIONS =
  'Responde SIEMPRE y ÚNICAMENTE con un array JSON de strings, sin ' +
  'explicaciones, sin markdown y sin texto fuera del array. Cada elemento ' +
  'debe ser una palabra o frase coherente (sustantivo, objeto, lugar, ' +
  'personaje o actividad) de entre 1 y 4 palabras, apta para que alguien la ' +
  'describa y otra persona la adivine en un juego. Elige palabras variadas ' +
  'y poco obvias, de temas distintos entre sí. No repitas palabras dentro ' +
  'de la lista ni des variantes de una misma idea (por ejemplo, no ' +
  '"Astronauta" y "Astronauta flotando"). Si te doy una lista de palabras a ' +
  'evitar, no uses ninguna de ellas ni variantes. Ejemplo de respuesta ' +
  'válida: ["Peras", "Silla de caballo", "Una casa embrujada"]';

/// Tope de palabras que se crean por petición. Debe coincidir con
/// GameConfig.maxAutoWords.
const MAX_CREATE = 100;

/// Tope de palabras por petición a la colección. Debe coincidir con
/// DirectusService.maxCount.
const MAX_COUNT = 450;

/// Ids que la app puede pedir excluir (las últimas palabras que jugó).
const MAX_EXCLUDE = 500;

const RATE_WINDOW_MS = 60 * 1000;

/// Peticiones por IP en cada ventana. Crear cuesta una llamada a Gemini,
/// así que tiene un límite más bajo; una partida hace una de cada una como
/// mucho.
const limits = {
  crear: { points: 5, hits: new Map() },
  palabras: { points: 10, hits: new Map() },
};

function allowed(route, ip) {
  const { points, hits } = limits[route];
  const now = Date.now();
  const entry = hits.get(ip);
  if (!entry || now - entry.start > RATE_WINDOW_MS) {
    hits.set(ip, { start: now, count: 1 });
    return true;
  }
  entry.count++;
  return entry.count <= points;
}

// Limpia las IPs viejas para que los mapas no crezcan sin fin.
setInterval(() => {
  const now = Date.now();
  for (const { hits } of Object.values(limits)) {
    for (const [ip, entry] of hits) {
      if (now - entry.start > RATE_WINDOW_MS) hits.delete(ip);
    }
  }
}, RATE_WINDOW_MS).unref();

function error(res, status, message) {
  return res.status(status).json({ errors: [{ message }] });
}

function clientIp(req) {
  return req.accountability?.ip ?? req.ip ?? 'desconocida';
}

/// Normaliza para comparar sin importar mayúsculas ni espacios.
function key(text) {
  return text.trim().replace(/\s+/g, ' ').toLowerCase();
}

/// Palabras que no cuentan para saber si dos frases son la misma idea.
const STOP_WORDS = new Set([
  'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'de', 'del', 'al',
  'a', 'y', 'e', 'o', 'u', 'en', 'con', 'sin', 'por', 'para', 'mi', 'tu',
  'su', 'se', 'que',
]);

/// Palabras importantes de una frase, sin tildes ni artículos:
/// "El Astronauta flotando" → {astronauta, flotando}.
export function significantWords(text) {
  const plain = text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9ñ ]/g, ' ');
  return new Set(plain.split(/\s+/).filter((w) => w && !STOP_WORDS.has(w)));
}

/// Recuerda frases para reconocer las variantes de una misma idea: dos
/// frases se parecen si las palabras importantes de una están todas en la
/// otra ("Astronauta" y "Astronauta flotando").
export class SimilarWords {
  constructor(texts = []) {
    this.byWord = new Map();
    for (const text of texts) this.add(text);
  }

  add(text) {
    const words = significantWords(text);
    if (words.size === 0) return;
    for (const w of words) {
      if (!this.byWord.has(w)) this.byWord.set(w, []);
      this.byWord.get(w).push(words);
    }
  }

  has(text) {
    const words = significantWords(text);
    if (words.size === 0) return false;
    for (const w of words) {
      for (const other of this.byWord.get(w) ?? []) {
        const small = other.size <= words.size ? other : words;
        const big = small === other ? words : other;
        if ([...small].every((x) => big.has(x))) return true;
      }
    }
    return false;
  }
}

/// [count] elementos distintos de [items], al azar.
export function sample(items, count) {
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy.slice(0, count);
}

/// Pedido para Gemini: cuántas palabras, de qué tema y cuáles evitar.
export function buildPrompt(size, theme, avoid) {
  let prompt =
    `Genera exactamente ${size} palabras o frases para el juego. ` +
    `Tema principal: ${theme}, pero incluye también otras ideas variadas.`;
  if (avoid.length > 0) {
    prompt += ` Evita estas palabras y sus variantes: ${avoid.join(', ')}.`;
  }
  return prompt;
}

/// Saca la lista de palabras de la respuesta del flujo, que trae el texto
/// de Gemini en `respuesta` (o `texto`, `text`, `message`).
export function parseGeminiWords(body) {
  let value = body;
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    value = value.respuesta ?? value.texto ?? value.text ?? value.message ?? value.data;
  }
  if (typeof value === 'string') {
    const start = value.indexOf('[');
    const end = value.lastIndexOf(']');
    if (start === -1 || end <= start) return [];
    try {
      value = JSON.parse(value.slice(start, end + 1));
    } catch {
      return [];
    }
  }
  if (!Array.isArray(value)) return [];
  const seen = new Set();
  const words = [];
  for (const item of value) {
    if (typeof item !== 'string') continue;
    const text = item.trim().replace(/\s+/g, ' ');
    if (!text || text.length > 60 || seen.has(key(text))) continue;
    seen.add(key(text));
    words.push(text);
  }
  return words;
}

export default {
  id: 'juego',
  handler: (router, { database, logger, services, getSchema, env }) => {
    const flowId = env?.CHARADEANDO_GEMINI_FLOW || DEFAULT_GEMINI_FLOW;
    const flowUrl = `http://127.0.0.1:${env?.PORT || 8055}/flows/trigger/${flowId}`;

    async function askGeminiOnce(prompt) {
      const response = await fetch(flowUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: AbortSignal.timeout(GEMINI_TIMEOUT_MS),
        body: JSON.stringify({
          systemInstruction: { role: 'system', parts: [{ text: GEMINI_INSTRUCTIONS }] },
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
        }),
      });
      const text = await response.text();
      if (!response.ok) {
        throw new Error(`El flujo de Gemini respondió ${response.status}: ${text}`);
      }
      let body;
      try {
        body = JSON.parse(text);
      } catch {
        body = text;
      }
      return parseGeminiWords(body);
    }

    /// Pide [n] palabras nuevas. Hasta GEMINI_CHUNK va en un solo pedido;
    /// más de eso se reparte en pedidos en paralelo, cada uno con un tema
    /// distinto. Todos llevan una muestra de palabras ya guardadas para que
    /// Gemini no las repita, y se descartan las que igual se parezcan a una
    /// existente. Si algún pedido falla se usan los demás; solo falla si
    /// fallan todos.
    async function askGemini(n) {
      const existing = (await database(COLLECTION).select('frase')).map((w) => w.frase);
      const avoid = sample(existing, AVOID_SAMPLE);
      const wanted = Math.ceil(n * (1 + GEMINI_EXTRA));
      const chunks = Math.ceil(wanted / GEMINI_CHUNK);
      const themes = sample(GEMINI_THEMES, chunks);
      const results = await Promise.allSettled(
        Array.from({ length: chunks }, (_, i) =>
          askGeminiOnce(
            buildPrompt(
              Math.ceil(wanted / chunks),
              themes[i % themes.length],
              avoid,
            ),
          ),
        ),
      );
      const failed = results.filter((r) => r.status === 'rejected');
      if (failed.length === results.length) throw failed[0].reason;
      for (const r of failed) logger.warn(r.reason, '[juego] Un pedido a Gemini falló');

      const similar = new SimilarWords(existing);
      const words = [];
      let skipped = 0;
      for (const r of results) {
        if (r.status !== 'fulfilled') continue;
        for (const w of r.value) {
          if (similar.has(w)) {
            skipped++;
            continue;
          }
          similar.add(w);
          words.push(w);
        }
      }
      if (skipped > 0) {
        logger.info(`[juego] Se descartaron ${skipped} palabras repetidas o parecidas`);
      }
      return words;
    }

    /// Guarda las palabras que no existan todavía y devuelve todas, con su
    /// id, en el mismo orden.
    async function save(words) {
      const keys = words.map(key);
      const existing = await database(COLLECTION)
        .select('id', 'frase', 'categoria')
        .whereIn(database.raw('lower(frase)'), keys);
      const byKey = new Map(existing.map((w) => [key(w.frase), w]));

      const missing = words.filter((w) => !byKey.has(key(w)));
      if (missing.length > 0) {
        const items = new services.ItemsService(COLLECTION, {
          schema: await getSchema(),
          knex: database,
        });
        const ids = await items.createMany(
          missing.map((frase) => ({ frase, categoria: GEMINI_CATEGORY })),
        );
        missing.forEach((frase, i) => {
          byKey.set(key(frase), { id: ids[i], frase, categoria: GEMINI_CATEGORY });
        });
      }
      return words.map((w) => byKey.get(key(w)));
    }

    router.post('/crear', async (req, res) => {
      if (!allowed('crear', clientIp(req))) {
        return error(res, 429, 'Demasiadas peticiones. Espera un minuto.');
      }
      const n = Number(req.body?.n ?? 20);
      if (!Number.isInteger(n) || n < 1 || n > MAX_CREATE) {
        return error(res, 400, `"n" debe ser un número entre 1 y ${MAX_CREATE}.`);
      }

      let words;
      try {
        words = (await askGemini(n)).slice(0, n);
      } catch (e) {
        logger.error(e, '[juego] Gemini falló');
        return error(res, 502, `Gemini no respondió: ${e.message}`);
      }
      if (words.length === 0) {
        return error(res, 502, 'Gemini no devolvió palabras nuevas.');
      }

      try {
        return res.json({ data: await save(words) });
      } catch (e) {
        logger.error(e, '[juego] No se pudieron guardar las palabras de Gemini');
        return error(res, 500, 'No se pudieron guardar las palabras.');
      }
    });

    router.post('/palabras', async (req, res) => {
      if (!allowed('palabras', clientIp(req))) {
        return error(res, 429, 'Demasiadas peticiones. Espera un minuto.');
      }

      const body = req.body ?? {};
      const n = Number(body.n ?? 20);
      if (!Number.isInteger(n) || n < 1 || n > MAX_COUNT) {
        return error(res, 400, `"n" debe ser un número entre 1 y ${MAX_COUNT}.`);
      }

      const categoria = body.categoria ?? null;
      if (categoria !== null && (typeof categoria !== 'string' || categoria.length > 50)) {
        return error(res, 400, '"categoria" no es válida.');
      }

      const excluir = body.excluir ?? [];
      if (
        !Array.isArray(excluir) ||
        excluir.length > MAX_EXCLUDE ||
        !excluir.every((id) => (typeof id === 'string' && id.length <= 64) || Number.isInteger(id))
      ) {
        return error(res, 400, `"excluir" debe ser una lista de hasta ${MAX_EXCLUDE} ids.`);
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
      } catch (e) {
        logger.error(e, '[juego] No se pudieron leer las palabras');
        return error(res, 500, 'No se pudieron leer las palabras.');
      }
    });
  },
};

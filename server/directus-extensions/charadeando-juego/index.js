// Rutas públicas del juego:
//
//   POST /juego/crear     Le pide palabras nuevas a Gemini (por el flujo de
//                         Directus), las guarda en la colección con la
//                         categoría LIBRE y las devuelve.
//   POST /juego/palabras  Entrega palabras al azar de la colección, de una
//                         categoría o de varias en partes iguales.
//   POST /juego/canjear   Canjea un código promocional (colección codigos)
//                         y dice qué desbloquea: todo o algunas categorías.
//   POST /juego/mis-codigos  Lo que abren los códigos que un celular ya
//                         canjeó, para recuperarlo al reinstalar la app.
//   POST /juego/castigos  Castigos al azar de la colección castigos (campo
//                         nombre) para la ruleta.
//   POST /juego/fotomimica  Objetos al azar de la colección fotomimica
//                         (publicados) con el id de su imagen, para la
//                         sección Fotomímica.
//   GET  /juego/estado    Uso del servidor (RAM, CPU, carga, disco). Solo
//                         para administradores de Directus; solo lee.
//
// Al arrancar crea, si falta, el índice de palabras por categoría, idioma
// y dificultad (WORDS_INDEX).
//
// El rol Public de Directus no tiene permisos sobre la colección, así que
// estas rutas son la única forma de leer o crear palabras sin iniciar
// sesión. Las instrucciones para Gemini están fijas aquí: la app solo manda
// la cantidad. Ambas rutas tienen tope y límite de peticiones por IP.

import os from 'node:os';
import { readFile, statfs } from 'node:fs/promises';

const COLLECTION = 'palabras';

/// Índice de `palabras` por los campos que filtra /juego/palabras, para
/// que siga rápida cuando crezca la colección. No cambia las palabras: la
/// base de datos lo mantiene sola al crear, editar o borrar.
export const WORDS_INDEX = 'palabras_categoria_idioma_dificultad';
const WORDS_INDEX_COLUMNS = ['categoria', 'idioma', 'dificultad'];

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
/// mismo, tiende a dar las mismas palabras. Por eso cada pedido lleva una
/// muestra al azar de las palabras ya guardadas, para que no las repita.
/// Es una muestra para no alargar demasiado el pedido.
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

/// Idioma de las palabras que entrega el juego (campo `idioma` de la
/// colección). En Directus es `ESPAÑOL`; también se acepta `ESPANOL`, sin ñ,
/// como lo escriben los archivos de las tandas. Las que no tienen idioma son
/// de las primeras tandas, todas en español.
const IDIOMAS = ['ESPAÑOL', 'ESPANOL'];

/// Valores del campo `dificultad` de la colección.
const DIFICULTADES = ['FACIL', 'NORMAL', 'DIFICIL'];

/// Ids que la app puede pedir excluir (las últimas palabras que jugó).
const MAX_EXCLUDE = 500;

/// Categorías que se pueden pedir juntas ("Combinar categorías"). Debe
/// coincidir con DirectusService.maxCategories.
const MAX_CATEGORIES = 20;

const RATE_WINDOW_MS = 60 * 1000;

/// Peticiones por IP en cada ventana. Crear cuesta una llamada a Gemini,
/// así que tiene un límite más bajo; una partida hace una de cada una como
/// mucho.
const limits = {
  crear: { points: 5, hits: new Map() },
  palabras: { points: 10, hits: new Map() },
  // Pocos intentos, para que no se puedan adivinar códigos probando.
  canjear: { points: 5, hits: new Map() },
  misCodigos: { points: 5, hits: new Map() },
  castigos: { points: 10, hits: new Map() },
  fotomimica: { points: 10, hits: new Map() },
  // Una partida manda uno al terminar (y la app reintenta los que no
  // llegaron, de a uno), así que 20 por minuto sobra.
  partida: { points: 20, hits: new Map() },
};

/// Objetos de Fotomímica (nombre, imagen en directus_files, status y
/// premium). No es pública; sus imágenes sí (solo las de la carpeta
/// Fotomímica), para que la app las descargue de /assets.
const PHOTO_MIME = 'fotomimica';

/// Tope de objetos por petición. Debe coincidir con
/// DirectusService.maxPhotoMime.
const MAX_PHOTO_MIME = 100;

/// Castigos de la ruleta (campo `nombre`). No es pública.
const PUNISHMENTS = 'castigos';

/// Tope de castigos por petición. Debe coincidir con
/// PunishmentService.maxCount.
const MAX_PUNISHMENTS = 200;

/// Estadísticas anónimas de las partidas. No es pública: solo la escribe
/// /juego/partida y se ve en Insights.
const GAMES = 'partidas';

/// Modos de juego y cómo se marcan los aciertos, como los manda la app.
export const MODOS_PARTIDA = ['NORMAL', 'LIBRE', 'COMBINADA', 'MIS_CATEGORIAS', 'FOTOMIMICA'];
export const MODOS_ACIERTO = ['INCLINACION', 'TOQUE', 'JUEZ', 'TV'];

/// Dificultades de una partida con palabras automáticas (MEZCLADA es la que
/// viene elegida). Sin dificultad (palabras escritas, Fotomímica,
/// Mis categorías) llega null.
export const DIFICULTADES_PARTIDA = ['MEZCLADA', ...DIFICULTADES];

/// Campos que acepta /juego/partida; cualquier otro se rechaza.
const CAMPOS_PARTIDA = [
  'modo',
  'categorias',
  'dificultad',
  'equipos',
  'rondas',
  'duracion_turno',
  'palabras_jugadas',
  'aciertos',
  'pases',
  'modo_acierto',
  'terminada',
  'video',
  'version_app',
];

/// Topes razonables de una partida. Los de la app son menores (4 equipos,
/// 10 rondas, turnos de 30 a 90 s); estos dejan margen para versiones
/// futuras sin aceptar cualquier cosa.
const PARTIDA_MAX = {
  equipos: 10,
  rondas: 20,
  duracionMin: 10,
  duracionMax: 600,
  palabras: 2000,
};

/// Código de categoría: mayúsculas, números y guion bajo. Así nunca llega
/// el nombre de una categoría propia ("Mi familia").
const CATEGORY_CODE = /^[A-Z0-9_]{1,40}$/;

/// Valida el cuerpo de /juego/partida. Devuelve la fila lista para guardar
/// (sin `id` ni `fecha`, que pone el servidor) o `{ error }`. `categoria`
/// es la única categoría jugada, o COMBINADA si fueron varias, para poder
/// agrupar en Insights.
export function parsePartidaBody(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'El cuerpo debe ser un objeto JSON.' };
  }
  const extra = Object.keys(body).filter((k) => !CAMPOS_PARTIDA.includes(k));
  if (extra.length > 0) return { error: `Campos no permitidos: ${extra.join(', ')}.` };
  const faltan = CAMPOS_PARTIDA.filter((k) => !(k in body) && k !== 'dificultad');
  if (faltan.length > 0) return { error: `Faltan campos: ${faltan.join(', ')}.` };

  const b = body;
  if (!MODOS_PARTIDA.includes(b.modo)) {
    return { error: `"modo" debe ser uno de ${MODOS_PARTIDA.join(', ')}.` };
  }
  const categorias = b.categorias;
  if (
    !Array.isArray(categorias) ||
    categorias.length === 0 ||
    categorias.length > MAX_CATEGORIES ||
    !categorias.every((c) => typeof c === 'string' && CATEGORY_CODE.test(c)) ||
    new Set(categorias).size !== categorias.length
  ) {
    return {
      error: `"categorias" debe ser una lista de 1 a ${MAX_CATEGORIES} códigos distintos (A-Z, 0-9, _).`,
    };
  }
  const solo = (codigo) => categorias.length === 1 && categorias[0] === codigo;
  const modoOk = {
    NORMAL: categorias.length === 1 && !['LIBRE', 'FOTOMIMICA', 'MIS_CATEGORIAS'].includes(categorias[0]),
    LIBRE: solo('LIBRE'),
    FOTOMIMICA: solo('FOTOMIMICA'),
    MIS_CATEGORIAS: solo('MIS_CATEGORIAS'),
    COMBINADA:
      categorias.length >= 2 && !categorias.includes('LIBRE') && !categorias.includes('FOTOMIMICA'),
  }[b.modo];
  if (!modoOk) return { error: `"categorias" no corresponde al modo ${b.modo}.` };

  const dificultad = b.dificultad ?? null;
  if (dificultad !== null && !DIFICULTADES_PARTIDA.includes(dificultad)) {
    return { error: `"dificultad" debe ser null o uno de ${DIFICULTADES_PARTIDA.join(', ')}.` };
  }

  const entero = (campo, min, max) =>
    Number.isInteger(b[campo]) && b[campo] >= min && b[campo] <= max
      ? null
      : `"${campo}" debe ser un entero entre ${min} y ${max}.`;
  const rangos = [
    entero('equipos', 0, PARTIDA_MAX.equipos),
    entero('rondas', 1, PARTIDA_MAX.rondas),
    entero('duracion_turno', PARTIDA_MAX.duracionMin, PARTIDA_MAX.duracionMax),
    entero('palabras_jugadas', 0, PARTIDA_MAX.palabras),
    entero('aciertos', 0, PARTIDA_MAX.palabras),
    entero('pases', 0, PARTIDA_MAX.palabras),
  ].filter(Boolean);
  if (rangos.length > 0) return { error: rangos[0] };
  if (b.aciertos + b.pases > b.palabras_jugadas) {
    return { error: '"aciertos" más "pases" no puede ser mayor que "palabras_jugadas".' };
  }

  if (!MODOS_ACIERTO.includes(b.modo_acierto)) {
    return { error: `"modo_acierto" debe ser uno de ${MODOS_ACIERTO.join(', ')}.` };
  }
  for (const campo of ['terminada', 'video']) {
    if (typeof b[campo] !== 'boolean') return { error: `"${campo}" debe ser true o false.` };
  }
  if (typeof b.version_app !== 'string' || !/^\d{1,4}\.\d{1,4}\.\d{1,4}(\+\d{1,6})?$/.test(b.version_app)) {
    return { error: '"version_app" debe ser como 1.0.0+1.' };
  }

  return {
    modo: b.modo,
    categoria: categorias.length === 1 ? categorias[0] : 'COMBINADA',
    categorias,
    dificultad,
    equipos: b.equipos,
    rondas: b.rondas,
    duracion_turno: b.duracion_turno,
    palabras_jugadas: b.palabras_jugadas,
    aciertos: b.aciertos,
    pases: b.pases,
    modo_acierto: b.modo_acierto,
    terminada: b.terminada,
    video: b.video,
    version_app: b.version_app,
  };
}

/// Códigos promocionales y sus canjes. Ninguna de las dos es pública.
const CODES = 'codigos';
const REDEMPTIONS = 'codigos_canjes';

/// Valor de `desbloquea` que abre toda la app (Premium).
const UNLOCK_ALL = 'TODO';

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

/// Valida el cuerpo de /juego/fotomimica: `{ n, excluir?, incluir_premium? }`.
/// Devuelve `{ n, excluir, incluirPremium }` o `{ error }`.
export function parsePhotoMimeBody(body) {
  const b = body ?? {};
  const n = Number(b.n ?? 10);
  if (!Number.isInteger(n) || n < 1 || n > MAX_PHOTO_MIME) {
    return { error: `"n" debe ser un número entre 1 y ${MAX_PHOTO_MIME}.` };
  }
  const excluir = b.excluir ?? [];
  if (
    !Array.isArray(excluir) ||
    excluir.length > MAX_EXCLUDE ||
    !excluir.every((id) => Number.isInteger(id) || (typeof id === 'string' && /^\d{1,12}$/.test(id)))
  ) {
    return { error: `"excluir" debe ser una lista de hasta ${MAX_EXCLUDE} ids.` };
  }
  const incluir = b.incluir_premium ?? false;
  if (typeof incluir !== 'boolean') {
    return { error: '"incluir_premium" debe ser true o false.' };
  }
  return { n, excluir: excluir.map(Number), incluirPremium: incluir };
}

/// Toma [n] filas al azar con [query]: primero sin las de [excluir] (ya
/// jugadas) y, si no alcanzan, completa con esas. [query] recibe
/// `{ excluir, tomadas, limit }` y devuelve filas con `id`.
export async function pickAvoiding(query, n, excluir) {
  const data = [];
  for (const evitar of [excluir, []]) {
    if (data.length >= n) break;
    const rows = await query({
      excluir: evitar,
      tomadas: data.map((r) => r.id),
      limit: n - data.length,
    });
    data.push(...rows);
    if (evitar.length === 0) break;
  }
  return data;
}

/// Objetos de Fotomímica para la app: `{ id, nombre, imagen, premium }`,
/// sin los que no tienen nombre o imagen.
export function photoMimeOut(rows) {
  const out = [];
  for (const row of rows ?? []) {
    const nombre = typeof row?.nombre === 'string' ? row.nombre.trim() : '';
    const imagen = row?.imagen ? String(row.imagen) : '';
    if (!nombre || !imagen) continue;
    out.push({ id: row.id, nombre, imagen, premium: row.premium === true || row.premium === 1 });
  }
  return out;
}

/// Castigos para la app: `{ id, texto }`, sin vacíos ni repetidos.
export function punishmentsOut(rows) {
  const seen = new Set();
  const out = [];
  for (const row of rows) {
    const texto = typeof row?.nombre === 'string' ? row.nombre.trim() : '';
    if (!texto || seen.has(key(texto))) continue;
    seen.add(key(texto));
    out.push({ id: row.id, texto });
  }
  return out;
}

/// Lee `/proc/meminfo` (en kB) y devuelve bytes: total, disponible (lo que
/// de verdad queda, contando la caché que Linux suelta cuando hace falta)
/// y swap. null si no se puede leer.
export function parseMeminfo(text) {
  const kb = {};
  for (const line of String(text ?? '').split('\n')) {
    const match = /^(\w+):\s+(\d+)\s*kB/.exec(line);
    if (match) kb[match[1]] = Number(match[2]) * 1024;
  }
  if (kb.MemTotal === undefined || kb.MemAvailable === undefined) return null;
  return {
    total: kb.MemTotal,
    disponible: kb.MemAvailable,
    swapTotal: kb.SwapTotal ?? 0,
    swapUsada: (kb.SwapTotal ?? 0) - (kb.SwapFree ?? 0),
  };
}

/// Porcentaje de CPU usado entre dos lecturas de `os.cpus()`: lo que no
/// fue tiempo libre (idle), sumando todos los núcleos.
export function cpuPercent(before, after) {
  let busy = 0;
  let total = 0;
  for (let i = 0; i < Math.min(before.length, after.length); i++) {
    const a = before[i].times;
    const b = after[i].times;
    const spent = Object.keys(b).reduce((sum, k) => sum + (b[k] - (a[k] ?? 0)), 0);
    total += spent;
    busy += spent - (b.idle - a.idle);
  }
  return total > 0 ? Math.round((busy / total) * 1000) / 10 : 0;
}

/// Porcentaje con un decimal.
function percent(part, whole) {
  return whole > 0 ? Math.round((part / whole) * 1000) / 10 : 0;
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

/// Lista de "categorias" válida: de 1 a MAX_CATEGORIES textos de hasta 50
/// caracteres. Devuelve la lista sin repetidas, o null si no es válida.
export function parseCategorias(value) {
  if (!Array.isArray(value) || value.length === 0 || value.length > MAX_CATEGORIES) {
    return null;
  }
  if (!value.every((c) => typeof c === 'string' && c.length > 0 && c.length <= 50)) {
    return null;
  }
  return [...new Set(value)];
}

/// Cuántas palabras le tocan a cada una de [parts] categorías para juntar
/// [n], en partes iguales. El sobrante se reparte de a una entre las
/// primeras: 46 en 3 son 16, 15 y 15.
export function quotas(n, parts) {
  const base = Math.floor(n / parts);
  const extra = n % parts;
  return Array.from({ length: parts }, (_, i) => base + (i < extra ? 1 : 0));
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

/// Pedido para Gemini: cuántas palabras y cuáles evitar. Sin tema: las
/// palabras son de cualquier cosa; los temas son las categorías del juego.
export function buildPrompt(size, avoid) {
  let prompt =
    `Genera exactamente ${size} palabras o frases para el juego, al azar ` +
    'y de cualquier tema.';
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

/// Código como lo escribió la persona, en mayúsculas y sin espacios, o
/// null si no tiene la forma de un código (3 a 40 letras, números, - o _).
export function normalizeCode(value) {
  if (typeof value !== 'string') return null;
  const code = value.replace(/\s+/g, '').toUpperCase();
  return /^[A-Z0-9_-]{3,40}$/.test(code) ? code : null;
}

/// Identificador del celular que manda la app (8 a 100 caracteres), o null.
export function normalizeDevice(value) {
  if (typeof value !== 'string') return null;
  const device = value.trim();
  return /^[A-Za-z0-9_-]{8,100}$/.test(device) ? device : null;
}

/// Lo que desbloquea un código: `TODO`, o códigos de categorías separados
/// por comas (`ANIME, FUTBOLISTAS`).
export function parseUnlocks(value) {
  const parts = String(value ?? '')
    .split(',')
    .map((p) => p.trim().toUpperCase())
    .filter((p) => p.length > 0);
  if (parts.includes(UNLOCK_ALL)) return { todo: true, categorias: [] };
  return { todo: false, categorias: [...new Set(parts)] };
}

/// Junta lo que abren los códigos que un celular ya canjeó ([rows], cada
/// uno con `desbloquea` y `activo`). Los apagados no cuentan; los vencidos
/// sí, porque lo canjeado es de por vida.
export function restoredUnlocks(rows) {
  let todo = false;
  const categorias = new Set();
  for (const row of rows ?? []) {
    if (!row || row.activo === false) continue;
    const unlocks = parseUnlocks(row.desbloquea);
    if (unlocks.todo) todo = true;
    for (const c of unlocks.categorias) categorias.add(c);
  }
  return { todo, categorias: todo ? [] : [...categorias] };
}

/// Crea el índice de `palabras` si todavía no existe. [database] es el knex
/// de Directus. MySQL no tiene `IF NOT EXISTS` para índices: ahí se crea y,
/// si ya estaba, no pasa nada.
export async function ensureWordsIndex(database) {
  const client = String(database.client?.config?.client ?? '');
  if (/mysql|maria/i.test(client)) {
    try {
      await database.schema.alterTable(COLLECTION, (table) =>
        table.index(WORDS_INDEX_COLUMNS, WORDS_INDEX),
      );
    } catch (e) {
      if (e?.code !== 'ER_DUP_KEYNAME') throw e;
    }
    return;
  }
  await database.raw('CREATE INDEX IF NOT EXISTS ?? ON ?? (??, ??, ??)', [
    WORDS_INDEX,
    COLLECTION,
    ...WORDS_INDEX_COLUMNS,
  ]);
}

/// Crea la tabla de canjes (un renglón por celular que canjea un código) si
/// todavía no existe, para que con solo la colección `codigos` ya se pueda
/// canjear. [database] es el knex de Directus.
export async function ensureRedemptions(database) {
  if (await database.schema.hasTable(REDEMPTIONS)) return false;
  await database.schema.createTable(REDEMPTIONS, (table) => {
    table.increments('id');
    table.string('codigo', 100).notNullable().index();
    table.string('dispositivo', 100).notNullable().index();
    table.timestamp('fecha').notNullable();
  });
  return true;
}

/// Revisa si un código de la colección se puede canjear hoy. Devuelve null
/// si sí, o el error (estado HTTP y mensaje) si no. [alreadyHere] es que
/// este celular ya lo había canjeado: entonces no gasta otro uso.
export function codeProblem(row, now, alreadyHere = false) {
  if (!row || row.activo === false) return [404, 'Código no válido.'];
  // Una fecha sola (campo de tipo fecha) vale hasta el final de ese día.
  const vence = /^\d{4}-\d{2}-\d{2}$/.test(String(row.vence ?? ''))
    ? `${row.vence}T23:59:59`
    : row.vence;
  if (vence && new Date(vence) < now) {
    return [410, 'Este código ya venció.'];
  }
  const max = row.usos_max;
  if (!alreadyHere && max !== null && max !== undefined && (row.usos ?? 0) >= max) {
    return [409, 'Este código ya se usó todas las veces que permite.'];
  }
  const unlocks = parseUnlocks(row.desbloquea);
  if (!unlocks.todo && unlocks.categorias.length === 0) {
    return [404, 'Código no válido.'];
  }
  return null;
}

export default {
  id: 'juego',
  handler: (router, { database, logger, services, getSchema, env }) => {
    const flowId = env?.CHARADEANDO_GEMINI_FLOW || DEFAULT_GEMINI_FLOW;

    // El índice de palabras se crea solo al arrancar, si falta. Si falla,
    // el juego sigue igual, solo que sin el índice.
    ensureWordsIndex(database)
      .then(() => logger.info(`[juego] Índice ${WORDS_INDEX} listo`))
      .catch((e) => logger.warn(e, `[juego] No se pudo crear el índice ${WORDS_INDEX}`));

    // La tabla de canjes se crea sola la primera vez que se necesita; si
    // falla, se vuelve a intentar en el siguiente pedido.
    let redemptionsReady = null;
    function redemptions() {
      redemptionsReady ??= ensureRedemptions(database)
        .then((created) => {
          if (created) logger.info(`[juego] Tabla ${REDEMPTIONS} creada`);
        })
        .catch((e) => {
          redemptionsReady = null;
          throw e;
        });
      return redemptionsReady;
    }
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
    /// más de eso se reparte en pedidos en paralelo. Cada pedido lleva su
    /// propia muestra de palabras ya guardadas para que Gemini no las
    /// repita, y se descartan las que igual se parezcan a una existente o a
    /// otra del mismo lote. Si algún pedido falla se usan los demás; solo falla si
    /// fallan todos.
    async function askGemini(n) {
      const existing = (await database(COLLECTION).select('frase')).map((w) => w.frase);
      const wanted = Math.ceil(n * (1 + GEMINI_EXTRA));
      const chunks = Math.ceil(wanted / GEMINI_CHUNK);
      const results = await Promise.allSettled(
        Array.from({ length: chunks }, () =>
          askGeminiOnce(
            buildPrompt(Math.ceil(wanted / chunks), sample(existing, AVOID_SAMPLE)),
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

    // Canjea un código: { "codigo": "FAMILIA2026", "dispositivo": "..." }.
    // Si el celular ya lo había canjeado (por ejemplo, después de borrar la
    // app) responde igual sin gastar otro uso.
    router.post('/canjear', async (req, res) => {
      if (!allowed('canjear', clientIp(req))) {
        return error(res, 429, 'Demasiados intentos. Espera un minuto.');
      }
      const body = req.body ?? {};
      const codigo = normalizeCode(body.codigo);
      const dispositivo = normalizeDevice(body.dispositivo);
      if (!codigo) return error(res, 404, 'Código no válido.');
      if (!dispositivo) return error(res, 400, '"dispositivo" no es válido.');

      try {
        await redemptions();
        const result = await database.transaction(async (trx) => {
          const row = await trx(CODES)
            .whereRaw('upper(codigo) = ?', [codigo])
            .forUpdate()
            .first();
          const already = row
            ? await trx(REDEMPTIONS)
                .where({ codigo: row.codigo, dispositivo })
                .first()
            : null;
          const problem = codeProblem(row, new Date(), Boolean(already));
          if (problem) return { problem };
          if (!already) {
            await trx(CODES)
              .where('id', row.id)
              .update({ usos: (row.usos ?? 0) + 1 });
            await trx(REDEMPTIONS).insert({
              codigo: row.codigo,
              dispositivo,
              fecha: new Date(),
            });
          }
          return { unlocks: parseUnlocks(row.desbloquea) };
        });
        if (result.problem) return error(res, ...result.problem);
        return res.json({ data: result.unlocks });
      } catch (e) {
        logger.error(e, '[juego] No se pudo canjear el código');
        return error(res, 500, 'No se pudo canjear el código.');
      }
    });

    // Lo que abren los códigos que este celular ya canjeó:
    // { "dispositivo": "..." }. No gasta usos. Sirve para recuperarlos al
    // reinstalar la app.
    router.post('/mis-codigos', async (req, res) => {
      if (!allowed('misCodigos', clientIp(req))) {
        return error(res, 429, 'Demasiados intentos. Espera un minuto.');
      }
      const dispositivo = normalizeDevice((req.body ?? {}).dispositivo);
      if (!dispositivo) return error(res, 400, '"dispositivo" no es válido.');
      try {
        await redemptions();
        const rows = await database(REDEMPTIONS)
          .join(CODES, `${CODES}.codigo`, `${REDEMPTIONS}.codigo`)
          .where(`${REDEMPTIONS}.dispositivo`, dispositivo)
          .select(`${CODES}.desbloquea`, `${CODES}.activo`);
        return res.json({ data: restoredUnlocks(rows) });
      } catch (e) {
        logger.error(e, '[juego] No se pudieron leer los códigos canjeados');
        return error(res, 500, 'No se pudieron leer los códigos canjeados.');
      }
    });

    // Castigos al azar para la ruleta: { "n": 100 }.
    // Uso del servidor para revisarlo sin entrar a la terminal. Solo un
    // administrador de Directus (con su token); no cambia nada. Directus
    // corre en Docker, pero la RAM, la CPU, la carga y el disco que ve son
    // los del servidor completo; `directus` es solo lo de este contenedor.
    router.get('/estado', async (req, res) => {
      if (req.accountability?.admin !== true) {
        return error(res, 403, 'Solo para administradores.');
      }
      try {
        const before = os.cpus();
        await new Promise((resolve) => setTimeout(resolve, 500));
        const after = os.cpus();

        const memoria =
          parseMeminfo(await readFile('/proc/meminfo', 'utf8').catch(() => '')) ?? {
            total: os.totalmem(),
            disponible: os.freemem(),
            swapTotal: 0,
            swapUsada: 0,
          };
        const fsInfo = await statfs('/').catch(() => null);
        const disco = fsInfo
          ? {
              total: fsInfo.blocks * fsInfo.bsize,
              libre: fsInfo.bavail * fsInfo.bsize,
            }
          : null;
        // Memoria del contenedor de Directus (cgroup v2), si se puede leer.
        const contenedor = Number(
          (await readFile('/sys/fs/cgroup/memory.current', 'utf8').catch(() => '')).trim(),
        );
        let baseDeDatos = null;
        if (/pg|postgres/i.test(String(database.client?.config?.client ?? ''))) {
          const result = await database
            .raw('SELECT pg_database_size(current_database()) AS bytes')
            .catch(() => null);
          const bytes = Number(result?.rows?.[0]?.bytes);
          if (Number.isFinite(bytes)) baseDeDatos = { bytes };
        }

        const [carga1, carga5, carga15] = os.loadavg();
        return res.json({
          data: {
            fecha: new Date().toISOString(),
            encendidoSegundos: Math.round(os.uptime()),
            nucleos: after.length,
            cpu: { usoPorcentaje: cpuPercent(before, after) },
            carga: { '1min': carga1, '5min': carga5, '15min': carga15 },
            memoria: {
              ...memoria,
              usada: memoria.total - memoria.disponible,
              usoPorcentaje: percent(memoria.total - memoria.disponible, memoria.total),
            },
            disco: disco && {
              ...disco,
              usado: disco.total - disco.libre,
              usoPorcentaje: percent(disco.total - disco.libre, disco.total),
            },
            directus: {
              memoriaContenedor: Number.isFinite(contenedor) && contenedor > 0 ? contenedor : null,
              memoriaProceso: process.memoryUsage().rss,
              node: process.version,
            },
            baseDeDatos,
          },
        });
      } catch (e) {
        logger.error(e, '[juego] No se pudo leer el estado del servidor');
        return error(res, 500, 'No se pudo leer el estado del servidor.');
      }
    });

    // Objetos al azar para Fotomímica: { "n": 40, "excluir": [ids],
    // "incluir_premium": false }. Solo los publicados; sin Premium, solo los
    // gratis. Los de "excluir" (ya jugados) solo se repiten si no alcanzan.
    router.post('/fotomimica', async (req, res) => {
      if (!allowed('fotomimica', clientIp(req))) {
        return error(res, 429, 'Demasiadas peticiones. Espera un minuto.');
      }
      const body = parsePhotoMimeBody(req.body);
      if (body.error) return error(res, 400, body.error);
      try {
        const rows = await pickAvoiding(
          ({ excluir, tomadas, limit }) => {
            const q = database(PHOTO_MIME)
              .select('id', 'nombre', 'imagen', 'premium')
              .where('status', 'published')
              .whereNotNull('imagen')
              .orderByRaw('random()')
              .limit(limit);
            if (!body.incluirPremium) {
              q.where((w) => w.where('premium', false).orWhereNull('premium'));
            }
            const fuera = [...excluir, ...tomadas];
            if (fuera.length > 0) q.whereNotIn('id', fuera);
            return q;
          },
          body.n,
          body.excluir,
        );
        return res.json({ data: photoMimeOut(rows) });
      } catch (e) {
        logger.error(e, '[juego] No se pudieron leer los objetos de Fotomímica');
        return error(res, 500, 'No se pudieron leer los objetos de Fotomímica.');
      }
    });

    // Estadísticas anónimas de una partida (ver parsePartidaBody). No se
    // guarda la IP ni nada del celular: la IP solo se usa en memoria para el
    // límite de peticiones. Se escribe directo en la tabla, sin pasar por
    // los servicios de Directus, para que tampoco quede en la actividad.
    router.post('/partida', async (req, res) => {
      if (!allowed('partida', clientIp(req))) {
        return error(res, 429, 'Demasiadas peticiones. Espera un minuto.');
      }
      const row = parsePartidaBody(req.body);
      if (row.error) return error(res, 400, row.error);
      try {
        await database(GAMES).insert({
          ...row,
          categorias: JSON.stringify(row.categorias),
          fecha: new Date(),
        });
        return res.status(201).json({ data: { ok: true } });
      } catch (e) {
        logger.error(e, '[juego] No se pudo guardar la partida');
        return error(res, 500, 'No se pudo guardar la partida.');
      }
    });

    router.post('/castigos', async (req, res) => {
      if (!allowed('castigos', clientIp(req))) {
        return error(res, 429, 'Demasiadas peticiones. Espera un minuto.');
      }
      const n = Number((req.body ?? {}).n ?? 10);
      if (!Number.isInteger(n) || n < 1 || n > MAX_PUNISHMENTS) {
        return error(res, 400, `"n" debe ser un número entre 1 y ${MAX_PUNISHMENTS}.`);
      }
      try {
        const rows = await database(PUNISHMENTS)
          .select('id', 'nombre')
          .whereNotNull('nombre')
          .orderByRaw('random()')
          .limit(n);
        return res.json({ data: punishmentsOut(rows) });
      } catch (e) {
        logger.error(e, '[juego] No se pudieron leer los castigos');
        return error(res, 500, 'No se pudieron leer los castigos.');
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

      // Varias categorías a la vez ("Combinar categorías"). Si llega,
      // manda sobre "categoria".
      let categorias = null;
      if (body.categorias !== undefined && body.categorias !== null) {
        categorias = parseCategorias(body.categorias);
        if (categorias === null) {
          return error(
            res,
            400,
            `"categorias" debe ser una lista de 1 a ${MAX_CATEGORIES} textos de hasta 50 caracteres.`,
          );
        }
      }

      const dificultad = body.dificultad ?? null;
      if (dificultad !== null && !DIFICULTADES.includes(dificultad)) {
        return error(res, 400, `"dificultad" debe ser ${DIFICULTADES.join(', ')}.`);
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
        const query = (cats, conDificultad) => {
          const q = database(COLLECTION)
            .select('id', 'frase', 'categoria')
            .where((w) => w.whereIn('idioma', IDIOMAS).orWhereNull('idioma'))
            .orderByRaw('random()');
          if (cats) q.whereIn('categoria', cats);
          if (conDificultad && dificultad) q.where('dificultad', dificultad);
          return q;
        };

        // Agrega a [data] hasta [count] palabras de [cats] (null es de
        // todas). Para que la partida no quede corta, se completa en este
        // orden:
        // 1. palabras que la app no ha jugado, de la dificultad elegida;
        // 2. palabras no jugadas de las otras dificultades;
        // 3. palabras ya jugadas de la dificultad elegida;
        // 4. palabras ya jugadas de cualquier dificultad.
        const fill = async (data, cats, count) => {
          const goal = data.length + count;
          const pasos = [
            () => query(cats, true).whereNotIn('id', excluir),
            () => query(cats, false).whereNotIn('id', excluir),
            () => query(cats, true),
            () => query(cats, false),
          ];
          for (const paso of pasos) {
            if (data.length >= goal) break;
            const tomadas = data.map((w) => w.id);
            data.push(...(await paso().whereNotIn('id', tomadas).limit(goal - data.length)));
          }
        };

        const data = [];
        if (categorias) {
          // En partes iguales entre las categorías; si alguna no alcanza,
          // se completa con las otras de la lista.
          const cuotas = quotas(n, categorias.length);
          for (let i = 0; i < categorias.length; i++) {
            await fill(data, [categorias[i]], cuotas[i]);
          }
          if (data.length < n) await fill(data, categorias, n - data.length);
          return res.json({ data: sample(data, data.length) });
        }
        await fill(data, categoria ? [categoria] : null, n);
        return res.json({ data });
      } catch (e) {
        logger.error(e, '[juego] No se pudieron leer las palabras');
        return error(res, 500, 'No se pudieron leer las palabras.');
      }
    });
  },
};

// Carga en la colección `mas_menos` los datos de "¿Más o menos?" de un archivo
// JSON (los del repositorio privado palabras-juego, ya validados):
//
//   DIRECTUS_TOKEN=xxx node server/scripts/importar-datos.mjs <archivo.json> [--publicar]
//
// Cada elemento: { pregunta, respuesta, unidad?, dato_curioso?, categoria,
// dificultad, fuente }. Quedan como borrador (o publicados con
// --publicar) y gratis (premium false). Si ya hay uno con la misma
// pregunta (sin importar mayúsculas, tildes ni espacios), lo salta. Revisa
// que la respuesta sea un entero y que no falte nada; los que fallan no se
// cargan y se avisan.
//
// Antes hay que correr crear-datos.mjs. Node 22, sin dependencias.

import { readFile } from 'node:fs/promises';

import { configFromEnv, directusApi, isMain, query } from './directus-api.mjs';
import { FACTS } from './crear-datos.mjs';

export const DIFFICULTIES = ['FACIL', 'NORMAL', 'DIFICIL'];

/// Para comparar preguntas sin importar mayúsculas, tildes, signos ni
/// espacios.
export function questionKey(text) {
  return String(text ?? '')
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9ñ ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/// Qué le falta o qué tiene mal un dato, o null si está bien.
export function factProblem(f) {
  const text = (v) => (typeof v === 'string' ? v.trim() : '');
  if (!text(f?.pregunta)) return 'falta la pregunta';
  if (text(f.pregunta).length > 160) return 'la pregunta tiene más de 160 caracteres';
  if (!Number.isSafeInteger(f.respuesta)) return 'la respuesta no es un número entero';
  if (!text(f.categoria)) return 'falta la categoría';
  if (!DIFFICULTIES.includes(f.dificultad)) return `la dificultad debe ser ${DIFFICULTIES.join(', ')}`;
  if (!/^https?:\/\/\S+$/.test(text(f.fuente))) return 'la fuente debe ser una URL';
  if (f.unidad != null && text(f.unidad).length > 30) return 'la unidad tiene más de 30 caracteres';
  if (f.dato_curioso != null && text(f.dato_curioso).length > 200) {
    return 'el dato curioso tiene más de 200 caracteres';
  }
  return null;
}

/// Carga [facts]. Devuelve `{ cargados, saltados, errores }` (textos).
export async function importFacts(api, facts, { publish = false, log = () => {} } = {}) {
  const summary = { cargados: [], saltados: [], errores: [] };
  const existing = (await api.get(`/items/${FACTS}${query({ fields: 'id,pregunta', limit: '-1' })}`)) ?? [];
  const taken = new Set(existing.map((item) => questionKey(item.pregunta)));
  for (const f of facts) {
    const label = String(f?.pregunta ?? '(sin pregunta)').slice(0, 60);
    const problem = factProblem(f);
    if (problem) {
      summary.errores.push(`${label}: ${problem}.`);
      log(`x ${label}: ${problem}.`);
      continue;
    }
    const key = questionKey(f.pregunta);
    if (taken.has(key)) {
      summary.saltados.push(label);
      log(`= ${label}: ya existe, se salta.`);
      continue;
    }
    try {
      await api.post(`/items/${FACTS}`, {
        status: publish ? 'published' : 'draft',
        pregunta: f.pregunta.trim(),
        respuesta: f.respuesta,
        unidad: f.unidad?.trim() || null,
        dato_curioso: f.dato_curioso?.trim() || null,
        categoria: f.categoria.trim(),
        dificultad: f.dificultad,
        fuente: f.fuente.trim(),
        premium: false,
      });
      taken.add(key);
      summary.cargados.push(label);
      log(`+ ${label}`);
    } catch (e) {
      summary.errores.push(`${label}: ${e.message}`);
      log(`x ${label}: ${e.message}`);
    }
  }
  return summary;
}

if (isMain(import.meta.url)) {
  const [file, ...flags] = process.argv.slice(2);
  try {
    if (!file) {
      throw new Error(
        'Falta el archivo. Córrelo así: DIRECTUS_TOKEN=xxx node server/scripts/importar-datos.mjs <archivo.json> [--publicar]',
      );
    }
    const facts = JSON.parse(await readFile(file, 'utf8'));
    if (!Array.isArray(facts)) throw new Error('El archivo debe ser una lista de datos.');
    const config = configFromEnv();
    const publish = flags.includes('--publicar');
    console.log(`Directus: ${config.url}\nArchivo: ${file} (${facts.length} datos)\n`);
    const summary = await importFacts(directusApi(config), facts, { publish, log: console.log });
    console.log(
      `\nResumen: ${summary.cargados.length} cargados (${publish ? 'publicados' : 'borrador'}), ` +
        `${summary.saltados.length} ya existían, ${summary.errores.length} con errores.`,
    );
    if (summary.errores.length > 0) process.exitCode = 1;
  } catch (e) {
    console.error(`\nNo se pudo terminar: ${e.message}`);
    process.exitCode = 1;
  }
}

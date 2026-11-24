// Carga en `letras_tematicas` las temáticas del juego "Letras" de un archivo
// JSON temporal (los datos viven solo en Directus: el archivo se borra
// después de cargarlo):
//
//   DIRECTUS_TOKEN=xxx node server/scripts/importar-tematicas.mjs <archivo.json> [--borrador]
//
// Cada elemento: { "tematica": "Cosas que hay en un baño", "letras": "ABCDPST" }.
// Quedan publicadas (o como borrador con --borrador) y gratis. Si ya hay una
// con la misma temática (sin importar mayúsculas, tildes ni signos), la
// salta. Rechaza las que tengan Ñ, W, X o Z, o letras repetidas o raras.
//
// Antes hay que correr crear-tematicas.mjs. Node 22, sin dependencias.

import { readFile } from 'node:fs/promises';

import { configFromEnv, directusApi, isMain, query } from './directus-api.mjs';
import { TOPICS } from './crear-tematicas.mjs';
import { questionKey } from './importar-datos.mjs';

export const LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVY';

/// Qué tiene mal una temática, o null si está bien.
export function topicProblem(t) {
  const tematica = typeof t?.tematica === 'string' ? t.tematica.trim() : '';
  if (!tematica) return 'falta la temática';
  if (tematica.length > 60) return 'la temática tiene más de 60 caracteres';
  const letras = typeof t.letras === 'string' ? t.letras.trim() : '';
  if (!letras) return 'faltan las letras';
  if (/[ÑWXZ]/i.test(letras)) return 'tiene letras que no se juegan (Ñ, W, X o Z)';
  if (!/^[A-Z]+$/.test(letras)) return 'las letras deben ir en mayúscula, sin espacios';
  if (new Set(letras).size !== letras.length) return 'tiene letras repetidas';
  if (letras.length < 3) return 'tiene menos de 3 letras';
  return null;
}

/// Carga [topics]. Devuelve `{ cargadas, saltadas, errores }` (textos).
export async function importTopics(api, topics, { draft = false, log = () => {} } = {}) {
  const summary = { cargadas: [], saltadas: [], errores: [] };
  const existing = (await api.get(`/items/${TOPICS}${query({ fields: 'id,tematica', limit: '-1' })}`)) ?? [];
  const taken = new Set(existing.map((item) => questionKey(item.tematica)));
  for (const t of topics) {
    const label = String(t?.tematica ?? '(sin temática)');
    const problem = topicProblem(t);
    if (problem) {
      summary.errores.push(`${label}: ${problem}.`);
      log(`x ${label}: ${problem}.`);
      continue;
    }
    const k = questionKey(t.tematica);
    if (taken.has(k)) {
      summary.saltadas.push(label);
      log(`= ${label}: ya existe, se salta.`);
      continue;
    }
    try {
      const letras = [...LETTERS].filter((l) => t.letras.includes(l)).join('');
      await api.post(`/items/${TOPICS}`, {
        status: draft ? 'draft' : 'published',
        tematica: t.tematica.trim(),
        letras,
        premium: false,
      });
      taken.add(k);
      summary.cargadas.push(label);
      log(`+ ${label} (${letras})`);
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
        'Falta el archivo. Córrelo así: DIRECTUS_TOKEN=xxx node server/scripts/importar-tematicas.mjs <archivo.json>',
      );
    }
    const topics = JSON.parse(await readFile(file, 'utf8'));
    if (!Array.isArray(topics)) throw new Error('El archivo debe ser una lista de temáticas.');
    const config = configFromEnv();
    const draft = flags.includes('--borrador');
    console.log(`Directus: ${config.url}\nArchivo: ${file} (${topics.length} temáticas)\n`);
    const summary = await importTopics(directusApi(config), topics, { draft, log: console.log });
    console.log(
      `\nResumen: ${summary.cargadas.length} cargadas (${draft ? 'borrador' : 'publicadas'}), ` +
        `${summary.saltadas.length} ya existían, ${summary.errores.length} con errores.`,
    );
    if (summary.errores.length > 0) process.exitCode = 1;
  } catch (e) {
    console.error(`\nNo se pudo terminar: ${e.message}`);
    process.exitCode = 1;
  }
}

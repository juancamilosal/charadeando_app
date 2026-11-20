// Crea en Directus la colección `datos` del juego "¿Más o menos?":
//
//   id, status (published/draft), pregunta, respuesta (número entero),
//   unidad (opcional), dato_curioso, categoria, dificultad (FACIL, NORMAL,
//   DIFICIL), fuente (URL) y premium (por defecto false).
//
// La colección no es pública: la app la lee solo con POST /juego/datos.
// Se puede correr varias veces: lo que ya existe lo deja igual y lo dice.
// No borra ni cambia nada que ya exista.
//
//   DIRECTUS_TOKEN=xxx node server/scripts/crear-datos.mjs
//
// DIRECTUS_URL cambia el servidor (por defecto el de Charadeando). Node 22,
// sin dependencias.

import { configFromEnv, directusApi, isMain, query } from './directus-api.mjs';

export const FACTS = 'datos';

const choices = (values) => ({
  choices: values.map(([text, value]) => ({ text, value })),
});

/// Campos de la colección.
export const FIELDS = [
  {
    field: 'id',
    type: 'integer',
    meta: { hidden: true, interface: 'input', readonly: true },
    schema: { is_primary_key: true, has_auto_increment: true },
  },
  {
    field: 'status',
    type: 'string',
    meta: {
      interface: 'select-dropdown',
      display: 'labels',
      required: true,
      width: 'half',
      note: 'Solo los publicados salen en el juego.',
      options: choices([
        ['Publicado', 'published'],
        ['Borrador', 'draft'],
      ]),
    },
    schema: { default_value: 'draft', is_nullable: false, max_length: 20 },
  },
  {
    field: 'dificultad',
    type: 'string',
    meta: {
      interface: 'select-dropdown',
      required: true,
      width: 'half',
      note: 'FACIL: del 1 al 100. NORMAL: años. DIFICIL: números grandes.',
      options: choices([
        ['Fácil', 'FACIL'],
        ['Normal', 'NORMAL'],
        ['Difícil', 'DIFICIL'],
      ]),
    },
    schema: { is_nullable: false, max_length: 10 },
  },
  {
    field: 'pregunta',
    type: 'string',
    meta: {
      interface: 'input',
      required: true,
      options: { trim: true, placeholder: '¿Cuántas patas tiene una araña?' },
      note: 'La lee el grupo en voz alta (máx. 160).',
    },
    schema: { is_nullable: false, max_length: 160 },
  },
  {
    field: 'respuesta',
    type: 'bigInteger',
    meta: {
      interface: 'input',
      required: true,
      width: 'half',
      note: 'Un solo número entero, exacto e indiscutible.',
    },
    schema: { is_nullable: false },
  },
  {
    field: 'unidad',
    type: 'string',
    meta: {
      interface: 'input',
      width: 'half',
      options: { trim: true, placeholder: 'patas' },
      note: 'Opcional: "años", "metros", "patas"… Va después del número.',
    },
    schema: { is_nullable: true, max_length: 30 },
  },
  {
    field: 'dato_curioso',
    type: 'string',
    meta: {
      interface: 'input',
      options: { trim: true },
      note: 'Una frase corta que sale en el resultado del turno (máx. 200).',
    },
    schema: { is_nullable: true, max_length: 200 },
  },
  {
    field: 'categoria',
    type: 'string',
    meta: {
      interface: 'input',
      required: true,
      width: 'half',
      options: { trim: true, placeholder: 'Animales' },
      note: 'Tema del dato, arriba de la pregunta: Historia, Espacio…',
    },
    schema: { is_nullable: false, max_length: 40 },
  },
  {
    field: 'fuente',
    type: 'string',
    meta: {
      interface: 'input',
      required: true,
      width: 'half',
      options: { trim: true, placeholder: 'https://' },
      note: 'URL de donde sale la respuesta.',
    },
    schema: { is_nullable: false, max_length: 300 },
  },
  {
    field: 'premium',
    type: 'boolean',
    meta: {
      interface: 'boolean',
      special: ['cast-boolean'],
      width: 'half',
      note: 'Si está activo, solo sale con Todo Charadeando.',
    },
    schema: { default_value: false, is_nullable: false },
  },
];

export const COLLECTION_META = {
  icon: 'quiz',
  note: 'Datos del juego "¿Más o menos?" de Charadeando.',
  display_template: '{{pregunta}} → {{respuesta}} {{unidad}}',
  archive_field: 'status',
  archive_value: 'draft',
  unarchive_value: 'published',
  archive_app_filter: true,
};

/// Hace todo y devuelve qué creó, qué ya existía y los avisos.
export async function createFacts(api, log = () => {}) {
  const summary = { creado: [], existia: [], avisos: [] };
  const created = (what) => {
    summary.creado.push(what);
    log(`+ Creado: ${what}`);
  };
  const existed = (what) => {
    summary.existia.push(what);
    log(`= Ya existía: ${what}`);
  };
  const warn = (what) => {
    summary.avisos.push(what);
    log(`! Aviso: ${what}`);
  };

  const collections = await api.get('/collections');
  const exists = (collections ?? []).some((c) => c.collection === FACTS);
  if (!exists) {
    await api.post('/collections', { collection: FACTS, meta: COLLECTION_META, schema: {}, fields: FIELDS });
    created(`colección "${FACTS}" con ${FIELDS.map((f) => f.field).join(', ')}`);
  } else {
    existed(`colección "${FACTS}"`);
    const fields = new Set(((await api.get(`/fields/${FACTS}`)) ?? []).map((f) => f.field));
    for (const field of FIELDS) {
      if (fields.has(field.field)) {
        existed(`campo ${FACTS}.${field.field}`);
        continue;
      }
      await api.post(`/fields/${FACTS}`, field);
      created(`campo ${FACTS}.${field.field}`);
    }
  }

  // No debe ser pública: solo se avisa, no se borra nada.
  const access = await api.get(
    `/access${query({
      'filter[role][_null]': 'true',
      'filter[user][_null]': 'true',
      fields: 'policy',
      limit: '-1',
    })}`,
  );
  const publicPolicy = access?.[0]?.policy;
  if (!publicPolicy) {
    warn('no se encontró la política Public; no se revisaron los permisos.');
  } else {
    const permissions =
      (await api.get(
        `/permissions${query({
          'filter[policy][_eq]': publicPolicy,
          'filter[collection][_eq]': FACTS,
          fields: 'id',
          limit: '-1',
        })}`,
      )) ?? [];
    if (permissions.length > 0) {
      warn(
        `la política Public tiene ${permissions.length} permiso(s) sobre "${FACTS}" ` +
          `(ids ${permissions.map((p) => p.id).join(', ')}). La colección no debe ser pública: ` +
          'quítalos en Configuración → Control de acceso → Public. El script no los borra.',
      );
    } else {
      existed(`"${FACTS}" sin permisos públicos`);
    }
  }
  return summary;
}

if (isMain(import.meta.url)) {
  try {
    const config = configFromEnv();
    console.log(`Directus: ${config.url}\n`);
    const summary = await createFacts(directusApi(config), console.log);
    console.log(`\nResumen: ${summary.creado.length} creado(s), ${summary.existia.length} ya existían, ` +
      `${summary.avisos.length} aviso(s).`);
  } catch (e) {
    console.error(`\nNo se pudo terminar: ${e.message}`);
    process.exitCode = 1;
  }
}

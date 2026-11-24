// Crea en Directus la colección `letras_tematicas` del juego "Letras":
//
//   id, status (published/draft), tematica ("Cosas que hay en un baño"),
//   letras (las letras con que se puede jugar, como "ABCDPST"; nunca Ñ, W,
//   X ni Z) y premium (por defecto false).
//
// La colección no es pública: la app la lee solo con POST /juego/tematicas.
// Se puede correr varias veces: lo que ya existe lo deja igual y lo dice.
// No borra ni cambia nada que ya exista.
//
//   DIRECTUS_TOKEN=xxx node server/scripts/crear-tematicas.mjs
//
// DIRECTUS_URL cambia el servidor (por defecto el de Charadeando). Node 22,
// sin dependencias.

import { configFromEnv, directusApi, isMain, query } from './directus-api.mjs';

export const TOPICS = 'letras_tematicas';

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
      note: 'Solo las publicadas salen en el juego.',
      options: choices([
        ['Publicado', 'published'],
        ['Borrador', 'draft'],
        ['Archivado', 'archived'],
      ]),
    },
    schema: { default_value: 'published', is_nullable: false, max_length: 20 },
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
  {
    field: 'tematica',
    type: 'string',
    meta: {
      interface: 'input',
      required: true,
      options: { trim: true, placeholder: 'Cosas que hay en un baño' },
      note: 'Se ve arriba de la letra (máx. 60).',
    },
    schema: { is_nullable: false, max_length: 60 },
  },
  {
    field: 'letras',
    type: 'string',
    meta: {
      interface: 'input',
      required: true,
      options: { trim: true, placeholder: 'ABCDEJLPST' },
      note: 'Letras con que se puede jugar esta temática. Nunca Ñ, W, X ni Z.',
    },
    schema: { is_nullable: false, max_length: 30 },
  },
];

export const COLLECTION_META = {
  icon: 'abc',
  note: 'Temáticas del juego Letras de Charadeando.',
  display_template: '{{tematica}} ({{letras}})',
  archive_field: 'status',
  archive_value: 'archived',
  unarchive_value: 'published',
  archive_app_filter: true,
};

/// Hace todo y devuelve qué creó, qué ya existía y los avisos.
export async function createTopics(api, log = () => {}) {
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
  const exists = (collections ?? []).some((c) => c.collection === TOPICS);
  if (!exists) {
    await api.post('/collections', { collection: TOPICS, meta: COLLECTION_META, schema: {}, fields: FIELDS });
    created(`colección "${TOPICS}" con ${FIELDS.map((f) => f.field).join(', ')}`);
  } else {
    existed(`colección "${TOPICS}"`);
    const fields = new Set(((await api.get(`/fields/${TOPICS}`)) ?? []).map((f) => f.field));
    for (const field of FIELDS) {
      if (fields.has(field.field)) {
        existed(`campo ${TOPICS}.${field.field}`);
        continue;
      }
      await api.post(`/fields/${TOPICS}`, field);
      created(`campo ${TOPICS}.${field.field}`);
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
          'filter[collection][_eq]': TOPICS,
          fields: 'id',
          limit: '-1',
        })}`,
      )) ?? [];
    if (permissions.length > 0) {
      warn(
        `la política Public tiene ${permissions.length} permiso(s) sobre "${TOPICS}" ` +
          `(ids ${permissions.map((p) => p.id).join(', ')}). La colección no debe ser pública: ` +
          'quítalos en Configuración → Control de acceso → Public. El script no los borra.',
      );
    } else {
      existed(`"${TOPICS}" sin permisos públicos`);
    }
  }
  return summary;
}

if (isMain(import.meta.url)) {
  try {
    const config = configFromEnv();
    console.log(`Directus: ${config.url}\n`);
    const summary = await createTopics(directusApi(config), console.log);
    console.log(`\nResumen: ${summary.creado.length} creado(s), ${summary.existia.length} ya existían, ` +
      `${summary.avisos.length} aviso(s).`);
  } catch (e) {
    console.error(`\nNo se pudo terminar: ${e.message}`);
    process.exitCode = 1;
  }
}

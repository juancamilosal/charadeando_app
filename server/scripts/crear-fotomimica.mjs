// Crea en Directus lo que necesita la sección Fotomímica:
//
//   1. La carpeta de archivos "Fotomímica".
//   2. La colección `fotomimica` (id, status, nombre, imagen, premium).
//   3. En la política Public, permiso de LECTURA en directus_files solo para
//      los archivos de la carpeta Fotomímica, para que la app descargue
//      /assets/<id>. La colección `fotomimica` no es pública.
//
// Se puede correr varias veces: lo que ya existe lo deja igual y lo dice.
// No borra ni cambia nada que ya exista.
//
//   DIRECTUS_TOKEN=xxx node server/scripts/crear-fotomimica.mjs
//
// DIRECTUS_URL cambia el servidor (por defecto el de Charadeando). Node 22,
// sin dependencias.

import {
  FOLDER_NAME,
  PHOTO_MIME,
  configFromEnv,
  directusApi,
  findFolder,
  isMain,
  query,
} from './directus-api.mjs';

/// Campos de la colección, sin la imagen (que necesita la carpeta y su
/// relación con directus_files).
export const BASE_FIELDS = [
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
      options: {
        choices: [
          { text: 'Publicado', value: 'published' },
          { text: 'Borrador', value: 'draft' },
        ],
      },
      display_options: {
        choices: [
          { text: 'Publicado', value: 'published', foreground: '#FFFFFF', background: '#2BC273' },
          { text: 'Borrador', value: 'draft', foreground: '#18222F', background: '#D3DAE4' },
        ],
      },
    },
    schema: { default_value: 'draft', is_nullable: false, max_length: 20 },
  },
  {
    field: 'nombre',
    type: 'string',
    meta: {
      interface: 'input',
      required: true,
      width: 'half',
      options: { trim: true, placeholder: 'Taladro' },
      note: 'Nombre del objeto, en letra pequeña debajo de la foto (máx. 60).',
    },
    schema: { max_length: 60, is_nullable: false },
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

/// Campo de la imagen: un archivo de directus_files, guardado por defecto
/// en la carpeta [folderId].
export function imageField(folderId) {
  return {
    field: 'imagen',
    type: 'uuid',
    meta: {
      interface: 'file-image',
      special: ['file'],
      display: 'image',
      required: true,
      width: 'half',
      options: { folder: folderId, crop: false },
      note: 'Foto del objeto. Se guarda en la carpeta Fotomímica.',
    },
    schema: { is_nullable: true },
  };
}

export const IMAGE_RELATION = {
  collection: PHOTO_MIME,
  field: 'imagen',
  related_collection: 'directus_files',
  schema: { on_delete: 'SET NULL' },
};

/// Meta de la colección: ícono, `nombre` como plantilla y `status` como
/// campo de archivo (draft = archivado).
export const COLLECTION_META = {
  icon: 'photo_camera',
  note: 'Objetos de la sección Fotomímica de Charadeando.',
  display_template: '{{nombre}}',
  archive_field: 'status',
  archive_value: 'draft',
  unarchive_value: 'published',
  archive_app_filter: true,
};

/// Filtro del permiso público: solo los archivos de la carpeta [folderId].
export function publicFilesFilter(folderId) {
  return { folder: { _eq: folderId } };
}

/// Hace todo y devuelve qué creó, qué ya existía y los avisos. [log]
/// recibe cada paso.
export async function createPhotoMime(api, log = () => {}) {
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

  // 1. Carpeta.
  let folder = await findFolder(api);
  if (folder) {
    existed(`carpeta "${FOLDER_NAME}" (${folder.id})`);
  } else {
    folder = await api.post('/folders', { name: FOLDER_NAME });
    created(`carpeta "${FOLDER_NAME}" (${folder.id})`);
  }

  // 2. Colección y campos.
  const collections = await api.get('/collections');
  const exists = (collections ?? []).some((c) => c.collection === PHOTO_MIME);
  if (!exists) {
    await api.post('/collections', {
      collection: PHOTO_MIME,
      meta: COLLECTION_META,
      schema: {},
      fields: BASE_FIELDS,
    });
    created(`colección "${PHOTO_MIME}" con id, status, nombre y premium`);
  } else {
    existed(`colección "${PHOTO_MIME}"`);
  }

  const fields = new Set((await api.get(`/fields/${PHOTO_MIME}`) ?? []).map((f) => f.field));
  for (const field of [...BASE_FIELDS, imageField(folder.id)]) {
    if (fields.has(field.field)) {
      if (exists) existed(`campo ${PHOTO_MIME}.${field.field}`);
      continue;
    }
    await api.post(`/fields/${PHOTO_MIME}`, field);
    created(`campo ${PHOTO_MIME}.${field.field}`);
  }

  const relations = await api.get(`/relations/${PHOTO_MIME}`);
  if ((relations ?? []).some((r) => r.field === 'imagen')) {
    existed(`relación ${PHOTO_MIME}.imagen → directus_files`);
  } else {
    await api.post('/relations', IMAGE_RELATION);
    created(`relación ${PHOTO_MIME}.imagen → directus_files`);
  }

  // 3. Permisos de la política Public.
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
    warn('no se encontró la política Public; no se tocaron los permisos.');
  } else {
    const permissions =
      (await api.get(
        `/permissions${query({
          'filter[policy][_eq]': publicPolicy,
          fields: 'id,collection,action,permissions',
          limit: '-1',
        })}`,
      )) ?? [];
    const onPhotoMime = permissions.filter((p) => p.collection === PHOTO_MIME);
    if (onPhotoMime.length > 0) {
      warn(
        `la política Public tiene ${onPhotoMime.length} permiso(s) sobre "${PHOTO_MIME}" ` +
          `(ids ${onPhotoMime.map((p) => p.id).join(', ')}). La colección no debe ser pública: ` +
          'quítalos en Configuración → Control de acceso → Public. El script no los borra.',
      );
    } else {
      existed(`"${PHOTO_MIME}" sin permisos públicos`);
    }

    const filesRead = permissions.filter(
      (p) => p.collection === 'directus_files' && p.action === 'read',
    );
    const wanted = JSON.stringify(publicFilesFilter(folder.id));
    const ours = filesRead.find((p) => JSON.stringify(p.permissions ?? null) === wanted);
    const others = filesRead.filter((p) => p !== ours);
    if (others.length > 0) {
      warn(
        `la política Public ya puede leer otros archivos (permiso ${others.map((p) => p.id).join(', ')}` +
          `, filtro ${others.map((p) => JSON.stringify(p.permissions)).join(', ')}). ` +
          'Revísalo: solo deberían ser públicos los de la carpeta Fotomímica. El script no lo cambia.',
      );
    }
    if (ours) {
      existed('lectura pública de directus_files solo en la carpeta Fotomímica');
    } else {
      await api.post('/permissions', {
        policy: publicPolicy,
        collection: 'directus_files',
        action: 'read',
        permissions: publicFilesFilter(folder.id),
        validation: null,
        presets: null,
        fields: ['*'],
      });
      created('lectura pública de directus_files solo en la carpeta Fotomímica');
    }
  }
  return summary;
}

function printSummary(summary) {
  console.log('\nResumen');
  console.log(`  Creado (${summary.creado.length}):`);
  for (const c of summary.creado) console.log(`    - ${c}`);
  console.log(`  Ya existía (${summary.existia.length}):`);
  for (const c of summary.existia) console.log(`    - ${c}`);
  if (summary.avisos.length > 0) {
    console.log(`  Avisos (${summary.avisos.length}):`);
    for (const a of summary.avisos) console.log(`    - ${a}`);
  }
}

if (isMain(import.meta.url)) {
  try {
    const config = configFromEnv();
    console.log(`Directus: ${config.url}\n`);
    const summary = await createPhotoMime(directusApi(config), console.log);
    printSummary(summary);
  } catch (e) {
    console.error(`\nNo se pudo terminar: ${e.message}`);
    process.exitCode = 1;
  }
}

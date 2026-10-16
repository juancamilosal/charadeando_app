// Sube en lote las fotos de una carpeta a Fotomímica:
//
//   DIRECTUS_TOKEN=xxx node server/scripts/importar-fotomimica.mjs <carpeta>
//
// - Lee las imágenes .jpg, .jpeg, .png y .webp de la carpeta (no entra en
//   subcarpetas).
// - El nombre sale del archivo: "secador-de-pelo.jpg" → "Secador de pelo".
// - Sube cada foto a la carpeta Fotomímica de directus_files y crea su
//   registro en `fotomimica` como borrador (status draft) y gratis
//   (premium false). Se publican a mano en Directus después de revisarlas.
// - Si ya hay uno con el mismo nombre (sin importar mayúsculas ni tildes),
//   lo salta y lo avisa.
// - Rechaza las fotos de más de 5 MB.
//
// Antes hay que correr crear-fotomimica.mjs. Node 22, sin dependencias.

import { readdir, readFile, stat } from 'node:fs/promises';
import { extname, join } from 'node:path';

import {
  FOLDER_NAME,
  PHOTO_MIME,
  configFromEnv,
  directusApi,
  findFolder,
  isMain,
  query,
} from './directus-api.mjs';

export const MAX_BYTES = 5 * 1024 * 1024;
export const MAX_NAME = 60;

export const IMAGE_TYPES = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
};

/// Tipo de la imagen por su extensión, o null si no es una de las que se
/// suben.
export function imageType(fileName) {
  return IMAGE_TYPES[extname(fileName).toLowerCase()] ?? null;
}

/// "secador-de-pelo.jpg" → "Secador de pelo": guiones y guiones bajos a
/// espacios y la primera letra en mayúscula. Respeta tildes y ñ.
export function nameFromFile(fileName) {
  const base = fileName.slice(0, fileName.length - extname(fileName).length);
  const text = base.normalize('NFC').replace(/[-_]+/g, ' ').replace(/\s+/g, ' ').trim();
  if (!text) return '';
  return text.charAt(0).toLocaleUpperCase('es') + text.slice(1);
}

/// Para comparar nombres sin importar mayúsculas, tildes ni espacios:
/// "Cañón" y "canon" son el mismo. La ñ cuenta como n.
export function nameKey(name) {
  return String(name ?? '')
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

/// Sube las fotos de [dir]. [fs] y [log] se cambian en las pruebas.
/// Devuelve `{ subidas, saltadas, errores }` (listas de textos).
export async function importPhotoMime(
  api,
  dir,
  { log = () => {}, fs = { readdir, readFile, stat } } = {},
) {
  const summary = { subidas: [], saltadas: [], errores: [] };

  const folder = await findFolder(api);
  if (!folder) {
    throw new Error(
      `No existe la carpeta "${FOLDER_NAME}". Corre primero: ` +
        'DIRECTUS_TOKEN=xxx node server/scripts/crear-fotomimica.mjs',
    );
  }

  const existing = (await api.get(
    `/items/${PHOTO_MIME}${query({ fields: 'id,nombre', limit: '-1' })}`,
  )) ?? [];
  const taken = new Map(existing.map((item) => [nameKey(item.nombre), item.nombre]));

  const entries = (await fs.readdir(dir, { withFileTypes: true }))
    .filter((e) => e.isFile() && imageType(e.name))
    .map((e) => e.name)
    .sort((a, b) => a.localeCompare(b, 'es'));
  if (entries.length === 0) {
    log(`No hay imágenes .jpg, .jpeg, .png ni .webp en ${dir}.`);
    return summary;
  }

  for (const fileName of entries) {
    const nombre = nameFromFile(fileName);
    const path = join(dir, fileName);
    try {
      if (!nombre) {
        summary.errores.push(`${fileName}: el nombre del archivo está vacío.`);
        log(`x ${fileName}: el nombre del archivo está vacío.`);
        continue;
      }
      if (nombre.length > MAX_NAME) {
        summary.errores.push(`${fileName}: el nombre tiene más de ${MAX_NAME} caracteres.`);
        log(`x ${fileName}: el nombre tiene más de ${MAX_NAME} caracteres.`);
        continue;
      }
      const key = nameKey(nombre);
      if (taken.has(key)) {
        summary.saltadas.push(`${fileName}: ya existe "${taken.get(key)}".`);
        log(`= ${fileName}: ya existe "${taken.get(key)}", se salta.`);
        continue;
      }
      const { size } = await fs.stat(path);
      if (size > MAX_BYTES) {
        const mb = (size / 1024 / 1024).toFixed(1);
        summary.errores.push(`${fileName}: pesa ${mb} MB (máximo 5 MB).`);
        log(`x ${fileName}: pesa ${mb} MB (máximo 5 MB).`);
        continue;
      }

      const form = new FormData();
      // En Directus los datos van antes que el archivo.
      form.append('folder', folder.id);
      form.append('title', nombre);
      form.append(
        'file',
        new Blob([await fs.readFile(path)], { type: imageType(fileName) }),
        fileName,
      );
      const file = await api.post('/files', form);
      try {
        await api.post(`/items/${PHOTO_MIME}`, {
          status: 'draft',
          nombre,
          imagen: file.id,
          premium: false,
        });
      } catch (e) {
        // Sin registro, la foto subida no sirve: se borra.
        await api.delete(`/files/${file.id}`).catch(() => {});
        throw e;
      }
      taken.set(key, nombre);
      summary.subidas.push(`${fileName} → "${nombre}"`);
      log(`+ ${fileName} → "${nombre}"`);
    } catch (e) {
      summary.errores.push(`${fileName}: ${e.message}`);
      log(`x ${fileName}: ${e.message}`);
    }
  }
  return summary;
}

if (isMain(import.meta.url)) {
  const dir = process.argv[2];
  try {
    if (!dir) {
      throw new Error(
        'Falta la carpeta. Córrelo así: DIRECTUS_TOKEN=xxx node server/scripts/importar-fotomimica.mjs <carpeta>',
      );
    }
    const config = configFromEnv();
    console.log(`Directus: ${config.url}\nCarpeta: ${dir}\n`);
    const summary = await importPhotoMime(directusApi(config), dir, { log: console.log });
    console.log('\nResumen');
    console.log(`  Subidas: ${summary.subidas.length}`);
    console.log(`  Saltadas (ya existían): ${summary.saltadas.length}`);
    console.log(`  Errores: ${summary.errores.length}`);
    for (const e of summary.errores) console.log(`    - ${e}`);
    if (summary.subidas.length > 0) {
      console.log(
        '\nQuedaron como borrador: revísalas en Directus y cámbialas a Publicado para que salgan en el juego.',
      );
    }
    if (summary.errores.length > 0) process.exitCode = 1;
  } catch (e) {
    console.error(`\nNo se pudo terminar: ${e.message}`);
    process.exitCode = 1;
  }
}

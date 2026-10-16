// Ayudas compartidas por los scripts de Fotomímica: hablar con la API REST
// de Directus y los nombres de la colección y la carpeta. Node 22, sin
// dependencias.

import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const DEFAULT_URL = 'https://charadeando-api.valkiriacode.com';

/// Colección de los objetos y carpeta de sus imágenes en directus_files.
export const PHOTO_MIME = 'fotomimica';
export const FOLDER_NAME = 'Fotomímica';

/// Error de Directus con su código HTTP.
export class DirectusError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

/// Lee DIRECTUS_URL y DIRECTUS_TOKEN. El token nunca va en el código: se
/// pasa por variable de entorno al correr el script.
export function configFromEnv(env = process.env) {
  const token = (env.DIRECTUS_TOKEN ?? '').trim();
  if (!token) {
    throw new Error(
      'Falta DIRECTUS_TOKEN. Córrelo así: DIRECTUS_TOKEN=xxx node server/scripts/<script>.mjs',
    );
  }
  const url = (env.DIRECTUS_URL ?? DEFAULT_URL).trim().replace(/\/+$/, '');
  return { url, token };
}

/// Cliente mínimo de la API REST de Directus. Cada método devuelve el
/// `data` de la respuesta (o null si no hay cuerpo) y lanza DirectusError
/// si Directus responde con error.
export function directusApi({ url, token, fetchImpl = fetch }) {
  async function request(method, path, body) {
    const headers = { Authorization: `Bearer ${token}` };
    let payload;
    if (body instanceof FormData) {
      payload = body;
    } else if (body !== undefined) {
      headers['Content-Type'] = 'application/json';
      payload = JSON.stringify(body);
    }
    let response;
    try {
      response = await fetchImpl(`${url}${path}`, { method, headers, body: payload });
    } catch (e) {
      throw new DirectusError(null, `No se pudo conectar con ${url}: ${e.message}`);
    }
    const text = await response.text();
    let json = null;
    if (text) {
      try {
        json = JSON.parse(text);
      } catch {
        json = null;
      }
    }
    if (!response.ok) {
      const detail = json?.errors?.[0]?.message ?? text.slice(0, 200);
      const hint =
        response.status === 401 || response.status === 403
          ? ' (¿el token es de un usuario administrador y está bien copiado?)'
          : '';
      throw new DirectusError(response.status, `${method} ${path}: ${response.status} ${detail}${hint}`);
    }
    return json?.data ?? null;
  }

  return {
    get: (path) => request('GET', path),
    post: (path, body) => request('POST', path, body),
    patch: (path, body) => request('PATCH', path, body),
    delete: (path) => request('DELETE', path),
  };
}

/// `?a=1&b=2` con los valores codificados (filtros con corchetes y tildes).
export function query(params) {
  return `?${new URLSearchParams(params).toString()}`;
}

/// La carpeta Fotomímica (en la raíz de los archivos), o null si no existe.
export async function findFolder(api) {
  const folders = await api.get(
    `/folders${query({
      'filter[name][_eq]': FOLDER_NAME,
      'filter[parent][_null]': 'true',
      fields: 'id,name',
      limit: '1',
    })}`,
  );
  return folders?.[0] ?? null;
}

/// Si el script se está corriendo directamente (y no importado en las
/// pruebas).
export function isMain(importMetaUrl) {
  const script = process.argv[1];
  if (!script) return false;
  return pathToFileURL(resolve(script)).href === importMetaUrl;
}

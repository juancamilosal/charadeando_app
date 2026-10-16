// Pruebas de los scripts de Fotomímica con un Directus de mentira en
// memoria: node --test server/tests/
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createPhotoMime } from '../scripts/crear-fotomimica.mjs';
import { configFromEnv, directusApi } from '../scripts/directus-api.mjs';
import {
  MAX_BYTES,
  imageType,
  importPhotoMime,
  nameFromFile,
  nameKey,
} from '../scripts/importar-fotomimica.mjs';

const PUBLIC = 'politica-public';

/// Lo mínimo de la API de Directus que usan los scripts, en memoria.
function fakeDirectus({ publicPermissions = [], items = [], failItem = false } = {}) {
  const db = {
    folders: [],
    collections: [{ collection: 'palabras' }],
    fields: {},
    relations: [],
    permissions: publicPermissions.map((p, i) => ({ id: 100 + i, policy: PUBLIC, ...p })),
    files: [],
    items: items.map((it, i) => ({ id: i + 1, ...it })),
    calls: [],
  };
  let next = 1;
  const params = (path) => new URL(`http://x${path}`).searchParams;
  const api = {
    async get(path) {
      db.calls.push(`GET ${path.split('?')[0]}`);
      const p = params(path);
      if (path.startsWith('/folders')) {
        return db.folders.filter(
          (f) => f.name === p.get('filter[name][_eq]') && f.parent === null,
        );
      }
      if (path === '/collections') return db.collections;
      if (path.startsWith('/fields/')) return db.fields[path.slice(8)] ?? [];
      if (path.startsWith('/relations/')) {
        return db.relations.filter((r) => r.collection === path.slice(11));
      }
      if (path.startsWith('/access')) return [{ policy: PUBLIC }];
      if (path.startsWith('/permissions')) {
        return db.permissions.filter((x) => x.policy === p.get('filter[policy][_eq]'));
      }
      if (path.startsWith('/items/fotomimica')) return db.items;
      throw new Error(`GET no esperado: ${path}`);
    },
    async post(path, body) {
      db.calls.push(`POST ${path}`);
      if (path === '/folders') {
        const folder = { id: `carpeta-${next++}`, name: body.name, parent: null };
        db.folders.push(folder);
        return folder;
      }
      if (path === '/collections') {
        db.collections.push({ collection: body.collection, meta: body.meta });
        db.fields[body.collection] = body.fields.map((f) => ({ ...f }));
        return {};
      }
      if (path.startsWith('/fields/')) {
        (db.fields[path.slice(8)] ??= []).push(body);
        return body;
      }
      if (path === '/relations') {
        db.relations.push(body);
        return body;
      }
      if (path === '/permissions') {
        const permission = { id: next++, ...body };
        db.permissions.push(permission);
        return permission;
      }
      if (path === '/files') {
        const file = { id: `archivo-${next++}`, folder: body.get('folder'), title: body.get('title') };
        db.files.push(file);
        return file;
      }
      if (path === '/items/fotomimica') {
        if (failItem) throw new Error('falló el registro');
        const item = { id: db.items.length + 1, ...body };
        db.items.push(item);
        return item;
      }
      throw new Error(`POST no esperado: ${path}`);
    },
    async patch(path) {
      throw new Error(`PATCH no esperado: ${path}`);
    },
    async delete(path) {
      db.calls.push(`DELETE ${path}`);
      db.files = db.files.filter((f) => `/files/${f.id}` !== path);
      return null;
    },
  };
  return { api, db };
}

test('crea la carpeta, la colección, la imagen y el permiso; la segunda vez no duplica', async () => {
  const { api, db } = fakeDirectus();
  const first = await createPhotoMime(api);
  assert.equal(first.avisos.length, 0);
  assert.equal(db.folders.length, 1);
  assert.equal(db.folders[0].name, 'Fotomímica');
  const collection = db.collections.find((c) => c.collection === 'fotomimica');
  assert.equal(collection.meta.icon, 'photo_camera');
  assert.equal(collection.meta.display_template, '{{nombre}}');
  assert.equal(collection.meta.archive_field, 'status');
  assert.equal(collection.meta.archive_value, 'draft');
  const fields = Object.fromEntries(db.fields.fotomimica.map((f) => [f.field, f]));
  assert.deepEqual(Object.keys(fields).sort(), ['id', 'imagen', 'nombre', 'premium', 'status']);
  assert.equal(fields.id.schema.has_auto_increment, true);
  assert.equal(fields.status.schema.default_value, 'draft');
  assert.equal(fields.status.meta.required, true);
  assert.deepEqual(
    fields.status.meta.options.choices.map((c) => c.value),
    ['published', 'draft'],
  );
  assert.equal(fields.nombre.schema.max_length, 60);
  assert.equal(fields.nombre.meta.required, true);
  assert.equal(fields.imagen.type, 'uuid');
  assert.equal(fields.imagen.meta.interface, 'file-image');
  assert.equal(fields.imagen.meta.required, true);
  assert.equal(fields.imagen.meta.options.folder, db.folders[0].id);
  assert.equal(fields.premium.schema.default_value, false);
  assert.deepEqual(db.relations, [
    {
      collection: 'fotomimica',
      field: 'imagen',
      related_collection: 'directus_files',
      schema: { on_delete: 'SET NULL' },
    },
  ]);
  // Solo lectura de archivos de la carpeta; nada sobre la colección.
  assert.equal(db.permissions.length, 1);
  assert.deepEqual(
    {
      policy: db.permissions[0].policy,
      collection: db.permissions[0].collection,
      action: db.permissions[0].action,
      permissions: db.permissions[0].permissions,
    },
    {
      policy: PUBLIC,
      collection: 'directus_files',
      action: 'read',
      permissions: { folder: { _eq: db.folders[0].id } },
    },
  );

  const before = JSON.stringify({ ...db, calls: [] });
  const second = await createPhotoMime(api);
  assert.equal(second.creado.length, 0);
  assert.ok(second.existia.length >= 8);
  assert.equal(JSON.stringify({ ...db, calls: [] }), before);
  assert.ok(!db.calls.slice(db.calls.indexOf('GET /folders', 1)).some((c) => c.startsWith('POST')));
});

test('avisa (sin borrar) si la colección o otros archivos ya son públicos', async () => {
  const { api, db } = fakeDirectus({
    publicPermissions: [
      { collection: 'fotomimica', action: 'read', permissions: {} },
      { collection: 'directus_files', action: 'read', permissions: {} },
    ],
  });
  const summary = await createPhotoMime(api);
  assert.equal(summary.avisos.length, 2);
  assert.match(summary.avisos[0], /no debe ser pública/);
  assert.match(summary.avisos[1], /otros archivos/);
  // Los de antes siguen y se agrega el de la carpeta.
  assert.equal(db.permissions.length, 3);
  assert.ok(!db.calls.some((c) => c.startsWith('DELETE')));
});

test('el nombre sale del archivo', () => {
  assert.equal(nameFromFile('secador-de-pelo.jpg'), 'Secador de pelo');
  assert.equal(nameFromFile('cepillo_de_dientes.PNG'), 'Cepillo de dientes');
  assert.equal(nameFromFile('ñame.webp'), 'Ñame');
  assert.equal(nameFromFile('árbol--de__navidad.jpeg'), 'Árbol de navidad');
  assert.equal(nameFromFile('taladro.jpg'), 'Taladro');
  assert.equal(nameFromFile('TV.png'), 'TV');
  assert.equal(nameFromFile('---.png'), '');
});

test('compara nombres sin mayúsculas ni tildes', () => {
  assert.equal(nameKey('Cañón'), nameKey('canon'));
  assert.equal(nameKey(' Secador  de Pelo '), nameKey('secador de pelo'));
  assert.notEqual(nameKey('Taladro'), nameKey('Taladros'));
});

test('solo acepta jpg, jpeg, png y webp', () => {
  assert.equal(imageType('a.JPG'), 'image/jpeg');
  assert.equal(imageType('a.jpeg'), 'image/jpeg');
  assert.equal(imageType('a.png'), 'image/png');
  assert.equal(imageType('a.webp'), 'image/webp');
  assert.equal(imageType('a.gif'), null);
  assert.equal(imageType('notas.txt'), null);
});

/// Una carpeta de mentira: nombre → tamaño en bytes.
function fakeFs(files) {
  const entry = (name, isFile = true) => ({ name, isFile: () => isFile });
  return {
    readdir: async () => [...Object.keys(files).map((n) => entry(n)), entry('subcarpeta', false)],
    stat: async (path) => ({ size: files[path.split('/').pop()] }),
    readFile: async () => Buffer.from('imagen'),
  };
}

test('importa las fotos, salta las repetidas y rechaza las pesadas', async () => {
  const { api, db } = fakeDirectus({ items: [{ nombre: 'Cañón', imagen: 'x' }] });
  await createPhotoMime(api);
  const summary = await importPhotoMime(api, '/fotos', {
    fs: fakeFs({
      'secador-de-pelo.jpg': 1000,
      'canon.png': 1000,
      'llaves.webp': 1000,
      'Llaves.png': 1000,
      'piano.jpg': MAX_BYTES + 1,
      'notas.txt': 10,
    }),
  });
  assert.deepEqual(summary.subidas, [
    'Llaves.png → "Llaves"',
    'secador-de-pelo.jpg → "Secador de pelo"',
  ]);
  assert.equal(summary.saltadas.length, 2);
  assert.match(summary.saltadas.join(' '), /canon\.png: ya existe "Cañón"/);
  assert.match(summary.saltadas.join(' '), /llaves\.webp: ya existe "Llaves"/);
  assert.equal(summary.errores.length, 1);
  assert.match(summary.errores[0], /piano\.jpg: pesa 5\.0 MB/);

  const folder = db.folders[0].id;
  assert.ok(db.files.every((f) => f.folder === folder));
  const added = db.items.slice(1);
  assert.deepEqual(
    added.map(({ status, nombre, premium }) => ({ status, nombre, premium })),
    [
      { status: 'draft', nombre: 'Llaves', premium: false },
      { status: 'draft', nombre: 'Secador de pelo', premium: false },
    ],
  );
  assert.deepEqual(
    added.map((i) => i.imagen),
    db.files.map((f) => f.id),
  );
});

test('si no se puede crear el registro, borra la foto subida', async () => {
  const { api, db } = fakeDirectus({ failItem: true });
  await createPhotoMime(api);
  const summary = await importPhotoMime(api, '/fotos', { fs: fakeFs({ 'taladro.jpg': 10 }) });
  assert.equal(summary.subidas.length, 0);
  assert.equal(summary.errores.length, 1);
  assert.equal(db.files.length, 0);
});

test('sin la carpeta Fotomímica pide correr primero el de creación', async () => {
  const { api } = fakeDirectus();
  await assert.rejects(
    importPhotoMime(api, '/fotos', { fs: fakeFs({}) }),
    /crear-fotomimica\.mjs/,
  );
});

test('el token sale del entorno, nunca del código', () => {
  assert.throws(() => configFromEnv({}), /DIRECTUS_TOKEN/);
  assert.deepEqual(configFromEnv({ DIRECTUS_TOKEN: ' abc ' }), {
    url: 'https://charadeando-api.valkiriacode.com',
    token: 'abc',
  });
  assert.equal(
    configFromEnv({ DIRECTUS_TOKEN: 'a', DIRECTUS_URL: 'http://localhost:8055/' }).url,
    'http://localhost:8055',
  );
});

test('el cliente manda el token y explica los errores', async () => {
  const sent = [];
  const api = directusApi({
    url: 'https://d.test',
    token: 'secreto',
    fetchImpl: async (url, init) => {
      sent.push({ url, init });
      if (url.endsWith('/malo')) {
        return new Response(JSON.stringify({ errors: [{ message: 'Sin permiso' }] }), {
          status: 403,
        });
      }
      return new Response(JSON.stringify({ data: { ok: true } }), { status: 200 });
    },
  });
  assert.deepEqual(await api.post('/folders', { name: 'X' }), { ok: true });
  assert.equal(sent[0].init.headers.Authorization, 'Bearer secreto');
  assert.equal(sent[0].init.headers['Content-Type'], 'application/json');
  await assert.rejects(api.get('/malo'), /403 Sin permiso.*administrador/);
});

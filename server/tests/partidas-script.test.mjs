// Pruebas del script crear-partidas.mjs con un Directus de mentira en
// memoria: node --test server/tests/partidas-script.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { DASHBOARD_NAME, FIELDS, PANELS, createGames, plan } from '../scripts/crear-partidas.mjs';

/// Lo mínimo de la API de Directus que usa el script, en memoria.
function fakeDirectus({ collections = [], dashboards = [], publicPermissions = [] } = {}) {
  const db = { collections, dashboards, panels: [], fields: {}, calls: [] };
  const params = (path) => new URL(`http://x${path}`).searchParams;
  const api = {
    async get(path) {
      db.calls.push(`GET ${path.split('?')[0]}`);
      const p = params(path);
      if (path === '/collections') return db.collections;
      if (path.startsWith('/fields/')) return db.fields[path.slice(8)] ?? [];
      if (path.startsWith('/access')) return [{ policy: 'public' }];
      if (path.startsWith('/permissions')) {
        return publicPermissions.filter((x) => x.collection === p.get('filter[collection][_eq]'));
      }
      if (path.startsWith('/dashboards')) {
        return db.dashboards.filter((d) => d.name === p.get('filter[name][_eq]'));
      }
      throw new Error(`GET no esperado: ${path}`);
    },
    async post(path, body) {
      db.calls.push(`POST ${path}`);
      if (path === '/collections') {
        db.collections.push({ collection: body.collection });
        db.fields[body.collection] = body.fields;
        return body;
      }
      if (path.startsWith('/fields/')) {
        (db.fields[path.slice(8)] ??= []).push(body);
        return body;
      }
      if (path === '/dashboards') {
        const d = { id: 'tablero-1', ...body };
        db.dashboards.push(d);
        return d;
      }
      if (path === '/panels') {
        db.panels.push(body);
        return body;
      }
      throw new Error(`POST no esperado: ${path}`);
    },
  };
  return { api, db };
}

test('los campos no guardan nada que identifique a una persona o al celular', () => {
  const names = FIELDS.map((f) => f.field);
  for (const prohibido of ['ip', 'android_id', 'dispositivo', 'equipos_nombres', 'jugadores', 'nombre']) {
    assert.equal(names.includes(prohibido), false, prohibido);
  }
  for (const campo of ['fecha', 'modo', 'categorias', 'aciertos', 'terminada', 'version_app']) {
    assert.ok(names.includes(campo), campo);
  }
});

test('crea la colección, el tablero y sus paneles', async () => {
  const { api, db } = fakeDirectus();
  const summary = await createGames(api);
  assert.ok(db.collections.some((c) => c.collection === 'partidas'));
  assert.equal(db.dashboards[0].name, DASHBOARD_NAME);
  assert.equal(db.panels.length, PANELS.length);
  assert.ok(db.panels.every((p) => p.dashboard === 'tablero-1' && p.options.collection === 'partidas'));
  assert.equal(summary.avisos.length, 0);
});

test('si ya existe todo, no crea nada', async () => {
  const { api, db } = fakeDirectus({
    collections: [{ collection: 'partidas' }],
    dashboards: [{ id: 'viejo', name: DASHBOARD_NAME }],
  });
  db.fields.partidas = FIELDS;
  const summary = await createGames(api);
  assert.deepEqual(summary.creado, []);
  assert.equal(db.calls.filter((c) => c.startsWith('POST')).length, 0);
});

test('avisa si la colección tiene permisos públicos, sin borrarlos', async () => {
  const { api } = fakeDirectus({ publicPermissions: [{ id: 7, collection: 'partidas' }] });
  const summary = await createGames(api);
  assert.equal(summary.avisos.length, 1);
  assert.match(summary.avisos[0], /no debe ser pública/);
});

test('el plan dice lo que se crearía sin conectarse', () => {
  const text = plan();
  assert.match(text, /Colección "partidas"/);
  assert.match(text, new RegExp(DASHBOARD_NAME));
});

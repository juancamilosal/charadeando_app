// Pruebas de los scripts de las temáticas de Letras con un Directus de
// mentira: node --test server/tests/
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { TOPICS, FIELDS, createTopics } from '../scripts/crear-tematicas.mjs';
import { importTopics, topicProblem } from '../scripts/importar-tematicas.mjs';

function fakeDirectus({ collections = [], items = [] } = {}) {
  const db = { collections: [...collections], fields: {}, items: [...items], posts: [] };
  return {
    db,
    async get(path) {
      if (path === '/collections') return db.collections.map((c) => ({ collection: c }));
      if (path.startsWith('/fields/')) return (db.fields[TOPICS] ?? []).map((f) => ({ field: f }));
      if (path.startsWith('/access')) return [{ policy: 'public' }];
      if (path.startsWith('/permissions')) return [];
      if (path.startsWith(`/items/${TOPICS}`)) return db.items;
      throw new Error(`GET inesperado ${path}`);
    },
    async post(path, body) {
      db.posts.push(path);
      if (path === '/collections') {
        db.collections.push(body.collection);
        db.fields[TOPICS] = body.fields.map((f) => f.field);
        return body;
      }
      if (path === `/fields/${TOPICS}`) {
        (db.fields[TOPICS] ??= []).push(body.field);
        return body;
      }
      if (path === `/items/${TOPICS}`) {
        db.items.push({ id: db.items.length + 1, ...body });
        return body;
      }
      throw new Error(`POST inesperado ${path}`);
    },
  };
}

test('crea la colección letras_tematicas una sola vez', async () => {
  const api = fakeDirectus();
  assert.equal((await createTopics(api)).creado.length, 1);
  assert.deepEqual(api.db.fields[TOPICS], FIELDS.map((f) => f.field));
  assert.equal((await createTopics(api)).creado.length, 0);
});

test('revisa cada temática', () => {
  assert.equal(topicProblem({ tematica: 'Frutas', letras: 'ABCMP' }), null);
  assert.match(topicProblem({ tematica: 'Frutas', letras: 'ABÑ' }), /no se juegan/);
  assert.match(topicProblem({ tematica: 'Frutas', letras: 'ABZ' }), /no se juegan/);
  assert.match(topicProblem({ tematica: 'Frutas', letras: 'abc' }), /mayúscula/);
  assert.match(topicProblem({ tematica: 'Frutas', letras: 'AAB' }), /repetidas/);
  assert.match(topicProblem({ tematica: 'Frutas', letras: 'AB' }), /menos de 3/);
  assert.match(topicProblem({ tematica: '', letras: 'ABC' }), /temática/);
});

test('carga publicadas, en orden y sin repetir', async () => {
  const api = fakeDirectus({ items: [{ id: 1, tematica: 'Frutas' }] });
  const summary = await importTopics(api, [
    { tematica: 'frutas', letras: 'ABC' },
    { tematica: 'Cosas que hay en un baño', letras: 'PCA' },
    { tematica: 'Animales', letras: 'XYZ' },
  ]);
  assert.equal(summary.cargadas.length, 1);
  assert.equal(summary.saltadas.length, 1);
  assert.equal(summary.errores.length, 1);
  assert.deepEqual(api.db.items.at(-1), {
    id: 2,
    status: 'published',
    tematica: 'Cosas que hay en un baño',
    letras: 'ACP',
    premium: false,
  });
});

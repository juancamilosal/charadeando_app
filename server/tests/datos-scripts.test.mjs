// Pruebas de los scripts de "¿Más o menos?" con un Directus de mentira:
// node --test server/tests/
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { FACTS, FIELDS, createFacts } from '../scripts/crear-datos.mjs';
import { factProblem, importFacts, questionKey } from '../scripts/importar-datos.mjs';

/// Lo mínimo de la API que usan los scripts, en memoria.
function fakeDirectus({ collections = [], items = [], publicPermissions = [] } = {}) {
  const db = { collections: [...collections], fields: {}, items: [...items], posts: [] };
  return {
    db,
    async get(path) {
      if (path === '/collections') return db.collections.map((c) => ({ collection: c }));
      if (path.startsWith('/fields/')) return (db.fields[FACTS] ?? []).map((f) => ({ field: f }));
      if (path.startsWith('/access')) return [{ policy: 'public' }];
      if (path.startsWith('/permissions')) return publicPermissions;
      if (path.startsWith(`/items/${FACTS}`)) return db.items;
      throw new Error(`GET inesperado ${path}`);
    },
    async post(path, body) {
      db.posts.push(path);
      if (path === '/collections') {
        db.collections.push(body.collection);
        db.fields[FACTS] = body.fields.map((f) => f.field);
        return body;
      }
      if (path === `/fields/${FACTS}`) {
        (db.fields[FACTS] ??= []).push(body.field);
        return body;
      }
      if (path === `/items/${FACTS}`) {
        db.items.push({ id: db.items.length + 1, ...body });
        return body;
      }
      throw new Error(`POST inesperado ${path}`);
    },
  };
}

const fact = (over = {}) => ({
  pregunta: '¿Cuántas patas tiene una araña?',
  respuesta: 8,
  unidad: 'patas',
  dato_curioso: 'Las arañas no son insectos.',
  categoria: 'Animales',
  dificultad: 'FACIL',
  fuente: 'https://es.wikipedia.org/wiki/Araneae',
  ...over,
});

test('crea la colección datos con todos sus campos, una sola vez', async () => {
  const api = fakeDirectus();
  const first = await createFacts(api);
  assert.equal(first.creado.length, 1);
  assert.deepEqual(api.db.fields[FACTS], FIELDS.map((f) => f.field));
  for (const campo of ['pregunta', 'respuesta', 'unidad', 'dato_curioso', 'categoria', 'dificultad', 'fuente', 'premium']) {
    assert.ok(api.db.fields[FACTS].includes(campo), campo);
  }
  const second = await createFacts(api);
  assert.equal(second.creado.length, 0);
  assert.equal(api.db.posts.filter((p) => p === '/collections').length, 1);
});

test('avisa si la colección tiene permisos públicos, sin borrarlos', async () => {
  const api = fakeDirectus({ collections: [FACTS], publicPermissions: [{ id: 7 }] });
  const summary = await createFacts(api);
  assert.equal(summary.avisos.length, 1);
  assert.match(summary.avisos[0], /no debe ser pública/);
  // Completa los campos que falten en una colección ya creada.
  assert.equal(summary.creado.length, FIELDS.length);
});

test('revisa cada dato antes de cargarlo', () => {
  assert.equal(factProblem(fact()), null);
  assert.match(factProblem(fact({ respuesta: 8.5 })), /entero/);
  assert.match(factProblem(fact({ respuesta: '8' })), /entero/);
  assert.match(factProblem(fact({ dificultad: 'MEDIA' })), /dificultad/);
  assert.match(factProblem(fact({ fuente: 'wikipedia' })), /URL/);
  assert.match(factProblem(fact({ pregunta: ' ' })), /pregunta/);
});

test('carga los datos como borrador y salta los repetidos', async () => {
  const api = fakeDirectus({ items: [{ id: 1, pregunta: '¿Cuántas patas tiene una ARAÑA?' }] });
  const summary = await importFacts(api, [
    fact(),
    fact({ pregunta: '¿En qué año llegó el ser humano a la Luna?', respuesta: 1969, unidad: null, dificultad: 'NORMAL' }),
    fact({ pregunta: '¿Cuántos planetas?', respuesta: 'ocho' }),
  ]);
  assert.equal(summary.cargados.length, 1);
  assert.equal(summary.saltados.length, 1);
  assert.equal(summary.errores.length, 1);
  const nuevo = api.db.items.at(-1);
  assert.equal(nuevo.status, 'draft');
  assert.equal(nuevo.premium, false);
  assert.equal(nuevo.unidad, null);
});

test('con --publicar quedan publicados', async () => {
  const api = fakeDirectus();
  await importFacts(api, [fact()], { publish: true });
  assert.equal(api.db.items[0].status, 'published');
});

test('compara preguntas sin mayúsculas, tildes ni signos', () => {
  assert.equal(questionKey('¿Cuántas patas tiene una araña?'), questionKey('cuantas  PATAS tiene una arana'));
});

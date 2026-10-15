// Pruebas de la extensión charadeando-juego: node --test server/tests/juego.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  codeProblem,
  ensureRedemptions,
  ensureWordsIndex,
  normalizeCode,
  normalizeDevice,
  parseCategorias,
  parseUnlocks,
  quotas,
  restoredUnlocks,
  punishmentsOut,
} from '../directus-extensions/charadeando-juego/index.js';

test('reparte en partes iguales y el sobrante de a una', () => {
  assert.deepEqual(quotas(45, 3), [15, 15, 15]);
  assert.deepEqual(quotas(46, 3), [16, 15, 15]);
  assert.deepEqual(quotas(47, 3), [16, 16, 15]);
  assert.deepEqual(quotas(2, 3), [1, 1, 0]);
});

test('valida la lista de categorías', () => {
  assert.deepEqual(parseCategorias(['ANIMALES', 'PELICULAS']), ['ANIMALES', 'PELICULAS']);
  assert.deepEqual(parseCategorias(['ANIMALES', 'ANIMALES']), ['ANIMALES']);
  assert.equal(parseCategorias('ANIMALES'), null);
  assert.equal(parseCategorias([]), null);
  assert.equal(parseCategorias([1, 2]), null);
  assert.equal(parseCategorias(['x'.repeat(51)]), null);
  assert.equal(parseCategorias(Array.from({ length: 21 }, (_, i) => `C${i}`)), null);
  assert.equal(parseCategorias(Array.from({ length: 20 }, (_, i) => `C${i}`)).length, 20);
});

test('normaliza los códigos y rechaza los raros', () => {
  assert.equal(normalizeCode(' familia 2026 '), 'FAMILIA2026');
  assert.equal(normalizeCode('promo-navidad_1'), 'PROMO-NAVIDAD_1');
  assert.equal(normalizeCode('ab'), null);
  assert.equal(normalizeCode('x'.repeat(41)), null);
  assert.equal(normalizeCode("a'; drop table"), null);
  assert.equal(normalizeCode(42), null);
  assert.equal(normalizeDevice('abc12345-xyz'), 'abc12345-xyz');
  assert.equal(normalizeDevice('corto'), null);
});

test('lee lo que desbloquea un código', () => {
  assert.deepEqual(parseUnlocks('TODO'), { todo: true, categorias: [] });
  assert.deepEqual(parseUnlocks('anime, FUTBOLISTAS,,anime'), {
    todo: false,
    categorias: ['ANIME', 'FUTBOLISTAS'],
  });
  assert.deepEqual(parseUnlocks(null), { todo: false, categorias: [] });
});

test('revisa si un código se puede canjear', () => {
  const now = new Date('2026-10-14T12:00:00Z');
  const base = { codigo: 'FAMILIA', desbloquea: 'TODO', activo: true, usos: 0, usos_max: 2 };
  assert.equal(codeProblem(base, now), null);
  assert.equal(codeProblem(undefined, now)[0], 404);
  assert.equal(codeProblem({ ...base, activo: false }, now)[0], 404);
  assert.equal(codeProblem({ ...base, vence: '2026-10-13' }, now)[0], 410);
  assert.equal(codeProblem({ ...base, vence: '2026-12-31' }, now), null);
  // Vale todo el día en que vence.
  assert.equal(codeProblem({ ...base, vence: '2026-10-14' }, now), null);
  assert.equal(codeProblem({ ...base, vence: '2026-10-14T10:00:00Z' }, now)[0], 410);
  assert.equal(codeProblem({ ...base, usos: 2 }, now)[0], 409);
  // El mismo celular puede volver a canjearlo aunque ya no queden usos.
  assert.equal(codeProblem({ ...base, usos: 2 }, now, true), null);
  // Sin límite de usos.
  assert.equal(codeProblem({ ...base, usos: 999, usos_max: null }, now), null);
  assert.equal(codeProblem({ ...base, desbloquea: '' }, now)[0], 404);
});

test('recupera lo que abren los códigos ya canjeados', () => {
  // Sin canjes.
  assert.deepEqual(restoredUnlocks([]), { todo: false, categorias: [] });
  assert.deepEqual(restoredUnlocks(undefined), { todo: false, categorias: [] });
  // Con categorías de varios códigos, sin repetir.
  assert.deepEqual(
    restoredUnlocks([
      { desbloquea: 'ANIME', activo: true },
      { desbloquea: 'anime, FUTBOLISTAS', activo: true },
    ]),
    { todo: false, categorias: ['ANIME', 'FUTBOLISTAS'] },
  );
  // Con uno que abre todo.
  assert.deepEqual(
    restoredUnlocks([
      { desbloquea: 'ANIME', activo: true },
      { desbloquea: 'TODO', activo: true },
    ]),
    { todo: true, categorias: [] },
  );
  // Un código apagado no cuenta.
  assert.deepEqual(
    restoredUnlocks([
      { desbloquea: 'TODO', activo: false },
      { desbloquea: 'NAVIDAD', activo: true },
    ]),
    { todo: false, categorias: ['NAVIDAD'] },
  );
  // Uno vencido igual se recupera: lo canjeado es de por vida.
  assert.deepEqual(
    restoredUnlocks([{ desbloquea: 'TODO', activo: true, vence: '2020-01-01' }]),
    { todo: true, categorias: [] },
  );
});

test('crea la tabla de canjes solo si no existe', async () => {
  const created = [];
  const fakeDb = (exists) => ({
    schema: {
      hasTable: async () => exists,
      createTable: async (name, build) => {
        const columns = [];
        const col = (kind) => (columnName) => {
          columns.push(`${kind}:${columnName}`);
          const chain = { notNullable: () => chain, index: () => chain };
          return chain;
        };
        build({
          increments: col('id'),
          string: col('string'),
          timestamp: col('timestamp'),
        });
        created.push({ name, columns });
      },
    },
  });
  assert.equal(await ensureRedemptions(fakeDb(true)), false);
  assert.equal(created.length, 0);
  assert.equal(await ensureRedemptions(fakeDb(false)), true);
  assert.deepEqual(created, [
    {
      name: 'codigos_canjes',
      columns: ['id:id', 'string:codigo', 'string:dispositivo', 'timestamp:fecha'],
    },
  ]);
});

test('entrega los castigos sin vacíos ni repetidos', () => {
  assert.deepEqual(
    punishmentsOut([
      { id: 'a', nombre: ' Cantar una canción ' },
      { id: 'b', nombre: 'cantar una  canción' },
      { id: 'c', nombre: '' },
      { id: 'd', nombre: null },
      { id: 'e', nombre: 'Bailar' },
    ]),
    [
      { id: 'a', texto: 'Cantar una canción' },
      { id: 'e', texto: 'Bailar' },
    ],
  );
});

test('crea el índice de palabras sin tocar las palabras', async () => {
  const raws = [];
  await ensureWordsIndex({
    client: { config: { client: 'pg' } },
    raw: async (sql, bindings) => raws.push({ sql, bindings }),
  });
  assert.deepEqual(raws, [
    {
      sql: 'CREATE INDEX IF NOT EXISTS ?? ON ?? (??, ??, ??)',
      bindings: [
        'palabras_categoria_idioma_dificultad',
        'palabras',
        'categoria',
        'idioma',
        'dificultad',
      ],
    },
  ]);
});

test('en MySQL crea el índice y si ya existe no falla', async () => {
  const made = [];
  const mysql = (fail) => ({
    client: { config: { client: 'mysql2' } },
    schema: {
      alterTable: async (name, build) => {
        if (fail) throw Object.assign(new Error('dup'), { code: fail });
        build({ index: (columns, index) => made.push({ name, columns, index }) });
      },
    },
  });
  await ensureWordsIndex(mysql(null));
  assert.deepEqual(made, [
    {
      name: 'palabras',
      columns: ['categoria', 'idioma', 'dificultad'],
      index: 'palabras_categoria_idioma_dificultad',
    },
  ]);
  await ensureWordsIndex(mysql('ER_DUP_KEYNAME'));
  await assert.rejects(ensureWordsIndex(mysql('ER_OTRO')));
});

// Pruebas de la extensión charadeando-juego: node --test server/tests/juego.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  codeProblem,
  normalizeCode,
  normalizeDevice,
  parseCategorias,
  parseUnlocks,
  quotas,
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

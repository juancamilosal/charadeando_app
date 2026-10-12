// Pruebas de la extensión charadeando-juego: node --test server/tests/juego.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { parseCategorias, quotas } from '../directus-extensions/charadeando-juego/index.js';

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

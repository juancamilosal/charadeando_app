// Pruebas de la validación de /juego/partida: node --test server/tests/partida.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { parsePartidaBody } from '../directus-extensions/charadeando-juego/index.js';

/// Una partida válida; cada prueba cambia lo que necesita.
function partida(cambios = {}) {
  return {
    modo: 'NORMAL',
    categorias: ['ANIMALES'],
    dificultad: 'MEZCLADA',
    equipos: 2,
    rondas: 3,
    duracion_turno: 60,
    palabras_jugadas: 30,
    aciertos: 20,
    pases: 8,
    modo_acierto: 'INCLINACION',
    terminada: true,
    video: true,
    version_app: '1.0.0+1',
    ...cambios,
  };
}

test('acepta una partida válida y agrega la categoría para agrupar', () => {
  const row = parsePartidaBody(partida());
  assert.equal(row.error, undefined);
  assert.equal(row.categoria, 'ANIMALES');
  assert.deepEqual(row.categorias, ['ANIMALES']);
  assert.equal(row.terminada, true);
  // La fecha y el id los pone el servidor.
  assert.equal('fecha' in row, false);
  assert.equal('id' in row, false);
});

test('una combinada se agrupa como COMBINADA y puede llevar MIS_CATEGORIAS', () => {
  const row = parsePartidaBody(
    partida({ modo: 'COMBINADA', categorias: ['ANIMALES', 'PELICULAS', 'MIS_CATEGORIAS'] }),
  );
  assert.equal(row.categoria, 'COMBINADA');
  assert.equal(row.categorias.length, 3);
});

test('los modos especiales solo llevan su propio código', () => {
  assert.equal(parsePartidaBody(partida({ modo: 'LIBRE', categorias: ['LIBRE'] })).error, undefined);
  assert.equal(
    parsePartidaBody(partida({ modo: 'FOTOMIMICA', categorias: ['FOTOMIMICA'], dificultad: null })).error,
    undefined,
  );
  assert.equal(
    parsePartidaBody(partida({ modo: 'MIS_CATEGORIAS', categorias: ['MIS_CATEGORIAS'], dificultad: null }))
      .error,
    undefined,
  );
  assert.ok(parsePartidaBody(partida({ modo: 'LIBRE', categorias: ['ANIMALES'] })).error);
  assert.ok(parsePartidaBody(partida({ modo: 'NORMAL', categorias: ['FOTOMIMICA'] })).error);
  assert.ok(parsePartidaBody(partida({ modo: 'COMBINADA', categorias: ['ANIMALES'] })).error);
  assert.ok(parsePartidaBody(partida({ modo: 'NORMAL', categorias: ['ANIMALES', 'MARCAS'] })).error);
});

test('nunca acepta el nombre de una categoría propia', () => {
  for (const nombre of ['Mi familia', 'mis_cosas', 'VIAJE A CARTAGENA', 'ÑANDÚ', '']) {
    assert.ok(
      parsePartidaBody(partida({ modo: 'COMBINADA', categorias: ['ANIMALES', nombre] })).error,
      nombre,
    );
  }
});

test('rechaza campos de más, como nombres, IP o el id del celular', () => {
  for (const campo of ['equipos_nombres', 'ip', 'android_id', 'jugadores', 'fecha', 'id']) {
    const res = parsePartidaBody(partida({ [campo]: 'algo' }));
    assert.match(res.error ?? '', /no permitidos/, campo);
  }
});

test('rechaza cuerpos que no son objetos o a los que les faltan campos', () => {
  for (const body of [null, undefined, 'hola', 3, [partida()]]) {
    assert.ok(parsePartidaBody(body).error);
  }
  const sinModo = partida();
  delete sinModo.modo;
  assert.match(parsePartidaBody(sinModo).error, /Faltan/);
  // La dificultad puede faltar (es null).
  const sinDificultad = partida();
  delete sinDificultad.dificultad;
  assert.equal(parsePartidaBody(sinDificultad).dificultad, null);
});

test('valida los valores permitidos', () => {
  assert.ok(parsePartidaBody(partida({ modo: 'OTRO' })).error);
  assert.ok(parsePartidaBody(partida({ modo_acierto: 'VOZ' })).error);
  assert.ok(parsePartidaBody(partida({ dificultad: 'MUY_DIFICIL' })).error);
  for (const d of [null, 'MEZCLADA', 'FACIL', 'NORMAL', 'DIFICIL']) {
    assert.equal(parsePartidaBody(partida({ dificultad: d })).error, undefined, String(d));
  }
  for (const m of ['INCLINACION', 'TOQUE', 'JUEZ', 'TV']) {
    assert.equal(parsePartidaBody(partida({ modo_acierto: m })).error, undefined, m);
  }
});

test('valida tipos y rangos de los números', () => {
  const malos = [
    { equipos: -1 },
    { equipos: 11 },
    { equipos: '2' },
    { rondas: 0 },
    { rondas: 21 },
    { rondas: 2.5 },
    { duracion_turno: 5 },
    { duracion_turno: 601 },
    { palabras_jugadas: 2001 },
    { aciertos: -3 },
    { pases: null },
    { aciertos: 25, pases: 10, palabras_jugadas: 30 },
  ];
  for (const cambio of malos) {
    assert.ok(parsePartidaBody(partida(cambio)).error, JSON.stringify(cambio));
  }
  // Sin equipos llega 0.
  assert.equal(parsePartidaBody(partida({ equipos: 0 })).error, undefined);
});

test('valida los booleanos y la versión de la app', () => {
  assert.ok(parsePartidaBody(partida({ terminada: 'si' })).error);
  assert.ok(parsePartidaBody(partida({ video: 1 })).error);
  for (const v of ['1.0', 'uno', '1.0.0+abc', '1.0.0 ', 12]) {
    assert.ok(parsePartidaBody(partida({ version_app: v })).error, String(v));
  }
  assert.equal(parsePartidaBody(partida({ version_app: '1.2.3' })).error, undefined);
});

test('rechaza categorías repetidas o demasiadas', () => {
  assert.ok(
    parsePartidaBody(partida({ modo: 'COMBINADA', categorias: ['ANIMALES', 'ANIMALES'] })).error,
  );
  const muchas = Array.from({ length: 21 }, (_, i) => `C${i}`);
  assert.ok(parsePartidaBody(partida({ modo: 'COMBINADA', categorias: muchas })).error);
});

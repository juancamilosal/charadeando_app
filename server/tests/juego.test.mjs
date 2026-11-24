// Pruebas de la extensión charadeando-juego: node --test server/tests/juego.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  LETRAS_JUEGO,
  codeProblem,
  cpuPercent,
  ensureRedemptions,
  ensureWordsIndex,
  normalizeCode,
  normalizeDevice,
  parseMeminfo,
  parseTopicsBody,
  topicLetters,
  topicsOut,
  factsOut,
  parseFactsBody,
  parsePhotoMimeBody,
  photoMimeOut,
  pickAvoiding,
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

test('lee la memoria del servidor de /proc/meminfo', () => {
  const text = [
    'MemTotal:        4000000 kB',
    'MemFree:          500000 kB',
    'MemAvailable:    2500000 kB',
    'SwapTotal:       1000000 kB',
    'SwapFree:         800000 kB',
  ].join('\n');
  assert.deepEqual(parseMeminfo(text), {
    total: 4000000 * 1024,
    disponible: 2500000 * 1024,
    swapTotal: 1000000 * 1024,
    swapUsada: 200000 * 1024,
  });
  assert.equal(parseMeminfo(''), null);
  assert.equal(parseMeminfo('MemTotal: 10 kB'), null);
});

test('calcula el uso de CPU entre dos lecturas', () => {
  const cpu = (user, idle) => ({ times: { user, nice: 0, sys: 0, idle, irq: 0 } });
  // Un núcleo trabajó 30 de 100 y el otro 70 de 100: 50 % en total.
  assert.equal(cpuPercent([cpu(0, 0), cpu(0, 0)], [cpu(30, 70), cpu(70, 30)]), 50);
  assert.equal(cpuPercent([cpu(5, 5)], [cpu(5, 5)]), 0);
});

test('valida el pedido de Fotomímica', () => {
  assert.deepEqual(parsePhotoMimeBody({ n: 5 }), { n: 5, excluir: [], incluirPremium: false });
  assert.deepEqual(parsePhotoMimeBody({}), { n: 10, excluir: [], incluirPremium: false });
  assert.deepEqual(parsePhotoMimeBody({ n: 100, excluir: [1, '2'], incluir_premium: true }), {
    n: 100,
    excluir: [1, 2],
    incluirPremium: true,
  });
  assert.ok(parsePhotoMimeBody({ n: 0 }).error);
  assert.ok(parsePhotoMimeBody({ n: 101 }).error);
  assert.ok(parsePhotoMimeBody({ n: 2.5 }).error);
  assert.ok(parsePhotoMimeBody({ n: 5, excluir: 'x' }).error);
  assert.ok(parsePhotoMimeBody({ n: 5, excluir: ['abc'] }).error);
  assert.ok(parsePhotoMimeBody({ n: 5, excluir: Array.from({ length: 501 }, (_, i) => i) }).error);
  assert.ok(parsePhotoMimeBody({ n: 5, incluir_premium: 'si' }).error);
});

test('Fotomímica: primero las no jugadas y solo repite si no alcanzan', async () => {
  const all = [1, 2, 3, 4, 5].map((id) => ({ id }));
  const query = async ({ excluir, tomadas, limit }) =>
    all.filter((r) => !excluir.includes(r.id) && !tomadas.includes(r.id)).slice(0, limit);
  // Alcanzan las no jugadas: no vuelve ninguna jugada.
  assert.deepEqual((await pickAvoiding(query, 3, [1, 2])).map((r) => r.id), [3, 4, 5]);
  // No alcanzan: se completa con las jugadas, sin repetir dentro del lote.
  assert.deepEqual((await pickAvoiding(query, 5, [1, 2])).map((r) => r.id), [3, 4, 5, 1, 2]);
  // Pide más de las que hay: entrega todas una sola vez.
  assert.deepEqual((await pickAvoiding(query, 9, [5])).map((r) => r.id), [1, 2, 3, 4, 5]);
});

test('Fotomímica: entrega id, nombre, imagen y premium', () => {
  assert.deepEqual(
    photoMimeOut([
      { id: 1, nombre: ' Taladro ', imagen: 'f1', premium: false },
      { id: 2, nombre: 'Llaves', imagen: 'f2', premium: true },
      { id: 3, nombre: '', imagen: 'f3', premium: false },
      { id: 4, nombre: 'Sin foto', imagen: null, premium: false },
      { id: 5, nombre: 'Peine', imagen: 'f5', premium: null },
    ]),
    [
      { id: 1, nombre: 'Taladro', imagen: 'f1', premium: false },
      { id: 2, nombre: 'Llaves', imagen: 'f2', premium: true },
      { id: 5, nombre: 'Peine', imagen: 'f5', premium: false },
    ],
  );
});

test('valida el pedido de ¿Más o menos?', () => {
  assert.deepEqual(parseFactsBody({}), { n: 20, excluir: [], dificultad: null, incluirPremium: false });
  assert.deepEqual(parseFactsBody({ n: 30, excluir: [3, '4'], dificultad: 'FACIL' }), {
    n: 30,
    excluir: [3, 4],
    dificultad: 'FACIL',
    incluirPremium: false,
  });
  // Mezclada es lo mismo que sin dificultad: de todas.
  assert.equal(parseFactsBody({ dificultad: 'MEZCLADA' }).dificultad, null);
  assert.ok(parseFactsBody({ n: 0 }).error);
  assert.ok(parseFactsBody({ n: 101 }).error);
  assert.ok(parseFactsBody({ dificultad: 'MUY_FACIL' }).error);
  assert.ok(parseFactsBody({ excluir: ['x'] }).error);
  assert.ok(parseFactsBody({ incluir_premium: 1 }).error);
});

test('¿Más o menos?: entrega solo datos con pregunta y respuesta entera', () => {
  assert.deepEqual(
    factsOut([
      {
        id: 1,
        pregunta: ' ¿Cuántas patas tiene una araña? ',
        respuesta: '8',
        unidad: 'patas',
        dato_curioso: 'Las arañas no son insectos.',
        categoria: 'Animales',
        dificultad: 'FACIL',
      },
      { id: 2, pregunta: '', respuesta: 5 },
      { id: 3, pregunta: '¿Qué tan alto es?', respuesta: 8848.86 },
      { id: 4, pregunta: '¿Año de la Luna?', respuesta: 1969, unidad: '' },
    ]),
    [
      {
        id: 1,
        pregunta: '¿Cuántas patas tiene una araña?',
        respuesta: 8,
        unidad: 'patas',
        dato_curioso: 'Las arañas no son insectos.',
        categoria: 'Animales',
        dificultad: 'FACIL',
      },
      {
        id: 4,
        pregunta: '¿Año de la Luna?',
        respuesta: 1969,
        unidad: null,
        dato_curioso: null,
        categoria: null,
        dificultad: null,
      },
    ],
  );
});

test('Letras: valida el pedido de temáticas', () => {
  assert.deepEqual(parseTopicsBody({}), { n: 100, excluir: [], incluirPremium: false });
  assert.deepEqual(parseTopicsBody({ n: 5, excluir: [1, '2'], incluir_premium: true }), {
    n: 5,
    excluir: [1, 2],
    incluirPremium: true,
  });
  for (const body of [{ n: 0 }, { n: 201 }, { n: 1.5 }, { excluir: 'x' }, { excluir: ['a'] }, { incluir_premium: 'si' }]) {
    assert.ok(parseTopicsBody(body).error, JSON.stringify(body));
  }
});

test('Letras: las letras de una temática nunca traen Ñ, W, X ni Z', () => {
  assert.equal(LETRAS_JUEGO.join(''), 'ABCDEFGHIJKLMNOPQRSTUVY');
  assert.equal(topicLetters('pstabc'), 'ABCPST');
  assert.equal(topicLetters('A, B, B, ñ, w, x, z'), 'AB');
  // Sin letras válidas, todas las del juego.
  assert.equal(topicLetters('ÑWXZ'), LETRAS_JUEGO.join(''));
  assert.equal(topicLetters(null), LETRAS_JUEGO.join(''));
});

test('Letras: entrega temáticas sin vacías ni repetidas', () => {
  assert.deepEqual(
    topicsOut([
      { id: 1, tematica: ' Cosas que hay en un baño ', letras: 'abcz' },
      { id: 2, tematica: 'cosas que hay en un BAÑO', letras: 'p' },
      { id: 3, tematica: '', letras: 'a' },
      { id: 4, tematica: 'Frutas', letras: null },
    ]),
    [
      { id: 1, tematica: 'Cosas que hay en un baño', letras: 'ABC' },
      { id: 4, tematica: 'Frutas', letras: LETRAS_JUEGO.join('') },
    ],
  );
});

// Crea en Directus lo que necesitan las estadísticas anónimas de las
// partidas:
//
//   1. La colección `partidas` (no pública), que llena la ruta
//      POST /juego/partida de la extensión.
//   2. El panel de Insights "Estadísticas de Charadeando".
//
// Se puede correr varias veces: lo que ya existe lo deja igual y lo dice.
// No borra ni cambia nada que ya exista. Con --mostrar solo dice lo que
// crearía, sin conectarse.
//
//   DIRECTUS_TOKEN=xxx node server/scripts/crear-partidas.mjs
//   node server/scripts/crear-partidas.mjs --mostrar
//
// DIRECTUS_URL cambia el servidor (por defecto el de Charadeando). Node 22,
// sin dependencias.

import { configFromEnv, directusApi, isMain, query } from './directus-api.mjs';

export const GAMES = 'partidas';
export const DASHBOARD_NAME = 'Estadísticas de Charadeando';

/// Desplegable con los valores permitidos.
function choices(values) {
  return { choices: values.map((v) => ({ text: v, value: v })) };
}

/// Número entero de solo lectura en el panel (lo escribe la ruta).
function integer(field, note) {
  return {
    field,
    type: 'integer',
    meta: { interface: 'input', readonly: true, width: 'half', note },
    schema: { is_nullable: false, default_value: 0 },
  };
}

/// Sí o no, de solo lectura.
function boolean(field, note) {
  return {
    field,
    type: 'boolean',
    meta: { interface: 'boolean', special: ['cast-boolean'], readonly: true, width: 'half', note },
    schema: { is_nullable: false, default_value: false },
  };
}

/// Texto corto de solo lectura, con desplegable si tiene valores fijos.
function string(field, maxLength, note, values, nullable = false) {
  return {
    field,
    type: 'string',
    meta: {
      interface: values ? 'select-dropdown' : 'input',
      options: values ? choices(values) : null,
      readonly: true,
      width: 'half',
      note,
    },
    schema: { max_length: maxLength, is_nullable: nullable },
  };
}

/// Campos de la colección. Ninguno identifica a una persona ni al celular:
/// sin IP, sin ANDROID_ID, sin nombres de equipos ni de jugadores.
export const FIELDS = [
  {
    field: 'id',
    type: 'integer',
    meta: { hidden: true, interface: 'input', readonly: true },
    schema: { is_primary_key: true, has_auto_increment: true },
  },
  {
    field: 'fecha',
    type: 'timestamp',
    meta: {
      interface: 'datetime',
      display: 'datetime',
      readonly: true,
      width: 'half',
      note: 'La pone el servidor al recibir la partida.',
    },
    schema: { is_nullable: false },
  },
  string('modo', 20, 'Cómo se jugó.', ['NORMAL', 'LIBRE', 'COMBINADA', 'MIS_CATEGORIAS', 'FOTOMIMICA']),
  string(
    'categoria',
    40,
    'La categoría jugada, o COMBINADA si fueron varias. Sirve para agrupar en Insights.',
  ),
  {
    field: 'categorias',
    type: 'json',
    meta: {
      interface: 'tags',
      display: 'labels',
      readonly: true,
      width: 'half',
      note: 'Códigos de las categorías. Las propias del usuario llegan solo como MIS_CATEGORIAS.',
    },
    schema: { is_nullable: false },
  },
  string(
    'dificultad',
    10,
    'MEZCLADA, FACIL, NORMAL o DIFICIL; vacía si las palabras no tienen dificultad.',
    ['MEZCLADA', 'FACIL', 'NORMAL', 'DIFICIL'],
    true,
  ),
  integer('equipos', 'Cantidad de equipos (0 = sin equipos).'),
  integer('rondas', 'Rondas configuradas.'),
  integer('duracion_turno', 'Segundos por turno.'),
  integer('palabras_jugadas', 'Palabras que salieron en todos los turnos.'),
  integer('aciertos', 'Palabras acertadas.'),
  integer('pases', 'Palabras pasadas.'),
  string('modo_acierto', 15, 'Cómo se marcaron los aciertos.', ['INCLINACION', 'TOQUE', 'JUEZ', 'TV']),
  boolean('terminada', 'Llegaron al resultado final (si no, la abandonaron después de un turno).'),
  boolean('video', 'Se grabó el video de los turnos.'),
  string('version_app', 20, 'Versión de la app, como 1.0.0+1.'),
];

export const COLLECTION_META = {
  icon: 'insights',
  note: 'Estadísticas anónimas de las partidas de Charadeando. Las escribe /juego/partida.',
  display_template: '{{modo}} · {{categoria}}',
  sort_field: null,
};

/// Últimos 30 días, para los paneles que lo piden.
export const LAST_30_DAYS = { _and: [{ fecha: { _gte: '$NOW(-30 days)' } }] };

export const DASHBOARD = {
  name: DASHBOARD_NAME,
  icon: 'insights',
  note: 'Qué categorías y modos se juegan más. Datos anónimos de /juego/partida.',
  color: '#6A1BE0',
};

/// Paneles del tablero, en una cuadrícula de 2 columnas de 24.
export const PANELS = [
  {
    name: 'Partidas (últimos 30 días)',
    icon: 'sports_esports',
    type: 'metric',
    position_x: 1,
    position_y: 1,
    width: 16,
    height: 8,
    options: { collection: GAMES, field: 'id', function: 'count', filter: LAST_30_DAYS },
  },
  {
    name: 'Partidas terminadas y abandonadas',
    icon: 'flag',
    type: 'pie-chart',
    position_x: 17,
    position_y: 1,
    width: 16,
    height: 16,
    options: {
      collection: GAMES,
      column: 'terminada',
      function: 'count',
      donut: true,
      showLabels: true,
      legend: 'bottom',
    },
  },
  {
    name: 'Partidas por modo',
    icon: 'category',
    type: 'pie-chart',
    position_x: 33,
    position_y: 1,
    width: 16,
    height: 16,
    options: { collection: GAMES, column: 'modo', function: 'count', showLabels: true, legend: 'bottom' },
  },
  {
    name: 'Partidas por día',
    icon: 'calendar_month',
    type: 'time-series',
    position_x: 1,
    position_y: 17,
    width: 48,
    height: 14,
    options: {
      collection: GAMES,
      dateField: 'fecha',
      valueField: 'id',
      function: 'count',
      precision: 'day',
      range: '1 month',
      decimals: 0,
    },
  },
  {
    name: 'Partidas por categoría (últimos 30 días)',
    icon: 'bar_chart',
    type: 'bar-chart',
    position_x: 1,
    position_y: 31,
    width: 24,
    height: 18,
    options: {
      collection: GAMES,
      xAxis: 'categoria',
      yAxis: 'id',
      function: 'count',
      horizontal: true,
      decimals: 0,
      filter: LAST_30_DAYS,
    },
  },
  {
    name: 'Promedio de aciertos por categoría',
    icon: 'check_circle',
    type: 'bar-chart',
    position_x: 25,
    position_y: 31,
    width: 24,
    height: 18,
    options: {
      collection: GAMES,
      xAxis: 'categoria',
      yAxis: 'aciertos',
      function: 'avg',
      horizontal: true,
      decimals: 1,
    },
  },
];

/// Hace todo y devuelve qué creó, qué ya existía y los avisos. [log]
/// recibe cada paso.
export async function createGames(api, log = () => {}) {
  const summary = { creado: [], existia: [], avisos: [] };
  const created = (what) => {
    summary.creado.push(what);
    log(`+ Creado: ${what}`);
  };
  const existed = (what) => {
    summary.existia.push(what);
    log(`= Ya existía: ${what}`);
  };
  const warn = (what) => {
    summary.avisos.push(what);
    log(`! Aviso: ${what}`);
  };

  // 1. Colección y campos.
  const collections = await api.get('/collections');
  const exists = (collections ?? []).some((c) => c.collection === GAMES);
  if (!exists) {
    await api.post('/collections', { collection: GAMES, meta: COLLECTION_META, schema: {}, fields: FIELDS });
    created(`colección "${GAMES}" con ${FIELDS.map((f) => f.field).join(', ')}`);
  } else {
    existed(`colección "${GAMES}"`);
    const fields = new Set(((await api.get(`/fields/${GAMES}`)) ?? []).map((f) => f.field));
    for (const field of FIELDS) {
      if (fields.has(field.field)) continue;
      await api.post(`/fields/${GAMES}`, field);
      created(`campo ${GAMES}.${field.field}`);
    }
  }

  // Que no sea pública: solo se avisa, no se borra nada.
  const access = await api.get(
    `/access${query({
      'filter[role][_null]': 'true',
      'filter[user][_null]': 'true',
      fields: 'policy',
      limit: '-1',
    })}`,
  );
  const publicPolicy = access?.[0]?.policy;
  if (publicPolicy) {
    const permissions =
      (await api.get(
        `/permissions${query({
          'filter[policy][_eq]': publicPolicy,
          'filter[collection][_eq]': GAMES,
          fields: 'id',
          limit: '-1',
        })}`,
      )) ?? [];
    if (permissions.length > 0) {
      warn(
        `la política Public tiene permisos sobre "${GAMES}" (ids ${permissions.map((p) => p.id).join(', ')}). ` +
          'La colección no debe ser pública: quítalos en Configuración → Control de acceso → Public.',
      );
    } else {
      existed(`"${GAMES}" sin permisos públicos`);
    }
  }

  // 2. Tablero de Insights con sus paneles.
  const dashboards =
    (await api.get(
      `/dashboards${query({ 'filter[name][_eq]': DASHBOARD_NAME, fields: 'id', limit: '1' })}`,
    )) ?? [];
  if (dashboards.length > 0) {
    existed(`tablero "${DASHBOARD_NAME}" (no se tocan sus paneles)`);
  } else {
    const dashboard = await api.post('/dashboards', DASHBOARD);
    created(`tablero "${DASHBOARD_NAME}"`);
    for (const panel of PANELS) {
      await api.post('/panels', { ...panel, dashboard: dashboard.id, show_header: true });
      created(`panel "${panel.name}"`);
    }
  }
  return summary;
}

/// Lo que crearía, para revisarlo antes de correrlo de verdad.
export function plan() {
  return [
    `Colección "${GAMES}" (no pública) con los campos:`,
    ...FIELDS.map((f) => `  - ${f.field} (${f.type})${f.meta?.note ? `: ${f.meta.note}` : ''}`),
    `Tablero de Insights "${DASHBOARD_NAME}" con los paneles:`,
    ...PANELS.map((p) => `  - ${p.name} (${p.type})`),
  ].join('\n');
}

function printSummary(summary) {
  console.log('\nResumen');
  console.log(`  Creado (${summary.creado.length}):`);
  for (const c of summary.creado) console.log(`    - ${c}`);
  console.log(`  Ya existía (${summary.existia.length}):`);
  for (const c of summary.existia) console.log(`    - ${c}`);
  if (summary.avisos.length > 0) {
    console.log(`  Avisos (${summary.avisos.length}):`);
    for (const a of summary.avisos) console.log(`    - ${a}`);
  }
}

if (isMain(import.meta.url)) {
  if (process.argv.includes('--mostrar')) {
    console.log(plan());
  } else {
    try {
      const config = configFromEnv();
      console.log(`Directus: ${config.url}\n`);
      printSummary(await createGames(directusApi(config), console.log));
    } catch (e) {
      console.error(`\nNo se pudo terminar: ${e.message}`);
      process.exitCode = 1;
    }
  }
}

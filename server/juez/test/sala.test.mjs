// Pruebas del modo "Celular juez": node --test test/
import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  ALFABETO,
  INACTIVIDAD_MS,
  MAX_MENSAJE,
  huella,
  iguales,
  leerMensaje,
  limitar,
  normalizarCodigo,
  nuevoCodigo,
  nuevoToken,
} from '../src/logica.js';
import { paginaInicio, paginaJuez } from '../src/pagina.js';
import { CIERRES, SalaCore } from '../src/sala.js';

/// Una sala con almacenamiento y WebSockets de mentira.
function salaDePrueba() {
  const datos = new Map();
  const conexiones = [];
  let ahora = 1_000_000;
  const alarmas = [];
  const storage = {
    async get(clave) {
      return structuredClone(datos.get(clave));
    },
    async put(clave, valor) {
      if (typeof clave === 'object') {
        for (const [k, v] of Object.entries(clave)) datos.set(k, structuredClone(v));
      } else {
        datos.set(clave, structuredClone(valor));
      }
    },
    async deleteAll() {
      datos.clear();
    },
    async setAlarm(t) {
      alarmas.push(t);
    },
    async deleteAlarm() {
      alarmas.push(null);
    },
  };
  const core = new SalaCore({
    storage,
    sockets: (rol) => conexiones.filter((w) => w.rol === rol && w.abierto),
    adjunto: (w) => w.adjunto,
    guardarAdjunto: (w, a) => {
      w.adjunto = structuredClone(a);
    },
    ahora: () => ahora,
  });
  /// Conecta como [rol]; devuelve el socket (aceptado o rechazado).
  async function conectar(rol, token) {
    const ws = {
      rol,
      abierto: true,
      enviados: [],
      cierre: null,
      adjunto: null,
      send(t) {
        this.enviados.push(JSON.parse(t));
      },
      close(codigo, razon) {
        this.abierto = false;
        this.cierre = { codigo, razon };
      },
      ultimo(tipo) {
        return [...this.enviados].reverse().find((m) => !tipo || m.tipo === tipo);
      },
    };
    const rechazo = await core.admitir(rol, token);
    if (rechazo) {
      ws.rol = 'rechazado';
      core.rechazar(ws, rechazo);
    } else {
      conexiones.push(ws);
      await core.conectado(ws, rol);
    }
    return ws;
  }
  function cerrar(ws) {
    ws.abierto = false;
    core.cerrado(ws);
  }
  return {
    core,
    datos,
    alarmas,
    conectar,
    cerrar,
    avanzar: (ms) => {
      ahora += ms;
    },
  };
}

async function salaCreada() {
  const sala = salaDePrueba();
  const token = nuevoToken();
  assert.equal(await sala.core.iniciar(await huella(token)), true);
  return { ...sala, token };
}

const estado = (extra = {}) =>
  JSON.stringify({
    tipo: 'estado',
    palabra: 'Jirafa',
    categoria: 'Animales',
    segundos: 42,
    equipo: 'Los Tigres',
    puntos: 3,
    estado: 'jugando',
    ...extra,
  });

const accion = (accion, id) => JSON.stringify({ tipo: 'accion', accion, id });

test('el código tiene 6 letras sin las que se confunden', () => {
  for (let i = 0; i < 500; i++) {
    const codigo = nuevoCodigo();
    assert.match(codigo, /^[2-9A-HJKMNP-Z]{6}$/);
    assert.doesNotMatch(codigo, /[01OIL]/);
  }
  assert.ok(!/[01OIL]/.test(ALFABETO));
  assert.equal(normalizarCodigo(' abc234 '), 'ABC234');
  assert.equal(normalizarCodigo('ABC23O'), null);
  assert.equal(normalizarCodigo('ABC2'), null);
  assert.equal(normalizarCodigo(null), null);
});

test('el token es largo y al azar; la sala guarda solo su huella', async () => {
  const a = nuevoToken();
  const b = nuevoToken();
  assert.equal(a.length, 43);
  assert.notEqual(a, b);
  assert.match(a, /^[A-Za-z0-9_-]+$/);
  const { datos, token } = await salaCreada();
  assert.equal(datos.get('huella'), await huella(token));
  assert.ok(![...datos.values()].includes(token));
  assert.equal(iguales('abc', 'abc'), true);
  assert.equal(iguales('abc', 'abd'), false);
  assert.equal(iguales('abc', 'abcd'), false);
});

test('un código ya usado no se vuelve a crear', async () => {
  const { core } = await salaCreada();
  assert.equal(await core.iniciar(await huella('otro')), false);
});

test('el anfitrión necesita su token; el juez, no', async () => {
  const { conectar, token } = await salaCreada();
  const sin = await conectar('anfitrion');
  assert.deepEqual(sin.cierre, { codigo: CIERRES.token.codigo, razon: 'token_invalido' });
  const malo = await conectar('anfitrion', nuevoToken());
  assert.equal(malo.cierre.codigo, CIERRES.token.codigo);
  const bueno = await conectar('anfitrion', token);
  assert.equal(bueno.cierre, null);
  assert.deepEqual(bueno.enviados[0], { tipo: 'bienvenida', rol: 'anfitrion' });
  const juez = await conectar('juez');
  assert.equal(juez.cierre, null);
  const raro = await conectar('admin');
  assert.equal(raro.cierre.codigo, CIERRES.rol.codigo);
});

test('una sala que no existe se cierra con su motivo', async () => {
  const { conectar } = salaDePrueba();
  const juez = await conectar('juez');
  assert.deepEqual(juez.enviados, [{ tipo: 'error', codigo: 'sala_no_existe' }]);
  assert.equal(juez.cierre.codigo, 4404);
});

test('máximo 2 jueces, y el anfitrión sabe cuántos hay', async () => {
  const { conectar, cerrar, token } = await salaCreada();
  const anfitrion = await conectar('anfitrion', token);
  assert.deepEqual(anfitrion.ultimo('jueces'), { tipo: 'jueces', cantidad: 0 });
  const j1 = await conectar('juez');
  assert.deepEqual(anfitrion.ultimo('jueces'), { tipo: 'jueces', cantidad: 1 });
  await conectar('juez');
  assert.deepEqual(anfitrion.ultimo('jueces'), { tipo: 'jueces', cantidad: 2 });
  const tercero = await conectar('juez');
  assert.equal(tercero.cierre.codigo, CIERRES.llena.codigo);
  assert.deepEqual(tercero.enviados, [{ tipo: 'error', codigo: 'sala_llena' }]);
  cerrar(j1);
  assert.deepEqual(anfitrion.ultimo('jueces'), { tipo: 'jueces', cantidad: 1 });
  // Con un lugar libre, entra otro.
  assert.equal((await conectar('juez')).cierre, null);
});

test('estado y acciones de punta a punta', async () => {
  const { core, conectar, token } = await salaCreada();
  const anfitrion = await conectar('anfitrion', token);
  const j1 = await conectar('juez');
  await core.mensaje(anfitrion, estado());
  assert.equal(j1.ultimo().palabra, 'Jirafa');
  assert.equal(j1.ultimo().estado, 'jugando');
  // Uno que entra después recibe el último estado.
  const j2 = await conectar('juez');
  assert.equal(j2.ultimo('estado').segundos, 42);

  await core.mensaje(j1, accion('acierto', 'a1'));
  assert.deepEqual(anfitrion.ultimo(), { tipo: 'accion', accion: 'acierto', id: 'a1' });
  // Reenviada con el mismo id: no se repite.
  const antes = anfitrion.enviados.length;
  await core.mensaje(j1, accion('acierto', 'a1'));
  assert.equal(anfitrion.enviados.length, antes);
  await core.mensaje(j2, accion('pasar', 'p1'));
  assert.deepEqual(anfitrion.ultimo(), { tipo: 'accion', accion: 'pasar', id: 'p1' });
});

test('el juez no puede mandar estado ni el anfitrión acciones', async () => {
  const { core, conectar, token } = await salaCreada();
  const anfitrion = await conectar('anfitrion', token);
  const juez = await conectar('juez');
  await core.mensaje(juez, estado({ palabra: 'Trampa' }));
  assert.equal(juez.ultimo().tipo, 'error');
  assert.equal(juez.ultimo().codigo, 'mensaje_invalido');
  await core.mensaje(anfitrion, accion('acierto', 'x1'));
  assert.equal(anfitrion.ultimo().codigo, 'mensaje_invalido');
  assert.equal(juez.enviados.filter((m) => m.tipo === 'estado').length, 0);
});

test('mensajes inválidos se rechazan sin cerrar la conexión', async () => {
  for (const [crudo, rol] of [
    ['no es json', 'juez'],
    ['[]', 'juez'],
    [JSON.stringify({ tipo: 'accion', accion: 'borrar', id: '1' }), 'juez'],
    [JSON.stringify({ tipo: 'accion', accion: 'acierto' }), 'juez'],
    [JSON.stringify({ tipo: 'accion', accion: 'acierto', id: 'x'.repeat(41) }), 'juez'],
    [JSON.stringify({ tipo: 'accion', accion: 'acierto', id: '1', extra: 1 }), 'juez'],
    [estado({ estado: 'ganando' }), 'anfitrion'],
    [estado({ segundos: -1 }), 'anfitrion'],
    [estado({ segundos: 1.5 }), 'anfitrion'],
    [estado({ palabra: 'x'.repeat(121) }), 'anfitrion'],
    [estado({ nombre: 'Ana' }), 'anfitrion'],
    [JSON.stringify({ tipo: 'estado', palabra: 'Sin tiempo' }), 'anfitrion'],
    ['x'.repeat(MAX_MENSAJE + 1), 'juez'],
    [new Uint8Array([1, 2]), 'juez'],
  ]) {
    assert.ok(leerMensaje(crudo, rol).error, String(crudo).slice(0, 60));
  }
  assert.deepEqual(leerMensaje(accion('pasar', 'abc-1_2'), 'juez'), {
    tipo: 'accion',
    accion: 'pasar',
    id: 'abc-1_2',
  });
  const ok = leerMensaje(estado({ palabra: null, aciertos: 2, pasadas: 1 }), 'anfitrion');
  assert.equal(ok.tipo, 'estado');
  assert.equal(ok.palabra, null);

  const { core, conectar } = await salaCreada();
  const juez = await conectar('juez');
  await core.mensaje(juez, '{malo');
  assert.equal(juez.ultimo().codigo, 'mensaje_invalido');
  assert.equal(juez.cierre, null);
});

test('más de 4 acciones por segundo de un juez se ignoran', async () => {
  const { core, conectar, token, avanzar } = await salaCreada();
  const anfitrion = await conectar('anfitrion', token);
  const juez = await conectar('juez');
  for (let i = 0; i < 7; i++) await core.mensaje(juez, accion('acierto', `r${i}`));
  assert.equal(anfitrion.enviados.filter((m) => m.tipo === 'accion').length, 4);
  avanzar(1000);
  await core.mensaje(juez, accion('acierto', 'r9'));
  assert.equal(anfitrion.enviados.filter((m) => m.tipo === 'accion').length, 5);
  const v = limitar(null, 0, 2);
  assert.equal(v.acepta, true);
});

test('si se reconecta el anfitrión, el anterior se cierra', async () => {
  const { conectar, token } = await salaCreada();
  const viejo = await conectar('anfitrion', token);
  const nuevo = await conectar('anfitrion', token);
  assert.equal(viejo.cierre.codigo, CIERRES.reemplazado.codigo);
  assert.equal(nuevo.cierre, null);
});

test('una acción sin anfitrión conectado avisa al juez', async () => {
  const { core, conectar } = await salaCreada();
  const juez = await conectar('juez');
  await core.mensaje(juez, accion('acierto', 'solo'));
  assert.deepEqual(juez.ultimo(), { tipo: 'aviso', codigo: 'sin_anfitrion' });
});

test('se borra sola tras 3 horas sin actividad, no antes', async () => {
  const { core, conectar, datos, alarmas, avanzar, token } = await salaCreada();
  assert.equal(alarmas.length, 1);
  const anfitrion = await conectar('anfitrion', token);
  const juez = await conectar('juez');
  avanzar(2 * 60 * 60 * 1000);
  await core.mensaje(anfitrion, estado());
  avanzar(60 * 60 * 1000 + 1);
  // Hubo actividad hace 1 hora: sigue.
  assert.equal(await core.alarma(), false);
  assert.ok(datos.has('huella'));
  avanzar(INACTIVIDAD_MS);
  assert.equal(await core.alarma(), true);
  assert.equal(datos.size, 0);
  assert.equal(juez.cierre.codigo, CIERRES.cerrada.codigo);
  assert.equal(anfitrion.cierre.codigo, CIERRES.cerrada.codigo);
  // Ya no existe.
  const otro = await conectar('juez');
  assert.equal(otro.cierre.codigo, 4404);
});

test('no se guarda nada personal: solo el estado del turno', async () => {
  const { core, conectar, datos, token } = await salaCreada();
  const anfitrion = await conectar('anfitrion', token);
  const juez = await conectar('juez');
  await core.mensaje(anfitrion, estado());
  await core.mensaje(juez, accion('acierto', 'z1'));
  assert.deepEqual([...datos.keys()].sort(), [
    'acciones',
    'actividad',
    'creada',
    'estado',
    'huella',
  ]);
});

test('la página del juez escapa el código y no pide nada afuera', () => {
  const html = paginaJuez('ABC234');
  assert.match(html, /✓ Acierto/);
  assert.match(html, /→ Pasar/);
  assert.match(html, /Esperando a que empiece el turno…/);
  assert.match(html, /Se perdió la conexión, reconectando…/);
  assert.match(html, /Esta sala ya no existe/);
  assert.match(html, /Fin del turno/);
  assert.match(html, /valkiriacode\.com\/charadeando/);
  assert.match(html, /navigator\.vibrate/);
  // Solo el enlace de descarga sale del sitio: sin scripts ni fuentes de afuera.
  const externos = [...html.matchAll(/(?:src|href)=["']?(https?:[^"' >]+)/g)].map((m) => m[1]);
  assert.deepEqual([...new Set(externos)], ['https://valkiriacode.com/charadeando']);
  assert.doesNotMatch(paginaInicio('<b>'), /<b>/);
});

test('index.js solo exporta el Worker y el Durable Object', async () => {
  // Cloudflare no arranca si el módulo principal exporta otra cosa (por
  // ejemplo, una constante de texto).
  const { readFile } = await import('node:fs/promises');
  const codigo = await readFile(new URL('../src/index.js', import.meta.url), 'utf8');
  const exportados = [...codigo.matchAll(/^export\s+(default|class\s+\w+|const\s+\w+|function\s+\w+|\{[^}]*\})/gm)].map(
    (m) => m[1].replace(/\s+/g, ' '),
  );
  assert.deepEqual(exportados, ['default', 'class Sala']);
});

// Worker "charadeando-juez": el modo "Celular juez" de Charadeando.
//
//   POST /juez/api/salas                  Crea una sala: { codigo, tokenAnfitrion }.
//   GET  /juez/api/salud                  { ok: true, servicio }: si el Worker está.
//   GET  /juez/<CODIGO>                    La página del juez.
//   GET  /juez/api/salas/<CODIGO>/ws       WebSocket: ?rol=anfitrion&token=… (la
//                                          app) o ?rol=juez (la página).
//
// Cada sala es un Durable Object (con SQLite) que usa la API de WebSocket
// Hibernation: mientras nadie manda nada, no cobra tiempo. No se guarda
// ningún dato personal: solo el último estado del turno (palabra, tiempo,
// equipo y puntos) y la huella del token, y la sala se borra sola tras 3
// horas sin actividad.

import { DurableObject } from 'cloudflare:workers';

import { huella, normalizarCodigo, nuevoCodigo, nuevoToken } from './logica.js';
import { paginaInicio, paginaJuez } from './pagina.js';
import { SalaCore } from './sala.js';

const BASE = '/juez';

/// Nombre con que responde /juez/api/salud, para que la app sepa que es
/// este Worker y no otra página del sitio.
const SERVICIO = 'charadeando-juez';

/// Salas que se pueden crear por minuto desde una misma IP (en cada
/// instancia del Worker; es solo un freno contra abusos).
const SALAS_POR_MINUTO = 10;
const creadas = new Map();

function json(datos, status = 200) {
  return new Response(JSON.stringify(datos), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function html(texto, status = 200) {
  return new Response(texto, {
    status,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
      'Content-Security-Policy':
        "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; " +
        "font-src data:; connect-src 'self'; img-src data:; base-uri 'none'; form-action 'none'",
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer',
    },
  });
}

function permitido(ip, ahora = Date.now()) {
  const recientes = (creadas.get(ip) ?? []).filter((t) => ahora - t < 60_000);
  if (recientes.length >= SALAS_POR_MINUTO) {
    creadas.set(ip, recientes);
    return false;
  }
  recientes.push(ahora);
  creadas.set(ip, recientes);
  if (creadas.size > 5000) creadas.clear();
  return true;
}

async function crearSala(request, env) {
  const ip = request.headers.get('CF-Connecting-IP') ?? 'local';
  if (!permitido(ip)) return json({ error: 'Demasiadas salas. Espera un minuto.' }, 429);
  // Si el código ya está en uso (muy raro), se prueba con otro.
  for (let intento = 0; intento < 5; intento++) {
    const codigo = nuevoCodigo();
    const token = nuevoToken();
    const sala = env.SALAS.get(env.SALAS.idFromName(codigo));
    if (await sala.iniciar(await huella(token))) {
      return json({ codigo, tokenAnfitrion: token }, 201);
    }
  }
  return json({ error: 'No se pudo crear la sala. Inténtalo otra vez.' }, 503);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '');

    // La app pregunta esto antes de mostrar la opción "Celular juez".
    if (path === `${BASE}/api/salud`) return json({ ok: true, servicio: SERVICIO });

    if (path === `${BASE}/api/salas`) {
      if (request.method !== 'POST') return json({ error: 'Usa POST.' }, 405);
      return crearSala(request, env);
    }

    const ws = path.match(/^\/juez\/api\/salas\/([^/]+)\/ws$/);
    if (ws) {
      const codigo = normalizarCodigo(ws[1]);
      if (!codigo) return json({ error: 'Código inválido.' }, 404);
      if (request.headers.get('Upgrade') !== 'websocket') {
        return json({ error: 'Se espera un WebSocket.' }, 426);
      }
      return env.SALAS.get(env.SALAS.idFromName(codigo)).fetch(request);
    }

    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return json({ error: 'No existe.' }, 404);
    }
    if (path === BASE || path === '') return html(paginaInicio());
    const pagina = path.match(/^\/juez\/([^/]+)$/);
    if (pagina) {
      const codigo = normalizarCodigo(pagina[1]);
      if (!codigo) return html(paginaInicio('Ese código no es válido.'), 404);
      return html(paginaJuez(codigo));
    }
    return json({ error: 'No existe.' }, 404);
  },
};

/// Una sala: guarda el último estado del turno y pasa las acciones del juez
/// al celular de la frente.
export class Sala extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.core = new SalaCore({
      storage: ctx.storage,
      sockets: (rol) =>
        ctx.getWebSockets(rol).filter((w) => w.readyState === WebSocket.OPEN),
      adjunto: (w) => w.deserializeAttachment(),
      guardarAdjunto: (w, a) => w.serializeAttachment(a),
      ahora: () => Date.now(),
    });
  }

  /// Lo llama el Worker al crear la sala (RPC).
  async iniciar(huellaToken) {
    return this.core.iniciar(huellaToken);
  }

  async fetch(request) {
    const url = new URL(request.url);
    const rol = url.searchParams.get('rol');
    const token = url.searchParams.get('token');
    const { 0: cliente, 1: servidor } = new WebSocketPair();
    const rechazo = await this.core.admitir(rol, token);
    if (rechazo) {
      // Se acepta para poder decir por qué se cierra.
      this.ctx.acceptWebSocket(servidor, ['rechazado']);
      this.core.rechazar(servidor, rechazo);
    } else {
      this.ctx.acceptWebSocket(servidor, [rol]);
      await this.core.conectado(servidor, rol);
    }
    return new Response(null, { status: 101, webSocket: cliente });
  }

  async webSocketMessage(ws, mensaje) {
    await this.core.mensaje(ws, mensaje);
  }

  async webSocketClose(ws, codigo) {
    this.core.cerrado(ws);
    try {
      // 1005 y 1006 no se pueden mandar: se cierra como normal.
      ws.close(codigo === 1000 || (codigo >= 3000 && codigo < 5000) ? codigo : 1000, 'cerrado');
    } catch {
      // Ya estaba cerrado.
    }
  }

  async webSocketError(ws) {
    this.core.cerrado(ws);
  }

  async alarm() {
    await this.core.alarma();
  }
}


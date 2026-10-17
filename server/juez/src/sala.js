// Una sala del modo "Celular juez": el celular de la frente (anfitrión)
// manda el estado del turno y los jueces mandan "acierto" o "pasar". Esta
// clase no depende de Cloudflare: el Durable Object (index.js) le pasa un
// [entorno] con el almacenamiento y los WebSockets, y en las pruebas se usa
// uno de mentira.

import {
  ACCIONES_POR_SEGUNDO,
  ESTADOS_POR_SEGUNDO,
  INACTIVIDAD_MS,
  MAX_JUECES,
  huella,
  iguales,
  leerMensaje,
  limitar,
  normalizarIdJuez,
} from './logica.js';

/// Códigos de cierre de los WebSockets (el juez los muestra en español).
export const CIERRES = {
  noExiste: { codigo: 4404, razon: 'sala_no_existe' },
  token: { codigo: 4401, razon: 'token_invalido' },
  llena: { codigo: 4409, razon: 'sala_llena' },
  rol: { codigo: 4400, razon: 'rol_invalido' },
  reemplazado: { codigo: 4000, razon: 'otro_anfitrion' },
  // El mismo juez entró de nuevo (otra pestaña o se reconectó).
  mismoJuez: { codigo: 4001, razon: 'juez_reconectado' },
  cerrada: { codigo: 4410, razon: 'sala_cerrada' },
};

/// Cuántos ids de acciones se recuerdan para no repetir una reenviada.
const ACCIONES_RECORDADAS = 50;

/// Cada cuánto, como mucho, se corre la alarma de borrado.
const RENOVAR_ALARMA_MS = 10 * 60 * 1000;

function enviar(ws, mensaje) {
  try {
    ws.send(JSON.stringify(mensaje));
  } catch {
    // Si el socket ya se cerró, no hay a quién avisar.
  }
}

export class SalaCore {
  /// [entorno]: `{ storage, sockets(rol), adjunto(ws), guardarAdjunto(ws, a),
  /// ahora() }`. `storage` como el de un Durable Object (get, put,
  /// deleteAll, setAlarm, deleteAlarm).
  constructor(entorno) {
    this.e = entorno;
    this.alarmaHasta = 0;
  }

  get storage() {
    return this.e.storage;
  }

  /// Crea la sala con la huella del token del anfitrión. Falso si el código
  /// ya estaba en uso.
  async iniciar(huellaToken) {
    if (await this.storage.get('huella')) return false;
    const ahora = this.e.ahora();
    await this.storage.put({ huella: huellaToken, creada: ahora, actividad: ahora });
    await this.renovarAlarma(true);
    return true;
  }

  /// Si se acepta una conexión con [rol] y [token] (el anfitrión) o
  /// [idJuez] (el juez). Devuelve null si sí, o el cierre con que se
  /// rechaza.
  async admitir(rol, token, idJuez = null) {
    const guardada = await this.storage.get('huella');
    if (!guardada) return CIERRES.noExiste;
    if (rol === 'anfitrion') {
      if (!token || !iguales(await huella(token), guardada)) return CIERRES.token;
      return null;
    }
    if (rol === 'juez') {
      const jueces = this.e.sockets('juez');
      if (jueces.length < MAX_JUECES) return null;
      // Ya hay juez: solo entra si es el mismo celular que vuelve (por
      // ejemplo, se le fue la señal y la sala todavía no lo notó).
      const id = normalizarIdJuez(idJuez);
      if (id && jueces.every((w) => this.e.adjunto(w)?.idJuez === id)) return null;
      return CIERRES.llena;
    }
    return CIERRES.rol;
  }

  /// Rechaza [ws] (ya aceptado) con [cierre]: primero le dice por qué.
  rechazar(ws, cierre) {
    enviar(ws, { tipo: 'error', codigo: cierre.razon });
    try {
      ws.close(cierre.codigo, cierre.razon);
    } catch {
      // Ya estaba cerrado.
    }
  }

  /// Recién conectado [ws] con [rol]: le manda lo que necesita.
  async conectado(ws, rol, idJuez = null) {
    const id = rol === 'juez' ? normalizarIdJuez(idJuez) : null;
    this.e.guardarAdjunto(ws, { rol, ventana: null, idJuez: id });
    await this.tocar();
    if (rol === 'anfitrion') {
      // Solo un anfitrión: si el celular se reconecta, el anterior sobra.
      for (const otro of this.e.sockets('anfitrion')) {
        if (otro !== ws) this.rechazar(otro, CIERRES.reemplazado);
      }
      enviar(ws, { tipo: 'bienvenida', rol });
      this.avisarJueces();
      return;
    }
    // El mismo juez que vuelve reemplaza su conexión anterior.
    const viejas = this.e.sockets('juez').filter((w) => w !== ws);
    for (const vieja of viejas) this.rechazar(vieja, CIERRES.mismoJuez);
    enviar(ws, { tipo: 'bienvenida', rol });
    const estado = await this.storage.get('estado');
    if (estado) enviar(ws, estado);
    this.avisarJueces();
  }

  /// Le dice al anfitrión cuántos jueces hay ([sin], uno que se está
  /// yendo, no cuenta).
  avisarJueces(sin = null) {
    const cantidad = this.e.sockets('juez').filter((w) => w !== sin).length;
    for (const anfitrion of this.e.sockets('anfitrion')) {
      enviar(anfitrion, { tipo: 'jueces', cantidad });
    }
  }

  async mensaje(ws, crudo) {
    const adjunto = this.e.adjunto(ws) ?? {};
    const rol = adjunto.rol;
    const { ventana, acepta } = limitar(
      adjunto.ventana,
      this.e.ahora(),
      rol === 'anfitrion' ? ESTADOS_POR_SEGUNDO : ACCIONES_POR_SEGUNDO,
    );
    this.e.guardarAdjunto(ws, { ...adjunto, ventana });
    // Demasiados seguidos: se ignoran sin responder.
    if (!acepta) return;

    const msg = leerMensaje(crudo, rol);
    if (msg.error) {
      enviar(ws, { tipo: 'error', codigo: 'mensaje_invalido', detalle: msg.error });
      return;
    }
    await this.tocar();

    if (msg.tipo === 'estado') {
      await this.storage.put('estado', msg);
      for (const juez of this.e.sockets('juez')) enviar(juez, msg);
      return;
    }

    // Corregir solo se puede con el resumen del turno abierto para
    // editar, y en una palabra que exista.
    if (msg.accion === 'corregir') {
      const estado = await this.storage.get('estado');
      const palabras = estado?.palabras ?? [];
      if (!estado?.editable || msg.indice >= palabras.length) {
        enviar(ws, { tipo: 'error', codigo: 'no_editable' });
        return;
      }
    }

    // Una acción del juez: una sola vez por id, aunque llegue repetida.
    const recientes = (await this.storage.get('acciones')) ?? [];
    if (recientes.includes(msg.id)) return;
    await this.storage.put('acciones', [...recientes, msg.id].slice(-ACCIONES_RECORDADAS));
    const anfitriones = this.e.sockets('anfitrion');
    if (anfitriones.length === 0) {
      enviar(ws, { tipo: 'aviso', codigo: 'sin_anfitrion' });
      return;
    }
    for (const anfitrion of anfitriones) enviar(anfitrion, msg);
  }

  /// Se cerró [ws]: si era un juez, el anfitrión lo sabe.
  cerrado(ws) {
    const rol = this.e.adjunto(ws)?.rol;
    if (rol === 'juez') this.avisarJueces(ws);
  }

  /// Hubo actividad: la sala vive 3 horas más.
  async tocar() {
    await this.storage.put('actividad', this.e.ahora());
    await this.renovarAlarma();
  }

  async renovarAlarma(siempre = false) {
    const ahora = this.e.ahora();
    if (!siempre && ahora < this.alarmaHasta - INACTIVIDAD_MS + RENOVAR_ALARMA_MS) return;
    this.alarmaHasta = ahora + INACTIVIDAD_MS;
    await this.storage.setAlarm(this.alarmaHasta);
  }

  /// Alarma: si pasaron 3 horas sin actividad, la sala se borra.
  async alarma() {
    const actividad = (await this.storage.get('actividad')) ?? 0;
    const ahora = this.e.ahora();
    if (ahora - actividad < INACTIVIDAD_MS) {
      this.alarmaHasta = actividad + INACTIVIDAD_MS;
      await this.storage.setAlarm(this.alarmaHasta);
      return false;
    }
    for (const rol of ['anfitrion', 'juez']) {
      for (const ws of this.e.sockets(rol)) this.rechazar(ws, CIERRES.cerrada);
    }
    await this.storage.deleteAlarm();
    await this.storage.deleteAll();
    return true;
  }
}

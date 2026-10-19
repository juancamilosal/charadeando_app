// Reglas del modo "Celular juez" que no dependen de Cloudflare: códigos,
// tokens y validación de mensajes. Se prueban con node --test.

/// Letras del código de sala, sin las que se confunden (0/O, 1/I/L).
export const ALFABETO = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
export const LARGO_CODIGO = 6;

/// Máximo de jueces conectados a una sala: uno. Si ya hay juez, otro
/// celular no puede entrar (el mismo sí, para reconectarse).
export const MAX_JUECES = 1;

/// Id con que la página del juez se presenta (lo guarda el navegador),
/// para reconocer al mismo celular cuando se reconecta.
export function normalizarIdJuez(texto) {
  const id = String(texto ?? '');
  return /^[A-Za-z0-9_-]{8,40}$/.test(id) ? id : null;
}

/// Acciones por segundo que se aceptan de cada juez; las demás se ignoran.
export const ACCIONES_POR_SEGUNDO = 4;

/// Mensajes por segundo que se aceptan del anfitrión (el tiempo cambia cada
/// segundo y la palabra con cada acierto).
export const ESTADOS_POR_SEGUNDO = 20;

/// Tamaño máximo de un mensaje del juez, en caracteres.
export const MAX_MENSAJE = 2048;

/// Tamaño máximo de un mensaje del anfitrión: el resumen del turno lleva
/// la lista de palabras.
export const MAX_MENSAJE_ANFITRION = 16384;

/// Palabras que puede tener el resumen de un turno.
export const MAX_PALABRAS = 100;

/// Equipos que puede tener la tabla de posiciones del final.
export const MAX_POSICIONES = 20;

/// La sala se borra sola tras este tiempo sin actividad.
export const INACTIVIDAD_MS = 3 * 60 * 60 * 1000;

export const ESTADOS = ['esperando', 'jugando', 'fin_turno', 'fin_partida'];
export const ACCIONES = ['acierto', 'pasar'];

/// Al final del turno el juez puede corregir una palabra: "corregir".
export const CORREGIR = 'corregir';

/// Código de sala al azar, de [LARGO_CODIGO] letras de [ALFABETO].
export function nuevoCodigo(random = crypto) {
  const bytes = new Uint8Array(LARGO_CODIGO * 2);
  let codigo = '';
  // Se descartan los bytes que darían más peso a unas letras que a otras.
  const limite = 256 - (256 % ALFABETO.length);
  while (codigo.length < LARGO_CODIGO) {
    random.getRandomValues(bytes);
    for (const b of bytes) {
      if (b < limite && codigo.length < LARGO_CODIGO) codigo += ALFABETO[b % ALFABETO.length];
    }
  }
  return codigo;
}

/// Si [texto] es un código de sala válido (sin importar mayúsculas).
export function normalizarCodigo(texto) {
  const codigo = String(texto ?? '').trim().toUpperCase();
  if (codigo.length !== LARGO_CODIGO) return null;
  for (const letra of codigo) if (!ALFABETO.includes(letra)) return null;
  return codigo;
}

/// Token del anfitrión: 32 bytes al azar en base64url (43 caracteres).
export function nuevoToken(random = crypto) {
  const bytes = new Uint8Array(32);
  random.getRandomValues(bytes);
  return base64url(bytes);
}

export function base64url(bytes) {
  let texto = '';
  for (const b of bytes) texto += String.fromCharCode(b);
  return btoa(texto).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/// Huella SHA-256 (hex) del token: la sala guarda esto, no el token.
export async function huella(token) {
  const datos = new TextEncoder().encode(String(token));
  const hash = await crypto.subtle.digest('SHA-256', datos);
  return [...new Uint8Array(hash)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/// Compara dos textos sin que el tiempo delate cuántas letras coinciden.
export function iguales(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) return false;
  let diferencia = 0;
  for (let i = 0; i < a.length; i++) diferencia |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diferencia === 0;
}

function texto(valor, max) {
  return typeof valor === 'string' && valor.length <= max;
}

function entero(valor, min, max) {
  return Number.isInteger(valor) && valor >= min && valor <= max;
}

const CAMPOS_ESTADO = {
  palabra: (v) => v === null || texto(v, 120),
  categoria: (v) => v === null || texto(v, 60),
  segundos: (v) => entero(v, 0, 3600),
  equipo: (v) => v === null || texto(v, 60),
  puntos: (v) => entero(v, -9999, 99999),
  estado: (v) => ESTADOS.includes(v),
  // Resumen del turno ("Fin del turno"): opcionales.
  aciertos: (v) => entero(v, 0, 9999),
  pasadas: (v) => entero(v, 0, 9999),
  // Las palabras del turno, en orden, y si el juez todavía puede
  // corregirlas.
  palabras: (v) =>
    Array.isArray(v) &&
    v.length <= MAX_PALABRAS &&
    v.every(
      (p) =>
        p &&
        typeof p === 'object' &&
        !Array.isArray(p) &&
        Object.keys(p).every((k) => k === 'texto' || k === 'acierto' || k === 'puntos') &&
        texto(p.texto, 120) &&
        typeof p.acierto === 'boolean' &&
        (p.puntos === undefined || entero(p.puntos, 0, 99)),
    ),
  editable: (v) => typeof v === 'boolean',
  // Lo que el celular de la frente acaba de marcar ("¡Correcto!" o
  // "Paso"), para que el juez vea que llegó.
  marca: (v) => v === null || v === 'acierto' || v === 'pasar',
  // Al final de la partida: los equipos de más a menos puntos (el juez ve
  // el ganador o el empate) o, sin equipos, el total.
  posiciones: (v) =>
    Array.isArray(v) &&
    v.length <= MAX_POSICIONES &&
    v.every(
      (p) =>
        p &&
        typeof p === 'object' &&
        !Array.isArray(p) &&
        Object.keys(p).every((k) => k === 'nombre' || k === 'puntos') &&
        texto(p.nombre, 60) &&
        entero(p.puntos, -9999, 99999),
    ),
  total: (v) => entero(v, -9999, 99999),
  // La cuenta regresiva (3, 2, 1) antes de empezar el turno.
  cuenta: (v) => entero(v, 1, 9),
};
const OBLIGATORIOS_ESTADO = ['segundos', 'puntos', 'estado'];

/// Lee un mensaje recibido. Devuelve el objeto si es válido para [rol]
/// ('anfitrion' o 'juez'), o `{ error }` si no.
export function leerMensaje(crudo, rol) {
  if (typeof crudo !== 'string') return { error: 'El mensaje debe ser texto.' };
  if (crudo.length > (rol === 'anfitrion' ? MAX_MENSAJE_ANFITRION : MAX_MENSAJE)) {
    return { error: 'El mensaje es muy largo.' };
  }
  let msg;
  try {
    msg = JSON.parse(crudo);
  } catch {
    return { error: 'El mensaje no es JSON.' };
  }
  if (!msg || typeof msg !== 'object' || Array.isArray(msg)) {
    return { error: 'El mensaje debe ser un objeto.' };
  }
  if (rol === 'anfitrion') {
    if (msg.tipo !== 'estado') return { error: 'El anfitrión solo envía "estado".' };
    const limpio = { tipo: 'estado' };
    for (const [clave, valor] of Object.entries(msg)) {
      if (clave === 'tipo') continue;
      const valido = CAMPOS_ESTADO[clave];
      if (!valido) return { error: `Campo desconocido: ${clave}.` };
      if (!valido(valor)) return { error: `Campo inválido: ${clave}.` };
      limpio[clave] = valor;
    }
    for (const clave of OBLIGATORIOS_ESTADO) {
      if (!(clave in limpio)) return { error: `Falta el campo ${clave}.` };
    }
    return limpio;
  }
  if (rol === 'juez') {
    if (msg.tipo !== 'accion') return { error: 'El juez solo envía "accion".' };
    if (typeof msg.id !== 'string' || !/^[A-Za-z0-9_-]{1,40}$/.test(msg.id)) {
      return { error: 'Falta el id de la acción.' };
    }
    if (msg.accion === CORREGIR) {
      // { accion: "corregir", indice, acierto }: cambia una palabra del
      // resumen del turno.
      const extra = Object.keys(msg).filter(
        (k) => !['tipo', 'accion', 'id', 'indice', 'acierto'].includes(k),
      );
      if (extra.length > 0) return { error: `Campo desconocido: ${extra[0]}.` };
      if (!entero(msg.indice, 0, MAX_PALABRAS - 1)) return { error: 'Falta el índice de la palabra.' };
      if (typeof msg.acierto !== 'boolean') return { error: 'Falta si es acierto.' };
      return { tipo: 'accion', accion: CORREGIR, id: msg.id, indice: msg.indice, acierto: msg.acierto };
    }
    if (!ACCIONES.includes(msg.accion)) {
      return { error: 'La acción es "acierto", "pasar" o "corregir".' };
    }
    const extra = Object.keys(msg).filter((k) => !['tipo', 'accion', 'id'].includes(k));
    if (extra.length > 0) return { error: `Campo desconocido: ${extra[0]}.` };
    return { tipo: 'accion', accion: msg.accion, id: msg.id };
  }
  return { error: 'Rol desconocido.' };
}

/// Ventana de un segundo para limitar mensajes: `{ inicio, cuenta }`.
/// Devuelve la ventana nueva y si el mensaje se acepta.
export function limitar(ventana, ahora, maximo) {
  if (!ventana || ahora - ventana.inicio >= 1000) {
    return { ventana: { inicio: ahora, cuenta: 1 }, acepta: true };
  }
  const cuenta = ventana.cuenta + 1;
  return { ventana: { inicio: ventana.inicio, cuenta }, acepta: cuenta <= maximo };
}

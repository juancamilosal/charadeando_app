// Páginas que sirve el Worker: la del juez (todo en un solo HTML, sin
// pedir nada a otros servidores) y una de inicio por si entran sin código.

import { FREDOKA, NUNITO } from './fuentes.js';

const DESCARGA = 'https://valkiriacode.com/charadeando';

function escapar(texto) {
  return String(texto).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

const ESTILOS = `
@font-face{font-family:Fredoka;src:url(data:font/woff2;base64,${FREDOKA}) format('woff2');font-weight:600;font-display:swap}
@font-face{font-family:Nunito;src:url(data:font/woff2;base64,${NUNITO}) format('woff2');font-weight:700;font-display:swap}
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
[hidden]{display:none!important}
html,body{height:100%}
body{font-family:Nunito,system-ui,sans-serif;font-weight:700;color:#fff;
  background:linear-gradient(160deg,#5B21D6 0%,#9B2BD8 50%,#E83E8C 100%) fixed;
  min-height:100dvh;display:flex;flex-direction:column;user-select:none;-webkit-user-select:none;
  padding:max(14px,env(safe-area-inset-top)) 16px max(12px,env(safe-area-inset-bottom))}
.titulo{font-family:Fredoka,system-ui,sans-serif;font-weight:600}
a{color:#fff}
`;

/// La página del juez de la sala [codigo].
export function paginaJuez(codigo) {
  const c = escapar(codigo);
  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
<meta name="theme-color" content="#5B21D6">
<meta name="robots" content="noindex">
<title>Juez · Charadeando</title>
<style>${ESTILOS}
.arriba{display:flex;justify-content:space-between;align-items:center;gap:10px}
.pildora{background:rgba(255,255,255,.18);border-radius:999px;padding:7px 14px;font-size:17px;
  white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:65%}
.puntos{background:#fff;color:#4B10B0;font-family:Fredoka,system-ui,sans-serif;font-size:20px;max-width:35%}
.centro{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;gap:14px;padding:14px 4px}
.categoria{font-size:15px;letter-spacing:.08em;text-transform:uppercase;opacity:.85}
.palabra{font-family:Fredoka,system-ui,sans-serif;font-weight:600;font-size:clamp(34px,11vw,64px);line-height:1.05;
  word-break:break-word;text-shadow:0 4px 12px rgba(0,0,0,.25)}
.tiempo{font-family:Fredoka,system-ui,sans-serif;font-size:30px;background:#fff;color:#2B0A57;border-radius:999px;padding:4px 20px;min-width:96px}
.tiempo.poco{background:#FFD23F}
.botones{display:grid;grid-template-columns:1fr 1fr;gap:12px}
button{font-family:Fredoka,system-ui,sans-serif;font-weight:600;font-size:clamp(22px,7vw,30px);color:#fff;border:0;
  border-radius:24px;min-height:120px;padding:10px;box-shadow:0 6px 0 rgba(0,0,0,.25);touch-action:manipulation;cursor:pointer}
button:active{transform:translateY(4px);box-shadow:0 2px 0 rgba(0,0,0,.25)}
button:disabled{opacity:.45;transform:none}
.acierto{background:#18A85C}
.pasar{background:#FF8A00}
.descarga{text-align:center;font-size:13px;opacity:.8;margin-top:12px}
.aviso{position:fixed;inset:0;display:none;flex-direction:column;align-items:center;justify-content:center;gap:12px;
  text-align:center;padding:28px;background:linear-gradient(160deg,#4B10B0,#C8288C)}
.aviso.visible{display:flex}
.aviso h1{font-family:Fredoka,system-ui,sans-serif;font-weight:600;font-size:32px;line-height:1.1}
.aviso p{font-size:18px;opacity:.9;max-width:22em}
.resumen{display:flex;gap:10px;margin-top:6px}
.resumen div{background:rgba(255,255,255,.18);border-radius:16px;padding:10px 14px;font-size:16px}
.resumen b{display:block;font-family:Fredoka,system-ui,sans-serif;font-size:28px}
.codigo{font-family:Fredoka,system-ui,sans-serif;letter-spacing:.15em;opacity:.8}
.punto{width:14px;height:14px;border-radius:50%;background:#fff;animation:latir 1s infinite alternate}
@keyframes latir{from{opacity:.3}to{opacity:1}}
.aviso.con-lista{justify-content:flex-start;overflow-y:auto;padding-top:max(28px,env(safe-area-inset-top))}
.lista{width:100%;max-width:420px;background:#fff;border-radius:24px;padding:10px;display:flex;flex-direction:column;gap:8px;
  box-shadow:0 4px 10px rgba(0,0,0,.13);margin-top:4px}
.lista .fila{display:flex;align-items:center;gap:10px;width:100%;min-height:0;padding:12px 16px;border-radius:16px;
  background:#F4EEFD;color:#2B0A57;box-shadow:none;font-family:Nunito,system-ui,sans-serif;font-weight:800;font-size:17px;text-align:left}
.lista .fila:active{transform:none;box-shadow:none}
.lista .fila:disabled{opacity:1}
.lista .fila.editable{cursor:pointer;outline:2px dashed rgba(91,33,214,.25);outline-offset:-2px}
.lista .fila.cambiando{opacity:.5}
.fila .texto{flex:1;word-break:break-word}
.fila .pts{font-family:Fredoka,system-ui,sans-serif;font-weight:600;font-size:17px;border-radius:12px;padding:2px 10px;background:rgba(43,10,87,.12);color:rgba(43,10,87,.7)}
.fila.si .pts{background:#18A85C;color:#fff}
.fila .marca{font-size:20px}
.vacia{padding:12px;text-align:center;color:#2B0A57}
.pista{font-size:15px!important;opacity:.85}
.marca{font-family:Fredoka,system-ui,sans-serif;font-weight:600;font-size:clamp(22px,7vw,30px);border-radius:999px;
  padding:6px 20px;animation:aparecer .18s ease-out}
.marca.si{background:#18A85C}
.marca.no{background:#FF8A00}
.marca.falla{background:rgba(0,0,0,.28);font-size:18px}
@keyframes aparecer{from{transform:scale(.85);opacity:0}to{transform:scale(1);opacity:1}}
/* Al tocar, solo el botón tocado se hunde un instante: sin destellos en
   toda la pantalla. */
button.marcado{animation:marcado .22s ease-out}
@keyframes marcado{from{transform:scale(.95)}to{transform:scale(1)}}
</style>
</head>
<body>
<header class="arriba">
  <span class="pildora" id="equipo">Juez</span>
  <span class="pildora puntos" id="puntos">0</span>
</header>
<main class="centro">
  <div class="categoria" id="categoria"></div>
  <div class="palabra" id="palabra">…</div>
  <div class="marca" id="marca" role="status" aria-live="polite" hidden></div>
  <div class="tiempo" id="tiempo">--</div>
</main>
<section class="botones">
  <button class="acierto" id="acierto" disabled>✓ Acierto</button>
  <button class="pasar" id="pasar" disabled>→ Pasar</button>
</section>
<p class="descarga"><a href="${DESCARGA}" target="_blank" rel="noopener">¿Quieres jugar? Descarga Charadeando</a></p>

<div class="aviso visible" id="aviso">
  <div class="punto" id="aviso-punto"></div>
  <h1 id="aviso-titulo">Conectando…</h1>
  <p id="aviso-texto">Sala <span class="codigo">${c}</span></p>
  <div class="resumen" id="resumen" hidden>
    <div><b id="r-aciertos">0</b>aciertos</div>
    <div><b id="r-pasadas">0</b>pasadas</div>
    <div><b id="r-puntos">0</b>puntos</div>
  </div>
  <p class="pista" id="pista" hidden>Toca una palabra si se marcó mal: cambia entre ✅ y ⏭️.</p>
  <div class="lista" id="lista" hidden></div>
  <p class="descarga"><a href="${DESCARGA}" target="_blank" rel="noopener">¿Quieres jugar? Descarga Charadeando</a></p>
</div>

<script>
(() => {
  const CODIGO = ${JSON.stringify(codigo)};
  const $ = (id) => document.getElementById(id);
  const botones = [$('acierto'), $('pasar')];
  let ws = null;
  let estado = null;
  let espera = 1000;
  let final = false;
  let bloqueado = false;

  // Las palabras del turno, como en la app: ✅ si se acertó, ⏭️ si se pasó.
  // Si todavía se puede, al tocar una se corrige (en el celular también).
  function lista(e) {
    const palabras = Array.isArray(e && e.palabras) ? e.palabras : null;
    const caja = $('lista');
    caja.hidden = !palabras;
    $('pista').hidden = !(palabras && palabras.length && e.editable);
    $('aviso').classList.toggle('con-lista', !!palabras);
    caja.replaceChildren();
    if (!palabras) return;
    if (palabras.length === 0) {
      const v = document.createElement('div');
      v.className = 'vacia';
      v.textContent = 'No se marcó ninguna palabra.';
      caja.append(v);
      return;
    }
    palabras.forEach((p, i) => {
      const fila = document.createElement('button');
      fila.type = 'button';
      fila.className = 'fila' + (p.acierto ? ' si' : '') + (e.editable ? ' editable' : '');
      fila.disabled = !e.editable;
      const t = document.createElement('span');
      t.className = 'texto';
      t.textContent = p.texto;
      const pts = document.createElement('span');
      pts.className = 'pts';
      pts.textContent = p.acierto ? '+' + (p.puntos ?? 1) : '0';
      const m = document.createElement('span');
      m.className = 'marca';
      m.textContent = p.acierto ? '✅' : '⏭️';
      m.setAttribute('aria-label', p.acierto ? 'acierto' : 'pasada');
      fila.append(t, pts, m);
      fila.addEventListener('click', () => corregir(i, !p.acierto, fila));
      caja.append(fila);
    });
  }

  function aviso(titulo, texto, { punto = false, resumen = null } = {}) {
    $('aviso').classList.toggle('visible', titulo !== null);
    if (!resumen) lista(null);
    if (titulo === null) return;
    $('aviso-titulo').textContent = titulo;
    $('aviso-texto').textContent = texto;
    $('aviso-punto').hidden = !punto;
    $('resumen').hidden = !resumen;
    if (resumen) {
      $('r-aciertos').textContent = resumen.aciertos ?? 0;
      $('r-pasadas').textContent = resumen.pasadas ?? 0;
      $('r-puntos').textContent = resumen.puntos ?? 0;
    }
  }

  // "✓ ¡Correcto!" o "→ Paso" debajo de la palabra cuando el celular de la
  // frente confirma la marca (la haga el juez o el celular). Si el juez
  // toca y en 2 segundos no llega la confirmación, se le pide tocar otra
  // vez.
  let sinConfirmar = null;
  function marca(texto, clase) {
    const m = $('marca');
    if (!texto) {
      m.hidden = true;
      return;
    }
    m.textContent = texto;
    m.className = 'marca ' + clase;
    m.hidden = false;
  }

  function mostrar(e) {
    const antes = estado;
    estado = e;
    if (e.estado === 'jugando' && e.marca) {
      clearTimeout(sinConfirmar);
      sinConfirmar = null;
      marca(e.marca === 'acierto' ? '✓ ¡Correcto!' : '→ Paso', e.marca === 'acierto' ? 'si' : 'no');
    } else if (e.estado !== 'jugando' || (antes && antes.palabra !== e.palabra)) {
      // Palabra nueva (o fuera del turno): se borra la marca anterior.
      if (!sinConfirmar) marca(null);
    } else if (antes && antes.marca && !e.marca) {
      marca(null);
    }
    if (e.estado !== 'jugando') {
      clearTimeout(sinConfirmar);
      sinConfirmar = null;
    }
    $('equipo').textContent = e.equipo || 'Juez';
    $('puntos').textContent = e.puntos ?? 0;
    $('categoria').textContent = e.categoria || '';
    $('palabra').textContent = e.palabra || '…';
    $('tiempo').textContent = e.segundos + ' s';
    $('tiempo').classList.toggle('poco', e.segundos <= 10);
    const jugando = e.estado === 'jugando';
    for (const b of botones) b.disabled = !jugando;
    if (jugando) aviso(null);
    else if (e.estado === 'esperando') aviso('Esperando a que empiece el turno…', e.equipo ? 'Turno de ' + e.equipo : 'Prepárate para juzgar.', { punto: true });
    else if (e.estado === 'fin_turno') { aviso('Fin del turno', e.equipo ? 'Turno de ' + e.equipo : '', { resumen: e }); lista(e); }
    else if (e.estado === 'fin_partida') { aviso('¡Fin de la partida!', 'Gracias por ser el juez.', { resumen: e }); lista(e); }
  }

  function conectar() {
    const protocolo = location.protocol === 'https:' ? 'wss:' : 'ws:';
    ws = new WebSocket(protocolo + '//' + location.host + '/juez/api/salas/' + CODIGO + '/ws?rol=juez');
    ws.onopen = () => { espera = 1000; };
    ws.onmessage = (m) => {
      let msg;
      try { msg = JSON.parse(m.data); } catch { return; }
      if (msg.tipo === 'estado') mostrar(msg);
      else if (msg.tipo === 'bienvenida' && !estado) aviso('Esperando a que empiece el turno…', 'Ya estás conectado como juez.', { punto: true });
      // Ya no se podía corregir (el celular pasó al siguiente turno).
      else if (msg.tipo === 'error' && msg.codigo === 'no_editable') { if (estado) mostrar(estado); }
      else if (msg.tipo === 'error' && msg.codigo === 'sala_llena') { final = true; aviso('La sala ya tiene 2 jueces', 'Pídele a alguien que salga para poder entrar.'); }
      else if (msg.tipo === 'error' && (msg.codigo === 'sala_no_existe' || msg.codigo === 'sala_cerrada')) { final = true; aviso('Esta sala ya no existe', 'Pide en el celular de la frente un código nuevo.'); }
    };
    ws.onclose = (e) => {
      for (const b of botones) b.disabled = true;
      if (final || e.code === 4404 || e.code === 4410 || e.code === 4409) {
        if (!final) aviso('Esta sala ya no existe', 'Pide en el celular de la frente un código nuevo.');
        final = true;
        return;
      }
      aviso('Se perdió la conexión, reconectando…', 'No cierres esta página.', { punto: true });
      setTimeout(conectar, espera);
      espera = Math.min(espera * 2, 8000);
    };
  }

  function id() {
    const b = new Uint8Array(12);
    crypto.getRandomValues(b);
    return [...b].map((x) => x.toString(16).padStart(2, '0')).join('');
  }

  function accion(nombre) {
    if (bloqueado || !estado || estado.estado !== 'jugando' || !ws || ws.readyState !== 1) return;
    // Un toque a la vez: evita marcar dos por un doble toque.
    bloqueado = true;
    setTimeout(() => { bloqueado = false; }, 700);
    if (navigator.vibrate) navigator.vibrate(35);
    ws.send(JSON.stringify({ tipo: 'accion', accion: nombre, id: id() }));
    clearTimeout(sinConfirmar);
    sinConfirmar = setTimeout(() => {
      sinConfirmar = null;
      if (estado && estado.estado === 'jugando') marca('No llegó, toca otra vez', 'falla');
    }, 2000);
    const boton = $(nombre);
    boton.classList.remove('marcado');
    void boton.offsetWidth;
    boton.classList.add('marcado');
  }

  function corregir(indice, acierto, fila) {
    if (bloqueado || !estado || !estado.editable || !ws || ws.readyState !== 1) return;
    bloqueado = true;
    setTimeout(() => { bloqueado = false; }, 500);
    if (navigator.vibrate) navigator.vibrate(25);
    // Se ve el cambio cuando el celular de la frente lo confirma.
    fila.classList.add('cambiando');
    ws.send(JSON.stringify({ tipo: 'accion', accion: 'corregir', id: id(), indice, acierto }));
  }

  $('acierto').addEventListener('click', () => accion('acierto'));
  $('pasar').addEventListener('click', () => accion('pasar'));
  document.addEventListener('dblclick', (e) => e.preventDefault());

  // Que la pantalla no se apague mientras se juzga.
  async function despierto() {
    try { if (navigator.wakeLock && document.visibilityState === 'visible') await navigator.wakeLock.request('screen'); } catch {}
  }
  document.addEventListener('visibilitychange', despierto);
  despierto();
  conectar();
})();
</script>
</body>
</html>`;
}

/// Página de /juez sin código (o con uno inválido).
export function paginaInicio(error = '') {
  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#5B21D6">
<title>Celular juez · Charadeando</title>
<style>${ESTILOS}
main{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;gap:14px;padding:20px}
h1{font-size:34px}
p{font-size:18px;opacity:.9;max-width:22em}
.error{background:rgba(0,0,0,.2);border-radius:14px;padding:8px 14px}
.entrar{display:flex;flex-direction:column;gap:10px;width:100%;max-width:300px}
.entrar input{font-family:Fredoka,system-ui,sans-serif;font-size:30px;text-align:center;letter-spacing:.2em;text-transform:uppercase;
  border:0;border-radius:16px;padding:12px;color:#2B0A57}
.entrar button{font-family:Fredoka,system-ui,sans-serif;font-size:22px;color:#fff;background:#18A85C;border:0;border-radius:16px;
  padding:14px;box-shadow:0 5px 0 rgba(0,0,0,.25)}
</style>
</head>
<body>
<main>
  <h1 class="titulo">Celular juez</h1>
  ${error ? `<p class="error">${escapar(error)}</p>` : ''}
  <p>Escanea el código QR que aparece en el celular de la frente, o escribe aquí su código de 6 letras.</p>
  <form id="f" class="entrar">
    <input id="c" maxlength="6" autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="ABC234" aria-label="Código de la sala">
    <button type="submit">Ser el juez</button>
  </form>
  <p><a href="${DESCARGA}" target="_blank" rel="noopener">¿Quieres jugar? Descarga Charadeando</a></p>
</main>
<script>
document.getElementById('f').addEventListener('submit', (e) => {
  e.preventDefault();
  const codigo = document.getElementById('c').value.trim().toUpperCase();
  if (codigo) location.href = '/juez/' + encodeURIComponent(codigo);
});
</script>
</body>
</html>`;
}

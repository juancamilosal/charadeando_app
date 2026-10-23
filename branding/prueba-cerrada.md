# Prueba cerrada en Google Play

Google exige que las cuentas personales nuevas hagan una prueba cerrada con
**al menos 12 personas inscritas durante 14 días seguidos** antes de pedir
acceso a producción. Conviene invitar a 15–20 por si alguien se sale.

## 1. Crear la prueba cerrada

1. Play Console > **Prueba y lanza > Pruebas > Prueba cerrada**. Ya existe
   un segmento llamado **Alpha**: tocar **Administrar segmento**.
2. Pestaña **Países y regiones**: agregar **Colombia** (y los países donde
   vivan los probadores).
3. Pestaña **Verificadores**:
   - **Crear lista de correo electrónico**, nombre `Probadores Charadeando`,
     con los correos de Gmail (la cuenta de Google que usan en Play Store
     del celular).
   - **Correo o URL para comentarios**: `soporte@valkiriacode.com`.
   - **Guardar**.
4. Pestaña **Versiones** > **Crear versión** > **Agregar de la biblioteca**
   y elegir **8 (1.0.0)** (la misma de la prueba interna; no hace falta
   compilar otra). Notas de la versión:

   ```
   <es-419>
   Primera prueba cerrada de Charadeando. ¡Gracias por probarla!
   </es-419>
   ```

5. **Siguiente > Guardar** y luego, en **Descripción general de la
   publicación**, **Enviar la app para su revisión**. La primera revisión
   puede tardar de unas horas a unos días.

## 2. Invitar a los probadores

Cuando Google apruebe la versión, en **Verificadores** aparece el **enlace
para unirse** (web). Ese enlace es el que se manda.

Mensaje para WhatsApp:

```
¡Hola! 👋 Estoy por lanzar Charadeando, un juego de charadas para jugar en
familia: te pones el celular en la frente, los demás te dan pistas y la app
graba el turno en video. 🎬😂

Google me pide que 12 personas lo prueben durante 14 días antes de
publicarlo. ¿Me ayudas? Solo toma 2 minutos:

1. Abre este enlace en tu celular Android, con la misma cuenta de Gmail que
   usas en Play Store: [ENLACE]
2. Toca "Convertirse en verificador".
3. Toca "Descargar en Google Play" e instálala.

Lo importante: no la desinstales ni salgas de la prueba durante 14 días, y
ábrela de vez en cuando (si juegas una partida, ¡mejor!). Si algo falla o
tienes una idea, escríbeme por aquí.

No tienes que comprar nada: lo gratis alcanza para probar. ¡Mil gracias! 🙌
```

## 2b. Qué tienen que probar

Mensaje para mandar después de que se unan (o junto con la invitación):

```
¡Gracias por ayudarme con Charadeando! 🙌 Esto es lo que te pido en estos
14 días (no tienes que hacerlo todo el mismo día):

🎁 Primero: canjea tu código en Ajustes → Canjear código: [CÓDIGO]

1️⃣ Una partida rápida: toca una categoría y juega. Ponte el celular en la
   frente, inclínalo hacia abajo cuando aciertes y hacia arriba para pasar.
2️⃣ Una partida por equipos con familia o amigos (2 o más equipos), y al
   final gira la ruleta de castigos.
3️⃣ Mira el video de tu turno, guárdalo y compártelo por WhatsApp.
4️⃣ Prueba el Celular juez: en la configuración de la partida enciende
   "Celular juez" y escanea el QR con otro celular; esa persona marca los
   aciertos.
5️⃣ Si tienes Chromecast o un TV inteligente, prueba el Modo TV
   duplicando la pantalla.
6️⃣ Crea una categoría propia en "Mis categorías" y juega con ella.
7️⃣ Prueba Fotomímica (en "Más juegos") y el modo Libre.

Y lo más importante: ábrela de vez en cuando durante los 14 días y no la
desinstales 🙏

Cuéntame por aquí:
• Si algo falló o se cerró (qué estabas haciendo y qué celular tienes).
• Qué fue lo que más te gustó.
• Qué cambiarías o qué categoría te gustaría que tuviera.
```

Cada comentario se anota en la tabla del final.

## 3. Durante los 14 días

- Revisar en **Prueba cerrada > Verificadores** cuántos se han inscrito; el
  conteo de 14 días empieza cuando hay 12 inscritos.
- Recordarles abrir la app un par de veces por semana (por ejemplo, un
  mensaje al día 4 y otro al día 10 con alguna de las pruebas de 2b). Google pregunta
  después cómo fue la prueba y cuenta que haya uso real.
- Las compras de los probadores **son reales** (se cobran), salvo que el
  correo también esté en los verificadores de licencia. Si alguien quiere
  probar Premium, mejor darle un código promocional.
- Si se corrige algo, subir una versión nueva (código mayor) a la prueba
  cerrada; no reinicia los 14 días.
- Si a un probador le sale "No se puede descargar Charadeando" (aunque ya
  ve la ficha "acceso anticipado"): borrar la caché de Google Play Store
  (Ajustes > Aplicaciones > Google Play Store > Almacenamiento > Borrar
  caché) y volver a intentar. Así se resolvió el primer caso.

## 4. Pedir acceso a producción

Pasados los 14 días con 12+ inscritos, en el **Panel** se activa **Solicitar
acceso a producción**. Google pregunta cómo se reclutó a los probadores, qué
comentarios dieron, qué se cambió y por qué la app está lista. Ir anotando
aquí los comentarios y arreglos de la prueba facilita esas respuestas.

### Comentarios y arreglos

| Fecha | Quién | Comentario | Qué se hizo |
|---|---|---|---|
| 21 oct 2026 | Probador 7 | Al bajar el celular, tarda en dar "¡Correcto!" y mostrar la palabra siguiente. | 9 (1.0.0): basta inclinar 28° (antes 32°), la espera se mide en tiempo (60 ms) y no en lecturas del sensor, y "¡Correcto!" dura 0,5 s (antes 0,7 s). |
| 23 oct 2026 | Probador 5 | Antes de la cuenta 3, 2, 1 (después de la pantalla de la cámara), mostrar "Ponte el celular en la frente para comenzar" y calibrar el sensor cuando ya esté en la frente. | 9 (1.0.0): con Inclinación, después de "¡Listo!" sale "Ponte el celular en la frente para comenzar"; la cuenta arranca sola cuando el celular está en la frente y quieto un segundo (o con "Empezar igual"). |

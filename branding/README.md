# Marca de Charadeando

| Archivo | Uso |
|---|---|
| `icono.png` | Ícono de la app, 1024x1024, cuadrado completo (Android lo recorta). Fuente para `flutter_launcher_icons`. |
| `icono-adaptativo-frente.png` | Capa frontal del ícono adaptativo de Android (fondo transparente, con margen para el recorte en círculo). Va con el color de fondo `#1B024A`. |
| `google-play-icono-512.png` | Ícono para la ficha de Google Play (512x512). |
| `google-play-destacada-1024x500.png` | Imagen destacada para la ficha de Google Play. |
| `logo-transparente.png` | Logo completo sin fondo (PNG transparente). Es el que se usa dentro de la app. |
| `icono-adaptativo-app.png` | Generado: `icono.png` achicado sobre su mismo fondo, para el frente del ícono adaptativo (el que usa la app). |
| `icono-transparente.png` | Solo el celular con los destellos, sin fondo. Para usarlo dentro de la app (cargas, botones, splash). |
| `logo.png` | Logo completo (celular + "Charadeando") sobre fondo morado `#190442`, 1024x1024. |

Colores del fondo: `#1B024A` (ícono) y `#190442` (logo).

## Pantalla de carga (`branding/splash/`)

| Archivo | Uso |
|---|---|
| `referencia.png` | Cómo debe verse la pantalla (1080x1920). Solo referencia: la pantalla se arma por partes. |
| `logo.png` | Logo en alta resolución (sin fondo), para el centro de la pantalla. |
| `destello.png` | Destello lila con transparencia. Se usa varias veces, en distintos tamaños, y algunos teñidos de amarillo `#FFD23F`, turquesa `#1FC8B4` y magenta `#E5197E`. |
| `vacio-android12.png` | Generado: imagen transparente de 1152x1152 para el splash nativo de Android 12+, que siempre lleva un ícono; así solo se ve el fondo. |
| `firma.png` | "by ValkiriaCode" en blanco al 70% (600x240, fondo transparente), para la imagen de marca del splash nativo. |

Fondo: `#1F0252`, con un brillo radial `#6E28E6` detrás del logo.

## Google Play (textos)

- `ficha-play.md`: textos de la ficha de Play Store y lista de capturas.
- `politica-privacidad.md`: borrador de la política (la publicada está en
  https://valkiriacode.com/charadeando/privacidad).
- `prueba-cerrada.md`: cómo armar la prueba cerrada (12+ personas, 14 días),
  el mensaje de invitación y la tabla de comentarios para pedir producción.

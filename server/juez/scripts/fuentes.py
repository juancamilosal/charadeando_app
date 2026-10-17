"""Genera src/fuentes.js: Fredoka SemiBold y Nunito Bold en WOFF2, solo con
las letras del español, para incrustarlas en la página del juez (sin pedir
nada a otros servidores). Se corre desde server/juez:

    pip install fonttools brotli
    python3 scripts/fuentes.py
"""
import base64
import io
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

FONTS = Path(__file__).resolve().parents[3] / 'assets' / 'fonts'
TEXT = (
    ''.join(chr(c) for c in range(0x20, 0x7F))
    + 'áéíóúÁÉÍÓÚñÑüÜ¿¡…·–—“”‘’'
)


def woff2(name):
    font = TTFont(FONTS / name)
    options = subset.Options()
    options.flavor = 'woff2'
    options.layout_features = ['kern', 'liga']
    sub = subset.Subsetter(options)
    sub.populate(text=TEXT)
    sub.subset(font)
    out = io.BytesIO()
    font.flavor = 'woff2'
    font.save(out)
    return base64.b64encode(out.getvalue()).decode()


js = (
    '// Generado por scripts/fuentes.py: no editar a mano.\n'
    '// Fredoka y Nunito (licencia OFL, ver assets/fonts), solo con las\n'
    '// letras del español.\n'
    f"export const FREDOKA = '{woff2('Fredoka_600SemiBold.ttf')}';\n"
    f"export const NUNITO = '{woff2('Nunito_700Bold.ttf')}';\n"
)
Path(__file__).resolve().parents[1].joinpath('src', 'fuentes.js').write_text(js)
print(f'{len(js) // 1024} KB')

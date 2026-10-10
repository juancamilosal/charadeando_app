"""Valida una tanda nueva de frases LIBRE contra todas las anteriores.

Uso: python3 server/palabras/validar_libre.py server/palabras/libre_AAAA-MM-DD.json

Revisa que cada elemento tenga frase, categoría LIBRE y dificultad válida,
que la frase tenga de 1 a 4 palabras, que ninguna se repita ni sea variante
de otra (de esta tanda o de las anteriores `libre_*.json`) y que ningún
verbo o palabra importante aparezca más de 3 veces en la tanda.
Termina con código 1 si encuentra algún problema.
"""
import json
import re
import sys
import unicodedata
from collections import Counter
from pathlib import Path

DIFICULTADES = {'FACIL', 'NORMAL', 'DIFICIL'}
MAX_USOS = 3
STOP = set(
    'el la los las un una unos unas de del al a y e o u en con sin por para '
    'mi tu su se que me te nos le les lo muy mucho mucha esta estoy hay no'.split()
)


def plain(texto):
    texto = unicodedata.normalize('NFD', texto.lower())
    texto = ''.join(c for c in texto if unicodedata.category(c) != 'Mn')
    return re.sub(r'[^a-z0-9 ]', ' ', texto)


def importantes(texto):
    return frozenset(w for w in plain(texto).split() if w not in STOP)


def main(ruta):
    nueva = Path(ruta).resolve()
    anteriores = []
    for archivo in sorted(nueva.parent.glob('libre_*.json')):
        if archivo.resolve() != nueva:
            anteriores += [(e['frase'], archivo.name) for e in json.loads(archivo.read_text())]
    vistas = [(frase, origen, importantes(frase)) for frase, origen in anteriores]

    tanda = json.loads(nueva.read_text())
    problemas, usos = [], Counter()
    for e in tanda:
        frase = e.get('frase', '')
        if e.get('categoria') != 'LIBRE':
            problemas.append(f'categoría no es LIBRE: {frase}')
        if e.get('dificultad') not in DIFICULTADES:
            problemas.append(f'dificultad no válida: {frase}')
        if not 1 <= len(frase.split()) <= 4:
            problemas.append(f'{len(frase.split())} palabras: {frase}')
        palabras = importantes(frase)
        for otra, origen, suyas in vistas:
            if palabras <= suyas or suyas <= palabras:
                problemas.append(f'repetida o variante: {frase} ~ {otra} ({origen})')
        vistas.append((frase, 'esta tanda', palabras))
        usos.update(palabras)
    for palabra, veces in usos.items():
        if veces > MAX_USOS:
            problemas.append(f'"{palabra}" aparece {veces} veces')

    print(f'{len(tanda)} frases:', dict(Counter(e.get('dificultad') for e in tanda)))
    print('\n'.join(problemas) or 'Sin problemas')
    return 1 if problemas else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))

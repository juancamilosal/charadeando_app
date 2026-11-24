"""Arma el diccionario de "Letras" (assets/diccionario/es.bin).

Uso, desde la raíz del repositorio:

    python3 tool/diccionario/construir.py

1. Descarga el diccionario ortográfico de LibreOffice en español, variante
   de Colombia (proyecto RLA-ES: es_CO.dic y es_CO.aff), de
   https://github.com/LibreOffice/dictionaries/tree/master/es
   Licencia: GPL 3, LGPL 3 o MPL 1.1 o posterior; aquí se usa la MPL (2.0).
2. Expande las raíces con sus afijos (plurales, femeninos, verbos
   conjugados…), como el comando unmunch de Hunspell.
3. Deja solo las palabras en minúscula (sin nombres propios ni siglas) y
   las guarda como claves: minúsculas y sin tildes ni diéresis, pero con la
   ñ ("canción" -> "cancion", "año" -> "año"). Es la misma clave que usa
   la app (lib/models/letter_words.dart).
4. Las ordena y las guarda con prefijos compartidos (cada línea dice
   cuántas letras repite de la anterior, de 0 a 9, y el resto) y en gzip.
   El archivo termina en .bin y no en .gz: Android trata aparte los
   archivos .gz de la app y en el celular no cargaba.
"""
import collections
import gzip
import hashlib
import re
import sys
import unicodedata
import urllib.request
from pathlib import Path

FUENTE = 'https://raw.githubusercontent.com/LibreOffice/dictionaries/master/es/'
SALIDA = Path('assets/diccionario/es.bin')


def descargar(nombre):
    with urllib.request.urlopen(FUENTE + nombre, timeout=60) as r:
        datos = r.read()
    print(f'{nombre}: {len(datos)} bytes, sha256 {hashlib.sha256(datos).hexdigest()}')
    return datos.decode('utf-8')


def reglas_de(aff):
    reglas = collections.defaultdict(list)
    cruzan = {}
    for linea in aff.split('\n'):
        p = linea.split('#')[0].split()
        if len(p) < 4 or p[0] not in ('SFX', 'PFX'):
            continue
        if len(p) == 4 and p[3].isdigit():
            cruzan[(p[0], p[1])] = p[2] == 'Y'
            continue
        tipo, bandera, quita, agrega = p[0], p[1], p[2], p[3]
        cond = p[4] if len(p) > 4 else '.'
        quita = '' if quita == '0' else quita
        mas = ''
        if '/' in agrega:
            agrega, mas = agrega.split('/', 1)
        agrega = '' if agrega == '0' else agrega
        rx = re.compile(cond + '$' if tipo == 'SFX' else '^' + cond)
        reglas[bandera].append((tipo, quita, agrega, mas, rx))
    return reglas, cruzan


def expandir(dic, aff):
    reglas, cruzan = reglas_de(aff)

    def sufijos(palabra, banderas, nivel):
        res = []
        for b in banderas:
            for tipo, quita, agrega, mas, rx in reglas.get(b, []):
                if tipo != 'SFX' or not rx.search(palabra):
                    continue
                if quita and not palabra.endswith(quita):
                    continue
                nueva = (palabra[: -len(quita)] if quita else palabra) + agrega
                res.append((nueva, b))
                if mas and nivel < 1:
                    res += [(x, b) for x, _ in sufijos(nueva, mas, nivel + 1)]
        return res

    def prefijos(palabra, banderas):
        res = []
        for b in banderas:
            for tipo, quita, agrega, _, rx in reglas.get(b, []):
                if tipo != 'PFX' or not rx.search(palabra):
                    continue
                if quita and not palabra.startswith(quita):
                    continue
                res.append(agrega + palabra[len(quita):])
        return res

    formas = set()
    for linea in dic.split('\n')[1:]:
        linea = linea.strip()
        if not linea:
            continue
        palabra, _, banderas = linea.partition('/')
        banderas = banderas.split()[0] if banderas else ''
        formas.add(palabra)
        sf = sufijos(palabra, banderas, 0)
        formas.update(w for w, _ in sf)
        formas.update(prefijos(palabra, banderas))
        cruzables = [b for b in banderas if cruzan.get(('PFX', b))]
        for w, b in sf:
            if cruzan.get(('SFX', b)):
                formas.update(prefijos(w, cruzables))
    return formas


def clave(palabra):
    """Igual que LetterWords.key en la app, sin quitar plurales."""
    p = palabra.lower().replace('ñ', '\0')
    p = ''.join(c for c in unicodedata.normalize('NFD', p) if unicodedata.category(c) != 'Mn')
    return p.replace('\0', 'ñ')


def main():
    dic = descargar('es_CO.dic')
    aff = descargar('es_CO.aff')
    formas = expandir(dic, aff)
    claves = sorted({clave(w) for w in formas if w and w[0].islower() and w.isalpha()})
    lineas, anterior = [], ''
    for k in claves:
        n = 0
        while n < min(len(anterior), len(k), 9) and anterior[n] == k[n]:
            n += 1
        lineas.append(f'{n}{k[n:]}')
        anterior = k
    datos = ('\n'.join(lineas) + '\n').encode('utf-8')
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    # mtime=0: el mismo diccionario da siempre el mismo archivo.
    SALIDA.write_bytes(gzip.compress(datos, 9, mtime=0))
    print(f'{len(formas)} formas -> {len(claves)} palabras -> {SALIDA} ({SALIDA.stat().st_size} bytes)')


if __name__ == '__main__':
    sys.exit(main())

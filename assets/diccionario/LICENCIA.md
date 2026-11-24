# Diccionario de "Letras"

`es.txt.gz` es una lista de palabras en español derivada del diccionario
ortográfico de LibreOffice en español (variante de Colombia, `es_CO.dic` y
`es_CO.aff`), del proyecto RLA-ES, desarrollado por Santiago Bosio y
colaboradores:

- Fuente: https://github.com/LibreOffice/dictionaries/tree/master/es
- Proyecto: https://github.com/sbosio/rla-es
- Archivos usados (sha256):
  - `es_CO.dic`: 10f5e38e1c6898194cd860c237b1569725f721eb5eb0705e3a7158c69652c226
  - `es_CO.aff`: 243d5dc50b68261dd10118799724beb95a6c19d4f9d6848ebfc977430bf2f8e2

El diccionario original se distribuye con triple licencia (GNU GPL 3 o
posterior, GNU LGPL 3 o posterior, o MPL 1.1 o posterior). Esta lista
derivada se distribuye bajo la **Mozilla Public License 2.0**
(`MPL-2.0.txt`, en esta misma carpeta).

Cambios respecto al original: se expandieron las raíces con sus afijos
(plurales, femeninos y verbos conjugados), se quitaron los nombres propios
y las siglas, y cada palabra se guarda en minúsculas y sin tildes ni
diéresis (la ñ se conserva), ordenada y con prefijos compartidos. El
programa que lo genera es `tool/diccionario/construir.py`.

This Source Code Form is subject to the terms of the Mozilla Public License,
v. 2.0. If a copy of the MPL was not distributed with this file, You can
obtain one at https://mozilla.org/MPL/2.0/.

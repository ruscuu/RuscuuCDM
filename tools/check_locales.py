#!/usr/bin/env python3
"""Comprueba las traducciones de Ruscuu CDM.

- Cada frase que usa el código (L["..."] y las claves nameKey/labelKey/titleKey/descKey/textKey/tipKey)
  tiene traducción en todos los archivos de Locales/.
- No sobran traducciones de frases que ya no se usan.
- Cada traducción conserva los mismos marcadores de formato (%s, %d, %.1f, %%) en el mismo orden.

Uso: python3 tools/check_locales.py   (desde la carpeta del addon). Sale con código 1 si hay errores.
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STRING = r'"((?:[^"\\]|\\.)*)"'
FORMAT = re.compile(r"%[-+#0]*\d*(?:\.\d+)?[sdfgx%]")


def unescape(text):
    return re.sub(r"\\(.)", r"\1", text)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def used_keys():
    keys = set()
    for path in glob.glob(os.path.join(ROOT, "*.lua")):
        if os.path.basename(path) == "Locales.lua":
            continue
        text = read(path)
        keys |= {unescape(k) for k in re.findall(r"\bL\[" + STRING + r"\]", text)}
        keys |= {unescape(k) for k in re.findall(
            r"\b(?:nameKey|labelKey|titleKey|descKey|textKey|tipKey)\s*=\s*" + STRING, text)}
        for title, desc in re.findall(r"CreatePage\(" + STRING + r",\s*" + STRING, text):
            keys |= {unescape(title), unescape(desc)}
    return keys


def locale_tables():
    tables = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "Locales", "*.lua"))):
        entries = {}
        for key, value in re.findall(r"^L\[" + STRING + r"\]\s*=\s*" + STRING, read(path), re.M):
            key = unescape(key)
            if key in entries:
                print(f"{os.path.basename(path)}: traducción repetida: {key!r}")
            entries[key] = unescape(value)
        tables[os.path.basename(path)] = entries
    return tables


def main():
    used = used_keys()
    errors = 0
    tables = locale_tables()
    if not tables:
        print("No hay archivos en Locales/")
        return 1
    for name, entries in tables.items():
        for key in sorted(used - entries.keys()):
            print(f"{name}: falta la traducción de {key!r}")
            errors += 1
        for key in sorted(entries.keys() - used):
            print(f"{name}: traducción que ya no se usa: {key!r}")
            errors += 1
        for key, value in entries.items():
            if FORMAT.findall(key) != FORMAT.findall(value):
                print(f"{name}: los marcadores de formato no coinciden en {key!r} -> {value!r}")
                errors += 1
            if value.strip() == "":
                print(f"{name}: traducción vacía de {key!r}")
                errors += 1
    print(f"{len(used)} frases, {len(tables)} idiomas, {errors} errores")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

#!/bin/sh
# Pruebas del addon fuera del juego, con un simulador mínimo de la API de WoW (tests/wowmock.lua).
# Uso: sh tests/run.sh   (necesita luajit). Cada prueba va en su propio proceso para empezar limpia.
cd "$(dirname "$0")/.." || exit 1
failed=0

run() {
    if ! luajit "$@"; then
        echo "FALLO: $*"
        failed=1
    fi
}

for test in tests/test_*.lua; do
    run "$test"
done
# El addon completo, con el cliente del juego en cada idioma
for locale in enUS esES deDE frFR ptBR ruRU; do
    run tests/load_addon.lua "$locale"
done

exit $failed

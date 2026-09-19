#!/bin/sh
# Skull Browser -- preparacao do ambiente de build (Ubuntu / WSL).
#
# Instala as dependencias que o config.mk exige via pkg-config
# (gtk+-3.0, gthread-2.0, webkit2gtk-4.1, sqlite3, javascriptcoregtk-4.1,
# luajit) mais os modulos Lua usados em tempo de execucao (lfs, socket).
#
# Uso:
#   sh build-utils/setup-wsl-ubuntu.sh
#
# Precisa de sudo. Roda apenas o que falta; e seguro repetir.

set -eu

say() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

PACKAGES="
build-essential
pkg-config
libgtk-3-dev
libwebkit2gtk-4.1-dev
libsqlite3-dev
luajit
libluajit-5.1-dev
lua-filesystem
lua-socket
libgstreamer1.0-dev
gstreamer1.0-plugins-base
gstreamer1.0-plugins-good
"

say "Atualizando indice do apt"
sudo apt-get update

say "Instalando dependencias"
# shellcheck disable=SC2086
sudo apt-get install -y $PACKAGES

say "Conferindo pacotes pkg-config exigidos pelo config.mk"
missing=0
for pkg in gtk+-3.0 gthread-2.0 webkit2gtk-4.1 sqlite3 javascriptcoregtk-4.1 luajit; do
    if pkg-config --exists "$pkg"; then
        printf '  ok      %-24s %s\n' "$pkg" "$(pkg-config --modversion "$pkg")"
    else
        printf '  FALTA   %s\n' "$pkg"
        missing=1
    fi
done

say "Conferindo o binario Lua (config.mk exige LuaJIT ou Lua 5.1)"
if command -v luajit >/dev/null 2>&1; then
    printf '  ok      luajit                   %s\n' "$(luajit -v 2>&1 | head -1)"
else
    printf '  FALTA   luajit\n'
    missing=1
fi

say "Conferindo modulos Lua de runtime"
for mod in lfs socket; do
    if luajit -e "require('$mod')" >/dev/null 2>&1; then
        printf '  ok      %s\n' "$mod"
    else
        printf '  FALTA   %s  (necessario: lfs=sempre, socket=gopher)\n' "$mod"
        missing=1
    fi
done

if [ "$missing" -ne 0 ]; then
    say "Ambiente INCOMPLETO -- resolva os itens marcados FALTA acima"
    exit 1
fi

say "Ambiente pronto. Proximo passo:  make -j\$(nproc)"

#!/bin/sh
# Instala as dependencias de build do Skull Browser.
#
#   sh build-utils/setup-deps.sh          instala e verifica
#   sh build-utils/setup-deps.sh --check  so verifica, nao instala
#
# Suporta apt (Debian, Ubuntu), dnf (Fedora) e pacman (Arch, Omarchy).
# Precisa de sudo para instalar. Repetir e seguro.

set -eu

say() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

# --- que distro e esta -------------------------------------------------------

if command -v apt-get >/dev/null 2>&1; then
    FAMILY=debian
elif command -v dnf >/dev/null 2>&1; then
    FAMILY=fedora
elif command -v pacman >/dev/null 2>&1; then
    FAMILY=arch
else
    echo "Nao encontrei apt, dnf nem pacman." >&2
    echo "Instale manualmente: gtk3, webkit2gtk 4.1, sqlite3, luajit," >&2
    echo "lua-filesystem e lua-socket para Lua 5.1, gstreamer." >&2
    exit 1
fi

if [ -r /etc/os-release ]; then
    . /etc/os-release
    say "Distro: ${PRETTY_NAME:-$FAMILY}  (familia $FAMILY)"
else
    say "Familia de distro: $FAMILY"
fi

# --- pacotes por familia -----------------------------------------------------
#
# O que o config.mk exige via pkg-config: gtk+-3.0, gthread-2.0, webkit2gtk-4.1,
# sqlite3, javascriptcoregtk-4.1 e luajit (ou lua5.1). Em tempo de execucao o
# interpretador precisa achar lfs e socket -- e eles tem que ser da ABI 5.1,
# nao da 5.4, senao o require falha mesmo com o pacote instalado.

case "$FAMILY" in
debian)
    PACKAGES="build-essential pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev
              libsqlite3-dev luajit libluajit-5.1-dev lua-filesystem lua-socket
              libgstreamer1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good"
    INSTALL="sudo apt-get install -y"
    REFRESH="sudo apt-get update"
    ;;
fedora)
    PACKAGES="gcc make pkgconf-pkg-config gtk3-devel webkit2gtk4.1-devel
              sqlite-devel luajit luajit-devel lua-filesystem lua-socket
              gstreamer1-devel gstreamer1-plugins-base-devel"
    INSTALL="sudo dnf install -y"
    REFRESH="sudo dnf makecache"
    ;;
arch)
    PACKAGES="base-devel pkgconf gtk3 webkit2gtk-4.1 sqlite luajit
              lua51-filesystem lua51-socket gstreamer gst-plugins-base gst-plugins-good"
    INSTALL="sudo pacman -S --needed --noconfirm"
    REFRESH="sudo pacman -Sy"
    ;;
esac

if [ "$CHECK_ONLY" -eq 0 ]; then
    say "Atualizando indice de pacotes"
    $REFRESH
    say "Instalando"
    # shellcheck disable=SC2086
    $INSTALL $PACKAGES
fi

# --- verificacao -------------------------------------------------------------

missing=0

say "Pacotes pkg-config"
if ! command -v pkg-config >/dev/null 2>&1; then
    echo "  FALTA   pkg-config"
    missing=1
else
    for pkg in gtk+-3.0 gthread-2.0 webkit2gtk-4.1 sqlite3 javascriptcoregtk-4.1; do
        if pkg-config --exists "$pkg"; then
            printf '  ok      %-24s %s\n' "$pkg" "$(pkg-config --modversion "$pkg")"
        else
            printf '  FALTA   %s\n' "$pkg"
            missing=1
        fi
    done
fi

say "Interpretador Lua"
LUA_BIN=
for cand in luajit luajit51 lua5.1 lua-5.1 lua51; do
    if command -v "$cand" >/dev/null 2>&1 && "$cand" -v 2>&1 | grep -Eq '^Lua 5\.1|^LuaJIT'; then
        LUA_BIN=$cand
        break
    fi
done
if [ -n "$LUA_BIN" ]; then
    printf '  ok      %-24s %s\n' "$LUA_BIN" "$($LUA_BIN -v 2>&1 | head -1)"
else
    echo "  FALTA   luajit ou lua5.1 (config.mk nao aceita 5.2+)"
    missing=1
fi

say "Modulos Lua"
if [ -n "$LUA_BIN" ]; then
    for mod in lfs socket; do
        if "$LUA_BIN" -e "require('$mod')" >/dev/null 2>&1; then
            printf '  ok      %s\n' "$mod"
        else
            printf '  FALTA   %-8s (lfs e obrigatorio; socket move o gopher)\n' "$mod"
            missing=1
        fi
    done
else
    echo "  (pulado -- sem interpretador)"
fi

if [ "$missing" -ne 0 ]; then
    say "Incompleto. Resolva os itens marcados FALTA."
    [ "$FAMILY" = fedora ] && cat <<'EOF'

  No Fedora, lua-filesystem e lua-socket sao compilados para Lua 5.4.
  O LuaJIT nao os enxerga. Saidas possiveis:
    - luarocks --lua-version=5.1 install luafilesystem luasocket
    - ou construir contra lua5.1 em vez de luajit:  make USE_LUAJIT=0
EOF
    exit 1
fi

say "Ambiente pronto.  Proximo:  make -j\$(nproc)"

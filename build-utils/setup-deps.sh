#!/bin/sh
# Install the build dependencies for Skull Browser.
#
#   sh build-utils/setup-deps.sh          install, then check
#   sh build-utils/setup-deps.sh --check  check only, install nothing
#
# Handles apt (Debian, Ubuntu), dnf (Fedora) and pacman (Arch, Omarchy).
# Installing needs sudo. Running it again is safe.

set -eu

say() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

# --- which distribution is this -------------------------------------------------------

if command -v apt-get >/dev/null 2>&1; then
    FAMILY=debian
elif command -v dnf >/dev/null 2>&1; then
    FAMILY=fedora
elif command -v pacman >/dev/null 2>&1; then
    FAMILY=arch
else
    echo "Found neither apt, dnf nor pacman." >&2
    echo "Install by hand: gtk3, webkit2gtk 4.1, sqlite3, luajit," >&2
    echo "lua-filesystem and lua-socket for Lua 5.1, gstreamer." >&2
    exit 1
fi

if [ -r /etc/os-release ]; then
    . /etc/os-release
    say "Distribution: ${PRETTY_NAME:-$FAMILY}  ($FAMILY family)"
else
    say "Distribution family: $FAMILY"
fi

# --- packages, per family -----------------------------------------------------
#
# What config.mk asks pkg-config for: gtk+-3.0, gthread-2.0, webkit2gtk-4.1,
# sqlite3, javascriptcoregtk-4.1 and luajit (or lua5.1). At run time the
# interpreter has to find lfs and socket, and those must be built for the 5.1
# ABI, not 5.4, or require fails even with the package installed.

case "$FAMILY" in
debian)
    PACKAGES="build-essential pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev
              libsqlite3-dev luajit libluajit-5.1-dev lua-filesystem lua-socket lua-luassert lua-check
              libgstreamer1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good
              gstreamer1.0-plugins-bad gstreamer1.0-libav xvfb"
    INSTALL="sudo apt-get install -y"
    REFRESH="sudo apt-get update"
    ;;
fedora)
    PACKAGES="gcc make pkgconf-pkg-config gtk3-devel webkit2gtk4.1-devel
              sqlite-devel luajit luajit-devel lua-filesystem lua-socket
              gstreamer1-devel gstreamer1-plugins-base-devel
              gstreamer1-plugins-bad-free xorg-x11-server-Xvfb"
    INSTALL="sudo dnf install -y"
    REFRESH="sudo dnf makecache"
    ;;
arch)
    PACKAGES="base-devel pkgconf gtk3 webkit2gtk-4.1 sqlite luajit
              lua51-filesystem lua51-socket lua51-luassert luacheck
              gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-libav
              xorg-server-xvfb"
    INSTALL="sudo pacman -S --needed --noconfirm"
    REFRESH="sudo pacman -Sy"
    ;;
esac

if [ "$CHECK_ONLY" -eq 0 ]; then
    say "Refreshing the package index"
    $REFRESH
    say "Installing"
    # shellcheck disable=SC2086
    $INSTALL $PACKAGES
fi

# --- check -------------------------------------------------------------

missing=0

say "pkg-config packages"
if ! command -v pkg-config >/dev/null 2>&1; then
    echo "  MISSING pkg-config"
    missing=1
else
    for pkg in gtk+-3.0 gthread-2.0 webkit2gtk-4.1 sqlite3 javascriptcoregtk-4.1; do
        if pkg-config --exists "$pkg"; then
            printf '  ok      %-24s %s\n' "$pkg" "$(pkg-config --modversion "$pkg")"
        else
            printf '  MISSING %s\n' "$pkg"
            missing=1
        fi
    done
fi

say "Lua interpreter"
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
    echo "  MISSING luajit or lua5.1 (config.mk does not take 5.2+)"
    missing=1
fi

say "Lua modules"
if [ -n "$LUA_BIN" ]; then
    for mod in lfs socket; do
        if "$LUA_BIN" -e "require('$mod')" >/dev/null 2>&1; then
            printf '  ok      %s\n' "$mod"
        else
            printf '  MISSING %-8s (lfs is required; socket drives gopher)\n' "$mod"
            missing=1
        fi
    done
else
    echo "  (skipped, no interpreter)"
fi

if [ "$missing" -ne 0 ]; then
    say "Incomplete. Deal with the items marked MISSING."
    [ "$FAMILY" = fedora ] && cat <<'EOF'

  On Fedora, lua-filesystem and lua-socket are built for Lua 5.4, and
  luassert is not packaged at all. LuaJIT cannot see any of them.
  Two ways out:
    - luarocks --lua-version=5.1 install luafilesystem luasocket luassert
    - or build against lua5.1 instead of luajit:  make USE_LUAJIT=0
EOF
    exit 1
fi

say "Environment ready.  Next:  make -j\$(nproc)"

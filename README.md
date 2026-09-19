# Skull Browser

A keyboard-driven web browser that treats the small web as a first-class
citizen. Regular sites over `https://`, plus native `gopher://` support.
Everything above the C core is Lua, and you can change all of it.

![C](https://img.shields.io/badge/C-C11-555555?logo=c&logoColor=white)
![Lua](https://img.shields.io/badge/Lua-5.1%20%2F%20LuaJIT-2C2D72?logo=lua&logoColor=white)
![WebKitGTK](https://img.shields.io/badge/WebKitGTK-4.1-1F7A3D)


## What it is

Modal navigation in the vim tradition: `hjkl` to scroll, `f` to follow links by
keyboard hint, `:` for commands. The rendering engine is WebKitGTK, the widget
layer is GTK 3, and roughly sixty Lua modules sit on top providing tabs, modes,
bindings, ad blocking, bookmarks, history, downloads and the internal
`skull://` pages.

Version 0.01. Linux only. It has never been built on macOS, BSD or Windows, so
it is not claimed to work there. On Windows it runs under WSL with WSLg, because
that is Linux.


## Requirements

    GTK 3
    WebKitGTK 4.1
    Lua 5.1 or LuaJIT
    lfs        (lua filesystem)
    socket     (lua socket, for gopher)
    sqlite3
    gstreamer  (video playback)


## Install

Clone, pull in the dependencies, build:

    git clone https://github.com/runawaydevil/skull-browser.git
    cd skull-browser
    sh build-utils/setup-deps.sh
    make

`setup-deps.sh` handles apt, dnf and pacman. It needs sudo to install and it
verifies everything afterwards, so run it once and read what it prints. To
check an existing system without installing anything:

    sh build-utils/setup-deps.sh --check

Then install system-wide:

    sudo make install

Or into your home directory, no root needed:

    make PREFIX=$HOME/.local XDGPREFIX=$HOME/.local/etc/xdg install

Make sure `$HOME/.local/bin` is on your `PATH` if you go that route.


## Run

    skull
    skull gopher://gopher.floodgap.com
    skull -k        # check config and exit

Press `gA` or type `:about` for version information.


## Configuration

User config lives in `~/.config/skull/`. Copy the shipped `rc.lua` there and
edit it:

    mkdir -p ~/.config/skull
    cp config/rc.lua config/theme.lua ~/.config/skull/

A system install also drops a copy in `/usr/local/etc/xdg/skull/`, which is
picked up automatically when there is nothing in `~/.config/skull/`. A home
install (`PREFIX=$HOME/.local`) puts it somewhere the browser does not search,
so copy it by hand as shown above.

Themes are a flat Lua table in `theme.lua` with a cascading naming scheme:
`tab_selected_fg` falls back to `selected_fg`, then to `fg`. Change a handful
of root keys and the whole interface follows.


## Tests

    make run-tests

Requires `luassert`. The suite covers the Lua modules and the C bindings.


## License

GNU GPLv3. See `COPYING.GPLv3`.

Based on luakit. All prior authorship is preserved in `AUTHORS`.

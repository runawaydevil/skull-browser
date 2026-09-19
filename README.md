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

Under WSL, calling it from Windows needs a login shell, otherwise `~/.local/bin`
is not on `PATH` and the name does not resolve:

    wsl -d Ubuntu -- bash -lc 'skull gopher://gopher.floodgap.com'

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


## Security model

Worth reading before you trust this with anything.

### What it does by default

    third-party cookies      blocked
    DNS prefetching          off
    WebGL, WebAudio          off
    media capture            off
    clipboard access by JS   denied
    popups by JS             denied
    developer tools          off
    page permissions         denied
    typed addresses          https, never http
    Referer, cross-domain    dropped
    Referer, same domain     cut back to the origin, no path or query
    Referer on a downgrade   dropped
    files written on disk    0600, the process runs under umask 0077
    ad and tracker lists     EasyList, EasyPrivacy, EasyList Portuguese

### What it does not do

There is no sandbox around Lua. A module under `~/.config/skull/` runs in the
browser process with every power your user account has: it can read your files,
open sockets and start programs. That is the same deal as a window manager
config, and it is what makes the browser worth using, but it means **a Lua
module you did not read is a program you did not read**.

The same applies to userscripts installed with `:usinstall`. They reach the
bridge into Lua, so treat one from a web page as you would treat a shell script
from a web page.

JavaScript is on by default. Turn it off globally or per domain in `rc.lua`:

    settings.webview.enable_javascript = false
    settings.on["example.com"].webview.enable_javascript = true

Saved form data, including passwords, is stored in `~/.local/share/skull/`
as plain Lua that the browser executes on every page load. The file is 0600
and the pattern is anchored to the page host, but it is not encrypted. If that
matters to you, use a password manager and do not use `:formfiller`.

### Certificates

When a certificate fails verification you can trust it anyway. That choice
covers one certificate on one host, not the host in general, so a different
certificate on the same host warns again. The exception lapses after 90 days.

    gC          list the stored exceptions
    :certs      same thing

While an exception is in force the status bar shows `(exception)` rather than
`(trust)`, because the connection is not verified, it is excused.

### Reporting something

Open an issue at <https://github.com/runawaydevil/skull-browser/issues>. If it
is a vulnerability rather than a bug, say so in the title and leave out the
working payload until it is fixed.


## Extending

Everything above the C core is Lua, and the Lua is on your disk.

    lib/             the modules that make up the browser
    lib/*_wm.lua     modules that run inside WebKit's render process
    lib/lousy/       widgets and utilities shared by the rest
    config/rc.lua    what gets loaded, and in what order
    widgets/         the C widgets exposed to Lua
    clib/            the C libraries exposed to Lua

A module is an ordinary Lua file returning a table. Drop it in
`~/.config/skull/` and `require` it from your `rc.lua`.

An internal page takes about ten lines:

    local chrome = require "chrome"

    chrome.add("hello", function ()
        return "<html><body><h1>hello</h1></body></html>"
    end)

That gives you `skull://hello/`. Pass a table of functions as the fourth
argument to `chrome.add` and they become callable from the page's JavaScript,
returning promises. Only pages served from `skull://` can reach them.

Key bindings and commands go through `modes`:

    local modes = require "modes"

    modes.add_binds("normal", {
        { "^gh$", "Go home.", function (w) w:navigate("skull://newtab/") end },
    })

    modes.add_cmds({
        { ":hello", "Say hello.", function (w) w:notify("hello") end },
    })

Type `:help` in the browser for the generated documentation, which covers
every module, binding and setting present in your build.

`docs/decisions/` holds the decisions that shaped the fork and the reasoning
behind them. `001-webkitgtk-api.md` explains why nothing new should be written
under `extension/`.


## Contributing

    make                     build
    make run-tests           the whole suite
    make apidoc              regenerate doc/apidocs

The suite includes style checks. `luacheck` runs over every Lua file, trailing
whitespace fails the build, and every exported module function needs a doc
comment. Run the tests before sending anything; CI runs the same commands on
push and on pull requests.

Tests live in `tests/async/`, one file per module, each returning a table of
`test_*` functions. A fix belongs with a test that fails without it.

Commit messages say what changed and why, in English, present tense, with a
short subject line and a body when the subject is not enough.


## License

GNU GPLv3. See `COPYING.GPLv3`.

Based on luakit. All prior authorship is preserved in `AUTHORS`.

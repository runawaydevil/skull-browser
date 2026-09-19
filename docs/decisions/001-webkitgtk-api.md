# 001. Stay on webkit2gtk-4.1

**Date:** 2026-09-19
**Status:** accepted

## The problem

Skull Browser builds against `webkit2gtk-4.1`, the WebKitGTK API for GTK 3.
The current upstream API is `webkitgtk-6.0`, which requires GTK 4 and libsoup 3.

Two sentences from the official documentation set out the risk. From the
migration guide for 6.0:

> All APIs that were previously deprecated in webkit2gtk-4.0 and webkit2gtk-4.1
> have been removed. [...] It also includes the entire GObject DOM API (e.g.
> `WebKitDOMDocument`), which has been **removed without replacement**. Use
> JavaScript to interact with and manipulate the DOM instead.

And, in the same document:

> Beware that as of WebKitGTK 2.40, **the entire web process API may
> unfortunately be removed in the future.**

## Why that matters here

The second sentence is the serious one. The luakit architecture, and so ours,
is built on exactly that API:

- `extension/` is around 1,900 lines of C whose whole purpose is to run a Lua
  VM **inside** WebKit's rendering process
- the ten `lib/*_wm.lua` modules, around 1,480 lines, assume synchronous access
  to the DOM from that process
- `extension/scroll.c` goes as far as defining `WEBKIT_DOM_USE_UNSTABLE_API` to
  read the scroll position

If the web process API goes away, that is not an adjustment. Every synchronous
`dom_element` property becomes an asynchronous round trip, and all ten modules
have to be rethought.

Moving to 6.0 also drags GTK 3 to GTK 4 along with it, a port of its own that
is larger than any phase planned in this project so far.

## Decision

**Stay on `webkit2gtk-4.1`.** Do not migrate now.

The real pressure is low. 4.1 is supported upstream, Ubuntu 24.04 ships
WebKitGTK 2.52.6 built against it, and the build passes with deprecation
warnings only, no errors. No date has been announced for the removal.

## What follows from it

**Do not add new code under `extension/`.**

Code written there is code with an expiry date. When something can be done in
the interface process instead, or through `eval_js`, that is the way to do it,
even when it looks clumsier today.

## When to revisit

- when a distribution we care about stops packaging `webkit2gtk-4.1`
- when upstream announces a date for removing the web process API
- if something comes up that would force `extension/` to grow, at which point
  the cost of migrating has to be weighed against the cost of staying

## Sources

- WebKit 6.0: Migrating WebKitGTK Applications to GTK 4 (official documentation)
- WebKitGTK API Versions Demystified, Michael Catanzaro, 2025-04-28

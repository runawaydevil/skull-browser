--- New tab page for luakit.
--
-- This module provides <skull://newtab/>, the luakit new
-- tab page. This page is opened by default when opening a new tab without
-- specifying a URL to open.
--
-- # Customization
--
-- The easiest way to customize what is shown at
-- <skull://newtab/> is to create a HTML file at the
-- path specified by `newtab_chrome.new_tab_file`. By default, this is the
-- `newtab.html` file located in the luakit data directory.
--
-- If this file exists, then its contents will be used to provide the new tab
-- page. Otherwise, the value of `newtab_chrome.new_tab_src` is used.
--
-- # Files and Directories
--
-- - The default path for the new-tab file is `newtab.html`, located in the luakit data directory.
--
-- @module newtab_chrome
-- @author Aidan Holm
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

local chrome = require "chrome"
local theme = require "theme"
local luakit = require "luakit"
local settings = require "settings"

local _M = {}

--- Path to a HTML file to use for the new tab page.
--The default value is `$XDG_DATA_DIR/luakit/newtab.html`.
-- @type string
-- @readwrite
_M.new_tab_file = luakit.data_dir .. "/newtab.html"

-- The mark is inlined because the new tab page has to render before anything
-- else is ready to serve it a file.
local mark_svg = [==[
<svg class="mark" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" shape-rendering="crispEdges">
  <g fill="#3df07a">
    <rect x="9"  y="4"  width="14" height="2"/>
    <rect x="7"  y="6"  width="18" height="2"/>
    <rect x="6"  y="8"  width="20" height="10"/>
    <rect x="7"  y="18" width="18" height="2"/>
    <rect x="9"  y="20" width="14" height="2"/>
    <rect x="11" y="22" width="10" height="4"/>
  </g>
  <g fill="#0b0d11">
    <rect x="9"  y="10" width="5" height="5"/>
    <rect x="18" y="10" width="5" height="5"/>
    <rect x="15" y="15" width="2" height="3"/>
    <rect x="12" y="22" width="2" height="4"/>
    <rect x="15" y="22" width="2" height="4"/>
    <rect x="18" y="22" width="2" height="4"/>
  </g>
</svg>
]==]

--- HTML string to use for the new tab page, when no HTML file is present.
-- The default is the page Skull ships: the mark, the name, and the handful of
-- keys worth knowing before anything is open. Colours come from `theme.lua`.
-- @type string
-- @readwrite
_M.new_tab_src = ([==[
    <html>
    <head>
        <title>New Tab</title>
        <style>
            :root {
                --bg:   {bg};
                --fg:   {fg};
                --dim:  {dim};
                --phos: {phos};
            }
            * { box-sizing: border-box; }
            html, body { height: 100%; }
            body {
                margin: 0;
                display: flex;
                align-items: center;
                justify-content: center;
                background: var(--bg);
                color: var(--fg);
                font-family: ui-monospace, Menlo, Consolas, monospace;
            }
            .plate {
                text-align: center;
                opacity: 0.92;
            }
            .mark {
                width: 84px;
                height: 84px;
                margin: 0 auto 1.4rem;
                display: block;
            }
            .name {
                font-size: 0.78rem;
                letter-spacing: 0.42em;
                text-indent: 0.42em;
                text-transform: uppercase;
                color: var(--phos);
                margin: 0 0 0.5rem;
            }
            .hint {
                font-size: 0.72rem;
                color: var(--dim);
                margin: 0;
                line-height: 1.9;
            }
            .hint b {
                color: var(--fg);
                font-weight: 600;
            }
        </style>
    </head>
    <body>
        <div class="plate">
            {mark}
            <p class="name">Skull</p>
            <p class="hint">
                <b>o</b> open &nbsp; <b>t</b> new tab &nbsp; <b>f</b> follow<br>
                <b>:</b> command &nbsp; <b>gA</b> about &nbsp; <b>gC</b> certificates
            </p>
        </div>
    </body>
    </html>
]==]):gsub("{(%w+)}", {
    bg   = theme.bg,
    fg   = theme.fg,
    dim  = theme.tab_ntheme or theme.fg,
    phos = theme.selected_ntheme or theme.fg,
    mark = mark_svg,
})

local function load_file_contents(file)
    if not file then return nil end
    local f = io.open(file, "rb")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

chrome.add("newtab", function ()
    return load_file_contents(_M.new_tab_file) or _M.new_tab_src
end)

luakit.idle_add(function ()
    local undoclose = package.loaded.undoclose
    if not undoclose then return end
    undoclose.add_signal("save", function (view)
        local uri, hist = view.uri or "", view.history
        if uri:match("^skull://newtab/?") and #hist.items == 1 then
            return false
        end
    end)
end)

require "window"
settings.override_setting("window.new_tab_page", "skull://newtab/")

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80

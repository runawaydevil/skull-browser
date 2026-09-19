--- About page for Skull Browser.
--
-- This module provides <skull://about/>, which shows the browser name, the
-- running version and where the project came from. It is reachable with the
-- `gA` binding or the `:about` command.
--
-- @module about_chrome
-- @copyright 2026 Pablo Murad <pablomurad@pm.me>

local chrome = require("chrome")
local lousy = require("lousy")
local modes = require("modes")
local add_binds, add_cmds = modes.add_binds, modes.add_cmds

local _M = {}

--- CSS applied to the about page.
-- @type string
-- @readwrite
_M.stylesheet = [===[
    :root {
        --bg:      #07090c;
        --phos:    #3df07a;
        --phos-dim:#1f8f49;
        --bone:    #e9e5d9;
        --muted:   #5d6470;
        --cyan:    #35d6c3;
    }
    * { box-sizing: border-box; }
    body {
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 92vh;
        margin: 0;
        font-family: monospace;
        color: var(--bone);
        background:
            radial-gradient(ellipse at 50% 28%, #10281b 0%, transparent 62%),
            var(--bg);
    }
    /* Scanline sweep: faint, just enough that the background is not dead. */
    body::after {
        content: "";
        position: fixed;
        inset: 0;
        pointer-events: none;
        background: repeating-linear-gradient(
            to bottom, rgba(0,0,0,0.22) 0 1px, transparent 1px 3px);
    }
    #about { text-align: center; line-height: 1.75; }
    #mark {
        width: 104px;
        height: 104px;
        margin: 0 auto 30px;
        image-rendering: pixelated;
        filter: drop-shadow(0 0 14px rgba(61,240,122,0.45));
    }
    #name {
        font-size: 44px;
        font-weight: 700;
        letter-spacing: 12px;
        margin: 0 0 2px;
        padding-left: 12px;
        color: var(--phos);
        text-shadow: 0 0 18px rgba(61,240,122,0.55);
    }
    #tagline {
        font-size: 12px;
        letter-spacing: 3px;
        text-transform: uppercase;
        color: var(--phos-dim);
        margin: 0 0 26px;
    }
    #version {
        font-size: 12px;
        color: var(--muted);
        margin: 0 0 32px;
    }
    #author { font-size: 15px; margin: 0 0 6px; }
    #author b { color: var(--phos); font-weight: 700; }
    #site {
        display: inline-block;
        font-size: 13px;
        color: var(--cyan);
        text-decoration: none;
        border-bottom: 1px solid rgba(53,214,195,0.35);
        padding-bottom: 1px;
        margin-bottom: 34px;
    }
    #site:hover { border-bottom-color: var(--cyan); }
    #origin {
        font-size: 11px;
        color: var(--muted);
        max-width: 52ex;
        margin: 0 auto;
        padding-top: 20px;
        border-top: 1px solid rgba(93,100,112,0.22);
    }
]===]

-- The skull is inlined: the page has to render without depending on a
-- resource handler that does not exist.
local mark_svg = [==[
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<rect width="64" height="64" rx="14" fill="#050B07"/>
<g fill="#3DF07A">
<rect x="20" y="11" width="24" height="3"/><rect x="14" y="14" width="36" height="3"/>
<rect x="11" y="17" width="42" height="3"/><rect x="8" y="20" width="48" height="3"/>
<rect x="8" y="23" width="6" height="3"/><rect x="23" y="23" width="18" height="3"/>
<rect x="50" y="23" width="6" height="3"/><rect x="8" y="26" width="6" height="3"/>
<rect x="23" y="26" width="18" height="3"/><rect x="50" y="26" width="6" height="3"/>
<rect x="8" y="29" width="48" height="3"/><rect x="8" y="32" width="21" height="3"/>
<rect x="35" y="32" width="21" height="3"/><rect x="8" y="35" width="48" height="3"/>
<rect x="11" y="38" width="42" height="3"/><rect x="14" y="41" width="36" height="3"/>
<rect x="17" y="44" width="30" height="3"/><rect x="20" y="47" width="24" height="3"/>
<rect x="20" y="50" width="3" height="3"/><rect x="26" y="50" width="3" height="3"/>
<rect x="35" y="50" width="3" height="3"/><rect x="41" y="50" width="3" height="3"/>
</g></svg>
]==]

local html_template = [==[
<!DOCTYPE html>
<html>
<head>
    <title>About</title>
    <style>{stylesheet}</style>
</head>
<body>
    <div id="about">
        <div id="mark">{mark}</div>
        <p id="name">SKULL</p>
        <p id="tagline">{tagline}</p>
        <p id="version">{version}</p>
        <p id="author">developed by <b>{author}</b></p>
        <a id="site" href="{site}">{site}</a>
        <p id="origin">{origin}</p>
    </div>
</body>
</html>
]==]

chrome.add("about", function ()
    local subs = {
        stylesheet = _M.stylesheet,
        mark = mark_svg,
        tagline = "keyboard-driven browser for the whole web",
        version = lousy.util.escape(luakit.version),
        author = "pmurad",
        site = "https://pablomurad.com",
        origin = "Based on luakit. Distributed under the GNU GPLv3.",
    }
    return (string.gsub(html_template, "{(%w+)}", subs))
end)

add_binds("normal", {
    { "^gA$", "Open the about page.", function (w) w:navigate("skull://about/") end },
})

add_cmds({
    { ":about", "Open the about page.", function (w) w:navigate("skull://about/") end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80

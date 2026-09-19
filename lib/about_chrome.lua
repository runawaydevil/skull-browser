--- Pagina skull://about.
--
-- @module about_chrome
-- @copyright 2026 Pablo Murad <pablomurad@pm.me>

local chrome = require("chrome")
local lousy = require("lousy")
local modes = require("modes")
local add_binds, add_cmds = modes.add_binds, modes.add_cmds

local _M = {}

_M.stylesheet = [===[
    body {
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 78vh;
        margin: 0;
        background: #0c0d10;
        color: #e7e3d8;
        font-family: monospace;
    }
    #about {
        text-align: center;
        line-height: 1.7;
    }
    #mark {
        width: 96px;
        height: 96px;
        margin: 0 auto 26px;
        image-rendering: pixelated;
    }
    #name {
        font-size: 30px;
        font-weight: 700;
        letter-spacing: 3px;
        margin: 0;
        color: #3df07a;
    }
    #version {
        font-size: 13px;
        color: #6f7480;
        margin: 6px 0 30px;
    }
    #author {
        font-size: 15px;
        margin: 0 0 30px;
    }
    #origin {
        font-size: 12px;
        color: #6f7480;
        max-width: 46ex;
        margin: 0 auto;
    }
]===]

-- O cranio, embutido: a pagina precisa funcionar sem depender de um handler
-- de recurso que hoje nao existe.
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
    <title>Sobre</title>
    <style>{stylesheet}</style>
</head>
<body>
    <div id="about">
        <div id="mark">{mark}</div>
        <p id="name">SKULL BROWSER</p>
        <p id="version">{version}</p>
        <p id="author">{author}</p>
        <p id="origin">{origin}</p>
    </div>
</body>
</html>
]==]

chrome.add("about", function ()
    local subs = {
        stylesheet = _M.stylesheet,
        mark = mark_svg,
        version = lousy.util.escape(luakit.version),
        author = "Pablo Murad",
        origin = "Baseado no luakit. Distribuido sob a GNU GPLv3.",
    }
    return (string.gsub(html_template, "{(%w+)}", subs))
end)

add_binds("normal", {
    { "^gA$", "Abrir a pagina sobre.", function (w) w:navigate("skull://about/") end },
})

add_cmds({
    { ":about", "Abrir a pagina sobre.", function (w) w:navigate("skull://about/") end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80

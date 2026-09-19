--- Shared presentation layer for the small web.
--
-- `gopher://` and `gemini://` arrive as plain text over a plain socket and
-- leave as HTML. The parts that are the same for both, meaning the page shell,
-- the stylesheet and the choice between the page and terminal looks, live
-- here so the two schemes cannot drift apart.
--
-- ## Render modes
--
-- `smallweb.render_mode` takes `page` or `terminal`.
--
-- `page` reads like a document: comfortable measure, ordinary link colour.
--
-- `terminal` reads like a terminal: full width, fixed columns, a caret on
-- every link and a phosphor cast over the whole thing. It is the default,
-- because it is what these protocols were written against.
--
-- @module smallweb
-- @copyright 2026 Pablo Murad <pablomurad@pm.me>

local lousy = require("lousy")
local settings = require("settings")

local _M = {}

settings.register_settings({
    ["smallweb.render_mode"] = {
        type = "enum",
        options = {
            page     = { desc = "Read as a document, with a comfortable measure." },
            terminal = { desc = "Read as a terminal, full width and monospaced." },
        },
        default = "terminal",
        desc = [=[
            How `gopher://` and `gemini://` pages are presented.
        ]=],
    },
})

--- Return the palette for the current mode, taken from `theme.lua`.
-- @treturn table Fields `bg`, `fg` and `link`.
_M.palette = function ()
    local theme = lousy.theme.get()
    local dark = settings.get_setting("application.prefer_dark_mode")
    local pal = dark and theme.gopher_dark or theme.gopher_light
    if not pal then
        msg.warn("smallweb: no small web palette in theme.lua, using defaults")
        return dark and { bg = "#0b0d11", fg = "#e9e5d9", link = "#35d6c3" }
            or { bg = "#f4f2ec", fg = "#15181d", link = "#0d7d71" }
    end
    return pal
end

--- The stylesheet for a small web page, including the `<style>` element.
-- @treturn string
_M.stylesheet = function ()
    local pal = _M.palette()
    local terminal = settings.get_setting("smallweb.render_mode") == "terminal"

    local shell = terminal
        and [[
            body { max-width: none; padding: 1.25rem 1.5rem; }
            pre, .menu { font-size: 13px; line-height: 1.45; }
            a::before { content: "> "; opacity: 0.55; }
            .heading { color: ]] .. pal.link .. [[; font-weight: 600; }
            .quote { opacity: 0.75; border-left: 2px solid currentColor;
                     padding-left: 0.9em; margin-left: 0; }
        ]]
        or [[
            body { max-width: 80ex; padding: 1.5rem; margin: 0 auto; }
            pre, .menu { font-size: 14px; line-height: 1.6; }
            .heading { font-weight: 600; }
            .quote { opacity: 0.8; border-left: 3px solid currentColor;
                     padding-left: 1em; margin-left: 0; }
        ]]

    return [[
        <style>
            body, pre, input, .menu {
                font-family: ui-monospace, Menlo, Consolas, monospace;
            }
            body {
                background-color: ]] .. pal.bg .. [[;
                color: ]] .. pal.fg .. [[;
                margin: 0;
            }
            a, a:active, a:visited {
                text-decoration: none;
                color: ]] .. pal.link .. [[;
            }
            a:hover { text-decoration: underline; }
            h1, h2, h3 { font-size: 1em; margin: 1.2em 0 0.4em; }
            input {
                background: transparent;
                color: inherit;
                border: 1px solid currentColor;
                padding: 0.15em 0.4em;
            }
            ]] .. shell .. [[
        </style>
    ]]
end

--- Wrap rendered body markup in a complete document.
-- @tparam string title The page title. Escaped here, pass it raw.
-- @tparam string body Markup for the document body. Passed through as is.
-- @tparam[opt] string head Extra markup for the document head.
-- @treturn string
_M.document = function (title, body, head)
    return table.concat({
        "<html><head><title>", lousy.util.escape(tostring(title or "")), "</title>",
        '<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />',
        _M.stylesheet(), head or "", "</head><body>", body, "</body></html>",
    })
end

--- Escape text for HTML, including the braces that `error_page` reads as
-- placeholders.
-- @tparam string text The text to escape.
-- @treturn string
_M.escape = function (text)
    return (lousy.util.escape(tostring(text))
        :gsub("{", "&#123;"):gsub("}", "&#125;"))
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80

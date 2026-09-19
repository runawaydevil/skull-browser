--- Add custom skull:// scheme rendering functions.
--
-- This module provides a convenient interface for other modules to add
-- `skull://` chrome pages, with features like a shared theme, error reporting,
-- and Lua to JavaScript function bridge management.
--
-- @module chrome
-- @copyright 2010-2012 Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010 Fabian Streitel <karottenreibe@gmail.com>

local error_page = require("error_page")
local lousy = require("lousy")
local webview = require("webview")
local window = require("window")
local wm = require_web_module("chrome_wm")

local _M = {}

--- Common stylesheet that can be sourced from several chrome modules
-- for a consitent looking theme.
-- @type string
-- @readwrite
_M.stylesheet = [===[
    /* The identity lives here. Every skull:// page pulls this sheet in first,
       so changing a token below moves all of them at once. */
    :root {
        --bg:        #0b0d11;
        --bg-raised: #11151b;
        --bg-sunken: #070910;
        --line:      #1e242e;
        --line-soft: #161b23;

        --fg:        #e9e5d9;
        --fg-dim:    #98a0ae;
        --fg-faint:  #5d6470;

        --phos:      #3df07a;
        --phos-dim:  #1f8f49;
        --cyan:      #35d6c3;
        --amber:     #e8b23a;
        --blood:     #e05260;

        --radius:    3px;
        --mono:      ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace;
        --pad:       1.5rem;
        --header-h:  3.25rem;
    }

    @media (prefers-color-scheme: light) {
        :root:not([data-theme="dark"]) {
            --bg:        #f4f2ec;
            --bg-raised: #ffffff;
            --bg-sunken: #e7e4db;
            --line:      #d6d2c6;
            --line-soft: #e3dfd4;

            --fg:        #15181d;
            --fg-dim:    #4c535e;
            --fg-faint:  #848b96;

            --phos:      #0f7a3c;
            --phos-dim:  #16a64f;
            --cyan:      #0d7d71;
            --amber:     #9a6d05;
            --blood:     #b3202f;
        }
    }

    * { box-sizing: border-box; }

    body {
        background-color: var(--bg);
        color: var(--fg);
        display: block;
        margin: 0;
        padding: 0;
        font-family: var(--mono);
        font-size: 14px;
        line-height: 1.55;
        -webkit-font-smoothing: antialiased;
    }

    a { color: var(--cyan); text-decoration: none; }
    a:hover { color: var(--phos); }

    code, pre { font-family: var(--mono); }

    ::selection { background: var(--phos-dim); color: var(--bg); }

    #page-header {
        display: flex;
        -webkit-align-items: center;
        background-color: var(--bg-raised);
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        margin: 0;
        padding: 0 var(--pad);
        height: var(--header-h);
        border-bottom: 1px solid var(--line);
        -webkit-user-select: none;
        overflow-y: hidden;
        z-index: 100000;
    }
    #page-header > h1 {
        font-size: 0.85rem;
        font-weight: 600;
        letter-spacing: 0.18em;
        text-transform: uppercase;
        margin: 0 1.5em 0 0;
        color: var(--phos);
        cursor: default;
        white-space: nowrap;
    }
    /* The bar the title sits on, so the header reads as a console strip. */
    #page-header > h1::before {
        content: "";
        display: inline-block;
        width: 3px;
        height: 0.9em;
        margin-right: 0.7em;
        background: var(--phos);
        vertical-align: -0.05em;
    }
    #page-header > h1:first-child { margin-left: 0; }

    .content-margin {
        padding: calc(var(--header-h) + 1.5rem) var(--pad) 3rem var(--pad);
        max-width: 68rem;
    }

    h2 {
        font-size: 0.95rem;
        font-weight: 600;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: var(--fg);
    }
    h3 {
        font-size: 0.85rem;
        font-weight: 600;
        letter-spacing: 0.06em;
        color: var(--fg-dim);
    }

    #page-header input {
        font-family: var(--mono);
        font-size: 0.82rem;
        padding: 0.45rem 0.7rem;
        border: none;
        outline: none;
        margin: 0;
        color: var(--fg);
        background-color: var(--bg-sunken);
    }
    #page-header input::placeholder { color: var(--fg-faint); }

    #page-header #search-box {
        display: flex;
        padding: 0;
        background-color: var(--bg-sunken);
        border: 1px solid var(--line);
        border-radius: var(--radius);
    }
    #page-header #search-box:focus-within { border-color: var(--phos-dim); }

    #page-header #search {
        width: 20em;
        font-weight: normal;
        border-radius: var(--radius) 0 0 var(--radius);
        margin: 0;
        padding-right: 0;
        background: transparent;
    }

    #page-header #clear-button {
        margin: 0;
        padding: 0.45rem 0.6rem;
        border-radius: 0 var(--radius) var(--radius) 0;
        box-shadow: none;
        font-size: 0.9rem;
        line-height: 1rem;
        background: transparent;
        border: none;
        color: var(--fg-faint);
    }
    #page-header #clear-button:hover { color: var(--blood); }
    #page-header #clear-button:active { background-color: var(--line-soft); }

    .button {
        font-family: var(--mono);
        font-size: 0.8rem;
        letter-spacing: 0.04em;
        margin: 0.75rem 0 0.75rem 0.5rem;
        color: var(--fg-dim);
        background-color: transparent;
        display: inline-block;
        line-height: 1.25;
        text-align: center;
        white-space: nowrap;
        vertical-align: middle;
        -webkit-user-select: none;
        border: 1px solid var(--line);
        padding: 0.45rem 0.9rem;
        border-radius: var(--radius);
        transition: color 80ms linear, border-color 80ms linear,
                    background-color 80ms linear;
        cursor: pointer;
    }

    #page-header .button:hover, .button:hover {
        color: var(--phos);
        border-color: var(--phos-dim);
        background-color: var(--line-soft);
    }

    #page-header .button:active, .button:active {
        background-color: var(--bg-sunken);
    }

    #page-header .button[disabled], .button[disabled] {
        color: var(--fg-faint);
        border-color: var(--line-soft);
        background-color: transparent;
        cursor: not-allowed;
    }

    #page-header .rhs {
        display: flex;
        -webkit-align-items: center;
        position: fixed;
        top: 0;
        right: 0;
        margin: 0;
        padding-right: var(--pad);
        height: var(--header-h);
        background-color: inherit;
    }

    #page-header .rhs .button { margin-bottom: 0; }

    .license { font-family: var(--mono); }

    .hidden { display: none; }
]===]

-- skull:// page handlers
local handlers = {}
local on_first_visual_handlers = {}
local page_funcs = {}

--- Retrieve a list of the currently registered skull:// handlers.
-- @treturn {string} A list of `skull://` handler names, in alphabetical order.
function _M.available_handlers()
    return lousy.util.table.keys(handlers)
end

--- Register a chrome page URI with an associated handler function.
-- @tparam string page The name of the chrome page to register.
-- @tparam function func The handler function for the chrome page.
-- @tparam function on_first_visual_func An optional handler function
-- for the chrome page, called when the page first finishes loading.
-- @tparam table export_funcs An optional table of functions to
-- export to JavaScript.
function _M.add(page, func, on_first_visual_func, export_funcs)
    -- Do some sanity checking
    assert(type(page) == "string",
        "invalid chrome page name (string expected, got "..type(page)..")")
    assert(string.match(page, "^[%w%-]+$"),
        "illegal characters in chrome page name: " .. page)
    assert(type(func) == "function",
        "invalid chrome handler (function expected, got "..type(func)..")")
    assert(type(on_first_visual_func) == "nil"
        or type(on_first_visual_func) == "function",
        "invalid chrome handler (function/nil expected, got "..type(on_first_visual_func)..")")

    for name, export_func in pairs(export_funcs or {}) do
        assert(type(name) == "string")
        assert(type(export_func) == "function")
    end

    handlers[page] = func
    on_first_visual_handlers[page] = on_first_visual_func
    page_funcs[page] = export_funcs

    if page_funcs[page] then
        page_funcs[page].reset_mode = function (view)
            for _, w in pairs(window.bywidget) do
                if w.view == view then
                    w:set_mode()
                end
            end
        end
    end
end

--- Remove a regeistered chrome page.
-- @tparam string page The name of the chrome page to remove.
function _M.remove(page)
    handlers[page] = nil
    on_first_visual_handlers[page] = nil
end

luakit.register_scheme("skull")

-- Catch all navigations to the skull:// scheme
webview.add_signal("init", function (view)
    view:add_signal("scheme-request::skull", function (v, uri, request)
        -- Match "skull://page/path"
        local page, path = string.match(uri, "^skull://([^/]+)/?(.*)")
        if not page then return end

        local func = handlers[page]
        if func then
            -- Give the handler function everything it may need
            local w = webview.window(v)
            local meta = { page = page, path = path, w = w,
                uri = "skull://" .. page .. "/" .. path,
                request = request }

            -- Render error output in webview with traceback
            local function error_handler(err)
                error_page.show_error_page(v, {
                    heading = "Chrome handler error",
                    content = [==[
                        <div class="errorMessage">
                            <p>An error occurred in the <code>skull://{page}/</code> handler function:
                            <pre>{traceback}</pre>
                        </div>
                    ]==],
                    buttons = {},
                    page = page,
                    traceback = debug.traceback(err, 2),
                    request = request,
                })
            end

            -- Call skull:// page handler
            local ok, html, mime = xpcall(function () return func(v, meta) end,
                error_handler)
            if ok and not request.finished then request:finish(html, mime) end
            return
        end

        -- Load error page
        error_page.show_error_page(v, {
            heading = "Chrome handler error",
            content = [==[
                <div class="errorMessage">
                    <p>No chrome handler for <code>skull://{page}/</code></p>
                </div>
            ]==],
            buttons = {},
            page = page,
            request = request,
        })
    end)

    view:add_signal("load-status", function (v, status)
        -- Wait for new page to be created
        if status ~= "finished" then return end

        -- Match "skull://page/path"
        local page, path = string.match(v.uri, "^skull://([^/]+)/?(.*)")
        if not page then return end

        -- Ensure we have a hook to call
        local on_first_visual_func = on_first_visual_handlers[page]
        if not on_first_visual_func then return end

        local w = webview.window(v)
        local meta = { page = page, path = path, w = w,
            uri = "skull://" .. page .. "/" .. path }

        -- Call the supplied handler
        on_first_visual_func(v, meta)
    end)
    -- Always enable JavaScript on skull:// pages; without this, chrome
    -- pages which depend upon javascript will break
    view:add_signal("enable-scripts", function (v)
        if v.uri:match("^skull://") then return true end
    end)
end)

wm:add_signal("function-call", function (_, page_id, page_name, func_name, id, args)
    local func = assert(page_funcs[page_name][func_name])
    -- Find view
    local view
    for _, w in pairs(window.bywidget) do
        for _, v in pairs(w.tabs.children) do
            if v.id == page_id then view = v end
        end
    end
    -- Call Lua function, return result
    local ok, ret = xpcall(
        function () return func(view, unpack(args)) end,
        function (err)  msg.error(debug.traceback(err, 3)) end)
    wm:emit_signal(view, "function-return", id, ok, ret)
end)

luakit.add_signal("web-extension-created", function ()
    for page, export_funcs in pairs(page_funcs) do
        for name in pairs(export_funcs or {}) do
            wm:emit_signal("register-function", page, name)
        end
    end
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80

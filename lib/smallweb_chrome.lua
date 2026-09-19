--- Small web settings and known-host manager.
--
-- This module provides <skull://smallweb/>, which switches between the page
-- and terminal render modes and lists the gemini hosts remembered by
-- `smallweb.tofu`, so any of them can be forgotten.
--
-- Forgetting a host means the next visit is treated as a first one and its
-- certificate is trusted again without asking.
--
-- @module smallweb_chrome
-- @copyright 2026 Pablo Murad <pablomurad@pm.me>

local chrome = require("chrome")
local lousy = require("lousy")
local settings = require("settings")
local tofu = require("smallweb.tofu")
local modes = require("modes")
local add_binds, add_cmds = modes.add_binds, modes.add_cmds

local _M = {}

--- CSS applied to the small web page.
-- @type string
-- @readwrite
_M.stylesheet = [===[
    .modes { display: flex; gap: 0.75rem; margin: 0 0 2rem; }
    .mode {
        flex: 1;
        border: 1px solid var(--line);
        border-radius: var(--radius);
        padding: 1rem 1.1rem;
        cursor: pointer;
        background: var(--bg-raised);
    }
    .mode[data-active="true"] {
        border-color: var(--phos-dim);
        box-shadow: inset 3px 0 0 var(--phos);
    }
    .mode h3 { margin: 0 0 0.3rem; color: var(--fg); }
    .mode p { margin: 0; color: var(--fg-dim); font-size: 0.82rem; }

    table { border-collapse: collapse; width: 100%; }
    th {
        text-align: left; font-weight: normal; color: var(--fg-faint);
        font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.06em;
        padding: 0 1em 0.5em 0;
    }
    td { padding: 0.6em 1em 0.6em 0; border-top: 1px solid var(--line-soft);
         vertical-align: baseline; }
    td.host { color: var(--fg); }
    td.fp { color: var(--fg-faint); font-size: 0.78rem; word-break: break-all; }
    td.when { color: var(--fg-dim); white-space: nowrap; }
    td.act { text-align: right; width: 1%; }
    .forget { color: var(--blood); cursor: pointer; }
    .forget:hover { text-decoration: underline; }
    .empty { color: var(--fg-faint); padding: 2em 0; }
]===]

local html_template = [==[
<html>
<head>
    <title>Small web</title>
    <style type="text/css">{%stylesheet}</style>
</head>
<body>
    <div class="content-margin">
        <h2>Render mode</h2>
        <div class="modes">
            <div class="mode" data-mode="terminal" data-active="{%terminal}">
                <h3>Terminal</h3>
                <p>Full width, monospaced, a caret on every link.</p>
            </div>
            <div class="mode" data-mode="page" data-active="{%page}">
                <h3>Page</h3>
                <p>A comfortable measure, read like a document.</p>
            </div>
        </div>

        <h2>Known gemini hosts</h2>
        <p style="color:var(--fg-dim);font-size:0.85rem;margin-top:0">
            The certificate each host first presented, remembered so a change
            can be spotted. Forget one and its next certificate is trusted
            without asking.
        </p>
        {%rows}
    </div>
    <script type="text/javascript">{%javascript}</script>
</body>
</html>
]==]

local main_js = [=[
    document.addEventListener("click", function (event) {
        var el = event.target;
        var mode = el.closest ? el.closest(".mode") : null;
        if (mode) {
            set_render_mode(mode.dataset.mode).then(function () {
                window.location.reload();
            });
            return;
        }
        if (el.classList && el.classList.contains("forget")) {
            event.preventDefault();
            forget_host(el.dataset.host).then(function () {
                window.location.reload();
            });
        }
    });
]=]

local function format_time (t)
    return os.date("%Y-%m-%d %H:%M", tonumber(t) or 0)
end

local function build_rows ()
    local hosts = tofu.known_hosts()
    if #hosts == 0 then
        return "<p class=\"empty\">No gemini hosts remembered yet.</p>"
    end
    local out = {
        "<table><tr><th>Host</th><th>Fingerprint (SHA-256)</th>",
        "<th>First seen</th><th></th></tr>",
    }
    for _, h in ipairs(hosts) do
        local fp = h.fingerprint or ""
        local short = #fp > 24 and (fp:sub(1, 24) .. "...") or fp
        out[#out+1] = string.format(
            "<tr><td class=\"host\">%s</td><td class=\"fp\">%s</td>"
            .. "<td class=\"when\">%s</td>"
            .. "<td class=\"act\"><a class=\"forget\" href=\"#\" data-host=\"%s\">forget</a></td></tr>",
            lousy.util.escape(h.host), lousy.util.escape(short),
            format_time(h.first_seen), lousy.util.escape(h.host))
    end
    out[#out+1] = "</table>"
    return table.concat(out)
end

local export_funcs = {
    set_render_mode = function (mode)
        if mode == "page" or mode == "terminal" then
            settings.set_setting("smallweb.render_mode", mode)
            return true
        end
        return false
    end,
    forget_host = function (host)
        assert(type(host) == "string", "expected a host")
        return tofu.forget(host)
    end,
}

chrome.add("smallweb", function ()
    local mode = settings.get_setting("smallweb.render_mode")
    return (string.gsub(html_template, "{%%(%w+)}", {
        stylesheet = chrome.stylesheet .. _M.stylesheet,
        javascript = main_js,
        rows = build_rows(),
        terminal = tostring(mode == "terminal"),
        page = tostring(mode == "page"),
    }))
end, nil, export_funcs)

add_binds("normal", {
    { "^gS$", "Open the small web settings.",
        function (w) w:navigate("skull://smallweb/") end },
})

add_cmds({
    { ":smallweb", "Open the small web settings.",
        function (w) w:navigate("skull://smallweb/") end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80

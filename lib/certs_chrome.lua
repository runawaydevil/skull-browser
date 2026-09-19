--- Certificate exception manager.
--
-- This module provides <skull://certs/>, which lists every certificate the
-- user chose to trust after it failed verification, and lets any of them be
-- taken back.
--
-- An exception covers one certificate on one host. It lapses on its own after
-- `error_page.cert_exception_lifetime`, and this page is where it can be ended
-- sooner.
--
-- @module certs_chrome
-- @copyright 2026 Pablo Murad <pablomurad@pm.me>

local chrome = require("chrome")
local error_page = require("error_page")
local lousy = require("lousy")
local modes = require("modes")
local add_binds, add_cmds = modes.add_binds, modes.add_cmds

local _M = {}

--- CSS applied to the certificate page.
-- @type string
-- @readwrite
_M.stylesheet = [===[
    .header {
        display: flex;
        align-items: baseline;
        justify-content: space-between;
        border-bottom: 1px solid #d8d8d8;
        padding-bottom: 0.6em;
        margin-bottom: 1.4em;
    }
    .header h1 { margin: 0; font-size: 1.4em; }
    .header .count { color: #888; font-size: 0.9em; }

    .note {
        background: #fff8e1;
        border-left: 3px solid #e0a800;
        padding: 0.8em 1em;
        margin-bottom: 1.6em;
        font-size: 0.9em;
        line-height: 1.5;
    }

    table { border-collapse: collapse; width: 100%; }
    th {
        text-align: left;
        font-weight: normal;
        color: #888;
        font-size: 0.82em;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        padding: 0 1em 0.5em 0;
    }
    td {
        padding: 0.7em 1em 0.7em 0;
        border-top: 1px solid #ececec;
        vertical-align: baseline;
    }
    td.host { font-family: monospace; font-size: 1em; }
    td.when { color: #666; white-space: nowrap; }
    td.act { text-align: right; width: 1%; }

    .revoke {
        color: #b00020;
        cursor: pointer;
        text-decoration: none;
        border-bottom: 1px solid transparent;
    }
    .revoke:hover { border-bottom-color: #b00020; }

    .empty { color: #888; padding: 2em 0; }
]===]

local html_template = [==[
<html>
<head>
    <title>Certificate exceptions</title>
    <style type="text/css">{%stylesheet}</style>
</head>
<body>
    <div class="header">
        <h1>Certificate exceptions</h1>
        <span class="count">{%count}</span>
    </div>
    <div class="note">
        Each row is one certificate that failed verification and was trusted
        anyway. Revoking takes effect for new connections; a certificate WebKit
        has already been told to accept stays accepted until the browser is
        restarted.
    </div>
    {%rows}
    <script type="text/javascript">{%javascript}</script>
</body>
</html>
]==]

local function format_time (t)
    return os.date("%Y-%m-%d %H:%M", t)
end

local function build_rows ()
    local rows = error_page.certificate_exceptions()

    if #rows == 0 then
        return "<p class=\"empty\">No certificate exceptions are stored.</p>", "none"
    end

    local out = {
        "<table><tr><th>Host</th><th>Trusted on</th><th>Lapses on</th><th></th></tr>",
    }
    for _, row in ipairs(rows) do
        out[#out+1] = string.format(
            "<tr><td class=\"host\">%s</td><td class=\"when\">%s</td>"
            .. "<td class=\"when\">%s</td>"
            .. "<td class=\"act\"><a class=\"revoke\" href=\"#\" data-host=\"%s\">revoke</a></td></tr>",
            lousy.util.escape(row.host), format_time(row.created),
            format_time(row.expires), lousy.util.escape(row.host))
    end
    out[#out+1] = "</table>"

    local count = string.format("%d host%s", #rows, #rows == 1 and "" or "s")
    return table.concat(out), count
end

local main_js = [=[
    document.addEventListener("click", function (event) {
        var link = event.target;
        if (!link.classList || !link.classList.contains("revoke")) return;
        event.preventDefault();
        var host = link.dataset.host;
        revoke_certificate(host).then(function () { window.location.reload(); });
    });
]=]

local export_funcs = {
    revoke_certificate = function (host)
        assert(type(host) == "string", "expected a host name")
        return error_page.remove_certificate_exception(host)
    end,
}

chrome.add("certs", function ()
    local rows, count = build_rows()
    return (string.gsub(html_template, "{%%(%w+)}", {
        stylesheet = chrome.stylesheet .. _M.stylesheet,
        javascript = main_js,
        rows = rows,
        count = count,
    }))
end, nil, export_funcs)

add_binds("normal", {
    { "^gC$", "Open the certificate exception manager.",
        function (w) w:navigate("skull://certs/") end },
})

add_cmds({
    { ":certs", "Open the certificate exception manager.",
        function (w) w:navigate("skull://certs/") end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80

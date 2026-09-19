--- Add gemini:// scheme support.
--
-- Gemini is a small protocol: open TLS, send one line holding the URL, read
-- back one status line and a body. There is no compression, no cookies, no
-- scripting and no certificate authorities.
--
-- Trust works by trust on first use, handled by `smallweb.tofu`: the
-- certificate a host presents the first time is remembered, and a different
-- one later is reported rather than accepted.
--
-- Needs LuaSec, the `ssl` module. Without it the scheme is registered anyway
-- and every request explains what is missing, rather than failing silently.
--
-- @module gemini
-- @copyright 2026 Pablo Murad <pablomurad@pm.me>

local smallweb = require("smallweb")
local tofu = require("smallweb.tofu")

local socket_loaded, socket = pcall(require, "socket")
local ssl_loaded, ssl = pcall(require, "ssl")

local error_page = require("error_page")
local webview = require("webview")

local _M = {}

luakit.register_scheme("gemini")

--- Default port for gemini, fixed by the specification.
-- @type number
-- @readwrite
_M.default_port = 1965

--- How many redirects to follow before giving up.
-- @type number
-- @readwrite
_M.max_redirects = 5

--- How long to wait on a host, in seconds.
-- @type number
-- @readwrite
_M.timeout = 30

-- ---------------------------------------------------------------------------
-- URL handling
-- ---------------------------------------------------------------------------

--- Parse a gemini URL.
-- @tparam string url The URL to parse.
-- @treturn table Fields `host`, `port`, `path`, `query` and `title`.
_M.parse_url = function (url)
    assert(type(url) == "string", "expected a url string")

    local rest = url:match("^[Gg][Ee][Mm][Ii][Nn][Ii]://(.*)$")
    if not rest then error("not a gemini url: " .. url, 0) end

    local authority, path = rest:match("^([^/]*)(.*)$")
    if not authority or authority == "" then
        error("gemini url has no host: " .. url, 0)
    end

    local query
    path, query = (path or ""):match("^([^?]*)%??(.*)$")
    if path == "" then path = "/" end

    local host, port = authority:match("^(.-):(%d+)$")
    host = host or authority
    port = tonumber(port) or _M.default_port

    -- The host reaches a TLS handshake and a fingerprint store, so keep it to
    -- what a host name can actually contain.
    host = host:gsub("[^%w%.%-]", "")
    if host == "" then error("gemini url has no usable host: " .. url, 0) end

    return {
        host = host,
        port = port,
        path = path,
        query = query ~= "" and query or nil,
        title = authority .. path,
    }
end

local function url_string (url)
    local port = url.port ~= _M.default_port and (":" .. url.port) or ""
    return "gemini://" .. url.host .. port .. url.path
        .. (url.query and ("?" .. url.query) or "")
end

--- Resolve a link target against the page it was found on.
-- @tparam string target The link target, absolute or relative.
-- @tparam table base The parsed url of the page holding the link.
-- @treturn string An absolute url.
_M.resolve = function (target, base)
    if target:match("^%a[%w+.-]*:") then return target end

    local port = base.port ~= _M.default_port and (":" .. base.port) or ""
    local root = "gemini://" .. base.host .. port

    if target:sub(1, 2) == "//" then return "gemini:" .. target end
    if target:sub(1, 1) == "/" then return root .. target end

    local dir = base.path:match("^(.*/)") or "/"
    return root .. dir .. target
end

-- ---------------------------------------------------------------------------
-- gemtext
-- ---------------------------------------------------------------------------

--- Render gemtext as HTML.
--
-- The whole format is six line types: links, three heading levels, list items,
-- quotes, and a fence that toggles preformatted blocks.
--
-- @tparam string text The gemtext body.
-- @tparam table base The parsed url it came from, for resolving links.
-- @treturn string Markup for the document body.
_M.gemtext_to_html = function (text, base)
    local esc = smallweb.escape
    local out, pre, list = {}, false, false

    local function close_list ()
        if list then out[#out+1] = "</ul>" list = false end
    end

    for line in (text .. "\n"):gmatch("(.-)\r?\n") do
        if line:sub(1, 3) == "```" then
            close_list()
            if pre then
                out[#out+1] = "</pre>"
            else
                local alt = line:sub(4)
                out[#out+1] = alt ~= ""
                    and ('<pre aria-label="' .. esc(alt) .. '">') or "<pre>"
            end
            pre = not pre
        elseif pre then
            out[#out+1] = esc(line)
        elseif line:sub(1, 2) == "=>" then
            close_list()
            local target, label = line:match("^=>%s*(%S+)%s*(.-)$")
            if target then
                local href = _M.resolve(target, base)
                out[#out+1] = '<div class="menu"><a href="' .. esc(href)
                    .. '">' .. esc(label ~= "" and label or target) .. "</a></div>"
            end
        elseif line:sub(1, 1) == "#" then
            close_list()
            local hashes, body = line:match("^(#+)%s*(.*)$")
            local level = math.min(#hashes, 3)
            out[#out+1] = "<h" .. level .. ' class="heading">' .. esc(body)
                .. "</h" .. level .. ">"
        elseif line:sub(1, 2) == "* " then
            if not list then out[#out+1] = "<ul>" list = true end
            out[#out+1] = "<li>" .. esc(line:sub(3)) .. "</li>"
        elseif line:sub(1, 1) == ">" then
            close_list()
            out[#out+1] = '<p class="quote">' .. esc((line:sub(2):gsub("^%s", "")))
                .. "</p>"
        elseif line == "" then
            close_list()
            out[#out+1] = "<br>"
        else
            close_list()
            out[#out+1] = "<p>" .. esc(line) .. "</p>"
        end
    end

    if pre then out[#out+1] = "</pre>" end
    close_list()

    return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------------
-- Transport
-- ---------------------------------------------------------------------------

local tls_params = {
    mode = "client",
    protocol = "any",
    -- Verification is ours, not OpenSSL's: gemini has no certificate
    -- authorities, so a chain to a known root is not the question. What
    -- matters is whether the same certificate came back, which tofu answers.
    verify = "none",
    options = { "all", "no_sslv2", "no_sslv3", "no_tlsv1", "no_tlsv1_1" },
}

local function fingerprint_of (conn)
    local cert = conn.getpeercertificate and conn:getpeercertificate()
    if not cert then error("the server sent no certificate", 0) end
    local digest = cert:digest("sha256")
    if not digest or digest == "" then
        error("could not fingerprint the server certificate", 0)
    end
    return (digest:upper():gsub("[^%x]", ""))
end

-- One transaction, written so it can be driven a step at a time from a timer
-- rather than blocking the interface.
local function request (url)
    local sock = socket.tcp()
    sock:settimeout(0)

    local deadline = os.time() + _M.timeout
    local function expired ()
        if os.time() > deadline then
            error("timed out talking to " .. url.host, 0)
        end
    end

    local ok, err = sock:connect(url.host, url.port)
    if not ok and err ~= "timeout" and err ~= "Operation already in progress" then
        error("cannot reach " .. url.host .. ": " .. tostring(err), 0)
    end
    while not ok do
        if coroutine.yield() then sock:close() return end
        expired()
        local _, ready, serr = socket.select(nil, {sock}, 0)
        if (ready or {})[sock] then break end
        if serr and serr ~= "timeout" then
            error("cannot reach " .. url.host .. ": " .. tostring(serr), 0)
        end
    end

    local params = {}
    for k, v in pairs(tls_params) do params[k] = v end
    -- Without SNI a shared host cannot tell which certificate to send.
    params.sni = url.host

    local conn
    conn, err = ssl.wrap(sock, params)
    if not conn then
        sock:close()
        error("cannot start TLS: " .. tostring(err), 0)
    end
    conn:settimeout(0)
    if conn.sni then pcall(conn.sni, conn, url.host) end

    while true do
        local done, herr = conn:dohandshake()
        if done then break end
        if herr ~= "wantread" and herr ~= "wantwrite" and herr ~= "timeout" then
            conn:close()
            error("TLS handshake failed: " .. tostring(herr), 0)
        end
        if coroutine.yield() then conn:close() return end
        expired()
    end

    local status, stored = tofu.check(
        url.host .. ":" .. url.port, fingerprint_of(conn))
    if status == "changed" then
        conn:close()
        error("CERTIFICATE_CHANGED\t" .. tostring(stored), 0)
    end

    local message = url_string(url) .. "\r\n"
    local sent = 0
    while sent < #message do
        local n, serr, last = conn:send(message, sent + 1)
        if n then
            sent = n
        elseif serr == "wantwrite" or serr == "wantread" or serr == "timeout" then
            sent = last or sent
        else
            conn:close()
            error("could not send the request: " .. tostring(serr), 0)
        end
        if sent < #message then
            if coroutine.yield() then conn:close() return end
            expired()
        end
    end

    local chunks = {}
    while true do
        local data, rerr, partial = conn:receive("*a")
        if data then chunks[#chunks+1] = data break end
        if rerr == "closed" then chunks[#chunks+1] = partial or "" break end
        if rerr ~= "wantread" and rerr ~= "wantwrite" and rerr ~= "timeout" then
            conn:close()
            error("could not read the reply: " .. tostring(rerr), 0)
        end
        if partial and partial ~= "" then chunks[#chunks+1] = partial end
        if coroutine.yield() then conn:close() return end
        expired()
    end

    conn:close()

    local body = table.concat(chunks)
    local header, rest = body:match("^(.-)\r?\n(.*)$")
    if not header then error("the reply had no status line", 0) end

    local code, meta = header:match("^(%d%d)%s*(.*)$")
    if not code then
        error("the status line made no sense: " .. header:sub(1, 60), 0)
    end

    return { code = code, meta = meta or "", body = rest or "" }
end

-- ---------------------------------------------------------------------------
-- Presentation
-- ---------------------------------------------------------------------------

local status_text = {
    ["10"] = "The server is asking for input.",
    ["11"] = "The server is asking for input, and will not echo it.",
    ["40"] = "The server is temporarily unavailable.",
    ["41"] = "The server is unavailable.",
    ["42"] = "A CGI process on the server failed.",
    ["43"] = "A proxy the server relies on failed.",
    ["44"] = "The server is asking you to slow down.",
    ["50"] = "The request was refused.",
    ["51"] = "Not found.",
    ["52"] = "Gone. The resource will not come back.",
    ["53"] = "This server does not proxy for that host.",
    ["59"] = "The server did not understand the request.",
    ["60"] = "A client certificate is required, which Skull does not send yet.",
    ["61"] = "The client certificate was not authorised.",
    ["62"] = "The client certificate was not valid.",
}

local function input_page (url, meta, secret)
    local prompt = smallweb.escape(meta ~= "" and meta or "Input")
    local target = url_string({ host = url.host, port = url.port, path = url.path })
    local body = table.concat({
        '<h1 class="heading">', prompt, "</h1>",
        '<form onsubmit="return go()">',
        '<input id="q" type="', secret and "password" or "text",
        '" size="48" autofocus>',
        "</form>",
        "<script>function go(){",
        "var v=encodeURIComponent(document.getElementById('q').value);",
        "window.location=", string.format("%q", target), "+'?'+v; return false;}",
        "</script>",
    })
    return smallweb.document(url.title, body)
end

local function body_to_page (reply, url)
    local mime = reply.meta:match("^([^;]*)") or "text/gemini"
    mime = mime:gsub("%s", "")
    if mime == "" then mime = "text/gemini" end

    if mime == "text/gemini" then
        return smallweb.document(url.title,
            _M.gemtext_to_html(reply.body, url)), "text/html"
    end

    if mime:match("^text/") then
        return smallweb.document(url.title,
            "<pre>" .. smallweb.escape(reply.body) .. "</pre>"), "text/html"
    end

    -- Images and everything else go to WebKit untouched.
    return reply.body, mime
end

-- ---------------------------------------------------------------------------
-- Wiring
-- ---------------------------------------------------------------------------

local load_timer = timer{ interval = 50 }
local loads = {}

load_timer:add_signal("timeout", function ()
    if not next(loads) then load_timer:stop() end
end)

local function remove_loader (v, loader)
    local co = loads[v]
    if co then
        loads[v] = nil
        coroutine.resume(co, "stop")
    end
    if loader then load_timer:remove_signal("timeout", loader) end
end

local function show_error (v, request_obj, heading, reason, buttons)
    pcall(error_page.show_error_page, v, {
        heading = heading,
        content = smallweb.escape(reason),
        buttons = buttons,
        request = request_obj,
    })
end

local function handle_reply (v, request_obj, reply, url)
    local class = reply.code:sub(1, 1)

    if class == "2" then
        local html, mime = body_to_page(reply, url)
        request_obj:finish(html, mime)
        return
    end

    if class == "1" then
        request_obj:finish(input_page(url, reply.meta, reply.code == "11"),
            "text/html")
        return
    end

    if class == "3" then
        local target = _M.resolve(reply.meta, url)
        -- The redirect is handed back to the browser rather than followed
        -- here, so the address bar tells the truth and a redirect that leaves
        -- gemini reaches the handler that can serve it.
        request_obj:finish(smallweb.document(url.title,
            '<p>Redirected to <a href="' .. smallweb.escape(target) .. '">'
            .. smallweb.escape(target) .. "</a></p>"
            .. "<script>window.location=" .. string.format("%q", target)
            .. ";</script>"), "text/html")
        return
    end

    show_error(v, request_obj, "Gemini Request Failed",
        (status_text[reply.code] or ("The server answered " .. reply.code .. "."))
        .. (reply.meta ~= "" and ("\n\n" .. reply.meta) or ""))
end

webview.add_signal("init", function (view)
    view:add_signal("scheme-request::gemini", function (v, uri, request_obj)
        if not (socket_loaded and ssl_loaded) then
            local missing = {}
            if not socket_loaded then missing[#missing+1] = "luasocket" end
            if not ssl_loaded then missing[#missing+1] = "luasec" end
            show_error(v, request_obj, "Gemini Support Is Not Installed",
                "gemini:// needs " .. table.concat(missing, " and ")
                .. ". Install it and restart:\n\n"
                .. "  sh build-utils/setup-deps.sh")
            return
        end

        local ok, url = pcall(_M.parse_url, uri)
        if not ok or not url then
            show_error(v, request_obj, "Gemini Address Not Understood",
                tostring(url or uri))
            return
        end

        local co = coroutine.create(function () return request(url) end)
        if not load_timer.started then load_timer:start() end
        loads[v] = co

        local function loader ()
            if loads[v] ~= co then return remove_loader(v, loader) end

            local alive = pcall(function () return v.is_loading end)
            local running, res = coroutine.resume(co, not alive)

            if not running then
                if not request_obj.finished then
                    local stored = tostring(res):match("^CERTIFICATE_CHANGED\t(.*)$")
                    if stored then
                        local host = url.host .. ":" .. url.port
                        show_error(v, request_obj,
                            "This Host Changed Its Certificate",
                            "The certificate " .. host .. " presents is not the"
                            .. " one it presented before.\n\nGemini has no"
                            .. " certificate authorities, so the only check is"
                            .. " that the certificate stays the same. This can"
                            .. " mean the operator rotated it, or that"
                            .. " something is sitting between you and the"
                            .. " host.\n\nOn record: " .. stored,
                            {{
                                label = "Trust the new certificate",
                                callback = function (vv)
                                    tofu.forget(host)
                                    vv:reload()
                                end,
                            }})
                    else
                        show_error(v, request_obj, "Gemini Request Failed",
                            tostring(res))
                    end
                end
                return remove_loader(v, loader)
            end

            if not res then return end

            if not request_obj.finished then
                local handled, err = pcall(handle_reply, v, request_obj, res, url)
                if not handled and not request_obj.finished then
                    show_error(v, request_obj, "Gemini Reply Not Understood",
                        tostring(err))
                end
            end
            remove_loader(v, loader)
        end

        load_timer:add_signal("timeout", loader)
    end)

    view:add_signal("load-status", function (v, status)
        if status == "failed" then remove_loader(v) end
    end)
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80

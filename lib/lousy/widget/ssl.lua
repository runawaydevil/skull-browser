--- Web page security - ssl status bar widget.
--
-- Indicates whether the connection used to load the current web page
-- was secure.
--
-- @module lousy.widget.ssl
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>
-- @copyright 2010 Mason Larobina <mason.larobina@gmail.com>

local webview = require("webview")
local lousy = require("lousy")
local theme = lousy.theme.get()
local wc = require("lousy.widget.common")

local _M = {}

-- Loaded lazily: error_page pulls in chrome and webview, and this widget is
-- built while those are still being set up.
local function has_exception (uri)
    local error_page = package.loaded.error_page
    if not error_page or not error_page.has_certificate_exception then return false end
    local ok, host = pcall(function () return lousy.uri.parse(uri).host end)
    return ok and error_page.has_certificate_exception(host) or false
end

local widgets = {
    update = function (w, ssl)
        local trusted = w.view:ssl_trusted()
        if trusted == true and has_exception(w.view.uri) then
            -- WebKit reports no certificate errors once it has been told to
            -- allow one, so a certificate the user waved through looks exactly
            -- like one that verified. It is not the same thing.
            ssl.fg = theme.notrust_fg
            ssl.text = "(exception)"
            ssl:show()
        elseif trusted == true then
            ssl.fg = theme.trust_fg
            ssl.text = "(trust)"
            ssl:show()
        elseif string.sub(w.view.uri or "", 1, 4) == "http" then
            -- Display (notrust) on http/https URLs
            ssl.fg = theme.notrust_fg
            ssl.text = "(notrust)"
            ssl:show()
        else
            ssl:hide()
        end
    end,
}

webview.add_signal("init", function (view)
    -- Update widget when current page changes status
    view:add_signal("load-status", function (v, status)
        local w = webview.window(v)
        if status == "committed" and w and w.view == v then
            wc.update_widgets_on_w(widgets, w)
        end
    end)
    view:add_signal("switched-page", function (v)
        wc.update_widgets_on_w(widgets, webview.window(v))
    end)
end)

local function new()
    local ssl = widget{type="label"}
    ssl:hide()
    ssl.fg = theme.ssl_sbar_fg
    ssl.font = theme.ssl_sbar_font
    return wc.add_widget(widgets, ssl)
end

return setmetatable(_M, { __call = function(_, ...) return new(...) end })

-- vim: et:sw=4:ts=8:sts=4:tw=80

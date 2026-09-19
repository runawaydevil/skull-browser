--- Basic async test functions.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local T = {}
local test = require "tests.lib"

local window = widget{type="window"}
local view = widget{type="webview"}
window.child = view
window:show()

T.test_about_blank_loads_successfully = function ()
    view.uri = "about:blank"
    test.wait_for_view(view)
end

T.test_bare_host_defaults_to_https = function ()
    -- A typed address used to become http://, so the first request for it
    -- went out in the clear and a redirect to https could be stripped.
    view.uri = "example.com"
    assert(view.uri == "https://example.com",
        "expected https://example.com, got " .. tostring(view.uri))

    -- An explicit scheme is still honoured, both ways.
    view.uri = "http://example.com/"
    assert(view.uri == "http://example.com/",
        "expected http to be left alone, got " .. tostring(view.uri))

    view.uri = "about:blank"
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80

--- Test settings.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local assert = require "luassert"

local settings = require "settings"

local T = {}

T.test_settings = function ()
    assert.is_table(settings)

    settings.register_settings({
        ["test.setting.with.long.path"] = {
            default = "foo",
            type = "string",
        },
        ["foo.bar"] = {
            type = "number",
        },
    })

    assert.equal(settings.test.setting.with.long.path, "foo")
    settings.test.setting.with.long.path = "bar"
    assert.equal(settings.test.setting.with.long.path, "bar")
    assert.has_error(function () settings.test.setting = "baz" end)

    assert.has_error(function () settings.non_existent_setting = 1 end)
    assert.has_error(function () return settings.on["foo"].on["foo"] end)

    settings.foo.bar = 1
    assert.equal(settings.foo.bar, 1)
    settings.on["example.com"].foo.bar = 2
    assert.equal(settings.foo.bar, 1)
    assert.equal(settings.on["example.com"].foo.bar, 2)
    assert.equal(settings.on[".com"].foo.bar, nil)
end

T.test_webview_settings_apply_before_any_load = function ()
    -- Settings used to be pushed onto the widget when the load committed, so
    -- a brand new view ran on WebKit's own defaults until its first page was
    -- already on the way in.
    -- webview.new is the constructor that runs the init hooks; a raw
    -- widget{type="webview"} skips them.
    local webview = require "webview"
    local was = settings.webview.enable_javascript

    settings.webview.enable_javascript = false
    assert.is_false(webview.new({}).enable_javascript)

    settings.webview.enable_javascript = true
    assert.is_true(webview.new({}).enable_javascript)

    settings.webview.enable_javascript = was
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80

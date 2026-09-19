--- Test trust on first use for the small web.
--
-- The whole point of TOFU is that the first certificate is remembered and a
-- change is caught. These pin exactly that: new, then known, then changed,
-- and the two ways out, trusting the new one or forgetting the host.

local assert = require "luassert"
local tofu = require "smallweb.tofu"

local T = {}

local function clean (host) tofu.forget(host) end

T.test_first_visit_is_new_then_known = function ()
    local host = "tofu-test-a:1965"
    clean(host)

    assert.equal("new", tofu.check(host, "AA:BB"))
    -- Same certificate on the next visit is known, not new.
    assert.equal("known", tofu.check(host, "AA:BB"))
    clean(host)
end

T.test_a_changed_certificate_is_reported = function ()
    local host = "tofu-test-b:1965"
    clean(host)

    tofu.check(host, "AA:BB")
    local status, stored = tofu.check(host, "CC:DD")
    assert.equal("changed", status)
    assert.equal("AA:BB", stored)
    clean(host)
end

T.test_trusting_the_new_certificate_replaces_it = function ()
    local host = "tofu-test-c:1965"
    clean(host)

    tofu.check(host, "AA:BB")
    tofu.trust(host, "CC:DD")
    -- The new one is now the known one, and the old one would now be a change.
    assert.equal("known", tofu.check(host, "CC:DD"))
    clean(host)
end

T.test_forgetting_a_host_makes_it_new_again = function ()
    local host = "tofu-test-d:1965"
    clean(host)

    tofu.check(host, "AA:BB")
    assert.is_true(tofu.forget(host))
    assert.equal("new", tofu.check(host, "ZZ:ZZ"))
    -- Forgetting something that is not there says so.
    clean(host)
    assert.is_false(tofu.forget(host))
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80

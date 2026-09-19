--- Test the store of certificate exceptions.
--
-- An exception is a decision to trust one certificate that failed
-- verification. It used to last forever and there was no way to see or undo
-- it, so these tests pin the three things that changed: exceptions lapse, they
-- can be listed, and they can be revoked.

local assert = require "luassert"
local error_page = require "error_page"

local T = {}

local function store (host, created)
    error_page.cert_db:exec(
        "INSERT OR REPLACE INTO allowed_certificates VALUES (NULL, ?, ?, ?, ?)",
        {host, "-----BEGIN CERTIFICATE-----\nnot a real one\n-----END CERTIFICATE-----",
         created, 0})
end

local function clear ()
    error_page.cert_db:exec("DELETE FROM allowed_certificates")
end

T.test_exceptions_are_listed_newest_first = function ()
    clear()
    store("old.example", os.time() - 100)
    store("new.example", os.time())

    local rows = error_page.certificate_exceptions()
    assert.equal(2, #rows)
    assert.equal("new.example", rows[1].host)
    assert.equal("old.example", rows[2].host)
    assert.equal(rows[1].created + error_page.cert_exception_lifetime, rows[1].expires)
    clear()
end

T.test_exceptions_lapse_once_they_are_old_enough = function ()
    clear()
    store("stale.example", os.time() - error_page.cert_exception_lifetime - 1)
    store("fresh.example", os.time())

    assert.is_false(error_page.has_certificate_exception("stale.example"))
    assert.is_true(error_page.has_certificate_exception("fresh.example"))

    -- Listing sweeps the expired rows rather than just hiding them.
    local rows = error_page.certificate_exceptions()
    assert.equal(1, #rows)
    assert.equal("fresh.example", rows[1].host)
    clear()
end

T.test_an_exception_can_be_revoked = function ()
    clear()
    store("revoke.example", os.time())
    assert.is_true(error_page.has_certificate_exception("revoke.example"))

    assert.is_true(error_page.remove_certificate_exception("revoke.example"))
    assert.is_false(error_page.has_certificate_exception("revoke.example"))

    -- Revoking something that is not there says so instead of pretending.
    assert.is_false(error_page.remove_certificate_exception("revoke.example"))
    clear()
end

T.test_a_missing_host_is_not_trusted = function ()
    assert.is_false(error_page.has_certificate_exception(nil))
    assert.is_false(error_page.has_certificate_exception(""))
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80

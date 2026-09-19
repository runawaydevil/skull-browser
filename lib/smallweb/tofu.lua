--- Trust on first use for the small web.
--
-- Gemini does not use certificate authorities. A server presents a
-- self-signed certificate, the client remembers it, and what matters from then
-- on is that the same certificate comes back. That is trust on first use.
--
-- The first visit to a host is trusted without asking, because there is
-- nothing to compare against. Every visit after that compares fingerprints,
-- and a change is reported rather than accepted.
--
-- @module smallweb.tofu
-- @copyright 2026 Pablo Murad <pablomurad@pm.me>

local _M = {}

--- Path to the fingerprint store.
-- @type string
-- @readwrite
_M.db_path = luakit.data_dir .. "/smallweb_tofu.db"

local db

local function init_db ()
    if db then return db end
    db = sqlite3{ filename = _M.db_path }
    db:exec [[
        PRAGMA synchronous = OFF;
        PRAGMA secure_delete = 1;

        CREATE TABLE IF NOT EXISTS known_hosts (
            id INTEGER PRIMARY KEY,
            host TEXT NOT NULL,
            fingerprint TEXT NOT NULL,
            first_seen INTEGER NOT NULL,
            last_seen INTEGER NOT NULL
        );

        CREATE UNIQUE INDEX IF NOT EXISTS idx_tofu_host ON known_hosts (host);
    ]]
    return db
end

--- Check a fingerprint against what is on record, and record it when the host
-- is new.
--
-- @tparam string host The host, including the port.
-- @tparam string fingerprint The certificate fingerprint presented now.
-- @treturn string One of `"new"`, `"known"` or `"changed"`.
-- @treturn string|nil The fingerprint on record, when the answer is
--   `"changed"`.
_M.check = function (host, fingerprint)
    assert(type(host) == "string" and host ~= "", "expected a host")
    assert(type(fingerprint) == "string" and fingerprint ~= "",
        "expected a fingerprint")

    local rows = init_db():exec(
        "SELECT fingerprint FROM known_hosts WHERE host=?", {host})

    if not rows or #rows == 0 then
        local now = os.time()
        db:exec("INSERT INTO known_hosts VALUES (NULL, ?, ?, ?, ?)",
            {host, fingerprint, now, now})
        return "new"
    end

    if rows[1].fingerprint == fingerprint then
        db:exec("UPDATE known_hosts SET last_seen=? WHERE host=?",
            {os.time(), host})
        return "known"
    end

    return "changed", rows[1].fingerprint
end

--- Replace the fingerprint on record for a host.
--
-- Called when the user decides that a changed certificate is a legitimate
-- rotation rather than someone in the middle.
--
-- @tparam string host The host, including the port.
-- @tparam string fingerprint The fingerprint to trust from now on.
_M.trust = function (host, fingerprint)
    assert(type(host) == "string" and host ~= "", "expected a host")
    assert(type(fingerprint) == "string" and fingerprint ~= "",
        "expected a fingerprint")
    local now = os.time()
    init_db():exec("INSERT OR REPLACE INTO known_hosts VALUES "
        .. "(NULL, ?, ?, COALESCE((SELECT first_seen FROM known_hosts "
        .. "WHERE host=?), ?), ?)",
        {host, fingerprint, host, now, now})
end

--- Forget a host, so the next visit is treated as a first one.
-- @tparam string host The host, including the port.
-- @treturn boolean Whether anything was removed.
_M.forget = function (host)
    assert(type(host) == "string" and host ~= "", "expected a host")
    local rows = init_db():exec(
        "SELECT COUNT(*) AS n FROM known_hosts WHERE host=?", {host})
    local n = tonumber(rows and rows[1] and rows[1].n) or 0
    if n == 0 then return false end
    db:exec("DELETE FROM known_hosts WHERE host=?", {host})
    return true
end

--- List every host on record.
-- @treturn table Rows with `host`, `fingerprint`, `first_seen` and
--   `last_seen`.
_M.known_hosts = function ()
    return init_db():exec("SELECT host, fingerprint, first_seen, last_seen "
        .. "FROM known_hosts ORDER BY last_seen DESC") or {}
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80

--- Keep the adblock filter lists on disk.
--
-- The adblock module reads `*.txt` files from its data directory and does
-- nothing else: it has no way to fetch a list, so a fresh install blocks
-- nothing at all. This module downloads the default lists on first run and
-- refreshes them once they go stale.
--
-- Downloads go through `curl` rather than the browser's own download stack,
-- which would show every refresh in the download list as if the user had asked
-- for it.
--
-- @module adblock_bootstrap
-- @copyright 2026 Pablo Murad <pablomurad@pm.me>

local lfs = require("lfs")
local adblock = require("adblock")
local modes = require("modes")

local _M = {}

--- Lists fetched by default.
-- Each entry needs a `file` ending in `.txt`, which is the only extension the
-- adblock module looks at.
-- @type table
-- @readwrite
_M.lists = {
    { file = "easylist.txt",
      uri = "https://easylist.to/easylist/easylist.txt" },
    { file = "easyprivacy.txt",
      uri = "https://easylist.to/easylist/easyprivacy.txt" },
    { file = "easylistportuguese.txt",
      uri = "https://easylist-downloads.adblockplus.org/easylistportuguese.txt" },
}

--- Days before a list on disk is considered stale.
-- @type number
-- @readwrite
_M.max_age_days = 7

local dir = luakit.data_dir .. "/adblock/"

local function age_days(path)
    local mtime = lfs.attributes(path, "modification")
    if not mtime then return nil end
    return (os.time() - mtime) / 86400
end

-- A truncated download or a captive-portal login page would otherwise be
-- parsed as filter rules without a word of complaint.
local function looks_like_filterlist(path)
    local f = io.open(path, "rb")
    if not f then return false end
    local head = f:read(256) or ""
    f:close()
    return head:match("^%[Adblock") ~= nil or head:match("^!") ~= nil
end

local pending = 0

local function finish()
    pending = pending - 1
    if pending > 0 then return end

    adblock.load(true)
    msg.info("adblock: listas recarregadas")
end

local function fetch(entry)
    local dest, part = dir .. entry.file, dir .. entry.file .. ".part"
    local cmd = string.format("curl -fsSL --max-time 120 -o %q %q", part, entry.uri)

    local ok, err = pcall(luakit.spawn, cmd, function (_, status)
        if status == 0 and looks_like_filterlist(part) then
            os.remove(dest)
            os.rename(part, dest)
            msg.info("adblock: %s atualizada", entry.file)
        else
            os.remove(part)
            msg.warn("adblock: falha ao baixar %s (status %s)", entry.file, tostring(status))
        end
        finish()
    end)

    if not ok then
        msg.warn("adblock: could not run curl: %s", tostring(err))
        finish()
    end
end

--- Download any list that is missing or stale.
-- @tparam[opt] boolean force Refresh every list regardless of age.
_M.update = function (force)
    if not lfs.attributes(dir, "mode") then lfs.mkdir(dir) end

    local todo = {}
    for _, entry in ipairs(_M.lists) do
        local age = age_days(dir .. entry.file)
        if force or not age or age > _M.max_age_days then
            todo[#todo + 1] = entry
        end
    end

    if #todo == 0 then
        msg.verbose("adblock: listas em dia")
        return 0
    end

    pending = #todo
    for _, entry in ipairs(todo) do fetch(entry) end
    return #todo
end

modes.add_cmds({
    { ":adblock-update", "Baixar ou atualizar as listas de filtro.",
        function (w)
            local n = _M.update(true)
            w:notify(string.format("adblock: baixando %d lista(s)...", n))
        end },
})

--- Schedule an update off the startup path.
-- `adblock.load` parses synchronously on the UI thread and EasyList alone is
-- over two megabytes, so this defers to idle. Call it from the config; the
-- module deliberately does nothing on require, which keeps the test suite off
-- the network.
_M.update_when_idle = function ()
    luakit.idle_add(function ()
        _M.update(false)
        return false
    end)
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80

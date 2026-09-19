--- lousy.pickle library.
--
-- A table serialization utility for lua. Freeware.
--
-- *Note: The serialization format may change without notice. This
-- should be treated as an opaque interface.*
--
-- @module lousy.pickle
-- @author Steve Dekorte, http://www.dekorte.com
-- @copyright 2000 Steve Dekorte


local Pickle = {
    clone = function (t) local nt={}; for i, v in pairs(t) do nt[i]=v end return nt end
}

function Pickle:pickle_(root)
    if type(root) ~= "table" then
        error("can only pickle tables, not ".. type(root).."s")
    end
    self._tableToRef = {}
    self._refToTable = {}
    local savecount = 0
    self:ref_(root)
    local buf = {}

    while table.getn(self._refToTable) > savecount do
        savecount = savecount + 1
        local t = self._refToTable[savecount]
        buf[#buf+1] = "{"
        for i, v in pairs(t) do
                buf[#buf+1] = string.format("[%s]=%s,", self:value_(i), self:value_(v))
        end
        buf[#buf+1] = "},"
    end

    return string.format("{%s\n}", table.concat(buf,"\n"))
end

function Pickle:value_(v)
    local vtype = type(v)
    if vtype == "string" then return string.format("%q", v)
    elseif vtype == "number" then return v
    elseif vtype == "boolean" then return tostring(v)
    elseif vtype == "table" then return "{"..self:ref_(v).."}"
    else error("pickle a "..type(v).." is not supported")
    end
end

function Pickle:ref_(t)
    local ref = self._tableToRef[t]
    if not ref then
        if t == self then error("can't pickle the pickle class") end
        table.insert(self._refToTable, t)
        ref = table.getn(self._refToTable)
        self._tableToRef[t] = ref
    end
    return ref
end

local _M = {}

--- Convert a table into a string that can be saved to disk.
-- @tparam table t The table to serialize.
-- @treturn string The string representing the table contents.
_M.pickle = function(t)
    return Pickle:clone():pickle_(t)
end

-- Escape sequences string.format("%q") can emit, plus the rest of the Lua set.
local string_escapes = {
    a = "\a", b = "\b", f = "\f", n = "\n",
    r = "\r", t = "\t", v = "\v",
    ["\\"] = "\\", ['"'] = '"', ["'"] = "'",
}

-- Read a pickled string without executing it.
--
-- The previous implementation ran the payload through loadstring, which turned
-- every caller into a code execution sink: the session file, the command
-- history, the settings file, and worst of all the single instance D-Bus
-- channel, which any process on the user's session bus can write to.
--
-- This reader accepts only what pickle() emits: table literals, string, number
-- and boolean literals, and {n} table references. No call, no operator and no
-- identifier other than true/false/nil is reachable.
local function parse(s)
    local pos, depth = 1, 0

    local function fail(what)
        error(("malformed pickle at offset %d: %s"):format(pos, what), 0)
    end

    local function skip_space()
        pos = s:find("[^ \t\r\n]", pos) or #s + 1
    end

    local function accept(ch)
        skip_space()
        if s:sub(pos, pos) == ch then pos = pos + 1 return true end
        return false
    end

    local function expect(ch)
        if not accept(ch) then fail("expected '" .. ch .. "'") end
    end

    local function parse_string()
        pos = pos + 1 -- opening quote
        local out = {}
        while true do
            local c = s:sub(pos, pos)
            if c == "" then fail("unterminated string") end
            if c == '"' then pos = pos + 1 break end
            if c == "\\" then
                local nxt = s:sub(pos + 1, pos + 1)
                local digits = s:match("^%d%d?%d?", pos + 1)
                if digits then
                    out[#out + 1] = string.char(tonumber(digits))
                    pos = pos + 1 + #digits
                elseif nxt == "\n" then
                    -- %q writes a real newline escaped by a backslash
                    out[#out + 1] = "\n"
                    pos = pos + 2
                elseif string_escapes[nxt] then
                    out[#out + 1] = string_escapes[nxt]
                    pos = pos + 2
                else
                    fail("unknown escape")
                end
            else
                out[#out + 1] = c
                pos = pos + 1
            end
        end
        return table.concat(out)
    end

    local parse_value

    local function parse_table()
        depth = depth + 1
        if depth > 64 then fail("nesting too deep") end
        expect("{")
        local t = {}
        while true do
            if accept("}") then break end
            if accept("[") then
                local k = parse_value()
                expect("]")
                expect("=")
                t[k] = parse_value()
            else
                t[#t + 1] = parse_value()
            end
            if not accept(",") then
                expect("}")
                break
            end
        end
        depth = depth - 1
        return t
    end

    parse_value = function ()
        skip_space()
        local c = s:sub(pos, pos)
        if c == '"' then return parse_string() end
        if c == "{" then
            -- A bare {n} is a reference to the n-th table, not a literal.
            local ref, after = s:match("^{%s*(%d+)%s*}()", pos)
            if ref then pos = after return { tonumber(ref) } end
            return parse_table()
        end
        local word, after = s:match("^([%a_][%w_]*)()", pos)
        if word then
            if word == "true" then pos = after return true end
            if word == "false" then pos = after return false end
            if word == "nil" then pos = after return nil end
            fail("unexpected identifier")
        end
        local num
        num, after = s:match("^(%-?%d+%.?%d*[eE]?[%+%-]?%d*)()", pos)
        if num and tonumber(num) then pos = after return tonumber(num) end
        fail("unexpected character")
    end

    local value = parse_value()
    skip_space()
    if pos <= #s then fail("trailing data") end
    return value
end

--- Convert a string previously created with `pickle()` to a table.
-- @tparam string s The string previously created with `pickle()`.
-- @treturn table A table corresponding to the given string.
_M.unpickle = function(s)
    if type(s) ~= "string" then
        error("can't unpickle a "..type(s)..", only strings")
    end
    local tables = parse(s)
    if type(tables) ~= "table" then error("pickle did not contain a table", 0) end

    for tnum = 1, table.getn(tables) do
        local t = tables[tnum]
        local tcopy = {}; for i, v in pairs(t) do tcopy[i] = v end
        for i, v in pairs(tcopy) do
            local ni, nv
            if type(i) == "table" then ni = tables[i[1]] else ni = i end
            if type(v) == "table" then nv = tables[v[1]] else nv = v end
            t[i] = nil
            t[ni] = nv
        end
    end
    return tables[1]
end

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80

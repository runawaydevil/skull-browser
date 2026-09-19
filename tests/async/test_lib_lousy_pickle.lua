--- Test lousy.pickle.
--
-- unpickle used to be loadstring in disguise, which made every caller a code
-- execution sink. These tests pin both halves: the format still round-trips,
-- and payloads that are valid Lua but not valid pickle are refused.

local assert = require "luassert"
local pickle = require "lousy.pickle"
local T = {}

local tricky = 'quote " backslash \\ newline\n tab \t nul \0 high \200'

T.test_round_trip_preserves_values = function ()
    local orig = {
        "a", 42, true,
        nested = { x = 1.5, s = tricky, neg = -7 },
        [7] = "seven",
    }
    local back = pickle.unpickle(pickle.pickle(orig))
    assert.is_equal("a", back[1])
    assert.is_equal(42, back[2])
    assert.is_true(back[3])
    assert.is_equal(1.5, back.nested.x)
    assert.is_equal(-7, back.nested.neg)
    assert.is_equal(tricky, back.nested.s)
    assert.is_equal("seven", back[7])
end

T.test_round_trip_preserves_shared_references = function ()
    local shared = { v = 1 }
    local back = pickle.unpickle(pickle.pickle({ a = shared, b = shared }))
    assert.is_true(back.a == back.b)
end

T.test_rejects_code_execution_payloads = function ()
    local payloads = {
        '(os.execute("id"))',
        '{[1]={os.time()},}',
        '{} ; os.exit()',
        'setmetatable({},{__index=os})',
        '{[1]={["x"]=(function() return 1 end)()},}',
        'os.getenv("HOME")',
        '{[1]={},} print("pwned")',
    }
    for _, payload in ipairs(payloads) do
        assert.has_error(function () pickle.unpickle(payload) end)
    end
end

T.test_rejects_malformed_input = function ()
    assert.has_error(function () pickle.unpickle('{[1]=') end)
    assert.has_error(function () pickle.unpickle('{"unterminated}') end)
    assert.has_error(function () pickle.unpickle(string.rep("{[1]=", 100)) end)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80

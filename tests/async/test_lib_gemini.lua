--- Test the gemini module's parsing and rendering.
--
-- The transport needs a network and a TLS library, so it is left to a live
-- run. What is pinned here is the pure logic: url parsing, link resolution,
-- and turning gemtext into HTML without letting hostile input become markup.

local assert = require "luassert"
local gemini = require "gemini"

local T = {}

T.test_parse_url_fills_defaults = function ()
    local u = gemini.parse_url("gemini://example.org/")
    assert.equal("example.org", u.host)
    assert.equal(1965, u.port)
    assert.equal("/", u.path)
    assert.is_nil(u.query)
end

T.test_parse_url_keeps_port_and_query = function ()
    local u = gemini.parse_url("gemini://example.org:1966/path?search")
    assert.equal("example.org", u.host)
    assert.equal(1966, u.port)
    assert.equal("/path", u.path)
    assert.equal("search", u.query)
end

T.test_parse_url_strips_a_hostile_host = function ()
    -- Whatever survives reaches a TLS handshake and a fingerprint key.
    local u = gemini.parse_url("gemini://ev il;rm$(id)/x")
    assert.is_nil(u.host:match("[^%w%.%-]"))
end

T.test_resolve_handles_relative_and_absolute = function ()
    local base = gemini.parse_url("gemini://h.org/dir/page.gmi")
    assert.equal("gemini://h.org/dir/other.gmi", gemini.resolve("other.gmi", base))
    assert.equal("gemini://h.org/root.gmi", gemini.resolve("/root.gmi", base))
    assert.equal("https://elsewhere/x", gemini.resolve("https://elsewhere/x", base))
    assert.equal("gemini://other.host/", gemini.resolve("//other.host/", base))
end

T.test_gemtext_links_and_headings = function ()
    local base = gemini.parse_url("gemini://h.org/")
    local html = gemini.gemtext_to_html(
        "# Title\n=> /page.gmi A link\n* item\n> quoted\nplain\n", base)
    assert.is_truthy(html:find("<h1", 1, true))
    assert.is_truthy(html:find('href="gemini://h.org/page.gmi"', 1, true))
    assert.is_truthy(html:find("<li>item</li>", 1, true))
    assert.is_truthy(html:find("quoted", 1, true))
end

T.test_gemtext_escapes_markup = function ()
    local base = gemini.parse_url("gemini://h.org/")
    -- A link label, a heading and a plain line, each carrying markup and a
    -- brace that error_page would otherwise read as a placeholder.
    local html = gemini.gemtext_to_html(
        "# <script>alert(1)</script>\n"
        .. "=> /x <img onerror=go>{x}\n"
        .. "plain <b>no</b> {y}\n", base)
    assert.is_nil(html:find("<script>", 1, true))
    assert.is_nil(html:find("<img onerror", 1, true))
    assert.is_nil(html:find("<b>no</b>", 1, true))
    assert.is_nil(html:find("{x}", 1, true))
    assert.is_nil(html:find("{y}", 1, true))
end

T.test_gemtext_preformatted_is_literal = function ()
    local base = gemini.parse_url("gemini://h.org/")
    local html = gemini.gemtext_to_html(
        "```\n=> not a link\n# not a heading\n```\n", base)
    -- Inside a fence, nothing is interpreted as a link or heading.
    assert.is_nil(html:find("<a ", 1, true))
    assert.is_nil(html:find("<h1", 1, true))
    assert.is_truthy(html:find("=&gt; not a link", 1, true))
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80

--[[--------------------------------------------------------------------------
The MIT License (MIT)
Copyright (c) 2010-2020 Mark Rogaski
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]--------------------------------------------------------------------------

---@diagnostic disable: undefined-global

lu = require('luaunit')
require('Loader')

local semver = LibStub:GetLibrary('SemanticVersion-1.0')

local function v(s)
    return semver(s)
end


--
-- Parsing.
--

TestSemanticVersionParse = {}

function TestSemanticVersionParse:test_plain_version()
    local ver = v('1.2.3')
    lu.assertEquals(ver.major, 1)
    lu.assertEquals(ver.minor, 2)
    lu.assertEquals(ver.patch, 3)
    lu.assertEquals(ver.pre, {})
    lu.assertEquals(ver.meta, {})
end

function TestSemanticVersionParse:test_prerelease()
    lu.assertEquals(v('1.0.0-alpha.1').pre, { 'alpha', 1 })
end

function TestSemanticVersionParse:test_rejects_malformed()
    lu.assertNil(v('not.a.version'))
    lu.assertNil(v('1.2'))
    lu.assertNil(v(''))
end

function TestSemanticVersionParse:test_rejects_suffix_without_separator()
    -- A pre-release needs the '-'.  GwConfig's GW:v: handler relies on this rejection.
    lu.assertNil(v('1.2.3beta'))
end

function TestSemanticVersionParse:test_rejects_leading_zero_identifier()
    -- semver.org 2.0.0 section 9: numeric identifiers must not include leading zeroes.
    lu.assertNil(v('1.0.0-01'))
end

function TestSemanticVersionParse:test_metadata_with_prerelease()
    local ver = v('1.0.0-alpha+build.1')
    lu.assertEquals(ver.pre, { 'alpha' })
    lu.assertEquals(ver.meta, { 'build', 1 })
end

function TestSemanticVersionParse:test_metadata_without_prerelease()
    -- semver.org 2.0.0 section 10: build metadata may follow the patch directly.  Requiring a
    -- leading '-' rejected the whole version string.
    local ver = v('1.0.0+20130313144700')
    lu.assertNotNil(ver)
    lu.assertEquals(ver.pre, {})
    lu.assertEquals(ver.meta, { 20130313144700 })
end


--
-- Rendering.
--

TestSemanticVersionString = {}

function TestSemanticVersionString:test_round_trip()
    lu.assertEquals(tostring(v('1.2.3')), '1.2.3')
    lu.assertEquals(tostring(v('1.0.0-alpha.1')), '1.0.0-alpha.1')
    lu.assertEquals(tostring(v('1.0.0-alpha+build.1')), '1.0.0-alpha+build.1')
end


--
-- Precedence.  semver.org 2.0.0 section 11.
--

TestSemanticVersionPrecedence = {}

function TestSemanticVersionPrecedence:test_major_minor_patch()
    lu.assertTrue(v('1.0.0') < v('2.0.0'))
    lu.assertTrue(v('2.0.0') < v('2.1.0'))
    lu.assertTrue(v('2.1.0') < v('2.1.1'))
end

function TestSemanticVersionPrecedence:test_equality()
    lu.assertTrue(v('1.2.3') == v('1.2.3'))
    lu.assertTrue(v('1.2.3') <= v('1.2.3'))
end

function TestSemanticVersionPrecedence:test_prerelease_below_release()
    lu.assertTrue(v('1.0.0-alpha') < v('1.0.0'))
    lu.assertFalse(v('1.0.0') < v('1.0.0-alpha'))
end

function TestSemanticVersionPrecedence:test_numeric_below_alphanumeric()
    -- "Numeric identifiers always have lower precedence than non-numeric identifiers."
    lu.assertTrue(v('1.0.0-1') < v('1.0.0-alpha'))
end

function TestSemanticVersionPrecedence:test_antisymmetric_across_types()
    -- If a < b then b < a must be false.  Both being true makes any ordering built on this
    -- comparison depend on the argument order.
    lu.assertFalse(v('1.0.0-alpha') < v('1.0.0-1'))
end

function TestSemanticVersionPrecedence:test_smaller_field_set_ranks_lower()
    -- "A larger set of pre-release fields has a higher precedence than a smaller set, if all of
    -- the preceding identifiers are equal."
    lu.assertTrue(v('1.0.0-alpha') < v('1.0.0-alpha.1'))
end

function TestSemanticVersionPrecedence:test_antisymmetric_across_field_counts()
    lu.assertFalse(v('1.0.0-alpha.1') < v('1.0.0-alpha'))
    lu.assertTrue(v('1.0.0-alpha') <= v('1.0.0-alpha.1'))
end

function TestSemanticVersionPrecedence:test_specification_example()
    local order = { '1.0.0-alpha', '1.0.0-alpha.1', '1.0.0-alpha.beta', '1.0.0-beta',
                    '1.0.0-beta.2', '1.0.0-beta.11', '1.0.0-rc.1', '1.0.0' }
    for i = 1, #order - 1 do
        lu.assertTrue(v(order[i]) < v(order[i + 1]),
                string.format('%s should rank below %s', order[i], order[i + 1]))
    end
end

function TestSemanticVersionPrecedence:test_metadata_ignored()
    -- semver.org 2.0.0 section 10: build metadata must be ignored when determining precedence.
    lu.assertTrue(v('1.0.0+build.1') == v('1.0.0+build.2'))
end


--
-- Run the tests
--

os.exit(lu.run())

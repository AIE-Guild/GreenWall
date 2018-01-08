--[[--------------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2018 Mark Rogaski

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

lu = require('luaunit')
require('TestCompat')
require('ClassLib')
require('Constants')
require('Lib/LibStub')
require('Lib/SemanticVersion')
require('Parser')

--
-- Mocks
--

gw = { logmsg = '' }

function gw.Debug(level, format, ...)
    gw.logmsg = string.format(format, ...)
end


--
-- Fixtures
--

info_a = [[
GWc:secretSquirrels:pencil
GWv:1.4.1
GWs:alea iacta est:n
GWp:$n:prime
GWp:$n audacia:audacia
GWp:$n fortuna-EarthenRing:fortuna
]]
info_b = [[
GWt=prime
GWc=secretSquirrels:pencil
GWv=1.4.1
GWp=alea iacta est audacia:audacia
GWp=alea iacta est fortuna-EarthenRing:fortuna
]]
info_c = [[
GWt="prime"
GWc="secretSquirrels:pencil"
GWv="1.4.1"
GWp="alea iacta est audacia:audacia"
GWp="alea iacta est fortuna-EarthenRing:fortuna"
]]
note_a = 'GWa:secretSquirrels:rosebud'
note_b = 'GWa=secretSquirrels:rosebud'
note_c = 'GWa="secretSquirrels:rosebud"'


--
-- Test Cases
--

TestParser = {}

function TestParser:test_new()
    local parser = GwParser:new()
    lu.assertTrue(parser:isa(GwParser))
end

function TestParser:test_version()
    lu.assertEquals(GwParser:version('GWc:somechannel:password'), 1)
    lu.assertEquals(GwParser:version('GWc="somechannel:password"'), 2)
end

function TestParser:test_factory()
    local parser = GwParser:get_parser('GWc:somechannel:password')
    lu.assertTrue(parser:isa(GwV1Parser))
    local parser = GwParser:get_parser('GWc="somechannel:password"')
    lu.assertTrue(parser:isa(GwV2Parser))
end


TestV1Parser = {}

function TestV1Parser:test_substitute()
    local parser = GwV1Parser:new()
    parser.xlat = { n = 'two' }
    s = parser:substitute('one $n three')
    lu.assertEquals(s, 'one two three')
    lu.assertEquals(gw.logmsg, "expanded 'one $n three' to 'one two three'")
end

os.exit(lu.run())

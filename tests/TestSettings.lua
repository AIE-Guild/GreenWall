--[[--------------------------------------------------------------------------
The MIT License (MIT)
Copyright (c) 2010-2017 Mark Rogaski
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
require('Constants')
require('Settings')


--
-- Mocks
--

gw = { logmsg = '' }

function gw.Debug(level, format, ...)
    gw.logmsg = string.format(format, ...)
end


--
-- Test Cases
--

TestSettings = {}

function TestSettings:test_new()
    local settings = GwSettings:new()
    lu.assertEquals(type(GreenWallMeta), 'table')
    lu.assertEquals(type(GreenWall), 'table')
    lu.assertEquals(type(GreenWallAccount), 'table')
end

function TestSettings:test_meta()
    local settings = GwSettings:new()
    lu.assertEquals(GreenWallMeta.mode, GW_MODE_ACCOUNT)
    lu.assertEquals(string.match(GreenWallMeta.created, '%d-%d-%d %d:%d:%d'))
    lu.assertEquals(string.match(GreenWallMeta.updated, '%d-%d-%d %d:%d:%d'))
end

function TestSettings:test_initialize()
    local settings = GwSettings:new()
    for i, tab in ipairs({GreenWall, GreenWallAccount}) do
        lu.assertEquals(string.match(tab.created, '%d-%d-%d %d:%d:%d'))
        lu.assertEquals(string.match(tab.updated, '%d-%d-%d %d:%d:%d'))
        lu.assertEquals(tab.tag, true)
        lu.assertEquals(tab.achievements, false)
        lu.assertEquals(tab.roster, true)
        lu.assertEquals(tab.rank, false)
        lu.assertEquals(tab.debug, GW_LOG_NONE)
        lu.assertEquals(tab.verbose, false)
        lu.assertEquals(tab.log, false)
        lu.assertEquals(tab.logsize, 2048)
        lu.assertEquals(tab.ochat, false)
        lu.assertEquals(tab.redact, true)
        lu.assertEquals(tab.joindelay, 30)
    end
end

os.exit(lu.run())

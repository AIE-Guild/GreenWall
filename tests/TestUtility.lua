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

--
-- Mocks
--

gw = { logmsg = '' }

function gw.Debug(level, format, ...)
    gw.logmsg = string.format(format, ...)
end


--
-- Includes
--

lu = require('luaunit')
require('TestCompat')
require('Lib/LibStub')
require('Lib/CRC16-CCITT')
require('Constants')
require('Utility')



--
-- Test Cases
--

TestItemInfo = {}

function TestItemInfo:test_GetItemString()
    local single = 'Testing |Hitem:6948::::::::80::::|h in a string.'
    local multi = 'Testing |Hitem:6948::::::::80::::|h and |Hitem:4388:0:0:0:0:0:0:210677200:80:0:0:0:0|h in a string.'
    lu.assertEquals(gw.GetItemString(single), 'item:6948::::::::80::::')
    lu.assertEquals(gw.GetItemString(multi), 'item:6948::::::::80::::')
    lu.assertEquals(gw.GetItemString('nothing here'), nil)
    lu.assertError(gw.GetItemString)
end


--
-- Run the tests
--

os.exit(lu.run())

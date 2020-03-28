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

--
-- Includes
--

lu = require('luaunit')
require('Loader')

--
-- Test Cases
--

TestSystemEventHandler = {}

function TestSystemEventHandler:test_online()
    message = "|Hplayer:Eggolas|h[Eggolas]|h has come online."
    sysmsg = GwSystemEventHandler:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwOnlineSystemEventHandler)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemEventHandler:test_online_raw()
    message = "Eggolas has come |cff298F00online|r."
    sysmsg = GwSystemEventHandler:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwOnlineSystemEventHandler)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemEventHandler:test_offline()
    message = "Eggolas has gone offline."
    sysmsg = GwSystemEventHandler:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwOfflineSystemEventHandler)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemEventHandler:test_join()
    message = "Eggolas has joined the guild."
    sysmsg = GwSystemEventHandler:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwJoinSystemEventHandler)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemEventHandler:test_leave()
    message = "Eggolas has left the guild."
    sysmsg = GwSystemEventHandler:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwLeaveSystemEventHandler)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemEventHandler:test_quit()
    message = "You are no longer a member of SparkleMotion."
    sysmsg = GwSystemEventHandler:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwQuitSystemEventHandler)
    lu.assertEquals(sysmsg.player, "Ralff-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemEventHandler:test_remove()
    message = "Eggolas has been kicked out of the guild by Ralff."
    sysmsg = GwSystemEventHandler:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwRemoveSystemEventHandler)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemEventHandler:test_kick()
    message = "You have been kicked out of the guild."
    sysmsg = GwSystemEventHandler:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwKickSystemEventHandler)
    lu.assertEquals(sysmsg.player, "Ralff-EarthenRing")
    lu.assertNil(sysmsg.rank)
end

function TestSystemEventHandler:test_promote()
    message = "Rallf has promoted Eggolas to Cohort."
    sysmsg = GwSystemEventHandler:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwPromoteSystemEventHandler)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertEquals(sysmsg.rank, "Cohort")
end

function TestSystemEventHandler:test_demote()
    message = "Rallf has demoted Eggolas to Pleb."
    sysmsg = GwSystemEventHandler:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwDemoteSystemEventHandler)
    lu.assertEquals(sysmsg.player, "Eggolas-EarthenRing")
    lu.assertEquals(sysmsg.rank, "Pleb")
end

function TestSystemEventHandler:test_no_match()
    message = "Don't panic."
    sysmsg = GwSystemEventHandler:factory(message)
    lu.assertEquals(getmetatable(sysmsg), GwSystemEventHandler)
    lu.assertNil(sysmsg.player)
    lu.assertNil(sysmsg.rank)
end


--
-- Run the tests
--

os.exit(lu.run())

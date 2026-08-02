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
-- Includes
--

lu = require('luaunit')
require('Loader')


--
-- Test Cases
--

TestAPI = {}

function TestAPI:test_get_channel_numbers()
    gw.config = {
        channel = {
            guild = { number = 5 },
            officer = { number = 6 }
        }
    }
    local c = GreenWallAPI.GetChannelNumbers()
    lu.assertEquals(c, { 5, 6 })
end


--
-- Message-handler registration, removal, and dispatch.
--

local function noop() end

function TestAPI:setUp()
    gw.api_table = {}
    -- AddMessageHandler validates `addon == C_AddOns.GetAddOnInfo(addon)` for non-'*' ids.
    C_AddOns.GetAddOnInfo = function(addon) return addon end
    gw.player = 'Ralff'
    gw.config = { guild_id = 'G1' }
end

function TestAPI:test_add_and_remove_handler()
    local id = GreenWallAPI.AddMessageHandler(noop, '*', 0)
    lu.assertEquals(#gw.api_table, 1)
    lu.assertTrue(GreenWallAPI.RemoveMessageHandler(id))
    lu.assertEquals(#gw.api_table, 0)
    lu.assertFalse(GreenWallAPI.RemoveMessageHandler(id))     -- already gone
    lu.assertFalse(GreenWallAPI.RemoveMessageHandler('nope')) -- never existed
end

function TestAPI:test_remove_middle_handler_leaves_no_hole()
    local function h1() end
    local function h2() end
    local function h3() end
    local id1 = GreenWallAPI.AddMessageHandler(h1, '*', 0)
    local id2 = GreenWallAPI.AddMessageHandler(h2, '*', 0)
    local id3 = GreenWallAPI.AddMessageHandler(h3, '*', 0)
    lu.assertTrue(GreenWallAPI.RemoveMessageHandler(id2))     -- remove the middle entry
    -- A nil-hole would truncate ipairs; table.remove keeps the array dense.
    lu.assertEquals(#gw.api_table, 2)
    local seen = {}
    for _, e in ipairs(gw.api_table) do seen[e[1]] = true end
    lu.assertTrue(seen[id1])
    lu.assertTrue(seen[id3])
    lu.assertNil(seen[id2])
end

function TestAPI:test_clear_by_addon_removes_all_matching()
    GreenWallAPI.AddMessageHandler(noop, 'AddonA', 0)
    GreenWallAPI.AddMessageHandler(noop, 'AddonA', 0)
    GreenWallAPI.AddMessageHandler(noop, 'AddonB', 0)
    lu.assertEquals(#gw.api_table, 3)
    GreenWallAPI.ClearMessageHandlers('AddonA')  -- must remove BOTH AddonA entries
    lu.assertEquals(#gw.api_table, 1)
    lu.assertEquals(gw.api_table[1][2], 'AddonB')
end

function TestAPI:test_clear_all_handlers()
    GreenWallAPI.AddMessageHandler(noop, '*', 0)
    GreenWallAPI.AddMessageHandler(noop, 'AddonA', 0)
    GreenWallAPI.ClearMessageHandlers()          -- nil -> remove everything
    lu.assertEquals(#gw.api_table, 0)
end

function TestAPI:test_dispatch_matches_by_addon()
    local hits = {}
    GreenWallAPI.AddMessageHandler(function() hits.a = (hits.a or 0) + 1 end, 'AddonA', 0)
    GreenWallAPI.AddMessageHandler(function() hits.b = (hits.b or 0) + 1 end, 'AddonB', 0)
    gw.APIDispatcher('AddonA', 'Someone', 'G1', 'hello')
    lu.assertEquals(hits.a, 1)   -- addon-matched handler fires
    lu.assertNil(hits.b)         -- non-matching handler does not
end


--
-- Run the tests
--

os.exit(lu.run())

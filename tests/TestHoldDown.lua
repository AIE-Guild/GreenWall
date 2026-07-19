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
-- Mocks
--

gw = { logmsg = '' }

function gw.Debug(level, format, ...)
    gw.logmsg = string.format(format, ...)
end

-- A controllable clock. HoldDown reads the global time(); tests advance `clock`
-- to simulate the passage of time deterministically.
local clock = 0
time = function() return clock end

--
-- Includes
--

lu = require('luaunit')
require('Loader')


--
-- Helpers
--

local function count_keys(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end


--
-- GwHoldDownCache: the element hold-down cache (interval window + pruning).
--

TestHoldDownCache = {}

function TestHoldDownCache:setUp()
    clock = 1000
end

function TestHoldDownCache:test_hold_window()
    local c = GwHoldDownCache:new(10, 100, 200)
    lu.assertFalse(c:hold('x'))     -- first sighting: registers, not held
    lu.assertTrue(c:hold('x'))      -- same instant: within the 10s window
    clock = clock + 9
    lu.assertTrue(c:hold('x'))      -- 9s elapsed: still inside the window
    clock = clock + 1
    lu.assertFalse(c:hold('x'))     -- 10s elapsed: expired, re-registered
    lu.assertTrue(c:hold('x'))      -- fresh window after re-registration
end

function TestHoldDownCache:test_distinct_keys_are_independent()
    local c = GwHoldDownCache:new(10, 100, 200)
    lu.assertFalse(c:hold('a'))
    lu.assertFalse(c:hold('b'))
    lu.assertTrue(c:hold('a'))
    lu.assertTrue(c:hold('b'))
end

function TestHoldDownCache:test_soft_prune_drops_expired()
    local c = GwHoldDownCache:new(10, 2, 100)   -- soft_max = 2
    c:hold('a')
    c:hold('b')
    c:hold('c')                                 -- 3 live entries, none expired yet
    lu.assertEquals(count_keys(c.cache), 3)     -- soft prune finds nothing to drop
    clock = clock + 11                          -- a, b, c all expire
    c:hold('d')                                 -- count 4 > soft_max: prune the expired
    lu.assertEquals(count_keys(c.cache), 1)
    lu.assertNotNil(c.cache['d'])
    lu.assertNil(c.cache['a'])
end

function TestHoldDownCache:test_hard_prune_evicts_oldest()
    local c = GwHoldDownCache:new(1000, 100, 3)  -- long interval; hard_max = 3
    c:hold('a'); clock = clock + 1
    c:hold('b'); clock = clock + 1
    c:hold('c'); clock = clock + 1
    c:hold('d'); clock = clock + 1
    c:hold('e')                                  -- 5 entries, none expired
    lu.assertEquals(count_keys(c.cache), 3)      -- capped at hard_max
    lu.assertNil(c.cache['a'])                   -- oldest two evicted
    lu.assertNil(c.cache['b'])
    lu.assertNotNil(c.cache['c'])
    lu.assertNotNil(c.cache['e'])
end


--
-- GwHoldDown: the scaling hold-down timer.
--

TestHoldDown = {}

function TestHoldDown:setUp()
    clock = 5000
end

function TestHoldDown:test_hold()
    local h = GwHoldDown:new(10)
    lu.assertFalse(h:hold())        -- never started
    h.timestamp = time()            -- simulate start without CreateFrame
    h.scale = 0
    lu.assertTrue(h:hold())         -- within the interval
    clock = clock + 10
    lu.assertFalse(h:hold())        -- interval elapsed
end

function TestHoldDown:test_continue_scales_up_to_limit()
    local h = GwHoldDown:new(10, 40) -- interval 10, limit 40
    h.timestamp = time()             -- pretend running so continue() won't call start()
    h.scale = 0
    h:continue()
    lu.assertEquals(h.scale, 1)      -- 10*2^1 = 20 <= 40
    h:continue()
    lu.assertEquals(h.scale, 2)      -- 10*2^2 = 40 <= 40
    h:continue()
    lu.assertEquals(h.scale, 2)      -- 10*2^3 = 80 > 40, capped
end

function TestHoldDown:test_clear_resets()
    local h = GwHoldDown:new(10)
    h.timestamp = time()
    h.scale = 3
    h:clear()
    lu.assertEquals(h.timestamp, 0)
    lu.assertEquals(h.scale, 0)
    lu.assertFalse(h:hold())
end


--
-- Run the tests
--

os.exit(lu.run())

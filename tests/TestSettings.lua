--[[--------------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2019 Mark Rogaski

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

TestSettingsCreate = {}

function TestSettingsCreate:setUp()
    GreenWallMeta = nil
    GreenWall = nil
    GreenWallAccount = nil
end

function TestSettingsCreate:test_new()
    local settings = GwSettings:new()
    lu.assertEquals(type(GreenWallMeta), 'table')
    lu.assertEquals(type(GreenWall), 'table')
    lu.assertEquals(type(GreenWallAccount), 'table')
end

function TestSettingsCreate:test_meta()
    local settings = GwSettings:new()
    lu.assertEquals(GreenWallMeta.mode, GW_MODE_ACCOUNT)
    lu.assertStrMatches(GreenWallMeta.created, '%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d')
    lu.assertStrMatches(GreenWallMeta.updated, '%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d')
end

function TestSettingsCreate:test_initialize()
    local settings = GwSettings:new()
    for i, tab in ipairs({GreenWall, GreenWallAccount}) do
        lu.assertStrMatches(tab.created, '%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d')
        lu.assertStrMatches(tab.updated, '%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d')
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


TestSettingsLoad = {}

function TestSettingsLoad:setUp()
    GreenWallMeta = {
        mode = GW_MODE_CHARACTER,
        created = "2018-01-01 17:28:47",
        updated = "2018-01-01 01:04:46",
    }
    GreenWall = {
        created = "2018-01-01 17:28:47",
        updated = "2018-01-01 01:04:46",
        achievements = true,
        roster = false,
    }
    GreenWallAccount = {
        created = "2018-01-01 17:28:47",
        updated = "2018-01-01 01:04:46",
        log = true,
        logsize = 1024,
        redact = false,
    }
end

function TestSettingsLoad:test_new()
    local settings = GwSettings:new()
    lu.assertEquals(type(GreenWallMeta), 'table')
    lu.assertEquals(type(GreenWall), 'table')
    lu.assertEquals(type(GreenWallAccount), 'table')
end

function TestSettingsLoad:test_meta()
    local settings = GwSettings:new()
    lu.assertEquals(GreenWallMeta.mode, GW_MODE_CHARACTER)
end

function TestSettingsLoad:test_character()
    local settings = GwSettings:new()
    lu.assertEquals(GreenWall.tag, true)
    lu.assertEquals(GreenWall.achievements, true)
    lu.assertEquals(GreenWall.roster, false)
    lu.assertEquals(GreenWall.rank, false)
end

function TestSettingsLoad:test_account()
    local settings = GwSettings:new()
    lu.assertEquals(GreenWallAccount.log, true)
    lu.assertEquals(GreenWallAccount.logsize, 1024)
    lu.assertEquals(GreenWallAccount.ochat, false)
    lu.assertEquals(GreenWallAccount.redact, false)
end


TestSettingsAccess = {}

function TestSettingsAccess:setUp()
    GreenWallMeta = {
        mode = GW_MODE_ACCOUNT,
        created = "2018-01-01 17:28:47",
        updated = "2018-01-01 01:04:46",
    }
    GreenWall = {
        created = "2018-01-01 17:28:47",
        updated = "2018-01-01 01:04:46",
        tag = true,
        achievements = true,
        logsize = 1024,
    }
    GreenWallAccount = {
        created = "2018-01-01 17:28:47",
        updated = "2018-01-01 01:04:46",
        tag = false,
        achievements = false,
        logsize = 2048,
    }
end

function TestSettingsAccess:test_get()
    local settings = GwSettings:new()

    lu.assertEquals(settings:get('mode'), GW_MODE_ACCOUNT)

    lu.assertEquals(settings:get('tag'), false)
    lu.assertEquals(settings:get('achievements'), false)
    lu.assertEquals(settings:get('logsize'), 2048)

    lu.assertEquals(settings:get('tag',GW_MODE_CHARACTER), true)
    lu.assertEquals(settings:get('achievements', GW_MODE_CHARACTER), true)
    lu.assertEquals(settings:get('logsize', GW_MODE_CHARACTER), 1024)

    settings:set('mode', GW_MODE_CHARACTER)
    lu.assertEquals(settings:get('mode'), GW_MODE_CHARACTER)

    lu.assertEquals(settings:get('tag'), true)
    lu.assertEquals(settings:get('achievements'), true)
    lu.assertEquals(settings:get('logsize'), 1024)

    lu.assertEquals(settings:get('tag', GW_MODE_ACCOUNT), false)
    lu.assertEquals(settings:get('achievements', GW_MODE_ACCOUNT), false)
    lu.assertEquals(settings:get('logsize', GW_MODE_ACCOUNT), 2048)
end

function TestSettingsAccess:test_set()
    local settings = GwSettings:new()

    settings:set('mode', GW_MODE_ACCOUNT)
    lu.assertEquals(settings:get('tag', GW_MODE_ACCOUNT), false)
    lu.assertEquals(settings:get('tag', GW_MODE_CHARACTER), true)

    settings:set('tag', true)
    lu.assertEquals(settings:get('tag', GW_MODE_ACCOUNT), true)
    lu.assertEquals(settings:get('tag', GW_MODE_CHARACTER), true)

    settings:set('mode', GW_MODE_CHARACTER)
    settings:set('tag', false)
    lu.assertEquals(settings:get('tag', GW_MODE_ACCOUNT), true)
    lu.assertEquals(settings:get('tag', GW_MODE_CHARACTER), false)
end


TestSettingsUpgrade = {}

function TestSettingsUpgrade:setUp()
    GreenWallMeta = nil
    GreenWall = {
        created = "2018-01-01 17:28:47",
        updated = "2018-01-01 01:04:46",
        ochat = true,
        redact = false,
    }
    GreenWallAccount = nil
end

function TestSettingsUpgrade:test_new()
    local settings = GwSettings:new()
    lu.assertEquals(type(GreenWallMeta), 'table')
    lu.assertEquals(type(GreenWall), 'table')
    lu.assertEquals(type(GreenWallAccount), 'table')
end

function TestSettingsUpgrade:test_meta()
    local settings = GwSettings:new()
    lu.assertEquals(GreenWallMeta.mode, GW_MODE_CHARACTER)
end

function TestSettingsUpgrade:test_character()
    local settings = GwSettings:new()
    lu.assertEquals(GreenWall.ochat, true)
    lu.assertEquals(GreenWall.redact, false)
end

function TestSettingsUpgrade:test_account()
    local settings = GwSettings:new()
    lu.assertEquals(GreenWallAccount.ochat, false)
    lu.assertEquals(GreenWallAccount.redact, true)
end


--
-- Run the tests
--

os.exit(lu.run())

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

lu = require('luaunit')
require('Loader')

TestGreenWallChatSend = {}

function TestGreenWallChatSend:setUp()
    self.now = 100
    self.sent = {}
    GetTime = function() return self.now end
    gw.compatibility = {
        name2chat = false,
        identity = false,
        incognito = false,
    }
    gw.config = {
        channel = {
            guild = {
                send = function(_, messageType, message)
                    table.insert(self.sent, { 'GUILD', messageType, message })
                end,
            },
            officer = {
                send = function(_, messageType, message)
                    table.insert(self.sent, { 'OFFICER', messageType, message })
                end,
            },
        },
    }
end

function TestGreenWallChatSend:test_direct_guild_send_from_macro_is_forwarded()
    GreenWall_SendChatMessage('macro message', 'GUILD')

    lu.assertEquals(self.sent, {
        { 'GUILD', GW_MTYPE_CHAT, 'macro message' },
    })
end

function TestGreenWallChatSend:test_typed_message_is_not_forwarded_twice()
    local editbox = {
        GetAttribute = function() return 'GUILD' end,
        GetText = function() return 'typed message' end,
    }

    GreenWall_ParseText(editbox, 1)
    GreenWall_SendChatMessage('typed message', 'GUILD')

    lu.assertEquals(self.sent, {
        { 'GUILD', GW_MTYPE_CHAT, 'typed message' },
    })
end

function TestGreenWallChatSend:test_direct_officer_send_is_forwarded()
    GreenWall_SendChatMessage('officer macro', 'OFFICER')

    lu.assertEquals(self.sent, {
        { 'OFFICER', GW_MTYPE_CHAT, 'officer macro' },
    })
end

function TestGreenWallChatSend:test_other_channels_and_blank_messages_are_ignored()
    GreenWall_SendChatMessage('party message', 'PARTY')
    GreenWall_SendChatMessage('   ', 'GUILD')

    lu.assertEquals(self.sent, {})
end

os.exit(lu.run())

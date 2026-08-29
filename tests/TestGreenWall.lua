lu = require('luaunit')
require('Loader')

TestGreenWallChatSend = {}

function TestGreenWallChatSend:setUp()
    self.now = 100
    self.sent = {}
    self.deferred = {}
    GetTime = function() return self.now end
    C_Timer = {
        After = function(_, callback)
            table.insert(self.deferred, callback)
        end,
    }
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

function TestGreenWallChatSend:runDeferred()
    local deferred = self.deferred
    self.deferred = {}
    for _, callback in ipairs(deferred) do callback() end
end

function TestGreenWallChatSend:test_direct_guild_send_from_macro_is_forwarded()
    GreenWall_SendChatMessage('macro message', 'GUILD')

    lu.assertEquals(self.sent, {})
    self:runDeferred()

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

    lu.assertEquals(self.sent, {})
    self:runDeferred()

    lu.assertEquals(self.sent, {
        { 'OFFICER', GW_MTYPE_CHAT, 'officer macro' },
    })
end

function TestGreenWallChatSend:test_other_channels_and_blank_messages_are_ignored()
    GreenWall_SendChatMessage('party message', 'PARTY')
    GreenWall_SendChatMessage('   ', 'GUILD')
    self:runDeferred()

    lu.assertEquals(self.sent, {})
end

os.exit(lu.run())

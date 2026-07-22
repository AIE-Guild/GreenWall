--[[-----------------------------------------------------------------------

Workarounds for compatibility with other addons

--]]-----------------------------------------------------------------------

--
-- Functions that may need to be overriden
--
-- Patch 1.15.9 (and Retail 11.0) rebuilt the chat frame as a mixin and removed
-- the global ChatFrame_MessageEventHandler outright -- MessageEventHandler is
-- now a method on each chat frame (ChatFrameMixin:MessageEventHandler). Use the
-- global where it still exists; otherwise adapt to the frame method so inbound
-- replication keeps working. ElvUI / Prat override this again below when loaded.
if type(ChatFrame_MessageEventHandler) == 'function' then
    gw.ChatFrame_MessageEventHandler = ChatFrame_MessageEventHandler
else
    gw.ChatFrame_MessageEventHandler = function(frame, ...)
        return frame:MessageEventHandler(...)
    end
end

--
-- Apply workarounds
--
function gw.EnableCompatibility()
    if C_AddOns.IsAddOnLoaded('Identity-2') or C_AddOns.IsAddOnLoaded('Identity') then
        -- Use Identity-2 for adding a chat identifier.
        gw.compatibility.identity = true
        gw.Debug(GW_LOG_NOTICE, 'Identity-2 compatibility enabled.')
    end
    if C_AddOns.IsAddOnLoaded('Name2Chat') then
        -- Use Name2Chat for adding a chat identifier.
        gw.compatibility.name2chat = true
        gw.Debug(GW_LOG_NOTICE, 'Name2Chat compatibility enabled.')
    end
    if C_AddOns.IsAddOnLoaded('Incognito') then
        -- Use Incognito for adding a chat identifier.
        gw.compatibility.incognito = true
        gw.Debug(GW_LOG_NOTICE, 'Incognito compatibility enabled.')
    end
    if C_AddOns.IsAddOnLoaded('ElvUI') then
        -- Use ElvUI's event handler for sending messages to the chat windows
        local status, enabled = pcall(function()
            return ElvUI[1].private.chat.enable
        end)
        if status and enabled then
            gw.compatibility.elvui = true
            local ElvUIChat = ElvUI[1]:GetModule('Chat')
            gw.ChatFrame_MessageEventHandler = function(...)
                ElvUIChat:FloatingChatFrame_OnEvent(...)
            end
            gw.Debug(GW_LOG_NOTICE, 'ElvUI compatibility enabled.')
        end
    elseif C_AddOns.IsAddOnLoaded('Prat-3.0') then
        -- Use Prat's event handler for sending messages to the chat windows
        gw.compatibility.prat = true
        gw.ChatFrame_MessageEventHandler = function(...)
            Prat.Addon.ChatFrame_MessageEventHandler(Prat.Addon, ...)
        end
        gw.Debug(GW_LOG_NOTICE, 'Prat-3.0 compatibility enabled.')
    end
end


--[[-----------------------------------------------------------------------

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

--]]-----------------------------------------------------------------------

--[[-----------------------------------------------------------------------

Workarounds for compatibility with other addons

--]]-----------------------------------------------------------------------

--
-- Functions that may need to be overriden
--
gw.ChatFrame_MessageEventHandler = ChatFrame_MessageEventHandler

--
-- Apply workarounds
--
function gw.EnableCompatibility()
    if IsAddOnLoaded('ElvUI') then
        -- Use ElvUI's event handler for sending messages to the chat windows
        if ElvUI[3].chat.enable then
            local ElvUIChat = ElvUI[1]:GetModule('Chat')
            gw.ChatFrame_MessageEventHandler = ElvUIChat.ChatFrame_OnEvent
            gw.Debug(GW_LOG_NOTICE, 'ElvUI compatibility enabled.')
        end
    elseif IsAddOnLoaded('Prat-3.0') then
        -- Use Prat's event handler for sending messages to the chat windows
        gw.ChatFrame_MessageEventHandler = function (...) Prat.Addon.ChatFrame_MessageEventHandler(Prat.Addon, ...) end
        gw.Debug(GW_LOG_NOTICE, 'Prat-3.0 compatibility enabled.')
    end
end


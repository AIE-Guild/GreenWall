--[[-----------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2014 Mark Rogaski

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

--- Add a message to the log file
-- @param msg A string to write to the log.
-- @param level (optional) The log level of the message.  Defaults to 0.
function gw.Log(msg)
    if GreenWall ~= nil and GreenWall.log and GreenWallLog ~= nil then
        local ts = date('%Y-%m-%d %H:%M:%S')
        tinsert(GreenWallLog, format('%s -- %s', ts, msg))
        while # GreenWallLog > GreenWall.logsize do
            tremove(GreenWallLog, 1)
        end
    end
end


--- Write a message to the default chat frame.
-- @param msg The message to send.
function gw.Write(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cffabd473GreenWall:|r ' .. msg)
    gw.Log(msg)
end


--- Write an error message to the default chat frame.
-- @param msg The error message to send.
function gw.Error(msg)
    DEFAULT_CHAT_FRAME:AddMessage('|cffabd473GreenWall:|r |cffff6000[ERROR] ' .. msg)
    gw.Log('[ERROR] ' .. msg)
end


--- Write a debugging message to the default chat frame with a detail level.
-- Messages will be filtered with the "/greenwall debug <level>" command.
-- @param level A positive integer specifying the debug level to display this under.
-- @param msg The message to send.
function gw.Debug(level, msg)

    if GreenWall ~= nil then
        if level <= GreenWall.debug then
            gw.Log(format('[DEBUG/%d] %s', level, msg))
            if GreenWall.verbose then
                DEFAULT_CHAT_FRAME:AddMessage(format('|cffabd473GreenWall:|r |cff778899[DEBUG/%d] %s|r', level, msg))
            end
        end
    end
    
end


--[[-----------------------------------------------------------------------

END

--]]-----------------------------------------------------------------------
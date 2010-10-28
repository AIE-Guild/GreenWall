--[[-----------------------------------------------------------------------

    $Id$

    $HeadURL$

    Copyright (c) 2010; Mark Rogaski.

    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

        * Redistributions of source code must retain the above copyright
          notice, this list of conditions and the following disclaimer.

        * Redistributions in binary form must reproduce the above
          copyright notice, this list of conditions and the following
          disclaimer in the documentation and/or other materials provided
          with the distribution.

        * Neither the name of the copyright holder nor the names of any
          contributors may be used to endorse or promote products derived
          from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
    A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
    OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
    SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
    LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
    DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
    THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


--]]-----------------------------------------------------------------------

--[[-----------------------------------------------------------------------

Global Variables

--]]-----------------------------------------------------------------------

local gwVersion			= "0.9.00";
local gwChannelName 	= "aieCommLink007";
local gwChannelPass 	= "KCRTZ7";
local gwDebugLevel  	= 2;
local gwUpdateInterval 	= 1.0;
local gwUpdateTimer		= 0.0;

--[[-----------------------------------------------------------------------

Convenience Functions

--]]-----------------------------------------------------------------------

local function GreenWall_Write(msg)

	DEFAULT_CHAT_FRAME:AddMessage("|cffff6600GreenWall:|r " .. msg);

end


local function GreenWall_Error(msg)

	DEFAULT_CHAT_FRAME:AddMessage("|cffff6600GreenWall:|r [ERROR] " .. msg);

end


local function GreenWall_Debug(level, msg)

	if level <= gwDebugLevel then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff6600GreenWall:|r [ERROR] " .. msg);
	end
	
end

local gwChatWindowTable = {};

local function GreenWall_JoinChannel()
	--
	-- Open the communication link
	--
	local id, name = JoinTemporaryChannel(gwChannelName, gwChannelPass);
		
	if name then
		gwChannelName = name;
	end
		
	if not id then
	
		GreenWall_Error("Cannot create communication channel");

	else 
	
		--
		-- Hide the channel
		--
		for i = 1, 10 do
			gwChatWindowTable = { GetChatWindowChannels(i) };
			for j, v in ipairs(gwChatWindowTable) do
				if v == gwChannelName then
					local frame = "ChatFrame" .. i;
					if _G[frame] then
						ChatFrame_RemoveChannel(frame, gwChannelName);
					end
				end
			end
		end
		
	end
	
end


--[[-----------------------------------------------------------------------

Initialization

--]]-----------------------------------------------------------------------

function GreenWall_OnLoad(self)

	--
    -- Trap the events we are interested in
    --
    self:RegisterEvent("ADDON_LOADED");
    self:RegisterEvent("PLAYER_ENTERING_WORLD");
    self:RegisterEvent("CHANNEL_UI_UPDATE");
    self:RegisterEvent("CHAT_MSG_CHANNEL");
    self:RegisterEvent("CHAT_MSG_GUILD");

end


--[[-----------------------------------------------------------------------

Frame Event Functions

--]]-----------------------------------------------------------------------

local gwChannelTable = {};

function GreenWall_OnEvent(self, event, ...)

	if event == "ADDON_LOADED" and select(1, ...) == "GreenWall" then

		GreenWall_Write("v" .. gwVersion .. "loaded.");			

	elseif event == "PLAYER_ENTERING_WORLD" then

		GreenWall_JoinChannel();
				
	elseif event == "CHANNEL_UI_UPDATE" then
	
		local connected = false;
		
		gwChannelList = { GetChannelList() };
		for i, v in ipairs(gwChannelList) do
			if v == gwChannelName then
				connected = true;
				break;
			end
		end
		
		if not connected then
			GreenWall_JoinChannel();
		end
	
	end

end


--[[-----------------------------------------------------------------------

END

--]]-----------------------------------------------------------------------

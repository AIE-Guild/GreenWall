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

local gwVersion			= GetAddOnMetadata("GreenWall", "Version");

local gwPlayerName 		= UnitName("Player");
local gwPlayerLanguage	= GetDefaultLanguage("Player");

local qwConfigString	= '';
local gwChannelName 	= '';
local gwChannelNumber	= 0;
local gwChannelPass 	= '';
local gwContainerId		= '';

local gwUpdateInterval 	= 1.0;
local gwUpdateTimer		= 0.0;

local gwDebugLevel  	= 2;


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
		DEFAULT_CHAT_FRAME:AddMessage("|cffff6600GreenWall:|r [DEBUG] " .. msg);
	end
	
end


local gwChatWindowTable = {};

local function GreenWall_JoinChannel()

	if gwChannelName then
	
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
	
			GreenWall_Debug(1, format('joined channel %s', gwChannelName));
			gwChannelNumber = GetChannelName(gwChannelName);
			
			--
			-- Hide the channel
			--
			for i = 1, 10 do
				gwChatWindowTable = { GetChatWindowMessages(i) };
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
	
end


--[[-----------------------------------------------------------------------

Initialization

--]]-----------------------------------------------------------------------

function GreenWall_OnLoad(self)

	--
    -- Trap the events we are interested in
    --
    self:RegisterEvent('ADDON_LOADED');
    self:RegisterEvent('CHANNEL_UI_UPDATE');
	self:RegisterEvent('PLAYER_ENTERING_WORLD');
    self:RegisterEvent('GUILD_ROSTER_UPDATE');
    self:RegisterEvent('CHAT_MSG_GUILD');
    self:RegisterEvent('CHAT_MSG_CHANNEL');


end


--[[-----------------------------------------------------------------------

Frame Event Functions

--]]-----------------------------------------------------------------------

local gwChannelTable = {};

function GreenWall_OnEvent(self, event, ...)

	GreenWall_Debug(2, format('got event %s', event));

	if event == 'ADDON_LOADED' and select(1, ...) == 'GreenWall' then

		GreenWall_Write(format('v%s loaded.', gwVersion));			

	elseif event == 'CHANNEL_UI_UPDATE' then
	
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
	
	elseif event == 'PLAYER_ENTERING_WORLD' then

		GuildRoster();

	elseif event == 'GUILD_ROSTER_UPDATE' then
	
		local guildInfo = { strsplit("\n", GetGuildInfoText()) };
		local configString = strmatch(GetGuildInfoText(), '(GW:%w+:%w+:%w+)');
		
		if configString then
			GreenWall_Debug(2, format('found configuration: %s', configString));
		end
				
		if gwConfigString ~= configString then
		
			--
			-- Leave the old channel
			--
			LeaveChannelByName(gwChannelName);
		
			gwConfigString = configString;
			_, gwChannelName, gwChannelPass, gwContainerId = strsplit(':', configString);
				
			GreenWall_Write(format('channel: %s, container: %s',
					gwChannelName, gwContainerId));
	
			GreenWall_JoinChannel();
			
		end				

	elseif event == 'CHAT_MSG_GUILD' then
	
		local message, sender, language, _, _, flags, _, chanNum = select(1, ...);
				
		if sender ~= gwPlayerName then
		
			local index = GetChannelName(gwChannelName);
			SendChatMessage(message , "CHANNEL", nil, index); 
		
		end
	
	elseif event == 'CHAT_MSG_CHANNEL' then
	
	end

end


--[[-----------------------------------------------------------------------

END

--]]-----------------------------------------------------------------------

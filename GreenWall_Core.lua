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

local gwConfigString	= '';
local gwChannelName 	= nil;
local gwChannelNumber	= 0;
local gwChannelPass 	= nil;
local gwContainerId		= nil;
local gwPeerTable		= {};

local gwDebug			= 0;
local gwChannelTable	= {};
local gwChatWindowTable = {};
local gwFrameTable		= {};

local gwAddonLoaded		= false;


--[[-----------------------------------------------------------------------

Convenience Functions

--]]-----------------------------------------------------------------------

local function GwWrite(msg)

	DEFAULT_CHAT_FRAME:AddMessage("|cffff6600GreenWall:|r " .. msg);

end


local function GwError(msg)

	DEFAULT_CHAT_FRAME:AddMessage("|cffff6600GreenWall:|r [ERROR] " .. msg);

end


local function GwDebug(level, msg)

	if level <= gwDebug then
		DEFAULT_CHAT_FRAME:AddMessage(
				format('|cffff6600GreenWall:|r |c9482C900[DEBUG/%d] %s|r', level, msg));
	end
	
end


local function GwIsConnected()

	--
	-- Refresh the list of chat frames with guild chat
	--
	table.wipe(gwFrameTable);
	for i = 1, 10 do
		local ChatWindowTable = { GetChatWindowMessages(i) }
    	for _, v in ipairs(ChatWindowTable) do
       		if v == "GUILD" then
       			tinsert(gwFrameTable, i)
       		end
    	end 
   	end
	
	--
	-- Look for an existing connection
	--
	gwChannelList = { GetChannelList() };
	for i, v in ipairs(gwChannelList) do
		if v == gwChannelName then
			return true;
		end
	end

	return false;
			
end


local function GwJoinChannel(name, pass, container)

	if gwChannelName then
		--
		-- Leave the old channel
		--
		if gwChannelName then
			LeaveChannelByName(gwChannelName);
			GwDebug(1, format('left channel: %s', gwChannelName));
		end
	end
	
	if name then
		--
		-- Open the communication link
		--
		local id, altName = JoinTemporaryChannel(name, pass);
		
		if sysName then
			gwChannelName = altName;
		else
			gwChannelName = name;
		end
		
		if not id then

			GwError(format('cannot create communication channel: %s', name));

		else
	
			gwChannelNumber = GetChannelName(gwChannelName);
			gwContainerId = container;
			GwDebug(1, format('joined channel %s (%d)', gwChannelName, gwChannelNumber));
			
			--
			-- Hide the channel
			--
			for i = 1, 10 do
				gwChatWindowTable = { GetChatWindowMessages(i) };
				for j, v in ipairs(gwChatWindowTable) do
					if v == gwChannelName then
						local frame = "ChatFrame" .. i;
						if _G[frame] then
							GwDebug(2, format('hiding channel %s in %s', 
									gwChannelName, frame));
							ChatFrame_RemoveChannel(frame, gwChannelName);
						end
					end
				end
			end
		
		end
		
	end
	
end


local function GwRefreshComms()

	-- We will rebuild the list of peer container guilds
	wipe(gwPeerTable);

	for buffer in gmatch(GetGuildInfoText(), 'GW:([^\n]+)') do
		
		if buffer ~= nil then
						
			buffer = strtrim(buffer);
			local vector = { strsplit(':', buffer) };
			
			if vector[1] == 'c' then
				
				if not GwIsConnected() or buffer ~= gwConfigString then
					GwDebug(2, 'client not connected.');
					GwDebug(2, format('joining channel: %s', vector[2]));
					gwConfigString 	= buffer;
					GwJoinChannel(vector[2], vector[3], vector[4]);
				else
					GwDebug(2, 'client already connected.');
				end
				
			elseif vector[1] == 'p' then
		
				gwPeerTable[vector[2]] = vector[3];
				GwDebug(2, format('added peer: %s (%s)', vector[2], vector[3]));
		
			end
		
		end
		
	end		

end


local function FindRankingMember()

	SortGuildRoster('rank');
	local n = GetNumGuildMembers(true);

	for i = i, n do
		local name, _, rank, _, _, _, _, _, online = GetGuildRosterInfo(i);
		if online then
			GuildControlSetRank(i);
			local _, _, ochat = GuildControlGetRankFlags();
			if ochat then
				return name;
			end
		end
	end
	
end




--[[-----------------------------------------------------------------------

Slash Command Handler

--]]-----------------------------------------------------------------------

local function GwSlashCmd(message, editbox)

	-- to do

end


--[[-----------------------------------------------------------------------

Initialization

--]]-----------------------------------------------------------------------

function GreenWall_OnLoad(self)

	-- 
	-- Set up slash commands
	--
	SLASH_GREENWALL1, SLASH_GREENWALL2 = '/greenwall', '/gw';	
	SlashCmdList['GREENWALL'] = GwSlashCmd;
	
	--
    -- Trap the events we are interested in
    --
    self:RegisterEvent('ADDON_LOADED');
    self:RegisterEvent('CHANNEL_UI_UPDATE');
	self:RegisterEvent('PLAYER_ENTERING_WORLD');
    self:RegisterEvent('GUILD_ROSTER_UPDATE');
    self:RegisterEvent('GUILD_EVENT_LOG_UPDATE');
    self:RegisterEvent('CHAT_MSG_GUILD');
    self:RegisterEvent('CHAT_MSG_CHANNEL');
    self:RegisterEvent('CHAT_MSG_CHANNEL_NOTICE_USER');
    
end


--[[-----------------------------------------------------------------------

Frame Event Functions

--]]-----------------------------------------------------------------------

function GreenWall_OnEvent(self, event, ...)

	GwDebug(4, format('got event %s', event));

	if event == 'ADDON_LOADED' and select(1, ...) == 'GreenWall' then
		
		GwWrite(format('v%s loaded.', gwVersion));			
		gwAddonLoaded = true;
		
	elseif event == 'CHANNEL_UI_UPDATE' then
	
		if not GwIsConnected() then
			GwJoinChannel(gwChannelName, gwChannelPass);
		end
	
	elseif event == 'PLAYER_ENTERING_WORLD' then

		GuildRoster();

	elseif event == 'GUILD_ROSTER_UPDATE' or event == 'GUILD_EVENT_LOG_UPDATE' then
	
		GwRefreshComms();

	elseif event == 'CHAT_MSG_GUILD' then
	
		local message, sender, language, _, _, flags, _, chanNum = select(1, ...);
				
		if sender == gwPlayerName then
		
			local payload = strsub(format('C#%s', message), 1, 255);
			GwDebug(2, format('sending message from %s to %d', sender, gwChannelNumber));
			SendChatMessage(payload , "CHANNEL", nil, gwChannelNumber); 
		
		end
	
	elseif event == 'CHAT_MSG_CHANNEL' then
	
		local payload, sender, language, _, _, flags, _, 
				chanNum, _, _, counter, guid = select(1, ...);
		
		GwDebug(3, format('saw message from %s to on channel %d', sender, chanNum));
		
		if chanNum == gwChannelNumber and sender ~= gwPlayerName then
		
			local opcode, message = payload:match('^(%a)#(.*)');
			
			if opcode == nil then
			
				GwDebug(1, 'Invalid message received on common channel.');
			
			elseif opcode == 'C' then
		
				for i, v in ipairs(gwFrameTable) do
					local frame = 'ChatFrame' .. v;
					if _G[frame] then
						GwDebug(2, format('sending message from %s to guild', sender));
						ChatFrame_MessageEventHandler(_G[frame], 'CHAT_MSG_GUILD', message, 
								sender, language, '', '', '', 0, 0, '', 0, counter, guid);
					end
				end
			
			end
		
		end
		
	elseif event == 'CHAT_MSG_CHANNEL_NOTICE_USER' then
	
		local message, sender, _, _, target, _, _, chanNum = select(1, ...);
		GwDebug(2, strjoin(', ', message, sender, target, chanNum));	
	
	end

end


--[[-----------------------------------------------------------------------

END

--]]-----------------------------------------------------------------------

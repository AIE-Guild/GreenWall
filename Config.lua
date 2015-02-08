--[[-----------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2015 Mark Rogaski

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

Imported Libraries

--]]-----------------------------------------------------------------------

local crc = LibStub:GetLibrary("Hash:CRC:16ccitt-1.0")


--[[-----------------------------------------------------------------------

Class Variables

--]]-----------------------------------------------------------------------

GwConfig = {}
GwConfig.__index = GwConfig


--- GwConfig constructor function.
-- @return An initialized GwConfig instance.
function GwConfig:new()
    local self = {}
    setmetatable(self, GwConfig)
    self:initialize_param()
    self:initialize_state()
    return self
end


--- Initialize a GwConfig object with the default parameters.
-- @return The initialized GwConfig instance.
function GwConfig:initialize_param()
    self.valid = false
    self.major_version = 0
    self.minimum = 0
    self.guild_id = ''
    self.peer = {}
    return self
end


--- Initialize a GwConfig object with the default state.
-- @return The initialized GwConfig instance.
function GwConfig:initialize_state()
    self.channel = {
        guild   = GwChannel:new(),
        officer = GwChannel:new(),
    }
    self.timer = {
        channel = GwHoldDown:new(GW_TIMEOUT_CHANNEL_HOLD),
        config  = GwHoldDown:new(GW_TIMEOUT_CONFIG_HOLD),
        reload  = GwHoldDown:new(GW_TIMEOUT_RELOAD_HOLD),
    }
    self.comember_cache = GwHoldDownCache:new(GW_CACHE_COMEMBER_HOLD,
            GW_CACHE_COMEMBER_SOFT_MAX, GW_CACHE_COMEMBER_HARD_MAX)
            
    return self
end


--- Dump configuration attributes.
function GwConfig:dump(keep)
    local function dump_tier(t, level)
        level = level == nil and 0 or level 
        local indent = strrep('  ', level)
        local index = {}
        for i in pairs(t) do
            table.insert(index, i)
        end
        table.sort(index)
        for i, k in ipairs(index) do
            if type(t[k]) == 'table' then
                gw.Write("%s%s:", indent, k, tostring(t[k]))
                dump_tier(t[k], level + 1)
            else
                if type(t[k]) == 'string' then
                    if k == 'name' or k == 'password' then
                        gw.Write("%s%s = <<%04X>>", indent, k, crc.Hash(tostring(t[k])))
                    else
                        gw.Write("%s%s = '%s'", indent, k, tostring(t[k]))
                    end
                else
                    gw.Write("%s%s = %s", indent, k, tostring(t[k]))
                end
            end 
        end
    end
    
    dump_tier(self, 0)
end


--- Parse the guild information page to gather configuration information.
-- @return True if successful, false otherwise.
function GwConfig:load()
    local function substitute(cstr, xlat)
        local estr, count = string.gsub(cstr, '%$(%a)', function(s) return xlat[s] end)
        if count > 0 then
            gw.Debug(GW_LOG_DEBUG, "guild_conf: expanded '%s' to '%s'", cstr, estr)
        end
        return estr
    end
    
    local function get_gm_officer_note()
        if not gw.IsOfficer() then
            return
        end
        
        local n = GetNumGuildMembers();
        local name, rank, note
        for i = 1, n do
            name, _, rank, _, _, _, _, note = GetGuildRosterInfo(i);
            if rank == 0 then
                gw.Debug(GW_LOG_INFO, 'officer_config: parsing officer note for %s.', name);
                return note;
            end
        end
        return
    end
    
    local xlat = {}                     -- Translation table for string substitution.

    -- Abort if current configuration is valid
    if self.valid then
        return false
    end

    -- Abort if not in a guild
    local guild_name = gw.GetGuildName()
    if guild_name then
        gw.Debug(GW_LOG_INFO, 'guild_conf: co-guild is %s', guild_name)
    else
        gw.Debug(GW_LOG_INFO, 'guild_conf: not in a guild.')
        return false
    end
    
    -- Abort if configuration is not yet available
    local info = GetGuildInfoText()     -- Guild information text.
    if info == '' then
        gw.Debug(GW_LOG_INFO, 'guild_conf: guild configuration not available.')
        return false
    end
    
    gw.Debug(GW_LOG_INFO, 'guild_conf: parsing guild configuration.')
    


    -- Soft reset of configuration
    self:initialize_param()
    
    --
    -- Parse version 1 configuration
    --
    
    -- Guild info
    for buffer in gmatch(info, 'GW:?(%l:[^\n]*)') do
    
        if buffer ~= nil then
        
            self.major_version = 1
            buffer = strtrim(buffer)
            local field = { strsplit(':', buffer) }
        
            if field[1] == 'c' then
                -- Guild channel configuration
                if field[2] and field[2] ~= '' then
                    self.channel.guild:configure(1, field[2], field[3])
                else
                    gw.Error('invalid common channel name specified')
                end

            elseif field[1] == 'p' then
                -- Peer guild
                local peer_name = gw.GlobalName(substitute(field[2], xlat))                
                local peer_id = substitute(field[3], xlat)
                if gw.iCmp(guild_name, peer_name) then
                    self.guild_id = peer_id
                    gw.Debug(GW_LOG_INFO, 'guild_config: guild=%s (%s)', guild_name, peer_id);
                else
                    self.peer[peer_id] = peer_name
                    gw.Debug(GW_LOG_INFO, 'guild_config: peer=%s (%s)', peer_name, peer_id);
                end
            elseif field[1] == 's' then
                local key = field[3]
                local val = field[2]
                if string.len(key) == 1 then
                    xlat[key] = val
                    gw.Debug(GW_LOG_INFO, "guild_config: parser substitution added, '$%s' := '%s'", key, val)
                else
                    gw.Debug(GW_LOG_ERROR, "guild_config: invalid parser substitution key, '$%s'", key)
                end
            elseif field[1] == 'v' then
                -- Minimum version
                if strmatch(field[2], '^%d+%.%d+%.%d+%w*$') then
                    self.minimum = field[2];
                    gw.Debug(GW_LOG_INFO, 'guild_config: minimum version set to %s', self.minimum);
                end
            elseif field[1] == 'o' then
                -- Deprecated option list
                local optlist = { strsplit(',', gsub(field[2], '%s+', '')) }
                for i, opt in ipairs(optlist) do
                    local key, val = strsplit('=', opt)
                    key = strlower(key)
                    val = strlower(val)
                    if key == 'mv' then
                        if strmatch(val, '^%d+%.%d+%.%d+%w*$') then
                            self.minimum = val;
                            gw.Debug(GW_LOG_INFO, 'guild_config: minimum version set to %s', self.minimum);
                        end
                    end
                end
            end
        end
    
    end
    
    -- Officer note
    if GreenWall.ochat then
        local cname, cpass = string.match(get_gm_officer_note(), 'GW:?a:([%w_]*):([%w_]*)')
        if cname and cname~= '' then
            self.channel.officer:configure(1, cname, cpass)
        else
            gw.Error('invalid officer channel name specified')
        end
    end
    
    -- Clean up.
    self.valid = true
    self.timer.config:set()
    
    return true;
    
end


--- Initiate a refresh of the configuration.
-- This is a periodic or user-initiated update.
-- @return True is refresh submitted, false otherwise.
function GwConfig:refresh()
    if self.timer.config:hold() then
        gw.Debug(GW_LOG_DEBUG, 'config_refresh: skipping due to hold-down.')
        return false
    else
        self.valid = false
        GuildRoster()
        gw.Debug(GW_LOG_DEBUG, 'config_refresh: roster update requested.')
        return true
    end
end


--- Initiate a reload of the configuration.
-- This is an update initiated by a reload request.
-- @return True is refresh submitted, false otherwise.
function GwConfig:refresh()
    if self.timer.reload:hold() then
        gw.Debug(GW_LOG_DEBUG, 'config_reload: skipping due to hold-down.')
        return false
    else
        self.valid = false
        GuildRoster()
        self.timer.reload:set()
        gw.Debug(GW_LOG_DEBUG, 'config_reload: roster update requested.')
        return true
    end
end


--- Initiate a reset and reload of the configuration.
-- This is a disruptive reset of the configuration and state.
-- @return True is refresh submitted, false otherwise.
function GwConfig:reset()
    self:initialize_param(true)
    GuildRoster()
    gw.Debug(GW_LOG_DEBUG, 'config_reset: roster update requested.')
    return true
end


--- Check a guild for peer status.
-- @param guild The name of the guild to check.
-- @return True if the target guild is a peer co-guild, false otherwise.
function GwConfig:IsPeer(guild)
    for i, v in pairs(self.peer) do
        if v == guild then
            return true
        end
    end
    return false
end


--- Refresh the channel state.
function GwConfig:refreshChannels()
    if self.timer.channel:hold() then
        gw.Debug(GW_LOG_INFO, 'channel join blocked.')
    else
        gw.Debug(GW_LOG_INFO, 'refreshing channels.')
        for k, v in pairs(self.channel) do
            self.channel[k]:join()
        end
    end
end


--- Check a guild for membership within the confederation.
-- @param guild The name of the guild to check.
-- @return True if the target guild is in the confederation, false otherwise.
function GwConfig:IsContainer(guild)
    if guild == self:GetGuildName() then
        return self.guild_id ~= nil
    else
        return self:IsPeer(guild)
    end
end


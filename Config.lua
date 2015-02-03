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
    self:initialize()
    return self
end


--- Initialize a GwConfig object with the default attributes and state.
-- @param soft If true, keep state intact.
-- @return The initialized GwConfig instance.
function GwConfig:initialize(soft)
    local function new_channel(name, password)
        return {
            name = name ~= nil and name or '',
            password = password ~= nil and password or '',
            number = 0,
            configured = false;
            dirty = false,
            owner = false,
            handoff = false,
            queue = {},
            tx_hash = {},
            stats = {
                sconn = 0,
                fconn = 0,
                leave = 0,
                disco = 0
            }
        }
    end
    
    -- General configuration
    self.major_version = 0
    self.minimum = 0
    self.loaded = false
    
    -- Confederation configuration
    self.guild_id = ''
    self.peer = {}
    
    -- Channel configuration
    if self.channel == nil then
        self.channel = {
            guild = {},
            officer = {},
        }
    end
    for k, v in pairs(self.channel) do
        if self.channel[k].configured == nil then
            self.channel[k] = new_channel()
        end
    end
    
    -- State information
    self.addon_loaded = false
    self.send_who = 0
    self.timeout = {
        config_hold = 0,
        reload_hold = 0,
        channel_hold = 0,
    }
            
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
    
    local info = GetGuildInfoText()     -- Guild information text.
    local xlat = {}                     -- Translation table for string substitution.

    if info == '' then
        gw.Debug(GW_LOG_INFO, 'guild_conf: guild configuration not available.')
        return false
    end
    
    gw.Debug(GW_LOG_INFO, 'guild_conf: parsing guild configuration.')
    
    local guild_name = gw.GetGuildName()
    gw.Debug(GW_LOG_INFO, 'guild_conf: co-guild is %s', guild_name)

    -- Soft reset of configuration
    self:initialize(true)
    
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
                if self.channel.guild.name ~= field[2] then
                    self.channel.guild.name = field[2]
                    self.channel.guild.configured = true
                    self.channel.guild.dirty = true
                end
                if self.channel.guild.password ~= field[3] then
                    self.channel.guild.password = field[3]
                    self.channel.guild.configured = true
                    self.channel.guild.dirty = true
                end
                gw.Debug(GW_LOG_DEBUG, 'guild_config: channel=<<%04X>>, password=<<%04X>>',
                        crc.Hash(self.channel.guild.name),
                        crc.Hash(self.channel.guild.password));
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
        local cname, cpass = string.match(get_gm_officer_note(), 'GW:?a:([%w_]+):([%w_]*)')
        if cname ~= nil then
            self.channel.officer.name = cname
            self.channel.officer.password = cpass ~= nil and cpass or ''
            self.channel.officer.configured = true
            self.channel.officer.dirty = true
            gw.Debug(GW_LOG_DEBUG, 'officer_config: channel=<<%04X>>, password=<<%04X>>',
                        crc.Hash(self.channel.officer.name),
                        crc.Hash(self.channel.officer.password));
        end
    end
    
    return true;
    
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


--- Check whether the configuration hold-down has expired.
-- @param flag (optional) True to start the hold-down, false to clear the hold-down.
-- @return True if the hold-down is still in effect, false if it has expired.
function GwConfig:configHold(flag)    
    local t = time()
    if flag ~= nil then
        if flag then
            self.timeout.config_hold = t + GW_TIMEOUT_CONFIG_HOLD
        else
            self.timeout.config_hold = 1
        end
    end
    return t > self.timeout.config_hold
end


--- Check whether the channel hold-down has expired.
-- @param flag (optional) True to start the hold-down, false to clear the hold-down.
-- @return True if the hold-down is still in effect, false if it has expired.
function GwConfig:channelHold(flag)    
    local t = time()
    if flag ~= nil then
        if flag then
            self.timeout.channel_hold = t + GW_TIMEOUT_CHANNEL_HOLD
        else
            self.timeout.channel_hold = 1
        end
    end
    return t > self.timeout.channel_hold
end


--- Check whether the reload hold-down has expired.
-- @param flag (optional) True to start the hold-down, false to clear the hold-down.
-- @return True if the hold-down is still in effect, false if it has expired.
function GwConfig:reloadHold(flag)    
    local t = time()
    if flag ~= nil then
        if flag then
            self.timeout.reload_hold = t + GW_TIMEOUT_RELOAD_HOLD
        else
            self.timeout.reload_hold = 1
        end
    end
    return t > self.timeout.reload_hold
end


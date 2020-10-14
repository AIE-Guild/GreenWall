--[[-----------------------------------------------------------------------

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

--]]-----------------------------------------------------------------------

--[[-----------------------------------------------------------------------

Imported Libraries

--]]-----------------------------------------------------------------------

local crc = LibStub:GetLibrary("Hash:CRC:16ccitt-1.0")
local semver = LibStub:GetLibrary("SemanticVersion-1.0")


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
    self.cversion = 0
    self.minimum = ''
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
        channel = GwHoldDown:new(gw.settings:get('joindelay')),
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

    gw.Write('[Settings]')
    dump_tier(GreenWall, 0)
    gw.Write('[Configuration]')
    dump_tier(self, 0)
end

--- Dump a status summary.
function GwConfig:dump_status()
    gw.Write('version=%s, cversion=%d, configured=%s', gw.version, self.cversion, tostring(self.valid))
    self.channel.guild:dump_status('guild bridge')
    if gw.IsOfficer() then
        self.channel.officer:dump_status('officer bridge')
    end
end


--- Parse the guild information page to gather configuration information.
-- @return True if successful, false otherwise.
function GwConfig:load()
    local function substitute(cstr, xlat)
        local estr, count = string.gsub(cstr, '%$(%a)', function(s) return xlat[s] end)
        if count > 0 then
            gw.Debug(GW_LOG_DEBUG, "expanded '%s' to '%s'", cstr, estr)
        end
        return estr
    end
    
    local xlat = {}                     -- Translation table for string substitution.

    -- Abort if current configuration is valid
    if self.valid then
        gw.Debug(GW_LOG_DEBUG, 'configuration valid; skipping.')
        return false
    end

    -- Abort if not in a guild
    local guild_name = gw.GetGuildName()
    if guild_name then
        gw.Debug(GW_LOG_INFO, 'co-guild is %s', guild_name)
    else
        gw.Debug(GW_LOG_WARNING, 'not in a guild.')
        return false
    end

    -- Abort if configuration is not yet available
    local info = GetGuildInfoText()     -- Guild information text.
    if info == '' then
        gw.Debug(GW_LOG_WARNING, 'guild configuration not available.')
        return false
    end

    gw.Debug(GW_LOG_INFO, 'parsing guild configuration.')



    -- Soft reset of configuration
    self:initialize_param()
    for k, channel in pairs(self.channel) do
        channel:age()
    end

    -- Update the channel hold-down
    self.timer.channel:set(gw.settings:get('joindelay'))

    --
    -- Check configuration version
    --
    if strmatch(info, 'GWc=".*"') then
        gw.Error('Guild configuration uses a format not supported by this version.')
    end
    if strmatch(info, 'GW:?c:') then
        self.cversion = 1
    end

    if self.cversion == 1 then
        --
        -- Parse version 1 configuration
        --
        for buffer in gmatch(info, 'GW:?(%l:[^\n]*)') do

            if buffer ~= nil then

                self.cversion = 1
                
                -- Groom configuration entries.
                local field = {}
                for i, v in ipairs({ strsplit(':', buffer) }) do
                    field[i] = strtrim(v)
                end

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
                        gw.Debug(GW_LOG_DEBUG, 'guild=%s (%s)', guild_name, peer_id);
                    else
                        self.peer[peer_id] = peer_name
                        gw.Debug(GW_LOG_DEBUG, 'peer=%s (%s)', peer_name, peer_id);
                    end
                elseif field[1] == 's' then
                    local key = field[3]
                    local val = field[2]
                    if string.len(key) == 1 then
                        xlat[key] = val
                        gw.Debug(GW_LOG_DEBUG, "parser substitution added, '$%s' := '%s'", key, val)
                    else
                        gw.Debug(GW_LOG_ERROR, "invalid parser substitution key, '$%s'", key)
                    end
                elseif field[1] == 'v' then
                    -- Minimum version
                    if strmatch(field[2], '^%d+%.%d+%.%d+%w*$') then
                        self.minimum = tostring(semver(field[2]));
                        gw.Debug(GW_LOG_DEBUG, 'minimum version set to %s', self.minimum);
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
                                self.minimum = tostring(semver(val));
                                gw.Debug(GW_LOG_DEBUG, 'minimum version set to %s', self.minimum);
                            end
                        end
                    end
                end
            end
        end

        self.valid = true
    end

    -- Officer note
    if gw.settings:get('ochat') then
        local note = gw.GetGMOfficerNote()
        if note and note ~= '' then
            local cname, cpass = string.match(note, 'GW:?a:([%w_]*):([%w_]*)')
            if cname and cname ~= '' then
                self.channel.officer:configure(1, cname, cpass)
            else
                gw.Error('invalid officer channel name specified')
            end
        else
            gw.Debug(GW_LOG_INFO, 'no officer channel configuration found; skipping.')
        end
    else
        self.channel.officer:clear()
    end

    --
    -- Version check
    --
    local min = semver(self.minimum)
    local cur = semver(gw.version)
    if min and cur then
        if cur < min then
            gw.Error('Guild configuration specifies a minimum version of %s (%s currently installed).', tostring(min), tostring(cur))
        end
    end

    --
    -- Clean up.
    --
    for _, channel in ipairs(self.channel) do
        if channel:is_stale() then
            channel:clear()
        end
    end
    if self.valid then
        self.timer.config:start()
    end

    return true;

end


--- Initiate a reload of the configuration.
-- @return True is refresh submitted, false otherwise.
function GwConfig:reload()
    self.valid = false
    GuildRoster()
    gw.Debug(GW_LOG_INFO, 'roster update requested.')
    return true
end


--- Initiate a refresh of the configuration.
-- This is a reload protected by a hold-down timer.
-- @return True is refresh submitted, false otherwise.
function GwConfig:refresh()
    if self.timer.config:hold() then
        gw.Debug(GW_LOG_WARNING, 'skipping due to hold-down.')
        return false
    else
        return self:reload()
    end
end


--- Initiate a reset and reload of the configuration.
-- This is a disruptive reset of the configuration and state.
-- @return True is refresh submitted, false otherwise.
function GwConfig:reset()
    self:initialize_param(true)
    for _, channel in pairs(self.channel) do
        channel:clear()
    end
    return self:reload()
end


--- Check a guild for peer status.
-- @param guild The name of the guild to check.
-- @return True if the target guild is a peer co-guild, false otherwise.
function GwConfig:is_peer(guild)
    for i, v in pairs(self.peer) do
        if v == guild then
            return true
        end
    end
    return false
end


--- Refresh the channel state.
function GwConfig:refresh_channels()
    if self.timer.channel:hold() then
        gw.Debug(GW_LOG_INFO, 'channel join blocked.')
    else
        gw.Debug(GW_LOG_INFO, 'refreshing channels.')
        self.channel.guild:join()
        if gw.settings:get('ochat') then
            self.channel.officer:join()
        else
            self.channel.officer:leave()
        end
    end
end


--- Check a guild for membership within the confederation.
-- @param guild The name of the guild to check.
-- @return True if the target guild is in the confederation, false otherwise.
function GwConfig:is_container(guild)
    if guild == self:GetGuildName() then
        return self.guild_id ~= nil
    else
        return self:is_peer(guild)
    end
end


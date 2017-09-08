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

--]] -----------------------------------------------------------------------

--[[-----------------------------------------------------------------------

Imported Libraries

--]] -----------------------------------------------------------------------


--[[-----------------------------------------------------------------------

Class Variables

--]] -----------------------------------------------------------------------

GwSettings = {}
GwSettings.__index = GwSettings


--- GwSettings constructor function.
-- @return An initialized GwSettings instance.
function GwSettings:new()
    -- Object instantiation
    local self = {}
    setmetatable(self, GwSettings)

    -- Default Settings
    self._default = {
        mode = {
            value = GW_MODE_ACCOUNT,
            compat = GW_MODE_CHARACTER,
            desc = 'settings mode: account or character',
            control = true,
            opts = {GW_MODE_ACCOUNT, GW_MODE_CHARACTER}
        },
        tag = {
            value = true,
            desc = "co-guild tagging"
        },
        achievements = {
            value = false,
            desc = "co-guild achievement announcements"
        },
        roster = {
            value = true,
            desc = "co-guild roster announcements"
        },
        rank = {
            value = false,
            desc = "co-guild rank announcements"
        },
        debug = {
            value = GW_LOG_NONE,
            min = 0,
            max = 4294967295,
            desc = "debugging level"
        },
        verbose = {
            value = false,
            desc = "verbose debugging"
        },
        log = {
            value = false,
            desc = "event logging"
        },
        logsize = {
            value = 2048,
            min = 0,
            max = 8192,
            desc = "maximum log buffer size"
        },
        ochat = {
            value = false,
            desc = "officer chat bridging"
        },
        redact = {
            value = true,
            desc = "obfuscate sensitive data"
        },
        joindelay = {
            value = 30,
            min = 0,
            max = 120,
            step = 1,
            desc = "channel join delay"
        }
    }
    for k, v in pairs(self._default) do
        self._default[k].type = type(v.value)
    end

    -- Initialize saved settings
    GreenWall = self:initialize(GreenWall)
    GreenWallProfiles = self:initialize(GreenWallProfiles, 'default')
    self._char = GreenWall
    self._acct = GreenWallProfiles.default

    -- Initialize user log
    if GreenWallLog == nil then
        GreenWallLog = {}
    end
    self._log = GreenWallLog

    gw.Debug(GW_LOG_INFO, 'settings initialized')
    return self
end


--- Set the default values and attributes.
-- @param svtable Settings table reference (may be nil).
-- @param profile The name of a shared profile or nil.
-- @return An initialized settings table reference.
function GwSettings:initialize(svtable, profile)
    -- Flag to indicate a fresh installation
    local init = false
    local store

    -- Create the store if necessary
    if svtable == nil then
        svtable = {}
        init = true
    end
    if profile then
        if svtable[profile] == nil then
            svtable[profile] = {}
            init = true
        end
        store = svtable[profile]
    else
        store = svtable
    end
    if init then
        store.created = date('%Y-%m-%d %H:%M:%S')
    end

    -- Groom the valid variables
    for k, v in pairs(self._default) do
        if not profile or not v.control then
            if store[k] == nil or self:validate(k, store[k]) then
                if v.compat and not init then
                    -- use compatibility setting
                    store[k] = v.compat
                else
                    -- use default
                    store[k] = v.value
                end
            end
        end
    end

    -- Update the metadata
    store.version = gw.version
    store.updated = date('%Y-%m-%d %H:%M:%S')

    return svtable
end


--- Reset options to default values.
-- @param svtable Settings table reference
-- @param control True if control options should be reset, false otherwise.
function GwSettings:reset(svtable, control)
    for k, v in pairs(self._default) do
        if not v.control or control then
            if svtable[k] == nil or self:validate(k, svtable[k]) then
                svtable[k] = v.value
            end
        end
    end
end


--- Check if a setting exists.
-- @param name The name of the setting.
-- @return True if the setting exists, false otherwise.
function GwSettings:exists(name)
    return self._default[name] ~= nil
end


--- Get a user setting attribute.
-- @param name The name of the setting.
-- @param attr The setting attribute.
-- @return The setting attribute value.
function GwSettings:getattr(name, attr)
    if self._default[name] == nil then
        return
    else
        return self._default[name][attr]
    end
end


--- Check if a setting is a control variable.
-- @param name The name of the setting.
-- @return True if the setting is a control variable, false otherwise.
function GwSettings:is_control(name)
    if self:exists(name) then
        if self:getattr(name, 'control') then
            return true
        else
            return false
        end
    else
        return false
    end
end


--- Get a user setting value.
-- @param name The name of the setting.
-- @return The setting value.
function GwSettings:get(name)
    if self:exists(name) then
        if self:is_control(name) then
            return self._char[name]
        elseif self._char.mode == GW_MODE_CHARACTER then
            return self._char[name]
        else
            return self._acct[name]
        end
    else
        return
    end
end


--- Set a user setting value.
-- @param name The name of the setting.
-- @param value The value of the setting.
-- @return A string containing an error message on failure, nil on success.
function GwSettings:validate(name, value)
    local function contains(list, item)
        for index, value in ipairs(list) do
            if value == item then
                return true
            end
        end
        return false
    end

    if self._default[name] == nil then
        return string.format('%s is not a valid setting', name)
    else
        local opt_type = self._default[name].type
        if type(value) ~= opt_type then
            return string.format('%s must be a %s value', name, opt_type)
        end
        if opt_type == 'number' then
            if self:getattr(name, 'min') and self:getattr(name, 'min') > value then
                return string.format('%s must be greater than or equal to %d',
                    name, self:getattr(name, 'min'))
            end
            if self:getattr(name, 'max') and self:getattr(name, 'max') < value then
                return string.format('%s must be less than or equal to %d',
                    name, self:getattr(name, 'max'))
            end
        elseif opt_type == 'string' then
            if self:getattr(name, 'opts') and not contains(self:getattr(name, 'opts'), value) then
                return string.format('invalid option for %s: %s', name, value)
            end
        end
    end
    return
end

--- Set a user setting value.
-- @param name The name of the setting.
-- @param value The value of the setting.
-- @return True on success, false on failure.
function GwSettings:set(name, value)
    local err = self:validate(name, value)
    if err then
        gw.Error(err)
        return false
    end

    local curr = self:get(name)
    GreenWall[name] = value

    -- Special handling for value changes
    if curr ~= value then
        gw.Debug(GW_LOG_INFO, 'set %s to %s', name, tostring(value))
        GreenWall.updated = date('%Y-%m-%d %H:%M:%S')

        if name == 'logsize' then
            while #GreenWallLog > value do
                tremove(GreenWallLog, 1)
            end
        elseif name == 'joindelay' then
            gw.config.timer.channel:set(value)
        elseif name == 'ochat' then
            gw.config:reload()
        end
    end

    return true
end


--- Load settings from a user profile.
-- @param profile
-- @return True on success, false on failure.
function GwSettings:load_profile()
    local pdata = GreenWallProfiles[profile]
    if not pdata then
        gw.Error('no profile named %s found', profile)
        return false
    else
        for k, v in pairs(self._default) do
            if pdata[k] then
                self:set(k, pdata[k])
            else
                self:set(k, self._default[k].value)
            end
        end
        return true
    end
end


--- Save settings to a user profile.
-- @param profile
-- @return True on success, false on failure.
function GwSettings:save_profile()
    -- Profile timestamps
    if not GreenWallProfiles[profile] then
        GreenWallProfiles[profile].created = date('%Y-%m-%d %H:%M:%S')
    end
    GreenWallProfiles[profile].updated = date('%Y-%m-%d %H:%M:%S')
    -- Profile data
    for k, v in pairs(self._default) do
        GreenWallProfiles[profile][k] = v
    end
    return true
end

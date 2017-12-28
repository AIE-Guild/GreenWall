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
            meta = true,
            opts = { GW_MODE_ACCOUNT, GW_MODE_CHARACTER }
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
    GreenWallMeta = self:initialize(GreenWallMeta, true)
    GreenWall = self:initialize(GreenWall, false)
    GreenWallAccount = self:initialize(GreenWallAccount, false)
    self._meta = GreenWallMeta
    self._data = {
        [GW_MODE_CHARACTER] = GreenWall,
        [GW_MODE_ACCOUNT] = GreenWallAccount
    }

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
-- @param meta True if the table is metadata for settings, false otherwise.
-- @return An initialized settings table reference.
function GwSettings:initialize(svtable, meta)
    -- Flag to indicate a fresh installation
    local store
    local init = false

    gw.Debug(GW_LOG_INFO, 'initializing settings (meta=%s)', tostring(meta))

    -- Create the store if necessary
    if svtable == nil then
        store = {
            created = date('%Y-%m-%d %H:%M:%S')
        }
        init = true
    else
        store = svtable
    end

    -- Groom the valid variables
    for k, v in pairs(self._default) do
        if meta == v.meta then
            if store[k] == nil or self:validate(k, store[k]) then
                if v.compat and not init then
                    -- use compatibility setting
                    store[k] = v.compat
                else
                    -- use default
                    store[k] = v.value
                end
                gw.Debug(GW_LOG_DEBUG, 'initialized %s to "%s"', k, tostring(store[k]))
            end
        end
    end

    -- Update the metadata
    store.version = gw.version
    store.updated = date('%Y-%m-%d %H:%M:%S')
    return store
end


--- Reset options to default values.
-- @param svtable Settings table reference
-- @param meta True if meta options should be reset, false otherwise.
function GwSettings:reset(svtable, meta)
    for k, v in pairs(self._default) do
        if not v.meta or meta then
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


--- Check if a setting is a meta variable.
-- @param name The name of the setting.
-- @return True if the setting is a meta variable, false otherwise.
function GwSettings:is_meta(name)
    if self:exists(name) then
        if self:getattr(name, 'meta') then
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
        if self:is_meta(name) then
            return self._meta[name]
        else
            local mode = self._meta.mode
            return self._data[mode][name]
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
        for _, value in ipairs(list) do
            if value == item then
                return true
            end
        end
        return false
    end

    if not self:exists(name) then
        return string.format('%s is not a valid setting', name)
    else
        local opt_type = self:getattr(name, 'type')
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
    -- Validate the new value
    local err = self:validate(name, value)
    if err then
        gw.Error(err)
        return false
    end

    -- Apply the new setting
    local curr = self:get(name)
    if self:is_meta(name) then
        self._meta[name] = value
    else
        local mode = self._meta.mode
        self._data[mode][name] = value
    end

    -- Special handling for value changes
    if curr ~= value then
        gw.Debug(GW_LOG_INFO, 'changed %s from %s to %s (%s)',
            name, tostring(curr), tostring(value), self._meta.mode)
        GreenWall.updated = date('%Y-%m-%d %H:%M:%S')

        if name == 'logsize' then
            gw.Debug(GW_LOG_INFO, 'trimming user log')
            while #self._log > value do
                tremove(self._log, 1)
            end
        elseif name == 'joindelay' then
            gw.Debug(GW_LOG_INFO, 'updating channel timers')
            gw.config.timer.channel:set(value)
        elseif name == 'ochat' then
            gw.Debug(GW_LOG_INFO, 'reloading officer chat channel')
            gw.config:reload()
        end
    end

    return true
end


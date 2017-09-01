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

GwUserConfig = {}
GwUserConfig.__index = GwUserConfig



--- GwUserConfig constructor function.
-- @return An initialized GwUserConfig instance.
function GwUserConfig:new()
    local self = {}
    setmetatable(self, GwUserConfig)
    return self
end


--- Set the default values and attributes.
function GwUserConfig:initialize()
    self._default = {
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
            desc = "obfuscate sensitive data in debug output"
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

    -- Initialize the user settings
    if GreenWall == nil then
        GreenWall = { version = gw.version }
    end

    for k, p in pairs(self._default) do
        if GreenWall[k] == nil then
            GreenWall[k] = p.value
        end
    end

    -- Initialize user log
    if GreenWallLog == nil then
        GreenWallLog = {}
    end

    -- Initialize user profiles
    if GreenWallProfiles == nil then
        GreenWallProfiles = {}
    end
end


--- Reset options to default values.
function GwUserConfig:reset()
    for k, p in pairs(self._default) do
        GreenWall[k] = p.value
    end
end


--- Get a user setting value.
-- @param name The name of the setting.
-- @return The setting value.
function GwUserConfig:get(name)
    if self._default[name] == nil then
        return
    else
        return GreenWall[name]
    end
end


--- Get a user setting attribute.
-- @param name The name of the setting.
-- @param attr The setting attribute.
-- @return The setting attribute value.
function GwUserConfig:getattr(name, attr)
    if self._default[name] == nil then
        return
    else
        return self._default[name][attr]
    end
end


--- Set a user setting value.
-- @param name The name of the setting.
-- @param value The value of the setting.
-- @return A string containing an error message on failure, nil on success.
function GwUserConfig:validate(name, value)
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
        end
    end
    return
end

--- Set a user setting value.
-- @param name The name of the setting.
-- @param value The value of the setting.
-- @return True on success, false on failure.
function GwUserConfig:set(name, value)
    err = self:validate(name, value)
    if err then
        return false
    end
    GreenWall[name] = value
    return true
end


--- Load settings from a user profile.
-- @param profile
-- @return True on success, false on failure.
function GwUserConfig:load_profile()
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
function GwUserConfig:save_profile()
    -- Profile timestamps
    if not GreenWallProfiles[profile] then
        GreenWallProfiles[profile].created = os.date('%y-%m-%d %H:%M:%S')
    end
    GreenWallProfiles[profile].updated = os.date('%y-%m-%d %H:%M:%S')
    -- Profile data
    for k, v in pairs(GreenWall) do
        GreenWallProfiles[profile][k] = v
    end
    return true
end

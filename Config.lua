--[[-----------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2018 Mark Rogaski

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

local semver = LibStub:GetLibrary("SemanticVersion-1.0")


--- Configuration data class.
-- @type GwConfig
GwConfig = GwClass()

--- Construct an object instance.
-- @return A GwConfig instance.
function GwConfig:new()
    self.version = nil
    self.guild_name = nil
    self.guild_id = nil
    self.channel = {
        guild = nil,
        officer = nil,
    }
    self.peer = {}
    self.minimum_version = nil
    return self
end


--- Configuration builder class.
-- @type GwClassBuilder
GwConfigBuilder = GwClass()

--- Construct an object instance.
-- @return A GwClassBuilder instance.
function GwConfigBuilder:new()
    self.config = GwConfig:new()
    return self
end

--- Obtain the populated configuration data object.
-- @return A GwConfig instance.
function GwConfigBuilder:get_config()
    return self.config
end

--- Set the configuration version.
-- @param value The configuration version, either 1 or 2.
function GwConfigBuilder:set_version(value)
    assert(value == 1 or value == 2)
    self.config.version = value
end

--- Set the guild name.
-- @param value A string value fort the guild name, may be unqualified.
function GwConfigBuilder:set_guild_name(value)
    assert(value)
    self.config.guild_name = value
end

--- Set the guild ID.
-- @param value A short string that will be used to identify the guild to other co-guilds.
function GwConfigBuilder:set_guild_id(value)
    assert(value)
    self.config.guild_id = value
end

--- Set the guild channel configuration.
-- @param name The channel name.
-- @param password Optional channel password.
-- @param key An optional encryption key for communication across the channel.  Only supported in version 2.
-- @param cipher The optional encryption cipher to use. Only supported in version 2.
function GwConfigBuilder:set_guild_channel(name, password, key, cipher)
    assert(name)
    self.config.channel.guild = {
        name = name,
        password = password,
        key = key,
        cipher = cipher,
    }
end

--- Set the officer channel configuration.
-- @param name The channel name.
-- @param password Optional channel password.
-- @param key An optional encryption key for communication across the channel.  Only supported in version 2.
-- @param cipher The optional encryption cipher to use. Only supported in version 2.
function GwConfigBuilder:set_officer_channel(name, password, key, cipher)
    assert(name)
    self.config.channel.officer = {
        name = name,
        password = password,
        key = key,
        cipher = cipher,
    }
end

--- Add a peer co-guild to the filter list.
-- @param tag A short string that will be used by the co-guild for identification.
-- @param name The name of the peer co-guild.
function GwConfigBuilder:set_peer(tag, name)
    assert(tag and name)
    self.config.peer[tag] = name
end

--- Set the minimum version of GreenWall allowed for use.
-- @param value A version string.
function GwConfigBuilder:set_minimum_version(value)
    assert(value)
    self.config.minimum_version = semver(value)
end

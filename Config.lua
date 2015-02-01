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

Class Variables

--]]-----------------------------------------------------------------------

GwConfig = {}
GwConfig.__index = GwConfig

GwConfig.Options = {
    tag           = { default = true,           desc = "co-guild tagging"                   },
    achievements  = { default = false,          desc = "co-guild achievement announcements" },
    roster        = { default = true,           desc = "co-guild roster announcements"      },
    rank          = { default = false,          desc = "co-guild rank announcements"        },
    debug         = { default = GW_LOG_NONE,    desc = "debugging level"                    },
    verbose       = { default = false,          desc = "verbose debugging"                  },
    log           = { default = false,          desc = "event logging"                      },
    logsize       = { default = 2048,           desc = "maximum log buffer size"            },
    ochat         = { default = false,          desc = "officer chat bridging"              },
}


--- GwConfig constructor function.
-- @return An initialized GwConfig instance.
function GwConfig:new()
    local self = {}
    setmetatable(self, GwConfig)
    self:initialize()
    return self
end


--- Initialize a GwConfig object with the default attributes and state.
-- @param keep If true, update only undefined attributes.
-- @return The initialized GwConfig instance.
function GwConfig:initialize(keep)
    -- General configuration
    self.config_version = nil
    self.minimum_version = 0
    
    -- Confederation configuration
    self.guild_id = nil
    self.peer = {}
    self.channel = {
        guild = {},
        officer = {},
    }
    
    -- Groom parameters
    if keep == nil then
        keep = false
    else
        keep = true
    end
    
    -- Set user options
    for k, v in pairs(GwConfig.Options) do
        if not keep or self[k] == nil then
            self[k] = v.default
        end
    end

    return self
end


--- Dump configuration attributes.
function GwConfig:dump(keep)
    local index = {}
    for i in pairs(self) do
        table.insert(index, i)
    end
    table.sort(index)
    for i, k in ipairs(index) do
        gw.Write("%s = %s", k, tostring(self[k]))
    end
end


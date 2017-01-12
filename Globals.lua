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

--]]-----------------------------------------------------------------------

--[[-----------------------------------------------------------------------

Global Variables

--]]-----------------------------------------------------------------------

--
-- State variables
--
gw = {
    addon_loaded    = false,
    frame_table     = {},
    api_table       = {},
}
gw.version      = GetAddOnMetadata('GreenWall', 'Version')
gw.realm        = GetRealmName()
gw.player       = UnitName('player') .. '-' .. gw.realm:gsub("%s+", "")
gw.guild_status = ''


--
-- Default configuration values
--
gw.option = {
    tag             = { default=true,
                        desc="co-guild tagging" },
    achievements    = { default=false,
                        desc="co-guild achievement announcements" },
    roster          = { default=true,
                        desc="co-guild roster announcements" },
    rank            = { default=false,
                        desc="co-guild rank announcements" },
    debug           = { default=GW_LOG_NONE, min=0, max=4294967295,
                        desc="debugging level" },
    verbose         = { default=false,
                        desc="verbose debugging" },
    log             = { default=false,
                        desc="event logging" },
    logsize         = { default=2048, min=0, max=8192,
                        desc="maximum log buffer size" },
    ochat           = { default=false,
                        desc="officer chat bridging" },
    redact          = { default=true,
                        desc="obfuscate sensitive data in debug output" },
    joindelay       = { default=30, min=0, max=120, step=1,
                        desc="channel join delay" }
}

gw.usage = [[

  Usage:

  /greenwall <command>  or  /gw <command>

  Commands:

  help
        -- Print this message.
  version
        -- Print the add-on version.
  status
        -- Print connection status.
  reload
        -- Reload the configuration.
  reset
        -- Reset communications and reload the configuration.
  achievements <on|off>
        -- Toggle display of confederation achievements.
  roster <on|off>
        -- Toggle display of confederation online, offline, join, and leave messages.
  rank <on|off>
        -- Toggle display of confederation promotion and demotion messages.
  tag <on|off>
        -- Show co-guild identifier in messages.
  ochat <on|off>
        -- Enable officer chat bridging.
  dump
        -- Print configuration and state information.
  debug <level>
        -- Set debugging level to integer <level>.
  redact <on|off>
        -- Obfuscate sensitive information in debug output.
  verbose <on|off>
        -- Toggle the display of debugging output in the chat window.
  log <on|off>
        -- Toggle output logging to the GreenWall.lua file.
  logsize <length>
        -- Specify the maximum number of log entries to keep.
  admin reload
        -- (officer only) Force a reload of the configuration by all online guild members.

]]


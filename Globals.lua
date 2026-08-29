--[[-----------------------------------------------------------------------

Global Variables

--]] -----------------------------------------------------------------------

--
-- State variables
--
gw = {
    addon_loaded = false,
    frame_table = {},
    api_table = {},
    compatibility = { identity = false, name2chat = false, incognito = false, elvui = false, prat = false, },
}
gw.version = C_AddOns.GetAddOnMetadata('GreenWall', 'Version')
gw.realm = GetRealmName()
gw.player = UnitName('player') .. '-' .. gw.realm:gsub("%s+", "")
gw.guild_status = ''

local build_info = { GetBuildInfo() }
gw.build = {
    version = build_info[1],
    number = build_info[2],
    date = build_info[3],
    interface = build_info[4]
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
  roster <on|off>
        -- Toggle display of confederation online, offline, join, and leave messages.
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

]]


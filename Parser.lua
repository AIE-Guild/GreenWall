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

local semver = LibStub:GetLibrary("SemanticVersion-1.0")


--
-- Parser base class
--

GwParser = GwClass()

function GwParser:new(info, note)
    self.info = info
    self.note = note
    return self
end

--- Factory method to produce parser instances.
-- @param info Guild information summary.
-- @return An instance of a GwParser subclass.
function GwParser:get_parser(info, note)
    local version = self:version(info)
    if version == 1 then
        return GwV1Parser:new(info, note)
    elseif version == 2 then
        return GwV2Parser:new(info, note)
    end
    return
end

--- Determine the configuration version.
-- @param info Guild information summary.
-- @return An integer representing configuration version, or nil if no configuration detected.
function GwParser:version(info)
    if string.match(info, 'GWc=".*"') then
        return 2
    elseif string.match(info, 'GW:?c:') then
        return 1
    end
    return
end

function GwParser:split_args(buffer)
    local fields = {}
    for i, v in ipairs({ strsplit(':', buffer) }) do
        fields[i] = strtrim(v)
    end
    return unpack(fields)
end


--
-- Version 1 parser
--

GwV1Parser = GwClass(GwParser)

function GwV1Parser:new(info, note)
    self.info = info
    self.note = note
    self.xlat = {}
    return self
end

function GwV1Parser:substitute(text)
    local output, count = string.gsub(text, '%$(%a)', function(s) return self.xlat[s] end)
    if count > 0 then
        gw.Debug(GW_LOG_DEBUG, "expanded '%s' to '%s'", text, output)
    end
    return output
end



--
-- Version 2 parser
--

GwV2Parser = GwClass(GwParser)


--- Parse version 1 configuration.
-- @param info The guild info tab contents.
-- @param guild_name Co-guild name.
-- @return Configuration table.
function GwParser:get_v1(info, guild_name)
    local conf = {
        version = 1,
        channel = {},
        peer = {}
    }
    local xlat = {}

    for buffer in string.gmatch(info, 'GW:?(%l:[^\n]*)') do

        if buffer ~= nil then

            -- Groom configuration entries.
            local field = {}
            for i, v in ipairs({ strsplit(':', buffer) }) do
                field[i] = strtrim(v)
            end

            if field[1] == 'c' then
                -- Guild channel configuration
                if field[2] and field[2] ~= '' then
                    conf.channel.guild = { name = field[2], password = field[3] }
                else
                    gw.Error('invalid common channel name specified')
                end

            elseif field[1] == 'p' then
                -- Peer guild
                local peer_name = gw.GlobalName(self:substitute(field[2], xlat))
                local peer_id = self:substitute(field[3], xlat)
                if gw.iCmp(guild_name, peer_name) then
                    conf.guild_id = peer_id
                    gw.Debug(GW_LOG_DEBUG, 'guild=%s (%s)', guild_name, peer_id);
                else
                    conf.peer[peer_id] = peer_name
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
                    conf.minimum = tostring(semver(field[2]))
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
                            conf.minimum = tostring(semver(val))
                            gw.Debug(GW_LOG_DEBUG, 'minimum version set to %s', self.minimum);
                        end
                    end
                end
            end
        end
    end

    if conf.guild_id and conf.channel.guild.name then
        return conf
    else
        return
    end
end



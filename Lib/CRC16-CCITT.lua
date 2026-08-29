----------------------------------------------------------------------------
-- Package Definition
----------------------------------------------------------------------------

local VERSION_MAJOR = "Hash:CRC:16ccitt-1.0"
local VERSION_MINOR = 1
local CRC = LibStub:NewLibrary(VERSION_MAJOR, VERSION_MINOR)
if not CRC then
    return
end

----------------------------------------------------------------------------
-- Imports
----------------------------------------------------------------------------

local bxor, band, rshift = bit.bxor, bit.band, bit.rshift


----------------------------------------------------------------------------
-- Functions
----------------------------------------------------------------------------

--- CRC16-CCITT hash function
-- @param str The string to hash.
-- @return The CRC hash.
function CRC.Hash(s)
    assert(type(s) == 'string')
    local crc = 0xffff
    for i = 1, #s do    
        local c = s:byte(i)
        crc = bxor(crc, c)
        for j = 1, 8 do
            local k = band(crc, 1)
            crc = rshift(crc, 1)
            if k ~= 0 then
                crc = bxor(crc, 0x8408)
            end
        end
    end
    return crc
end


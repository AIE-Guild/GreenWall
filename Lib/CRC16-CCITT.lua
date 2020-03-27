--[[--------------------------------------------------------------------------

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

--]]--------------------------------------------------------------------------

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


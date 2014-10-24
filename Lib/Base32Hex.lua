--[[--------------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2014 Mark Rogaski

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

local VERSION_MAJOR = "Encoding:Base32Hex-1.0"
local VERSION_MINOR = 1
local Base32Hex = LibStub:NewLibrary(VERSION_MAJOR, VERSION_MINOR)
if not Base32Hex then
    return
end

--- Encode
-- @param i Integer to convert.
-- @return The base32hex string.
function Base32Hex.Encode(i)
    local digit = nil
    local string = ''
    while i > 0 do
        local k = i % 32
        if k < 10 then
            digit = string.char(k + 48)
        else
            digit = string.char(k + 55)
        end
        string = string .. digit
    end
    return string
end


--- Decode
-- @param s String to convert.
-- @return The integer value.
function Base32Hex.Decode(s)
    local sum = 0
    for c in string.gmatch(s, '.') do
        local i = string.byte(c)
        if i >= 48 and i < 58 then
            sum = sum * 32 + (i - 48)
        elseif i >= 65 and i < 87 then
            sum = sum * 32 + (i - 65)
        elseif i >= 97 and i < 119 then
            sum = sum * 32 + (i - 97)
        else
            return
        end
    end
    return sum
end


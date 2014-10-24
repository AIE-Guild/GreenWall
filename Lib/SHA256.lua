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

----------------------------------------------------------------------------   

The U.S. Government holds U.S. Patent 6,829,355 on the "Device for and method
of one-way cryptographic hashing", which has been incorporated into Federal
Information Processing Standard (FIPS) 180-2. This patent was issued on
December 7, 2004. The National Security Agency has made U.S. Patent 6,829,355
available royalty-free.

--]]--------------------------------------------------------------------------

----------------------------------------------------------------------------
-- Package Definition
----------------------------------------------------------------------------

local VERSION_MAJOR = "Crypto:Hash:SHA256-1.0"
local VERSION_MINOR = 1
local SHA256 = LibStub:NewLibrary(VERSION_MAJOR, VERSION_MINOR)
if not SHA256 then
    return
end


----------------------------------------------------------------------------
-- Imports
----------------------------------------------------------------------------

-- require("bit32")


----------------------------------------------------------------------------
-- Local Functions
----------------------------------------------------------------------------

local bnot    = bit.bnot
local band    = bit.band
local bxor    = bit.bxor
local rrotate = bit.rrotate
local rshift  = bit.rshift

local function badd32(...)
    local sum = 0
    for _, v in ipairs({...}) do
        sum = sum + v
    end
    return band(sum, 0xFFFFFFFF)
end

--
-- Taken from http://lua-users.org/wiki/SecureHashAlgorithm
--
local function num2str(x, n)
    local s = ""
    for i = 1, n do
        local rem = x % 256
        s = string.char(rem) .. s
        x = (x - rem) / 256
    end
    return s
end

--
-- Taken from http://lua-users.org/wiki/SecureHashAlgorithm.
--
local function str2num(s, n, pos)
    assert(n <= 4)
    local x = 0
    for i = pos, pos + n - 1 do
        x = x * 256 + string.byte(s, i)
    end
    return x
end


----------------------------------------------------------------------------
-- Component Functions
----------------------------------------------------------------------------

local function preproc(message)
    local len = string.len(message)
    message = message .. string.char(0x80)
    while string.len(message) % 64 ~= 56 do
        message = message .. string.char(0)
    end
    message = message .. num2str(len * 8, 8)
    return message
end

----------------------------------------------------------------------------
-- User Functions
----------------------------------------------------------------------------

function SHA256.hash(message)
    local H = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }
    
    local K = { 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
                0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
                0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
                0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
                0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
                0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
                0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
                0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
                0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
                0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
                0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
                0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
                0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
                0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
                0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
                0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2 }
    
    message = preproc(message)
    
    for block = 1, string.len(message), 64 do
        local w = {}
        for i = 1, 64 do
            if i <= 16 then
                w[i] = str2num(message, 4, block + (i - 1) * 4)
            else
                local s0 = bxor(rrotate(w[i - 15], 7), rrotate(w[i - 15], 18), rshift(w[i - 15], 3)) 
                local s1 = bxor(rrotate(w[i - 2], 17), rrotate(w[i - 2], 19), rshift(w[i - 2], 10)) 
                w[i] = badd32(w[i - 16] + s0 + w[i - 7] + s1)
            end
        end
    
        local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
        
        for i = 1, 64 do
            local s1    = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
            local ch    = bxor(band(e, f), band(bnot(e), g))
            local temp1 = badd32(h + s1 + ch + K[i] + w[i])
            local s0    = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
            local maj   = bxor(band(a, b), band(a, c), band(b, c))
            local temp2 = badd32(s0 + maj)
            h = g
            g = f
            f = e
            e = badd32(d + temp1)
            d = c
            c = b
            b = a
            a = badd32(temp1 + temp2)
        end
        
        H[1] = H[1] + a
        H[2] = H[2] + b
        H[3] = H[3] + c
        H[4] = H[4] + d
        H[5] = H[5] + e
        H[6] = H[6] + f
        H[7] = H[7] + g
        H[8] = H[8] + h
        
    end
    
    local digest = ""
    for i = 1, 8 do
        digest = digest .. num2str(H[i], 4)
    end
    
    return digest
end


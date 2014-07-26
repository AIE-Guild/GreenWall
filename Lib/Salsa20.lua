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

local VERSION_MAJOR = "Crypto:Cipher:Salsa20-1.0"
local VERSION_MINOR = 1
local Salsa20 = LibStub:NewLibrary(VERSION_MAJOR, VERSION_MINOR)
if not Salsa20 then
    return
end


----------------------------------------------------------------------------
-- Imports
----------------------------------------------------------------------------

local band    = bit.band
local bxor    = bit.bxor
local lrotate = bit.lrotate
local rshift  = bit.rshift


----------------------------------------------------------------------------
-- Local Functions
----------------------------------------------------------------------------

local function apply(f, y, z, slice)
    local iv = {}
    for i, j in ipairs(slice) do
        iv[i] = y[j]
    end
    local ov = f(iv)
    for i, j in ipairs(slice) do
        z[j] = ov[i]
    end
end

local function byte_inc(b)
    local c = 1
    for i = 1, 8 do
        local new = (b[i] + c) % 0xFF
        c = math.floor((b[i] + c) / 0xFF)
        b[i] = new
        if c == 0 then
            break
        end
    end
    return b
end


----------------------------------------------------------------------------
-- Component Functions
----------------------------------------------------------------------------

function Salsa20.quarterround(y)
    assert(#y == 4)
    local z = {}
    z[2] = bxor(y[2], lrotate(y[1] + y[4], 7))
    z[3] = bxor(y[3], lrotate(z[2] + y[1], 9))
    z[4] = bxor(y[4], lrotate(z[3] + z[2], 13))
    z[1] = bxor(y[1], lrotate(z[4] + z[3], 18))
    return z
end

function Salsa20.rowround(y)
    assert(#y == 16)
    local z = {}
    apply(Salsa20.quarterround, y, z, {1, 2, 3, 4})
    apply(Salsa20.quarterround, y, z, {6, 7, 8, 5})
    apply(Salsa20.quarterround, y, z, {11, 12, 9, 10})
    apply(Salsa20.quarterround, y, z, {16, 13, 14, 15})
    return z
end

function Salsa20.columnround(y)
    assert(#y == 16)
    local z = {}
    apply(Salsa20.quarterround, y, z, {1, 5, 9, 13})
    apply(Salsa20.quarterround, y, z, {6, 10, 14, 2})
    apply(Salsa20.quarterround, y, z, {11, 15, 3, 7})
    apply(Salsa20.quarterround, y, z, {16, 4, 8, 12})
    return z
end

function Salsa20.doubleround(y)
    assert(#y == 16)
    return Salsa20.rowround(Salsa20.columnround(y))
end

function Salsa20.littleendian(b)
    assert(#b == 4)
    return b[1] + 2^8 * b[2] + 2^16 * b[3] + 2^24 * b[4]
end

function Salsa20.littleendian_inv(x)
    local b = {}
    for i = 1, 4 do
        b[i] = band(rshift(x, (i - 1) * 8), 0xFF)
    end
    return b
end

function Salsa20.hash(b, rounds)
    rounds = rounds or 20
    assert(#b == 64)
    assert(rounds == 20 or rounds == 12 or rounds == 8)
    local x = {}
    for i = 1, 16 do
        local quad = {}
        for j = 1, 4 do
            quad[j] = b[((i - 1) * 4) + j]
        end
        x[i] = Salsa20.littleendian(quad)
    end
    local z = Salsa20.doubleround(x)
    for i = 1, ((rounds / 2) - 1) do
        z = Salsa20.doubleround(z)
    end
    local h = {}
    for i = 1, 16 do
        local y = Salsa20.littleendian_inv(z[i] + x[i])
        for j = 1, 4 do
            h[((i - 1) * 4) + j] = y[j]
        end 
    end
    return h
end

function Salsa20.expand(k, n)
    assert(#k == 16 or #k == 32)
    assert(#n == 16)

    local c = { string.byte(string.format("expand %2d-byte k", #k), 1, 16) } 
    local x = {}

    for i =  1,  4 do table.insert(x, c[i]) end
    for i =  1, 16 do table.insert(x, k[i]) end
    for i =  5,  8 do table.insert(x, c[i]) end
    for i =  1, 16 do table.insert(x, n[i]) end
    for i =  9, 12 do table.insert(x, c[i]) end
    if #k == 16 then
        for i =  1, 16 do table.insert(x, k[i]) end
    else
        for i = 17, 32 do table.insert(x, k[i]) end
    end
    for i = 13, 16 do table.insert(x, c[i]) end

    return x
end


----------------------------------------------------------------------------
-- User Functions
----------------------------------------------------------------------------

--- Generate the i^th 64-byte block of the Salsa20_k(v) 2^70-byte sequence.
-- @param k A 16-byte or 32-byte sequence representing the secret key.
-- @param v An 8-byte sequence representing the nonce.
-- @param i An 8-byte sequence representing the stream position of the 64-byte block.
-- @param rounds Optional number of rounds. My be 20 (default), 12, or 8.
-- @return A 64-byte output block.
function Salsa20.generate(k, v, i, rounds)
    assert(#k == 16 or #k == 32)
    assert(#v == 8)
    assert(#i == 8)
    local n = {}
    for j = 1, 8 do
        n[j]     = v[j]
        n[j + 8] = i[j]
    end
    return Salsa20.hash(Salsa20.expand(k, n), rounds)
end

--- Encrypt a string.
-- @param key A 16-octet or 32-octet bytestring.
-- @param nonce An 8-octet bytestring nonce.
-- @param plaintext The unencrypted message.
-- @param rounds Optional number of rounds. My be 20 (default), 12, or 8.
-- @return The encrypted message.
function Salsa20.encrypt(key, nonce, plaintext, rounds)
    assert(type(key) == "string" and (key:len() == 16 or key:len() == 32))
    assert(type(nonce) == "string" and nonce:len() == 8)
    assert(type(plaintext) == "string")
    
    local k = { key:byte(1, #key) }
    local v = { nonce:byte(1, #nonce) }
    local i = { 0, 0, 0, 0, 0, 0, 0, 0 }
    local store = {}
    local ciphertext = ""
    
    for _, m in pairs({ plaintext:byte(1, #plaintext) }) do
        if #store == 0 then
            store = Salsa20.generate(k, v, i, rounds)
            i = byte_inc(i)
        end
        local r = table.remove(store, 1)
        ciphertext = ciphertext .. string.char(bxor(m, r))
    end
    return ciphertext
end

--- Decrypt a string.
-- @param key A 16-octet or 32-octet bytestring.
-- @param nonce An 8-octet bytestring nonce.
-- @param ciphertext The encrypted message.
-- @param rounds Optional number of rounds. My be 20 (default), 12, or 8.
-- @return The unencrypted message.
function Salsa20.decrypt(key, nonce, ciphertext, rounds)
    -- The easiest thing I've done all week.
    Salsa20.encrypt(key, nonce, ciphertext, rounds)
end

--- Encrypt a table of strings.
-- @param key A 16-octet or 32-octet bytestring.
-- @param nonce An 8-octet bytestring nonce.
-- @param plaintext The unencrypted messages.
-- @param rounds Optional number of rounds. My be 20 (default), 12, or 8.
-- @return The encrypted messages.
function Salsa20.encrypt_table(key, nonce, plaintext, rounds)
    assert(type(key) == "string" and (key:len() == 16 or key:len() == 32))
    assert(type(nonce) == "string" and nonce:len() == 8)
    assert(type(plaintext) == "table")
    
    local k = { key:byte(1, #key) }
    local v = { nonce:byte(1, #nonce) }
    local i = { 0, 0, 0, 0, 0, 0, 0, 0 }
    local store = {}
    local ciphertext = {}
    
    for _, s in pairs(plaintext) do
        local segment = ""
        for _, m in pairs({ s:byte(1, #s) }) do
            if #store == 0 then
                store = Salsa20.generate(k, v, i, rounds)
                i = byte_inc(i)
            end
            local r = table.remove(store, 1)
            segment = segment .. string.char(bxor(m, r))
        end
        table.insert(ciphertext, segment)
    end
    return ciphertext
end

--- Decrypt a string.
-- @param key A 16-octet or 32-octet bytestring.
-- @param nonce An 8-octet bytestring nonce.
-- @param ciphertext The encrypted messages.
-- @param rounds Optional number of rounds. My be 20 (default), 12, or 8.
-- @return The unencrypted messages.
function Salsa20.decrypt_table(key, nonce, ciphertext, rounds)
    -- The second easiest thing I've done all week.
    return Salsa20.encrypt_table(key, nonce, ciphertext, rounds)
end


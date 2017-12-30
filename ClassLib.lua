--[[--------------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2015-2017 Mark Rogaski

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

--]] --------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Object-oriented base classes
---------------------------------------------------------------------------

--- Generic superclass
-- @param super An optional superclass.
-- @return A class instance.
function GwClass(super)
    local cls = {}
    cls.__index = cls
    setmetatable(cls, super)

    --- Instance constructor
    -- @return An object instance.
    function cls:new(...)
        local obj = {}
        setmetatable(obj, cls)
        return obj
    end

    --- Get the inherited superclass
    -- @return The superclass instance.
    function cls:super()
        return super
    end

    --- Test for inheritance.
    -- @param target Class to test as an ancestor.
    -- @return True is target is an ancestor of the object or class.
    function cls:isa(target)
        local this = cls
        while this ~= nil do
            if this == target then
                return true
            else
                this = this:super()
            end
        end
        return false
    end

    -- Point the metatable to the superclass metatable
    if super ~= nil then
        setmetatable(cls, { __index = super })
    end

    return cls
end

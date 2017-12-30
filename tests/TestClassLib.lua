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

--]]--------------------------------------------------------------------------

lu = require('luaunit')

require('ClassLib')

TestClassLib = {}

function TestClassLib:test_new()
    Foo = Class()

    function Foo:answer()
        return 42
    end

    local obj = Foo:new()
    lu.assertEquals(obj:answer(), 42)
end

function TestClassLib:test_super()
    Foo = Class()
    Bar = Class(Foo)

    function Foo:answer()
        return 42
    end

    function Bar:answer()
        return 43
    end

    local obj = Bar:new()
    local parent = obj:super()
    lu.assertEquals(obj:answer(), 43)
    lu.assertEquals(parent:answer(), 42)
end

function TestClassLib:test_isa()
    Foo = Class()
    Bar = Class(Foo)
    Baz = Class()

    local bar = Bar:new()
    local baz = Baz:new()
    lu.assertTrue(bar:isa(Foo))
    lu.assertTrue(bar:isa(Bar))
    lu.assertFalse(baz:isa(Foo))
end

os.exit(lu.run())

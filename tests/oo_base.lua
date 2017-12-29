--
-- Created by IntelliJ IDEA.
-- User: mrogaski
-- Date: 29-Dec-17
-- Time: 17:06
-- To change this template use File | Settings | File Templates.
--
lu = require('luaunit')

require('Lib/ClassLib')

TestClassLib = {}

function TestClassLib:test_new()
    Foo = Class()

    function Foo:answer()
        return 42
    end

    local obj = Foo:new()
    assertEquals(obj:answer(), 42)
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
    assertEquals(obj:answer(), 43)
    assertEquals(parent:answer(), 42)
end

os.exit(lu.run())

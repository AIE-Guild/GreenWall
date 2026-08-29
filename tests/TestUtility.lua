--
-- Mocks
--

gw = { logmsg = '' }

function gw.Debug(level, format, ...)
    gw.logmsg = string.format(format, ...)
end


--
-- Includes
--

lu = require('luaunit')
require('Loader')


--
-- Test Cases
--

TestUtility = {}

function TestUtility:test_iCmp()
    lu.assertTrue(gw.iCmp("Foo", "FOO"))
    lu.assertTrue(gw.iCmp("Foo", "Foo"))
    lu.assertFalse(gw.iCmp("Foo", "FOOBAR"))
end

function TestUtility:test_GlobalName()
    lu.assertEquals(gw.GlobalName("Ralff", "EarthenRing"), "Ralff-EarthenRing")
    lu.assertEquals(gw.GlobalName("Ralff", "Earthen Ring"), "Ralff-EarthenRing")
    lu.assertEquals(gw.GlobalName("Ralff-EarthenRing"), "Ralff-EarthenRing")
    lu.assertEquals(gw.GlobalName("Ralff-EarthenRing", "EarthenRing"), "Ralff-EarthenRing")
    lu.assertEquals(gw.GlobalName("Ralff"), "Ralff-EarthenRing")
    lu.assertNil(gw.GlobalName(nil))
end

function TestUtility:test_GetItemString()
    local single = 'Testing |Hitem:6948::::::::80::::|h in a string.'
    local multi = 'Testing |Hitem:6948::::::::80::::|h and |Hitem:4388:0:0:0:0:0:0:210677200:80:0:0:0:0|h in a string.'
    lu.assertEquals(gw.GetItemString(single), 'item:6948::::::::80::::')
    lu.assertEquals(gw.GetItemString(multi), 'item:6948::::::::80::::')
    lu.assertEquals(gw.GetItemString('nothing here'), nil)
    lu.assertError(gw.GetItemString)
end


--
-- Run the tests
--

os.exit(lu.run())

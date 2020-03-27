set LUA_PATH="tests/?;tests/?.lua;;"
lua -lluacov tests/TestUtility.lua -v
lua -lluacov tests/TestSettings.lua -v
lua -lluacov tests/TestSystemMessage.lua -v

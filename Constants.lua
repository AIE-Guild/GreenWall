--[[-----------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2010-2014 Mark Rogaski

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

--]]-----------------------------------------------------------------------

--
-- Debugging levels
--
GW_LOG_NONE       = 0
GW_LOG_ERROR      = 1
GW_LOG_WARNING    = 2
GW_LOG_NOTICE     = 3
GW_LOG_INFO       = 4
GW_LOG_DEBUG      = 5 


--
-- Chat types
--
GW_CTYPE_CHAT           = 0
GW_CTYPE_ACHIEVEMENT    = 1
GW_CTYPE_BROADCAST      = 2
GW_CTYPE_NOTICE         = 3
GW_CTYPE_REQUEST        = 4
GW_CTYPE_ADDON          = 5


--
-- Message Flags
--
GW_MSG_END        = 0x01    -- Last segment of a message
GW_MSG_CRYPT      = 0x02    -- Encrypted


--
-- Limits
--
GW_MAX_MESSAGE_LENGTH = 255


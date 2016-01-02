

# GreenWall API Reference

## Purpose

Initially, it was hoped that GreenWall could be extended to bridge
standard add-on messages.  However, the WoW API doesn't have a function
similar to `ChatFrame_MessageEventHandler` that could be used
for add-on messages.

So this simple messaging API is provided for third-party add-on developers
who would like to be able to use the bridged communication on a guild
confederation.

A simple example, which demonstrates the use of the API, is [GWSonar](https://github.com/AIE-Guild/GWSonar).


## Safety First

Before any API functions are called, there are tests that should be
run to verify the environment.

### Individual API checks

#### Check that GreenWall is loaded

```lua
if IsAddOnLoaded('GreenWall') then
	...
end
```

#### Check that the API is supported

```lua
if GreenWallAPI ~= nil then
    ...
end
```

#### Check the API version

```lua

if GreenWallAPI >= 1 then
    ...
end
```

### Unified API check

This combines all of the tests into one function.

```lua
function apiAvailable()
    function testAPI()
        -- Raises and exception of GreenWall is loaded or is pre-1.7.
        assert(IsAddOnLoaded('GreenWall'))
        return GreenWallAPI.version
	end
    
	-- Catch any exceptions
	local found, version = pcall(testAPI)

	return found and version >= 1
end
```


## Sending a Message

To send a message to other instances of the add-on, use the following function.

```lua
GreenWallAPI.SendMessage(addon, message)
```

The __addon__ parameter is either the name of the add-on or '*', which matches 
from any add-on.

## Receiving a Message

The receiving of messages is handled with callbacks. 

### 1. Create the callback

```lua
local function handler(addon, sender, message, echo, guild)
```

The function should accept the following arguments:

- addon - The name of the addon sending the message.
- sender - The player sending the message.
- message - The text of the message.
- echo - Set to true if the message was sent by the player.
- guild - Set to true if the message originated in the player's co-guild.

### 2. Add the handler to the dispatch table

```lua
local id = GreenWallAPI.AddMessageHandler(handler, addon, priority)
```

- handler - The handler function.
- addon - A tag defining the name of the add-on messages will be received from.
  The `*` character can be used to match all add-ons.
- priority - A signed integer.  Lower priority matches are executed earlier.

## Dispatch Table

In addition to the `GreenWallAPI.AddMessageHandler` function to add a handler,
the following functions are available to manage the dispatch table.

### Remove a handler

```lua
local found = GreenWallAPI.RemoveMessageHandler(id)
```

- handler_id - The ID of the handler function.

### Clear one or more handlers

```lua
GreenWallAPI.ClearMessageHandlers(addon)
```

- addon - (Optional) A tag defining the name of the add-on messages will be 
  received from. The `*` character can be used to match all add-ons. If this 
  value is `nil`, all entries will be cleared.

> Note: A `*` value passed as add-on is not a wildcard in this context, it will only matched instances where the handler was installed with `*` as the add-on.


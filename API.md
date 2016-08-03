

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

Arguments:

- addon - The addon name, should the one used for the name of the TOC file.
- message - The message to send. Accepts 8-bit data.


## Receiving a Message

The receiving of messages is handled with callbacks. 

### 1. Create the callback

```lua
local function handler(addon, sender, message, echo, guild)
```

Arguments:

- addon - The name of the addon sending the message.
- sender - The player sending the message.
- message - The text of the message.
- echo - Set to true if the message was sent by the player.
- guild - Set to true if the message originated in the player's co-guild.

### 2. Add the handler to the dispatch table

```lua
local id = GreenWallAPI.AddMessageHandler(handler, addon, priority)
```

Arguments:

- handler - The callback function.
- addon - The name of the addon that you want to receive messages from (the same one used for the name of the TOC file).  If the value '*' is supplied, messages from all addons will be handled.
-  priority - A signed integer indicating relative priority, lower value is handled first.  The default is 0.

Returns:

- The ID that can be used to remove the handler.

## Dispatch Table

In addition to the `GreenWallAPI.AddMessageHandler` function to add a handler,
the following functions are available to manage the dispatch table.

### Remove a handler

```lua
local found = GreenWallAPI.RemoveMessageHandler(id)
```

Arguments:

- handler_id - The ID of the handler function.

### Clear one or more handlers

```lua
GreenWallAPI.ClearMessageHandlers(addon)
```

Arguments:

- addon - (Optional) A tag defining the name of the add-on messages will be 
  received from. The `*` character can be used to match all add-ons. If this 
  value is `nil`, all entries will be cleared.

> Note: A `*` value passed as add-on is not a wildcard in this context, it will only matched instances where the handler was installed with `*` as the add-on.


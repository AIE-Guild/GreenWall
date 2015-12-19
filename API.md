

# GreenWall API Reference

## Purpose

Initially, it was hoped that GreenWall could be extended to bridge
standard add-on messages.  However, the WoW API doesn't have a function
similar to `ChatFrame_MessageEventHandler` that could be used
for add-on messages.

So this simple messaging API is provided for third-party add-on developers
who would like to be able to use the bridged communication on a guild
confederation.

## Safety First

Before any API functions are called, there are two test that should be
run to verify the environment.

1. Check that GreenWall is loaded.

```lua
if IsAddOnLoaded('GreenWall') then
	...
end
```

2. Check that the API is supported.

```lua
if GreenWallAPI ~= nil then
    ...
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

1. Create the callback.

```lua
local function callback(addon, sender, echo, message)
```

The function should accept the following arguments:

- addon - The name of the addon sending the message.
- sender - The player sending the message.
- echo - Set to true if the message was sent by the current player.
- message - The text of the message.

2. Add the handler to the dispatch table. 

```lua
function GreenWallAPI.AddMessageHandler(handler, addon, priority)
    ...
end
```

- handler - The handler function.
- addon - A tag defining the name of the add-on messages will be received from.
- priority - A signed integer.  Lower priority matches are executed earlier.

## Dispatch Table


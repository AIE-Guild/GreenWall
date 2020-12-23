<h1 align="center">
    GreenWall
</h1>

<p align="center">
    A World of Warcraft add-on to bridge guild chat between multiple guilds within a single realm or connected realms.
</p>

<p align="center">
    <a href="#overview">Overview</a> •
    <a href="#installation">Installation</a> •
    <a href="#user-configuration">User Configuration</a> •
    <a href="#guild-configuration">Guild Configuration</a> •
    <a href="#support">Support</a> •
    <a href="#license">License</a> •
    <a href="#dedication">Dedication</a>
</p>

## Overview

[![Build Status](https://travis-ci.org/AIE-Guild/GreenWall.svg?branch=master)](https://travis-ci.org/AIE-Guild/GreenWall)
[![Coverage Status](https://coveralls.io/repos/github/AIE-Guild/GreenWall/badge.svg?branch=master)](https://coveralls.io/github/AIE-Guild/GreenWall?branch=master)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat)](http://makeapullrequest.com)

GreenWall is a World of Warcraft add-on that allows multiple guilds within a single realm, or 
[connected realms](https://us.battle.net/support/en/article/14296) to share guild chat as if they were one guild.
When a member in one guild types something in guild chat, members of the other connected guilds (co-guilds) 
will see what was said and can respond.

GreenWall is similar to other addons like [Guild2Guild](http://www.curse.com/addons/wow/guild2guild) or 
[Cross Guild Chat](http://www.curse.com/addons/wow/crossguildchat_lk), but it meets different design goals.

- Guild members can use GreenWall with zero configuration.
  - All of the necessary configuration work is done by the guild officers.
- There are no special "gateway" members.
  - No one member functions as a gateway for the guild chat traffic, and the bridged guild chat doesn't break when 
    specific members aren't logged in.
- There is no significant impact to the game performance.

Meeting these design goals does have a few requirements.

* All members must have at least one spare custom chat channel available (two for officers if officer chat is also being bridged).
* You must use the Guild Info screen for the configuration.
* The configuration must be identical for all guilds on the "confederation".
* The configuration may be a little intimidating for non-IT types.  But there is a [Quick Start Guide](https://github.com/AIE-Guild/GreenWall/blob/master/GUILD_QUICKSTART.md) for guild officers.


## Installation

### Requirements


- To use GreenWall, you must have fewer than 10 custom channels configured in-game.
  You can see a listing of the custom channels by opening the "Social" window (bound to the `o` key) 
  and selecting the "Chat" tab.
  
- To use GreenWall for officer chat, you must have access to officer notes for guild members.  
  __This can conflict with EPGP add-ons that use the officer note field.__

- To be able to create or edit a co-guild configuration, you must be able to edit the guild information 
  field in the guild management panel (bound to the `j` key).

### Twitch (Curse) App

![Twitch](https://raw.githubusercontent.com/AIE-Guild/GreenWall/assets/img/twitch_purple.png)

GreenWall is officially distributed on [CurseForge](https://www.curseforge.com/wow/addons/greenwall) and 
can be installed and updated with the [Twitch Desktop App](https://app.twitch.tv/).  This is the easiest
installation method and is recommended for most users.

### Manual Installation

GreenWall can also be downloaded from [Github](https://github.com/AIE-Guild/GreenWall/releases) 
and installed manually.

1. Download the compressed distribution file.
2. Close World of Warcaft.
3. Extract the contents of the file and place them in the World of Warcraft AddOns directory.
   - On Windows, `C:\Program Files (x86)\World of Warcraft\Interface\AddOns` or `C:\Program Files\World of Warcraft\Interface\AddOns`.
   - On OSX, `~/Applications/World of Warcraft/Interface/Addons`.
4. Launch World of Warcraft.
5. Click the __AddOns__ button on the character selection screen.
6. Enable the add-on for your character.


## User Configuration

### Graphical Interface

GreenWall was designed to minimize the amount of configuration necessary by most members.  If your officers have 
set up the guild configuration correctly, you don't need to do anything to participate in the conversation between
co-guilds.  However, there are a few options you may want to consider.  

To access the user configuration screen:

1. Open the **Game Menu** by hitting the `Esc` key.

2. Click on the **Interface** button.

3. Select the **AddOns** tab.

4. Click on **GreenWall** in the sidebar.

<p align="center">
    <img src="https://raw.githubusercontent.com/AIE-Guild/GreenWall/assets/img/interface.png" alt="Interface" />
</p>


You will be able to set the following options.

- __mode__ - _Use these settings for all characters on this account_

  If this options is selected, the configuration will be used that is shared will all other characters that have
  this option selected.  Otherwise, a character-specific configuration will be used. 
  
  Default: on
  
  _If GreenWall has been used on the character prior to version 1.9.0, this will default to _off_.

- __tag__ - _Show Co-Guild Tags_

  Show co-guild identifier in messages. 
  
  Default: on

- __roster__ - _Show Co-Guild Roster Announcements_

  Show guild join and leave messages from other co-guilds. 
  
  Default: on 

- __joindelay__ - _Channel Join Delay_

  Adjust the time in seconds GreenWall will wait for a the system default channels (e.g. General, Local Defense). 
  If you have explicitly left these channels, set this low.
  
  Default: 30 seconds

- __ochat__ - _Bridge Officer Chat_

  Show bridge officer chat between the co-guilds. This only works for members who have privileges to view officer notes.

  Default: off 


### Command Line Interface

In addition to the graphical user interface, you can also modify the add-on settings from the prompt in the chat 
window.

All commands must be prefixed with `/greenwall` or `/gw`.

As an example, the configuration option for co-guild tagging is `tag`. To turn it on, you would enter one of the following commands. In the command descriptions, optional arguments are in square brackets and alternatives are separated by the pipe character.

    /greenwall tag on
    /gw tag on

To view the current configuration, you would enter one of the following.

    /greenwall tag
    /gw tag

- mode [ account | character ]

  If `account` is specified, the configuration will be used that is shared will all other characters that have
  this option selected.  Otherwise, a character-specific configuration will be used. 
  
  Default: on
  
  _If GreenWall has been used on the character prior to version 1.9.0, this will default to off_.

- tag [ on | off ]
  
  Show co-guild identifier in messages. 
  
  Default: on

- roster [ on | off ]

  Show guild join and leave messages from other co-guilds. 

  Default: on 

- ochat [ on | off ]

  Show bridge officer chat between the co-guilds. This only works for members who have privileges to view officer notes.
  
  Default: off 

- debug _level_

  Enable debugging at the specified level. The level argument is an integer from 0 to 5. Setting the level to 0 disables debugging. 
  
  Default: 0 

- log [ on | off ]

  Capture debugging output in the `SavedVariables` file. 

  Default: off 

- logsize _length_

  Keep length number log entries in the `SavedVariables` file. 

  Default: 2048 

- verbose [ on | off ]

  Display the debugging output in your chat window. Only do this if you are masochistic. 
  
  Default: off 

- help

  Print a summary of available commands. 

- stats

  Prints a summary of the connection statistics for the common communication channel(s). 

- status
  
  Prints a summary of the GreenWall communication parameters and state variables. 

- reload

  Issues a request to all members of the confederated guilds to reload the configuration. 

- refresh

  Checks and corrects the communications status for the common channel(s). 

- version

  Print the installed version of GreenWall. 


## Guild Configuration

This section covers the somewhat more difficult part, setting up the co-guild configuration that GreenWall uses 
to establish communication with other co-guilds in a confederation.

### Definitions

- Bridging

  Replication of chat events within one guild into the guild and officer chat of another guild.

- Confederation

  A large WoW guild that is partitioned into smaller guilds to comply with Blizzard's guild size limit.

- Container Guild or Co-Guild

  One of the component members of a guild confederation.

- Officer

  A member of any of the co-guilds within a confederation who can view officer notes for members.
  
- Fully Qualified Guild Name

  The name of the guild suffixed with a dash and the name of the realm on which the guild resides. An example is
  `Nightlife-EarthenRing`
  
  Note that there are no spaces in the realm name.
  
- Connected Realms

  In their announcement of [connected realms](https://worldofwarcraft.com/en-us/news/10551009), 
  Bizzard described them as such.
  
  > In Patch 5.4, we’re looking to address this with a new feature called Connected Realms. 
  > Building on our existing cross-realm technology, a Connected Realm is a set of two or 
  > more standard realms that have been permanently and seamless “linked.” These linked realms
  > will behave as if they were one cohesive realm, meaning you’ll be able to join the same guilds,
  > access a single Auction House, run the same Raids and Dungeons, and join other adventurers to
  > complete quests.
  
  You can find a list of North American connected realms [here](https://worldofwarcraft.com/en-us/news/11393305) and
  EU connected realms [here](https://eu.battle.net/forums/en/wow/topic/8715582685).
  
  This is the limit of the scope for GreenWall's communication. If two guilds are on the same realm, or on 
  separate realms that are connected, they can be bridged with GreenWall. 


### Bridging Guild Chat

All configuration for general guild chat is stored in the "Guild Information" field in the "Guild" window (`J`).
The block of configuration text will be read by GreenWall on the member machines.  The benefit of this approach
is that a member can join and use GreenWall without having to perform any special configuration.

All configuration directives use the following format.

    GWx:arglist

The *x* is substituted with a specific opcode and the *arglist* portion is a colon separated list of arguments.

#### Required Configuration
 
- Common Channel
    
      GWc:channel_name:password

  This specifies the custom chat channel to use for all general confederation bridging.

        
- Peer Co-Guild

      GWp:guild_name:tag

  You must specify one of these directives for each co-guild in the confederation, **including the co-guild you
  are configuring**.

  Additionally, the "guild_name" must be match the name of the guild exactly and the tag (a short nickname that
  will be shown if the member enables tagging) must be the same in all of the configurations across the co-guilds.


#### Optional Configuration

- Minimum Version

      GWv:x.y.z

  This disables the GreenWall client if the member is running a version prior to version x.y.z.


#### Example

    GWc:topSekritChan:pencil
    GWv:1.1.00
    GWp:Darkmoon Clan:DMC
    GWp:Baseball Dandies:BBD
    GWp:Nightlife:NL
        

### Bridging Officer Chat


#### Configuration

There is only a single configuration directive for officer chat.  It is stored in the officer note of the guild leader.

    GWa:channel_name:password
        
This specifies the custom chat channel to use for bridging of the officer chat among co-guilds.

By default, officer chat bridging is disabled in the client.  To participate across co-guilds, an officer will need to issue the following command and make sure that officer chat is enabled in one of the chat windows.

    /greenwall ochat on


#### Example

    GWa:secretSquirrels:rosebud


## Support

Support for the GreenWall add-on is voluntary and considered "best effort".  I make a reasonable attempt to respond
to [e-mail](mailto:greenwall@aie-guild.org), comments and questions on the 
[CurseForge page](https://www.curseforge.com/wow/addons/greenwall), and issues raised in 
[Github](https://github.com/AIE-Guild/GreenWall/issues).

The best way to provide information about significant problems you encounter or bugs you find is to follow the guide,
[Collecting Debugging Information](https://github.com/AIE-Guild/GreenWall/wiki/Collecting-Debugging-Information).
  
All bug reports and feature requests should be submitted on Github.  If you aren't comfortable with the Github
issue tracker, please e-mail the details and I will add an issue record.


## License

```

The MIT License (MIT)

Copyright (c) 2010-2020 Mark Rogaski

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
```

## Dedication

<p align="center">
    <img src="https://raw.githubusercontent.com/AIE-Guild/GreenWall/assets/img/ralff.png" alt="Ralff" />
</p>

GreenWall is dedicated in memoriam to the memory of Roger Keith White (1962-2017), known to the members of 
Alea Iacta Est as Ralff.  Not only was he instrumental in the creation and refinement of GreenWall, he was 
the soul of our community writ in flesh and blood.  

_Never again shall we meet such a formidable mountain of intelligence, curiosity, hospitality, 
and non-stop innuendo._

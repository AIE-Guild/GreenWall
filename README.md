<h1 align="center">
    GreenWall
</h1>

<p align="center">
    A World of Warcraft add-on to bridge guild chat between multiple guilds within a single realm or connected realms.
</p>

<p align="center">
    <a href="#overview">Overview</a> •
    <a href="#installation">Installation</a> •
    <a href="#configuration">Configuration</a> •
    <a href="#guides">Guides</a> •
    <a href="#credits">Credits</a> •
    <a href="#license">License</a> •
    <a href="#dedication"></a>
</p>

## Overview

[![Build Status](https://travis-ci.org/AIE-Guild/GreenWall.svg?branch=master)](https://travis-ci.org/AIE-Guild/GreenWall)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

GreenWall is a World of Warcraft add-on that allows multiple guilds within a single realm, or 
[connected realms](https://worldofwarcraft.com/en-us/news/11393305) to share guild chat as if they were one guild.
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


## Configuration

### Guild Members

#### Graphical Interface

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


You will be able to enable or disable the following options.

<dl>
    <dt>Show Co-Guild Tags</dt>
    <dd>Show co-guild identifier in messages. (Default: on)</dd>
    <dt>Show Co-Guild Achievement Announcements</dt>
    <dd>Show achievements from other co-guilds. (Default: off)</dd>
    <dt>Show Co-Guild Roster Announcements</dt>
    <dd>Show guild join and leave messages from other co-guilds. (Default: on)</dd>
    <dt>Show Co-Guild Rank Announcements</dt>
    <dd>Show promotion and demotion messages from other co-guilds. (Default: off)</dd>
    <dt>Channel Join Delay (seconds)</dt>
    <dd>
        Adjust the time GreenWall will wait for a the system default channels (e.g. General, Local Defense). 
        If you have explicitly left these channels, set this low.  (Default: 30 seconds)
    </dd>
    <dt>Bridge Officer Chat</dt>
    <dd>
        Show bridge officer chat between the co-guilds. 
        This only works for members who have privileges to view officer notes. (Default: off)
    </dd>
</dl>

**Show Co-Guild Tags**
> Show co-guild identifier in messages. 
> Default: on

**Show Co-Guild Achievement Announcements**
> Show achievements from other co-guilds. 
> Default: off

**Show Co-Guild Roster Announcements**
> Show guild join and leave messages from other co-guilds. 
> Default: on 

**Show Co-Guild Rank Announcements**
> Show promotion and demotion messages from other co-guilds. 
> Default: off 

**Bridge Officer Chat**
> Show bridge officer chat between the co-guilds. This only works for members who have privileges to view officer notes.
> Default: off 

#### Command Line Interface

All commands must be prefixed with `/greenwall` or `/gw`.

As an example, the configuration option for co-guild tagging is `tag`. To turn it on, you would enter one of the following commands. In the command descriptions, optional arguments are in square brackets and alternatives are separated by the pipe character.

    /greenwall tag on
    /gw tag on

To view the current configuration, you would enter one of the following.

    /greenwall tag
    /gw tag

tag [ on | off ]
> Show co-guild identifier in messages. 
> Default: on

achievements [ on | off ]
> Show achievements from other co-guilds. 
> Default: off

roster [ on | off ]
> Show guild join and leave messages from other co-guilds. 
> Default: on 

rank [ on | off ]
> Show promotion and demotion messages from other co-guilds. 
> Default: off 

ochat [ on | off ]
> Show bridge officer chat between the co-guilds. This only works for members who have privileges to view officer notes.
> Default: off 

debug level
> Enable debugging at the specified level. The level argument is an integer from 0 to 5. Setting the level to 0 disables debugging. 
> Default: 0 

log [ on | off ]
> Capture debugging output in the `SavedVariables` file. 
> Default: off 

logsize length
> Keep length number log entries in the `SavedVariables` file. 
> Default: 2048 

verbose [ on | off ]
> Display the debugging output in your chat window. Only do this if you are masochistic. 
> Default: off 

help
> Print a summary of available commands. 

stats
> Prints a summary of the connection statistics for the common communication channel(s). 

status
> Prints a summary of the GreenWall communication parameters and state variables. 

reload
> Issues a request to all members of the confederated guilds to reload the configuration. 

refresh
> Checks and corrects the communications status for the common channel(s). 

version
> Print the installed version of GreenWall. 


## Dedication

<p align="center">
    <img src="https://raw.githubusercontent.com/AIE-Guild/GreenWall/assets/img/ralff.png" alt="Ralff" />
</p>

GreenWall is dedicated to the memory of Roger Keith White (1962-2017), known to the members of Alea Iacta Est as Ralff.
Not only was he instrumental in the initial release and refinement of GreenWall, he was the soul of our community writ 
in flesh and blood.  

_Never again shall we meet such a formidable mountain of intelligence, curiosity, hospitality, 
and non-stop innuendo._
